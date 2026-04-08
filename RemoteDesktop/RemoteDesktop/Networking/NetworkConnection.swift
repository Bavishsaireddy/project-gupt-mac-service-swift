//
//  NetworkConnection.swift
//  RemoteDesktop
//
//  Wrapper around NWConnection for client connections
//

import Foundation
import Network
import os.log

/// Network connection state
enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case failed(Error)
}

/// Delegate protocol for connection events
protocol NetworkConnectionDelegate: AnyObject {
    func connection(_ connection: NetworkConnection, didChangeState state: ConnectionState)
    func connection(_ connection: NetworkConnection, didReceiveMessage message: NetworkMessage)
    func connection(_ connection: NetworkConnection, didEncounterError error: Error)
}

/// Client-side network connection using NWConnection
@available(macOS 10.14, *)
class NetworkConnection {
    private let connection: NWConnection
    private let codec: MessageCodec
    private let queue: DispatchQueue
    private let logger = Logger(subsystem: "com.remotedesktop", category: "NetworkConnection")

    weak var delegate: NetworkConnectionDelegate?

    private(set) var state: ConnectionState = .disconnected {
        didSet {
            delegate?.connection(self, didChangeState: state)
        }
    }

    private var receiveBuffer = Data()
    private let bufferLock = NSLock()
    private var isProcessingBuffer = false
    private var sequenceNumber: UInt32 = 0
    private let sequenceLock = NSLock()

    // MARK: - Initialization

    /// Initialize with host and port
    init(host: String, port: UInt16, useTLS: Bool = true) {
        self.queue = DispatchQueue(label: "com.remotedesktop.connection", qos: .userInteractive)
        self.codec = MessageCodec()

        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true  // Disable Nagle's algorithm
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveInterval = 5  // seconds

        let parameters: NWParameters
        if useTLS {
            let tlsOptions = NWProtocolTLS.Options()
            // Accept self-signed certificates for now (improve security later)
            sec_protocol_options_set_verify_block(
                tlsOptions.securityProtocolOptions,
                { _, _, completion in
                    completion(true)
                },
                queue
            )
            // Match the host's TLS version requirement
            sec_protocol_options_set_min_tls_protocol_version(tlsOptions.securityProtocolOptions, .TLSv13)
            parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        } else {
            parameters = NWParameters(tls: nil, tcp: tcpOptions)
        }

        self.connection = NWConnection(host: nwHost, port: nwPort, using: parameters)
    }

    /// Initialize with existing NWConnection (for accepted connections)
    init(connection: NWConnection) {
        self.connection = connection
        self.queue = DispatchQueue(label: "com.remotedesktop.connection", qos: .userInteractive)
        self.codec = MessageCodec()
    }

    // MARK: - Connection Management

    /// Start the connection
    func start() {
        state = .connecting
        connection.stateUpdateHandler = { [weak self] newState in
            self?.handleStateUpdate(newState)
        }

        connection.start(queue: queue)
        startReceiving()
    }

    /// Stop the connection
    func stop() {
        connection.cancel()
        state = .disconnected
        bufferLock.lock()
        receiveBuffer.removeAll()
        bufferLock.unlock()
    }

    private func handleStateUpdate(_ newState: NWConnection.State) {
        let stateStr = String(describing: newState)
        logger.info("Connection state: \(stateStr, privacy: .public)")

        switch newState {
        case .ready:
            state = .connected

        case .waiting(let error):
            logger.warning("Connection waiting: \(error.localizedDescription, privacy: .public)")
            state = .connecting

        case .failed(let error):
            logger.error("Connection failed: \(error.localizedDescription, privacy: .public) | \(error.debugDescription, privacy: .public)")
            state = .failed(error)

        case .cancelled:
            state = .disconnected

        default:
            break
        }
    }

    // MARK: - Sending

    /// Send a network message
    func send(_ message: NetworkMessage) async throws {
        guard case .connected = state else {
            throw NetworkError.notConnected
        }

        let data = try await codec.encode(message)

        return try await withCheckedThrowingContinuation { continuation in
            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            )
        }
    }

    /// Send a typed payload
    func sendPayload<T: Codable>(_ payload: T, type: MessageType) async throws {
        let sequence = nextSequence()
        let message = try await codec.encodePayload(payload, type: type, sequence: sequence)
        try await send(message)
    }

    /// Send raw data (for video frames - optimized path)
    func sendVideoFrame(_ frame: VideoFrameMessage) async throws {
        let sequence = nextSequence()
        let data = try await codec.encodeVideoFrame(frame, sequence: sequence)

        return try await withCheckedThrowingContinuation { continuation in
            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            )
        }
    }

    private func nextSequence() -> UInt32 {
        sequenceLock.lock()
        defer { sequenceLock.unlock() }
        let current = sequenceNumber
        sequenceNumber &+= 1  // Wrapping add
        return current
    }

    // MARK: - Receiving

    private func startReceiving() {
        receiveMessage()
    }

    private func receiveMessage() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Receive error: \(error.localizedDescription)")
                self.delegate?.connection(self, didEncounterError: error)
                return
            }

            if let content = content, !content.isEmpty {
                // Thread-safely append to buffer
                self.bufferLock.lock()
                self.receiveBuffer.append(content)
                // Only spin up one processing Task at a time
                let shouldProcess = !self.isProcessingBuffer
                if shouldProcess { self.isProcessingBuffer = true }
                self.bufferLock.unlock()

                if shouldProcess {
                    Task {
                        await self.processReceiveBuffer()
                    }
                }
            }

            if !isComplete {
                self.receiveMessage()  // Continue receiving
            }
        }
    }

    private func processReceiveBuffer() async {
        defer {
            bufferLock.lock()
            isProcessingBuffer = false
            bufferLock.unlock()
        }

        // Drain the buffer in a loop so data that arrived while we were
        // processing is also handled without spawning another Task.
        while true {
            bufferLock.lock()
            let snapshot = receiveBuffer
            bufferLock.unlock()

            guard !snapshot.isEmpty else { break }

            do {
                let (messages, consumed) = try await codec.decodeMultiple(from: snapshot)

                // Remove exactly the bytes we consumed (guard against stale snapshots)
                if consumed > 0 {
                    bufferLock.lock()
                    let safeConsumed = min(consumed, receiveBuffer.count)
                    receiveBuffer.removeFirst(safeConsumed)
                    bufferLock.unlock()
                }

                // Deliver messages
                for message in messages {
                    delegate?.connection(self, didReceiveMessage: message)
                }

                // If we decoded nothing new, stop — more data will trigger a fresh Task
                if messages.isEmpty { break }

            } catch CodecError.insufficientData {
                // Wait for more data to arrive
                break
            } catch {
                logger.error("Failed to decode message: \(error.localizedDescription)")
                delegate?.connection(self, didEncounterError: error)
                break
            }
        }
    }

    // MARK: - Utility

    var isConnected: Bool {
        if case .connected = state {
            return true
        }
        return false
    }
}

// MARK: - Network Error

enum NetworkError: Error, LocalizedError {
    case notConnected
    case connectionFailed
    case sendFailed
    case receiveFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to server"
        case .connectionFailed:
            return "Failed to establish connection"
        case .sendFailed:
            return "Failed to send data"
        case .receiveFailed:
            return "Failed to receive data"
        case .timeout:
            return "Connection timeout"
        }
    }
}
