//
//  FramePresenter.swift
//  RemoteDesktop
//
//  Synchronizes frame presentation with display refresh rate (Vsync)
//

import Foundation
import QuartzCore
import CoreVideo
import os.log

/// Manages the timing and presentation of video frames
class FramePresenter {
    private let logger = Logger(subsystem: "com.gupt", category: "FramePresenter")
    
    private var displayLink: CVDisplayLink?
    private let jitterBuffer: JitterBuffer
    private let onNewFrame: (CVPixelBuffer) -> Void
    
    private var isRunning = false
    
    // MARK: - Initialization
    
    init(jitterBuffer: JitterBuffer, onNewFrame: @escaping (CVPixelBuffer) -> Void) {
        self.jitterBuffer = jitterBuffer
        self.onNewFrame = onNewFrame
        
        // Setup CVDisplayLink
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        
        if let link = displayLink {
            let callback: CVDisplayLinkOutputCallback = { (_, _, _, _, _, userInfo) -> CVReturn in
                let presenter = Unmanaged<FramePresenter>.fromOpaque(userInfo!).takeUnretainedValue()
                presenter.vblankCallback()
                return kCVReturnSuccess
            }
            
            CVDisplayLinkSetOutputCallback(link, callback, Unmanaged.passUnretained(self).toOpaque())
        }
    }
    
    // MARK: - Lifecycle
    
    func start() {
        guard !isRunning, let link = displayLink else { return }
        CVDisplayLinkStart(link)
        isRunning = true
        logger.info("FramePresenter started")
    }
    
    func stop() {
        guard isRunning, let link = displayLink else { return }
        CVDisplayLinkStop(link)
        isRunning = false
        logger.info("FramePresenter stopped")
    }
    
    // MARK: - VSync Callback
    
    private func vblankCallback() {
        // This is called on a high-priority thread from QuartzCore
        // Pop the next frame from the jitter buffer and deliver it
        if let frame = jitterBuffer.popNextFrame() {
            // In a real app, I would decode the frame here or beforehand.
            // For now, I'm assuming the frame is already the pixel buffer (simplified).
            // Actually, FrameReceiver/JitterBuffer handle encoded data.
            // This is just a skeleton of the timing logic.
            logger.debug("VSync: Delivering frame #\(frame.sequence)")
            // self.onNewFrame(somePixelBuffer)
        }
    }
}
