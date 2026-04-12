//
//  JitterBuffer.swift
//  RemoteDesktop
//
//  Buffers and reorders incoming frames to handle network jitter
//

import Foundation
import os.log

/// Buffers incoming frames and delivers them in order
class JitterBuffer {
    private let logger = Logger(subsystem: "com.gupt", category: "JitterBuffer")
    
    struct BufferedFrame {
        let sequence: UInt32
        let data: Data
        let isKeyframe: Bool
        let receiveTime: Date
    }
    
    private var buffer: [UInt32: BufferedFrame] = [:]
    private var nextExpectedSequence: UInt32 = 0
    private var isWaitingForKeyframe = true
    
    private let maxBufferSize = 30 // Max frames to buffer
    private let queue = DispatchQueue(label: "com.gupt.jitterbuffer", qos: .userInteractive)
    
    /// Add a frame to the buffer
    func addFrame(data: Data, isKeyframe: Bool, sequence: UInt32) {
        queue.async {
            // 1. Initial keyframe check
            if self.isWaitingForKeyframe {
                if isKeyframe {
                    self.isWaitingForKeyframe = false
                    self.nextExpectedSequence = sequence
                    self.logger.info("Received first keyframe, starting stream at #\(sequence)")
                } else {
                    self.logger.debug("Still waiting for keyframe, dropping frame #\(sequence)")
                    return
                }
            }
            
            // 2. Drop if very old
            if sequence < self.nextExpectedSequence {
                self.logger.warning("Dropping late frame #\(sequence) (expected >= \(self.nextExpectedSequence))")
                return
            }
            
            // 3. Buffer the frame
            let frame = BufferedFrame(
                sequence: sequence,
                data: data,
                isKeyframe: isKeyframe,
                receiveTime: Date()
            )
            self.buffer[sequence] = frame
            
            // 4. Buffer limit check (to avoid infinite growth if packet is lost)
            if self.buffer.count > self.maxBufferSize {
                self.handleOverflow()
            }
        }
    }
    
    /// Pop the next frame in sequence
    /// - Returns: The buffered frame if available, otherwise nil
    func popNextFrame() -> BufferedFrame? {
        var nextFrame: BufferedFrame?
        
        queue.sync {
            if let frame = self.buffer.removeValue(forKey: self.nextExpectedSequence) {
                self.nextExpectedSequence += 1
                nextFrame = frame
            }
        }
        
        return nextFrame
    }
    
    private func handleOverflow() {
        self.logger.error("JitterBuffer overflow! Missing frame #\(self.nextExpectedSequence). Resetting and waiting for keyframe.")
        self.reset()
    }
    
    /// Reset the buffer state
    func reset() {
        queue.async {
            self.buffer.removeAll()
            self.nextExpectedSequence = 0
            self.isWaitingForKeyframe = true
        }
    }
}
