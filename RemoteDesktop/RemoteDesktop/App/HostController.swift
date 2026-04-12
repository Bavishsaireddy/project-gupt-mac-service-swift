//
//  HostController.swift
//  GUPT
//
//  Main coordinator for the host-side logic
//

import Foundation
import Network
import CoreMedia
import os.log

/// Coordinates the host-side lifecycle and data pipeline
class HostController: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.gupt", category: "HostController")
    
    private var activeConnection: NetworkConnection?
    
    // The shared room code for this session
    @Published var roomCode: String = ""
    
    private let captureManager: ScreenCaptureManager
    private let encoder: VideoEncoder
    private var streamer: FrameStreamer?
    
    private let injector = InputEventInjector()
    private let clipboardManager = ClipboardManager()
    
    // MARK: - Published Properties (for SwiftUI)
    @Published var isRunning = false
    @Published var statusMessage = "Ready"
    
    private var isStarted = false
    
    // MARK: - Initialization
    
    override init() {
        self.captureManager = ScreenCaptureManager()
        self.encoder = VideoEncoder()
        
        super.init()
        
        // Generate random 6-digit room code
        let code = String(format: "%06d", Int.random(in: 100000...999999))
        self.roomCode = code
        
        self.captureManager.delegate = self
        self.encoder.delegate = self
        self.clipboardManager.delegate = self
    }
    
    // MARK: - Lifecycle Management
    
    /// Start the host service
    func start() async throws {
        guard !isStarted else { return }
        
        // 1. Check permissions (Log only, do not block)
        if !ScreenCaptureManager.requestPermission() {
            logger.warning("Screen capture permission might be denied, continuing anyway...")
        }
        
        if !InputEventInjector.requestAccessibilityPermission() {
            logger.warning("Accessibility permission might be denied, continuing anyway...")
        }
        
        // 2. Setup encoder
        try encoder.initialize(width: 1920, height: 1080)
        
        // 3. Connect to Relay Server
        let serverURLString = SessionManager.shared.relayServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let baserUrl = serverURLString.hasSuffix("/") ? String(serverURLString.dropLast()) : serverURLString
        guard let url = URL(string: "\(baserUrl)/host/\(roomCode)") else {
            logger.error("Invalid relay server URL")
            return
        }
        
        logger.info("Connecting Host to URL: \(url.absoluteString)")
        
        let connection = NetworkConnection(url: url)
        self.activeConnection = connection
        self.streamer = FrameStreamer(connection: connection)
        
        connection.delegate = self
        connection.start()
        
        isStarted = true
        DispatchQueue.main.async { self.isRunning = true }
        logger.info("HostController started")
    }
    
    /// Stop the host service
    func stop() async {
        guard isStarted else { return }
        
        await stopCapture()
        clipboardManager.stopMonitoring()
        activeConnection?.stop()
        activeConnection = nil
        
        isStarted = false
        DispatchQueue.main.async { self.isRunning = false }
        logger.info("HostController stopped")
    }
    
    private func startCapture() async {
        do {
            try await captureManager.startCapture()
        } catch {
            logger.error("Failed to start capture: \(error.localizedDescription)")
        }
    }
    
    private func stopCapture() async {
        do {
            try await captureManager.stopCapture()
        } catch {
            logger.error("Failed to stop capture: \(error.localizedDescription)")
        }
    }
}

// MARK: - ClipboardManagerDelegate

extension HostController: ClipboardManagerDelegate {
    func clipboardManager(_ manager: ClipboardManager, didDetectChange text: String) {
        guard let conn = activeConnection else { return }

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
                    logger.debug("Sent host clipboard to client: \(text.prefix(30))...")
                } catch {
                    logger.error("Failed to send clipboard: \(error.localizedDescription)")
                }
            }
        } catch {
            logger.error("Failed to encode clipboard message: \(error.localizedDescription)")
        }
    }
}

// MARK: - NetworkConnectionDelegate

extension HostController: NetworkConnectionDelegate {
    func connection(_ connection: NetworkConnection, didChangeState state: ConnectionState) {
        switch state {
        case .connected:
            Task { @MainActor in
                self.statusMessage = "Client Connected"
            }
            Task {
                await startCapture()
            }
            // Start clipboard monitoring for bidirectional sync
            clipboardManager.startMonitoring()

        case .disconnected, .failed:
            Task { @MainActor in
                self.statusMessage = "Ready"
            }
            Task {
                await stopCapture()
            }
            clipboardManager.stopMonitoring()

        default:
            break
        }
    }
    
    func connection(_ connection: NetworkConnection, didReceiveMessage message: NetworkMessage) {
        switch message.type {
        case .handshake:
            logger.info("Received handshake from client, forcing immediate keyframe")
            encoder.requestKeyframe()
            // Instantly awake ScreenCaptureKit to generate our newly requested keyframe 
            // by injecting a synthetic redundant mouse movement
            injector.jiggleMouse()
            
        case .inputEvent:
            do {
                let inputMessage = try JSONDecoder().decode(InputEventMessage.self, from: message.payload)
                injector.inject(inputMessage)
            } catch {
                logger.error("Failed to decode input event: \(error.localizedDescription)")
            }

        case .clipboard:
            // Receive clipboard from client and apply locally on the host
            do {
                let clipMsg = try JSONDecoder().decode(ClipboardMessage.self, from: message.payload)
                DispatchQueue.main.async {
                    self.clipboardManager.writeToLocalPasteboard(clipMsg.text)
                    self.logger.debug("Applied client clipboard on host: \(clipMsg.text.prefix(30))...")
                }
            } catch {
                logger.error("Failed to decode clipboard message: \(error.localizedDescription)")
            }

        default:
            break
        }
    }
    
    func connection(_ connection: NetworkConnection, didEncounterError error: Error) {
        logger.error("Client connection error: \(error.localizedDescription)")
        Task { @MainActor in
            self.statusMessage = "Connection failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - ScreenCaptureDelegate

extension HostController: ScreenCaptureDelegate {
    func screenCapture(_ manager: ScreenCaptureManager, didCaptureFrame sampleBuffer: CMSampleBuffer) {
        // Feed the captured frame to the encoder
        encoder.encode(sampleBuffer: sampleBuffer)
    }
    
    func screenCapture(_ manager: ScreenCaptureManager, didEncounterError error: Error) {
        logger.error("Capture error: \(error.localizedDescription)")
    }
}

// MARK: - VideoEncoderDelegate

extension HostController: VideoEncoderDelegate {
    func encoder(_ encoder: VideoEncoder, didEncodeFrame data: Data, isKeyframe: Bool, sps: Data?, pps: Data?, presentationTime: CMTime) {
        // Feed the encoded frame to the streamer
        streamer?.sendFrame(data: data, isKeyframe: isKeyframe, sps: sps, pps: pps, width: 1920, height: 1080)
    }
    
    func encoder(_ encoder: VideoEncoder, didEncounterError error: Error) {
        logger.error("Encoder error: \(error.localizedDescription)")
    }
}
