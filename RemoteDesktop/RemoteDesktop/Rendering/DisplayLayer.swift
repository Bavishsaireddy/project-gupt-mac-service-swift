//
//  DisplayLayer.swift
//  RemoteDesktop
//
//  SwiftUI-compatible wrapper for Metal-based video display
//

import SwiftUI
import MetalKit
import CoreVideo
import os.log

/// A SwiftUI view that displays a remote video stream
struct RemoteDisplayView: NSViewRepresentable {
    private let logger = Logger(subsystem: "com.gupt", category: "RemoteDisplayView")
    
    /// The current pixel buffer to render
    @Binding var currentFrame: CVPixelBuffer?
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        
        // 1. Get the default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            logger.error("Metal is not supported on this device")
            return mtkView
        }
        
        mtkView.device = device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.framebufferOnly = false // Required for blit/compute
        
        // 2. Initialize the renderer
        if let renderer = MetalRenderer(device: device) {
            context.coordinator.renderer = renderer
            mtkView.delegate = renderer
        }
        
        return mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Pass the new frame to the renderer
        if let frame = currentFrame {
            context.coordinator.renderer?.updateFrame(frame)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var renderer: MetalRenderer?
    }
}
