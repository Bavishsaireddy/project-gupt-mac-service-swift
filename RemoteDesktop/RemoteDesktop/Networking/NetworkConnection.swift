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
    private var sequenceNumber: UInt32 = 0
    private let sequenceLock = NSLock()

    // MARK: - Initialization

    /// Initialize with host and port
    init(host: String, port: UInt16, useTLS: Bool = true) async {
        self.queue = DispatchQueue(label: "com.remotedesktop.connection", qos: .userInteractive)
        self.codec = await MessageCodec()

        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        let parameters: NWParameters
        if useTLS {
            parameters = .tls
            // Configure TLS options
            let tlsOptions = NWProtocolTLS.Options()
            // Accept self-signed certificates for now (improve security later)
            sec_protocol_options_set_verify_block(
                tlsOptions.securityProtocolOptions,
                { _, _, completion in
                    completion(true)
                },
                queue
            )
            parameters.defaultProtocolStack.transportProtocol = tlsOptions
        } else {
            parameters = .tcp
        }

        // Configure TCP options for low latency
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true  // Disable Nagle's algorithm
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveInterval = 5  // seconds
        parameters.defaultProtocolStack.transportProtocol = tcpOptions

        self.connection = NWConnection(host: nwHost, port: nwPort, using: parameters)
    }

    /// Initialize with existing NWConnection (for accepted connections)
    init(connection: NWConnection) async {
        self.connection = connection
        self.queue = DispatchQueue(label: "com.remotedesktop.connection", qos: .userInteractive)
        self.codec = await MessageCodec()
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
        receiveBuffer.removeAll()
    }

    private func handleStateUpdate(_ newState: NWConnection.State) {
        logger.info("Connection state: \(String(describing: newState))")

        switch newState {
        case .ready:
            state = .connected

        case .waiting(let error):
            logger.warning("Connection waiting: \(error.localizedDescription)")
            state = .connecting

        case .failed(let error):
            logger.error("Connection failed: \(error.localizedDescription)")
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
                self.receiveBuffer.append(content)
                Task {
                    await self.processReceiveBuffer()
                }
            }

            if !isComplete {
                self.receiveMessage()  // Continue receiving
            }
        }
    }

    private func processReceiveBuffer() async {
        do {
            let (messages, consumed) = try await codec.decodeMultiple(from: receiveBuffer)

            // Remove processed bytes
            if consumed > 0 {
                receiveBuffer.removeFirst(consumed)
            }

            // Deliver messages
            for message in messages {
                delegate?.connection(self, didReceiveMessage: message)
            }
        } catch CodecError.insufficientData {
            // Wait for more data
            return
        } catch {
            logger.error("Failed to decode message: \(error.localizedDescription)")
            delegate?.connection(self, didEncounterError: error)
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
