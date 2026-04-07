//
//  HostController.swift
//  RemoteDesktop
//
//  Main coordinator for the host-side logic
//

import Foundation
import os.log

/// Coordinates the host-side lifecycle and data pipeline
class HostController: NSObject {
    private let logger = Logger(subsystem: "com.remotedesktop", category: "HostController")
    
    private let listener: NetworkListener
    private var activeConnection: NetworkConnection?
    
    private let captureManager: ScreenCaptureManager
    private let encoder: VideoEncoder
    private var streamer: FrameStreamer?
    
    private let injector = InputEventInjector()
    
    private var isStarted = false
    
    // MARK: - Initialization
    
    override init() {
        self.listener = NetworkListener(port: 5900)
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
        
        // 1. Check permissions
        guard ScreenCaptureManager.requestPermission() else {
            logger.error("Screen capture permission denied")
            return
        }
        
        guard InputEventInjector.checkPermission() else {
            logger.error("Accessibility permission denied")
            return
        }
        
        // 2. Start listener
        try listener.start()
        
        // 3. Setup encoder
        try encoder.setupSession(width: 1920, height: 1080)
        
        isStarted = true
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
        
        // Start screen capture now that we have a client
        Task {
            await startCapture()
        }
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
        encoder.encodeFrame(sampleBuffer)
    }
    
    func screenCapture(_ manager: ScreenCaptureManager, didEncounterError error: Error) {
        logger.error("Capture error: \(error.localizedDescription)")
    }
}

// MARK: - VideoEncoderDelegate

extension HostController: VideoEncoderDelegate {
    func videoEncoder(_ encoder: VideoEncoder, didEncodeFrame data: Data, isKeyframe: Bool, width: Int, height: Int) {
        // Feed the encoded frame to the streamer
        streamer?.sendFrame(data: data, isKeyframe: isKeyframe, width: width, height: height)
    }
    
    func videoEncoder(_ encoder: VideoEncoder, didEncounterError error: Error) {
        logger.error("Encoder error: \(error.localizedDescription)")
    }
}
