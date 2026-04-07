//
//  MetalRenderer.swift
//  RemoteDesktop
//
//  GPU-accelerated rendering of decoded video frames using Metal
//

import Foundation
import Metal
import MetalKit
import CoreVideo
import os.log

/// Manages the Metal-based rendering pipeline
class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var textureCache: CVMetalTextureCache?
    
    private let logger = Logger(subsystem: "com.remotedesktop", category: "MetalRenderer")
    
    private var currentPixelBuffer: CVPixelBuffer?
    private let semaphore = DispatchSemaphore(value: 3) // Triple buffering
    
    // MARK: - Initialization
    
    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        
        super.init()
    }
    
    /// Update the current frame to be rendered
    func updateFrame(_ pixelBuffer: CVPixelBuffer) {
        self.currentPixelBuffer = pixelBuffer
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle resize if needed
    }
    
    func draw(in view: MTKView) {
        guard let pixelBuffer = currentPixelBuffer,
              let drawable = view.currentDrawable,
              let textureCache = textureCache else {
            return
        }
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        // 1. Create Metal texture from CVPixelBuffer
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm, // Assuming 32BGRA from SCKit
            width,
            height,
            0,
            &cvTexture
        )
        
        guard status == kCVReturnSuccess, let texture = CVMetalTextureGetTexture(cvTexture!) else {
            logger.error("Failed to create Metal texture from pixel buffer")
            semaphore.signal()
            return
        }
        
        // 2. Render to drawable
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            semaphore.signal()
            return
        }
        
        // Simple blit for now (copy texture to drawable)
        // In production, use a proper render pass with shaders
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        blitEncoder?.copy(from: texture, to: drawable.texture)
        blitEncoder?.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { _ in
            self.semaphore.signal()
        }
        commandBuffer.commit()
    }
}
