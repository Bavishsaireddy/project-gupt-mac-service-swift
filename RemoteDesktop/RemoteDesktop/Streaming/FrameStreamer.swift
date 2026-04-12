//
//  FrameStreamer.swift
//  RemoteDesktop
//
//  Handles outgoing video frames, sequence numbers, and packetization
//

import Foundation
import os.log

/// Manages the outgoing stream of video frames
class FrameStreamer {
    private let connection: NetworkConnection
    private let logger = Logger(subsystem: "com.gupt", category: "FrameStreamer")
    
    private var frameSequence: UInt32 = 0
    private var messageSequence: UInt32 = 0
    
    private let queue = DispatchQueue(label: "com.gupt.streamer", qos: .userInteractive)
    
    init(connection: NetworkConnection) {
        self.connection = connection
    }
    
    /// Send an encoded video frame over the network
    /// - Parameters:
    ///   - data: Compressed frame data (H.264 NAL units)
    ///   - isKeyframe: Whether this is an I-frame
    ///   - width: Frame width
    ///   - height: Frame height
    func sendFrame(data: Data, isKeyframe: Bool, sps: Data? = nil, pps: Data? = nil, width: Int, height: Int) {
        queue.async {
            self.frameSequence += 1
            let currentFrameSeq = self.frameSequence
            
            // 1. Create the video frame payload
            let videoMessage = VideoFrameMessage(
                frameSequence: currentFrameSeq,
                isKeyframe: isKeyframe,
                width: width,
                height: height,
                frameData: data,
                sps: sps,
                pps: pps
            )
            
            // 2. Serialize the payload
            guard let payloadData = try? JSONEncoder().encode(videoMessage) else {
                self.logger.error("Failed to encode VideoFrameMessage")
                return
            }
            
            // 3. Wrap in network message envelope
            self.messageSequence += 1
            let networkMessage = NetworkMessage(
                type: .videoFrame,
                sequenceNumber: self.messageSequence,
                timestamp: NetworkMessage.currentTimestamp(),
                payload: payloadData
            )
            
            // 4. Send via connection
            Task {
                do {
                    try await self.connection.send(networkMessage)
                    self.logger.debug("Sent frame #\(currentFrameSeq) (\(data.count) bytes, keyframe: \(isKeyframe))")
                } catch {
                    self.logger.error("Failed to send frame #\(currentFrameSeq): \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// Reset sequence numbers (e.g. on new session)
    func reset() {
        queue.async {
            self.frameSequence = 0
            self.messageSequence = 0
        }
    }
}
