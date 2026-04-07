//
//  ClientController.swift
//  RemoteDesktop
//
//  Main coordinator for the client-side logic
//

import Foundation
import os.log
import CoreVideo

/// Coordinates the client-side session and data pipeline
class ClientController: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.remotedesktop", category: "ClientController")
    
    // Published properties for SwiftUI UI
    @Published var isConnected = false
    @Published var currentFrame: CVPixelBuffer?
    
    private var connection: NetworkConnection?
    private let receiver: FrameReceiver
    private let jitterBuffer: JitterBuffer
    private let decoder: VideoDecoder
    private let presenter: FramePresenter
    
    // MARK: - Initialization
    
    override init() {
        // 1. Initial configuration
        let dummyConnection = NetworkConnection(host: "localhost", port: 5900)
        self.connection = dummyConnection
        self.receiver = FrameReceiver(connection: dummyConnection)
        self.jitterBuffer = JitterBuffer()
        self.decoder = VideoDecoder()
        
        // 2. Setup presenter with a callback to update the UI
        self.presenter = FramePresenter(jitterBuffer: jitterBuffer) { [weak self] frame in
            DispatchQueue.main.async {
                self?.currentFrame = frame
            }
        }
        
        super.init()
        
        self.receiver.delegate = self
        self.decoder.delegate = self
    }
    
    // MARK: - Session Management
    
    /// Connect to a remote host
    func connect(host: String, port: UInt16) async throws {
        let newConnection = NetworkConnection(host: host, port: port)
        self.connection = newConnection
        
        try await newConnection.start()
        self.isConnected = true
        
        // Start pipelines
        self.receiver.start()
        self.presenter.start()
        
        logger.info("ClientController connected to \(host):\(port)")
    }
    
    /// Disconnect from the current host
    func disconnect() async {
        connection?.stop()
        connection = nil
        isConnected = false
        
        presenter.stop()
        jitterBuffer.reset()
        
        logger.info("ClientController disconnected")
    }
}

// MARK: - FrameReceiverDelegate

extension ClientController: FrameReceiverDelegate {
    func frameReceiver(_ receiver: FrameReceiver, didReceiveFrameData data: Data, isKeyframe: Bool, sequence: UInt32) {
        // Pass encoded frame to jitter buffer
        jitterBuffer.addFrame(data: data, isKeyframe: isKeyframe, sequence: sequence)
        
        // At some point (either here or via presenter), we decode it
        decoder.decodeFrame(data, isKeyframe: isKeyframe)
    }
}

// MARK: - VideoDecoderDelegate

extension ClientController: VideoDecoderDelegate {
    func videoDecoder(_ decoder: VideoDecoder, didDecodeFrame pixelBuffer: CVPixelBuffer) {
        // We've got a decoded frame!
        // In a real app, the JitterBuffer would store the decoded CVPixelBuffer
        // for vsync-aligned presentation via the FramePresenter.
        
        DispatchQueue.main.async {
            self.currentFrame = pixelBuffer
            LatencyMonitor.shared.reportFrameDelivered()
        }
    }
    
    func videoDecoder(_ decoder: VideoDecoder, didEncounterError error: Error) {
        logger.error("Decoder error: \(error.localizedDescription)")
    }
}
