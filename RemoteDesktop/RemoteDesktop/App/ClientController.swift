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
    
    // Only the real connection and decoder matter
    private var connection: NetworkConnection?
    private let decoder: VideoDecoder
    
    // MARK: - Initialization
    
    override init() {
        self.decoder = VideoDecoder()
        super.init()
        self.decoder.delegate = self
    }
    
    // MARK: - Session Management
    
    /// Connect to a remote host
    func connect(host: String, port: UInt16) async throws {
        let newConnection = NetworkConnection(host: host, port: port, useTLS: false)
        self.connection = newConnection
        newConnection.delegate = self
        newConnection.start()
        logger.info("ClientController connecting to \(host):\(port)")
    }
    
    /// Disconnect from the current host
    func disconnect() async {
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
                self.logger.info("Connection is ready — waiting for frames")
            case .disconnected:
                self.isConnected = false
            case .failed(let error):
                self.isConnected = false
                self.logger.error("Connection failed: \(error.localizedDescription)")
            default:
                break
            }
        }
    }
    
    func connection(_ connection: NetworkConnection, didReceiveMessage message: NetworkMessage) {
        guard message.type == .videoFrame else { return }
        
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
    }
    
    func connection(_ connection: NetworkConnection, didEncounterError error: Error) {
        logger.error("Network error: \(error.localizedDescription)")
    }
}
