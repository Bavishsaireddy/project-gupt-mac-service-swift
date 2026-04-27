//
//  NetworkConnection.swift
//  RemoteDesktop
//
//  WebSocket-based network connection using URLSessionWebSocketTask
//

import Foundation
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

/// WebSocket-based network connection using URLSessionWebSocketTask
class NetworkConnection: NSObject, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private let codec: MessageCodec
    private let url: URL
    private let logger = Logger(subsystem: "com.gupt", category: "NetworkConnection")

    weak var delegate: NetworkConnectionDelegate?

    private(set) var state: ConnectionState = .disconnected {
        didSet {
            delegate?.connection(self, didChangeState: state)
        }
    }

    private var sequenceNumber: UInt32 = 0
    private let sequenceLock = NSLock()

    // MARK: - Initialization

    init(url: URL) {
        self.url = url
        self.codec = MessageCodec()
        super.init()
    }

    // MARK: - Connection Management

    /// Start the connection
    func start() {
        state = .connecting
        logger.info("Connecting WebSocket to: \(self.url.absoluteString)")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300

        session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
    }

    /// Stop the connection
    func stop() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        state = .disconnected
    }

    // MARK: - URLSessionWebSocketDelegate

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        logger.info("WebSocket connected successfully!")
        state = .connected
        startReceiving()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        logger.info("WebSocket closed with code: \(closeCode.rawValue)")
        state = .disconnected
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            // Filter out normal cancellation errors
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled { return }
            
            logger.error("WebSocket task error: \(error.localizedDescription)")
            state = .failed(error)
            delegate?.connection(self, didEncounterError: error)
        }
    }

    // MARK: - Sending

    /// Send a network message
    func send(_ message: NetworkMessage) async throws {
        guard case .connected = state else {
            throw NetworkError.notConnected
        }

        let data = try await codec.encode(message)
        try await webSocketTask?.send(.data(data))
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

        guard case .connected = state else {
            throw NetworkError.notConnected
        }
        try await webSocketTask?.send(.data(data))
    }

    private func nextSequence() -> UInt32 {
        sequenceLock.lock()
        defer { sequenceLock.unlock() }
        let current = sequenceNumber
        sequenceNumber &+= 1
        return current
    }

    // MARK: - Receiving

    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let wsMessage):
                switch wsMessage {
                case .data(let data):
                    self.processReceivedData(data)
                case .string(let text):
                    // Convert text messages to data if needed
                    if let data = text.data(using: .utf8) {
                        self.processReceivedData(data)
                    }
                @unknown default:
                    break
                }
                // Continue receiving the next message
                self.startReceiving()

            case .failure(let error):
                let nsError = error as NSError
                // Don't report cancellation errors
                if nsError.code != NSURLErrorCancelled && nsError.code != 57 {
                    self.logger.error("WebSocket receive error: \(error.localizedDescription)")
                    self.delegate?.connection(self, didEncounterError: error)
                }
            }
        }
    }

    private func processReceivedData(_ data: Data) {
        // Each WebSocket message is a complete codec-framed message
        Task {
            do {
                let (messages, _) = try await codec.decodeMultiple(from: data)
                for message in messages {
                    delegate?.connection(self, didReceiveMessage: message)
                }
            } catch {
                logger.error("Failed to decode message: \(error.localizedDescription)")
                delegate?.connection(self, didEncounterError: error)
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

    /// Returns the remote host IP string, if available.
    var remoteHost: String? {
        return url.host
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
