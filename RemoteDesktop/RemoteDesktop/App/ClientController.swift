//
//  ClientController.swift
//  GUPT
//
//  Main coordinator for the client-side logic
//

import Foundation
import os.log
import CoreVideo
import CoreMedia
import QuartzCore

/// Coordinates the client-side session and data pipeline
class ClientController: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.gupt", category: "ClientController")
    
    // Published properties for SwiftUI UI
    @Published var isConnected = false
    @Published var currentFrame: CVPixelBuffer?
    @Published var clipboardSyncEnabled = true
    
    // Only the real connection and decoder matter
    private var connection: NetworkConnection?
    private let decoder: VideoDecoder
    private let inputCaptor = InputEventCaptor()
    private let clipboardManager = ClipboardManager()

    // Continuation to bridge async connect() with the delegate callback
    private var connectContinuation: CheckedContinuation<Void, Error>?

    // Mouse throttle: send at most every 16ms (~60Hz)
    private var lastMouseSendTime: CFTimeInterval = 0
    private var pendingMouseEvent: InputEventMessage?
    private var mouseThrottleTimer: Timer?
    
    // MARK: - Initialization
    
    override init() {
        self.decoder = VideoDecoder()
        super.init()
        self.decoder.delegate = self
        self.inputCaptor.delegate = self
        self.clipboardManager.delegate = self
    }
    
    // MARK: - Session Management
    
    /// Connect to a remote host using a room code.
    /// Awaits the WebSocket handshake and throws if it fails.
    func connect(roomCode: String) async throws {
        let safeRoomCode = roomCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let serverURLString = SessionManager.shared.relayServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let baserUrl = serverURLString.hasSuffix("/") ? String(serverURLString.dropLast()) : serverURLString
        guard let url = URL(string: "\(baserUrl)/client/\(safeRoomCode)") else {
            logger.error("Invalid relay server URL")
            throw URLError(.badURL)
        }

        logger.info("Connecting Client to URL: \(url.absoluteString)")

        // Await the actual WebSocket open (or failure) before returning
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectContinuation = continuation
            let newConnection = NetworkConnection(url: url)
            self.connection = newConnection
            newConnection.delegate = self
            newConnection.start()
        }

        inputCaptor.startCapturing()
        logger.info("ClientController connected to room: \(roomCode)")
    }
    
    /// Disconnect from the current host
    func disconnect() async {
        inputCaptor.stopCapturing()
        clipboardManager.stopMonitoring()
        connection?.stop()
        connection = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.currentFrame = nil
        }
        
        // Reset decoder so next session gets fresh SPS/PPS
        decoder.invalidate()
        logger.info("ClientController disconnected")
    }

    // MARK: - Clipboard Control

    func toggleClipboardSync(_ enabled: Bool) {
        clipboardSyncEnabled = enabled
        if enabled && isConnected {
            clipboardManager.startMonitoring()
        } else {
            clipboardManager.stopMonitoring()
        }
    }
}

// MARK: - ClipboardManagerDelegate

extension ClientController: ClipboardManagerDelegate {
    func clipboardManager(_ manager: ClipboardManager, didDetectChange text: String) {
        guard let conn = connection else { return }

        let clipboardMsg = ClipboardMessage(
            text: text,
            timestamp: NetworkMessage.currentTimestamp()
        )

        do {
            let data = try JSONEncoder().encode(clipboardMsg)
            let message = NetworkMessage(
                type: .clipboard,
                sequenceNumber: 0,
                timestamp: clipboardMsg.timestamp,
                payload: data
            )
            Task {
                do {
                    try await conn.send(message)
                    logger.debug("Sent clipboard to host: \(text.prefix(30))...")
                } catch {
                    logger.error("Failed to send clipboard: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to encode clipboard message: \(error.localizedDescription)")
        }
    }
}

// MARK: - InputEventCaptorDelegate

extension ClientController: InputEventCaptorDelegate {
    func captor(_ captor: InputEventCaptor, didCaptureEvent event: InputEventMessage) {
        guard isConnected, let conn = connection else { return }
        
        // Throttle mouse move events to reduce WebSocket overhead
        if event.eventType == .mouseMove {
            let now = CACurrentMediaTime()
            let elapsed = now - lastMouseSendTime
            
            if elapsed < 0.016 { // Less than 16ms since last send
                // Store the pending event, it will be sent by the timer
                pendingMouseEvent = event
                if mouseThrottleTimer == nil {
                    DispatchQueue.main.async {
                        self.mouseThrottleTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: false) { [weak self] _ in
                            guard let self = self, let pending = self.pendingMouseEvent else { return }
                            self.pendingMouseEvent = nil
                            self.mouseThrottleTimer = nil
                            self.sendInputEvent(pending, on: conn)
                        }
                    }
                }
                return
            }
            
            lastMouseSendTime = now
            pendingMouseEvent = nil
        }
        
        sendInputEvent(event, on: conn)
    }
    
    private func sendInputEvent(_ event: InputEventMessage, on conn: NetworkConnection) {
        do {
            let data = try JSONEncoder().encode(event)
            let message = NetworkMessage(
                type: .inputEvent,
                sequenceNumber: 0,
                timestamp: event.timestamp,
                payload: data
            )
            Task {
                do {
                    try await conn.send(message)
                } catch {
                    logger.error("Failed to send input event: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to encode input event: \(error.localizedDescription)")
        }
    }
}

// MARK: - VideoDecoderDelegate

extension ClientController: VideoDecoderDelegate {
    func decoder(_ decoder: VideoDecoder, didDecodeFrame pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        DispatchQueue.main.async {
            self.currentFrame = pixelBuffer
            LatencyMonitor.shared.reportFrameDelivered()
        }
    }
    
    func decoder(_ decoder: VideoDecoder, didEncounterError error: Error) {
        logger.error("Decoder error: \(error.localizedDescription)")
    }
}

// MARK: - NetworkConnectionDelegate

extension ClientController: NetworkConnectionDelegate {
    func connection(_ connection: NetworkConnection, didChangeState state: ConnectionState) {
        switch state {
        case .connected:
            // Resume the connect() continuation successfully
            connectContinuation?.resume(returning: ())
            connectContinuation = nil

            DispatchQueue.main.async {
                self.isConnected = true
                self.logger.info("Connection is ready — waiting for frames")
                if self.clipboardSyncEnabled {
                    self.clipboardManager.startMonitoring()
                }
            }

            // Send a handshake immediately to force the host to generate an I-frame
            Task {
                let handshake = HandshakeMessage(version: "1.0", deviceName: "Client", capabilities: HandshakeMessage.Capabilities(maxResolution: HandshakeMessage.Resolution(width: 1920, height: 1080), supportedCodecs: ["H264"], maxFrameRate: 60))
                if let data = try? JSONEncoder().encode(handshake) {
                    let msg = NetworkMessage(type: .handshake, sequenceNumber: 0, timestamp: NetworkMessage.currentTimestamp(), payload: data)
                    try? await connection.send(msg)
                }
            }

        case .disconnected:
            DispatchQueue.main.async { self.isConnected = false }

        case .failed(let error):
            // Resume the connect() continuation with the error so the UI can show it
            if let cont = connectContinuation {
                connectContinuation = nil
                cont.resume(throwing: error)
            }
            DispatchQueue.main.async {
                self.isConnected = false
                self.logger.error("Connection failed: \(error.localizedDescription)")
            }

        default:
            break
        }
    }
    
    func connection(_ connection: NetworkConnection, didReceiveMessage message: NetworkMessage) {
        switch message.type {
        case .videoFrame:
            do {
                let frameMessage = try JSONDecoder().decode(VideoFrameMessage.self, from: message.payload)
                
                let pts = CMTime(
                    value: Int64(frameMessage.frameSequence),
                    timescale: 30
                )
                
                // Single decode path — directly to VideoDecoder → didDecodeFrame → currentFrame → Metal
                decoder.decodeWithHeaders(
                    data: frameMessage.frameData,
                    presentationTime: pts,
                    sps: frameMessage.sps,
                    pps: frameMessage.pps
                )
                
                logger.debug("Dispatched frame #\(frameMessage.frameSequence) to decoder (keyframe: \(frameMessage.isKeyframe))")
            } catch {
                logger.error("Failed to decode VideoFrameMessage: \(error.localizedDescription)")
            }

        case .clipboard:
            // Receive clipboard from host and apply locally
            do {
                let clipMsg = try JSONDecoder().decode(ClipboardMessage.self, from: message.payload)
                DispatchQueue.main.async {
                    self.clipboardManager.writeToLocalPasteboard(clipMsg.text)
                    self.logger.debug("Applied host clipboard locally: \(clipMsg.text.prefix(30))...")
                }
            } catch {
                logger.error("Failed to decode clipboard message: \(error.localizedDescription)")
            }

        default:
            break
        }
    }
    
    func connection(_ connection: NetworkConnection, didEncounterError error: Error) {
        logger.error("Network error: \(error.localizedDescription)")
    }
}
