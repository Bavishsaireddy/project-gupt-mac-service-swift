//
//  HostController.swift
//  RemoteDesktop
//
//  Main coordinator for the host-side logic
//

import Foundation
import Network
import CoreMedia
import os.log

/// Coordinates the host-side lifecycle and data pipeline
class HostController: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.remotedesktop", category: "HostController")
    
    private let listener: NetworkListener
    private var activeConnection: NetworkConnection?
    
    private let captureManager: ScreenCaptureManager
    private let encoder: VideoEncoder
    private var streamer: FrameStreamer?
    
    private let injector = InputEventInjector()
    
    // MARK: - Published Properties (for SwiftUI)
    @Published var isRunning = false
    @Published var statusMessage = "Ready"
    
    private var isStarted = false
    
    // MARK: - Initialization
    
    override init() {
        self.listener = NetworkListener(port: 5999, useTLS: false)
        self.captureManager = ScreenCaptureManager()
        self.encoder = VideoEncoder()
        
        super.init()
        
        self.listener.delegate = self
        self.captureManager.delegate = self
        self.encoder.delegate = self
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
        
        // 2. Start listener
        try listener.start()
        
        // 3. Setup encoder
        try encoder.initialize(width: 1920, height: 1080)
        
        isStarted = true
        DispatchQueue.main.async { self.isRunning = true }
        logger.info("HostController started")
    }
    
    /// Stop the host service
    func stop() async {
        guard isStarted else { return }
        
        await stopCapture()
        listener.stop()
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

// MARK: - NetworkListenerDelegate

extension HostController: NetworkListenerDelegate {
    func listener(_ listener: NetworkListener, didAcceptConnection connection: NetworkConnection) {
        logger.info("Connected to client: \(String(describing: connection))")
        
        self.activeConnection = connection
        self.streamer = FrameStreamer(connection: connection)
        
        // Set delegate to wait for actual connected state
        connection.delegate = self
        
        // Start connection after setting delegate
        connection.start()
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
        case .disconnected, .failed:
            Task { @MainActor in
                self.statusMessage = "Ready"
            }
            Task {
                await stopCapture()
            }
        default:
            break
        }
    }
    
    func connection(_ connection: NetworkConnection, didReceiveMessage message: NetworkMessage) {
        if message.type == .inputEvent {
            do {
                let inputMessage = try JSONDecoder().decode(InputEventMessage.self, from: message.payload)
                injector.inject(inputMessage)
            } catch {
                logger.error("Failed to decode input event: \(error.localizedDescription)")
            }
        }
    }
    
    func connection(_ connection: NetworkConnection, didEncounterError error: Error) {
        logger.error("Client connection error: \(error.localizedDescription)")
    }
    
    func listener(_ listener: NetworkListener, didEncounterError error: Error) {
        logger.error("Listener error: \(error.localizedDescription)")
    }
    
    func listener(_ listener: NetworkListener, didChangeState state: NWListener.State) {
        logger.info("Listener state changed: \(String(describing: state))")
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
