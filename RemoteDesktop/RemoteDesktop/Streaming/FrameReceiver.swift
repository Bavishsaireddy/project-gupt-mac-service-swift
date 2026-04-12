//
//  FrameReceiver.swift
//  RemoteDesktop
//
//  Handles incoming video frame packets and passes them to the jitter buffer/decoder
//

import Foundation
import os.log

/// Delegate for frame receiver events
protocol FrameReceiverDelegate: AnyObject {
    func frameReceiver(_ receiver: FrameReceiver, didReceiveFrameData data: Data, isKeyframe: Bool, sequence: UInt32, sps: Data?, pps: Data?)
}

/// Manages incoming video frames from the network
class FrameReceiver {
    private let connection: NetworkConnection
    private let logger = Logger(subsystem: "com.gupt", category: "FrameReceiver")
    
    weak var delegate: FrameReceiverDelegate?
    
    private var lastReceivedSequence: UInt32 = 0
    private let queue = DispatchQueue(label: "com.gupt.receiver", qos: .userInteractive)
    
    init(connection: NetworkConnection) {
        self.connection = connection
    }
    
    /// Start receiving video frames
    func start() {
        logger.info("FrameReceiver started")
    }
    
    /// Process a received video frame message
    func processMessage(_ message: VideoFrameMessage) {
        queue.async {
            // Sequence number check (simple for now)
            if message.frameSequence <= self.lastReceivedSequence {
                self.logger.warning("Dropped out-of-order/duplicate frame #\(message.frameSequence)")
                return
            }
            
            self.lastReceivedSequence = message.frameSequence
            
            // Deliver to delegate (which will pass it to the jitter buffer or decoder)
            self.delegate?.frameReceiver(
                self,
                didReceiveFrameData: message.frameData,
                isKeyframe: message.isKeyframe,
                sequence: message.frameSequence,
                sps: message.sps,
                pps: message.pps
            )
            
            self.logger.debug("Received frame #\(message.frameSequence)")
        }
    }
    
    /// Reset receiver state (e.g. on new session)
    func reset() {
        queue.async {
            self.lastReceivedSequence = 0
        }
    }
}
