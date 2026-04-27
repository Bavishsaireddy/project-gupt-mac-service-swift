//
//  MetalRenderer.swift
//  RemoteDesktop
//
//  GPU-accelerated rendering of decoded video frames using Metal.
//  Uses a proper render pipeline (vertex + fragment shader) so that frames
//  are scaled to fit the MTKView regardless of their resolution — the old
//  blit-based copy(from:to:) required identical texture dimensions and caused
//  an IOGPUMetal assertion crash whenever they differed.
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
    private var renderPipeline: MTLRenderPipelineState?

    private let logger = Logger(subsystem: "com.gupt", category: "MetalRenderer")

    private var currentPixelBuffer: CVPixelBuffer?
    private let semaphore = DispatchSemaphore(value: 3) // Triple buffering

    // MARK: - Shaders (compiled inline; no .metal file needed)

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VertexOut {
        float4 position [[position]];
        float2 texCoord;
    };

    // Full-screen quad drawn as a triangle strip (4 vertices).
    // Metal NDC: (-1,-1) = bottom-left, (+1,+1) = top-right.
    // UV:        (0,0)   = top-left,    (1,1)   = bottom-right  (flipped Y).
    vertex VertexOut vertexShader(uint vertexID [[vertex_id]]) {
        const float2 positions[4] = {
            float2(-1.0, -1.0),
            float2( 1.0, -1.0),
            float2(-1.0,  1.0),
            float2( 1.0,  1.0)
        };
        const float2 texCoords[4] = {
            float2(0.0, 1.0),
            float2(1.0, 1.0),
            float2(0.0, 0.0),
            float2(1.0, 0.0)
        };
        VertexOut out;
        out.position = float4(positions[vertexID], 0.0, 1.0);
        out.texCoord = texCoords[vertexID];
        return out;
    }

    fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                   texture2d<float> tex [[texture(0)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        return tex.sample(s, in.texCoord);
    }
    """

    // MARK: - Initialization

    init?(device: MTLDevice) {
        self.device = device
        guard let queue = device.makeCommandQueue() else { return nil }
        self.commandQueue = queue

        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)

        super.init()

        // Compile shaders and build pipeline
        do {
            let library = try device.makeLibrary(source: MetalRenderer.shaderSource, options: nil)
            guard let vertexFn   = library.makeFunction(name: "vertexShader"),
                  let fragmentFn = library.makeFunction(name: "fragmentShader") else {
                return nil
            }

            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction   = vertexFn
            desc.fragmentFunction = fragmentFn
            desc.colorAttachments[0].pixelFormat = .bgra8Unorm

            renderPipeline = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            // Log but don't crash — draw(in:) will be a no-op if pipeline is nil
            Logger(subsystem: "com.gupt", category: "MetalRenderer")
                .error("Failed to build render pipeline: \(error.localizedDescription)")
            return nil
        }
    }

    /// Update the current frame to be rendered
    func updateFrame(_ pixelBuffer: CVPixelBuffer) {
        self.currentPixelBuffer = pixelBuffer
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // No per-size state to update; the shader scales automatically
    }

    func draw(in view: MTKView) {
        guard
            let pixelBuffer    = currentPixelBuffer,
            let drawable       = view.currentDrawable,
            let renderPassDesc = view.currentRenderPassDescriptor,
            let textureCache   = textureCache,
            let pipeline       = renderPipeline
        else { return }

        _ = semaphore.wait(timeout: .distantFuture)

        // 1. Wrap CVPixelBuffer as a Metal texture
        let width  = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard status == kCVReturnSuccess,
              let cvTex    = cvTexture,
              let texture  = CVMetalTextureGetTexture(cvTex)
        else {
            logger.error("Failed to create Metal texture from pixel buffer (status \(status))")
            semaphore.signal()
            return
        }

        // 2. Encode a render pass that draws a full-screen textured quad.
        //    The shader scales the frame to fit the drawable; no size-match required.
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            semaphore.signal()
            return
        }

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else {
            semaphore.signal()
            return
        }

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.semaphore.signal()
        }
        commandBuffer.commit()
    }
}
