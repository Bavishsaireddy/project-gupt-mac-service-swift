//
//  ClientController.swift
//  RemoteDesktop
//
//  Main coordinator for the client-side logic
//

import Foundation
import os.log
import CoreVideo
import CoreMedia

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
    private var presenter: FramePresenter!
    
    // MARK: - Initialization
    
    override init() {
        // Will initialize correctly on connect
        self.receiver = FrameReceiver(connection: NetworkConnection(host: "localhost", port: 5999, useTLS: false))
        self.jitterBuffer = JitterBuffer()
        self.decoder = VideoDecoder()
        
        super.init()
        
        // Setup presenter callback after super.init() to access self safely
        self.presenter = FramePresenter(jitterBuffer: jitterBuffer) { [weak self] frame in
            DispatchQueue.main.async {
                self?.currentFrame = frame
            }
        }
        
        self.receiver.delegate = self
        self.decoder.delegate = self
    }
    
    // MARK: - Session Management
    
    /// Connect to a remote host
    func connect(host: String, port: UInt16) async throws {
        let newConnection = NetworkConnection(host: host, port: port, useTLS: false)
        self.connection = newConnection
        newConnection.delegate = self
        
        newConnection.start()
        
        // Start pipelines
        self.receiver.start()
        self.presenter.start()
        
        logger.info("ClientController attempting to connect to \(host):\(port)")
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
        let pts = CMTime(value: Int64(sequence), timescale: 60) // Dummy PTS for now
        decoder.decodeWithHeaders(data: data, presentationTime: pts)
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
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.isConnected = true
            case .disconnected, .failed:
                self.isConnected = false
            default:
                break
            }
        }
    }
    
    func connection(_ connection: NetworkConnection, didReceiveMessage message: NetworkMessage) {
        if message.type == .videoFrame {
            do {
                let frameMessage = try JSONDecoder().decode(VideoFrameMessage.self, from: message.payload)
                receiver.processMessage(frameMessage)
            } catch {
                logger.error("Failed to decode video frame: \(error.localizedDescription)")
            }
        }
    }
    
    func connection(_ connection: NetworkConnection, didEncounterError error: Error) {
        logger.error("Network connection error: \(error.localizedDescription)")
    }
}
