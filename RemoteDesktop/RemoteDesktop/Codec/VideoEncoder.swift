//
//  VideoEncoder.swift
//  RemoteDesktop
//
//  H.264 video encoding using VideoToolbox
//

import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import os.log

/// Delegate for encoder events
protocol VideoEncoderDelegate: AnyObject {
    func encoder(_ encoder: VideoEncoder, didEncodeFrame data: Data, isKeyframe: Bool, sps: Data?, pps: Data?, presentationTime: CMTime)
    func encoder(_ encoder: VideoEncoder, didEncounterError error: Error)
}

/// H.264 video encoder using VideoToolbox
class VideoEncoder {
    private var compressionSession: VTCompressionSession?
    private let configuration: CodecConfiguration
    private let logger = Logger(subsystem: "com.gupt", category: "VideoEncoder")

    weak var delegate: VideoEncoderDelegate?

    private var frameCount: Int64 = 0
    private let queue = DispatchQueue(label: "com.gupt.encoder", qos: .userInteractive)
    private var pendingKeyframeRequest = false

    // MARK: - Initialization

    init(configuration: CodecConfiguration = .default) {
        self.configuration = configuration
    }

    deinit {
        invalidate()
    }

    // MARK: - Session Management

    /// Initialize encoding session
    func initialize(width: Int, height: Int) throws {
        guard compressionSession == nil else {
            logger.warning("Compression session already initialized")
            return
        }

        var session: VTCompressionSession?

        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: encodingOutputCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            throw CodecError.sessionCreationFailed
        }

        // Configure session properties
        try configureSession(session)

        // Prepare to encode
        VTCompressionSessionPrepareToEncodeFrames(session)

        self.compressionSession = session
        logger.info("Encoder initialized: \(width)x\(height)")
    }

    private func configureSession(_ session: VTCompressionSession) throws {
        // Set real-time encoding
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_RealTime,
            value: kCFBooleanTrue
        )

        // Set profile level
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_ProfileLevel,
            value: kVTProfileLevel_H264_Main_AutoLevel
        )

        // Set average bitrate
        let bitrate = configuration.bitrate as CFNumber
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_AverageBitRate,
            value: bitrate
        )

        // Set max keyframe interval
        let keyframeInterval = configuration.keyframeInterval as CFNumber
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_MaxKeyFrameInterval,
            value: keyframeInterval
        )

        // Set expected frame rate
        let fps = configuration.expectedFrameRate as CFNumber
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_ExpectedFrameRate,
            value: fps
        )

        // Allow frame reordering (set to false for low latency)
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_AllowFrameReordering,
            value: kCFBooleanFalse
        )

        // Set max frame delay to 0 (no B-frames)
        VTSessionSetProperty(
            session,
            key: kVTCompressionPropertyKey_MaxFrameDelayCount,
            value: 0 as CFNumber
        )

        // Hardware acceleration relies on Apple default for VideoToolbox
        
        // Let it determine priority natively by omitting the kVTCompressionPropertyKey_Priority key
        
        logger.info("Encoder configured: \(self.configuration.bitrate) bps, \(self.configuration.expectedFrameRate) fps")
    }

    /// Invalidate encoding session
    func invalidate() {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
            logger.info("Encoder invalidated")
        }
    }

    // MARK: - Encoding

    /// Encode a video frame
    func encode(sampleBuffer: CMSampleBuffer, forceKeyframe: Bool = false) {
        guard let session = compressionSession else {
            logger.error("Cannot encode: session not initialized")
            return
        }

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            logger.error("Cannot get image buffer from sample buffer")
            return
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let duration = CMSampleBufferGetDuration(sampleBuffer)

        // Prepare frame properties
        var frameProperties: [CFString: Any] = [:]
        if forceKeyframe || pendingKeyframeRequest {
            frameProperties[kVTEncodeFrameOptionKey_ForceKeyFrame] = kCFBooleanTrue
            pendingKeyframeRequest = false
        }

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: imageBuffer,
            presentationTimeStamp: presentationTime,
            duration: duration,
            frameProperties: frameProperties as CFDictionary?,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )

        if status != noErr {
            logger.error("Failed to encode frame: \(status)")
            delegate?.encoder(self, didEncounterError: CodecError.encodingFailed)
        }

        frameCount += 1
    }

    /// Encode a pixel buffer directly
    func encode(pixelBuffer: CVPixelBuffer, presentationTime: CMTime, duration: CMTime, forceKeyframe: Bool = false) {
        guard let session = compressionSession else {
            logger.error("Cannot encode: session not initialized")
            return
        }

        var frameProperties: [CFString: Any] = [:]
        if forceKeyframe || pendingKeyframeRequest {
            frameProperties[kVTEncodeFrameOptionKey_ForceKeyFrame] = kCFBooleanTrue
            pendingKeyframeRequest = false
        }

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: presentationTime,
            duration: duration,
            frameProperties: frameProperties as CFDictionary?,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil
        )

        if status != noErr {
            logger.error("Failed to encode frame: \(status)")
            delegate?.encoder(self, didEncounterError: CodecError.encodingFailed)
        }

        frameCount += 1
    }

    /// Force next frame to be a keyframe
    func requestKeyframe() {
        pendingKeyframeRequest = true
        logger.info("Keyframe requested (will force on next encode)")
    }

    // MARK: - Output Callback

    private let encodingOutputCallback: VTCompressionOutputCallback = { (
        outputCallbackRefCon: UnsafeMutableRawPointer?,
        sourceFrameRefCon: UnsafeMutableRawPointer?,
        status: OSStatus,
        infoFlags: VTEncodeInfoFlags,
        sampleBuffer: CMSampleBuffer?
    ) in
        guard status == noErr else {
            return
        }

        guard let sampleBuffer = sampleBuffer else {
            return
        }

        guard let encoder = outputCallbackRefCon.map({ Unmanaged<VideoEncoder>.fromOpaque($0).takeUnretainedValue() }) else {
            return
        }

        encoder.handleEncodedFrame(sampleBuffer: sampleBuffer, flags: infoFlags)
    }

    private func handleEncodedFrame(sampleBuffer: CMSampleBuffer, flags: VTEncodeInfoFlags) {
        // Check if this is a keyframe
        let isKeyframe = !flags.contains(.frameDropped) && sampleBuffer.isKeyframe

        // Extract encoded data
        guard let (data, sps, pps) = extractEncodedData(from: sampleBuffer, isKeyframe: isKeyframe) else {
            logger.error("Failed to extract encoded data")
            return
        }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        // Notify delegate
        delegate?.encoder(self, didEncodeFrame: data, isKeyframe: isKeyframe, sps: sps, pps: pps, presentationTime: presentationTime)
    }

    private func extractEncodedData(from sampleBuffer: CMSampleBuffer, isKeyframe: Bool) -> (Data, Data?, Data?)? {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?

        let status = CMBlockBufferGetDataPointer(
            dataBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        )

        guard status == noErr, let pointer = dataPointer else {
            return nil
        }

        let avccData = Data(bytes: pointer, count: length)
        var spsData: Data? = nil
        var ppsData: Data? = nil
        
        // 1. If keyframe, extract SPS and PPS
        if isKeyframe, let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
            var count: Int = 0
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil, parameterSetCountOut: &count, nalUnitHeaderLengthOut: nil)
            
            for i in 0..<count {
                var parameterSetPointer: UnsafePointer<UInt8>?
                var parameterSetSize: Int = 0
                let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                    formatDesc,
                    parameterSetIndex: i,
                    parameterSetPointerOut: &parameterSetPointer,
                    parameterSetSizeOut: &parameterSetSize,
                    parameterSetCountOut: nil,
                    nalUnitHeaderLengthOut: nil
                )
                
                if status == noErr, let paramPtr = parameterSetPointer {
                    let d = Data(bytes: paramPtr, count: parameterSetSize)
                    if i == 0 { spsData = d } else if i == 1 { ppsData = d }
                }
            }
        }

        return (avccData, spsData, ppsData)
    }

    // MARK: - Statistics

    var encodedFrameCount: Int64 {
        return frameCount
    }
}

// MARK: - CMSampleBuffer Extensions

extension CMSampleBuffer {
    /// Check if sample buffer contains a keyframe
    var isKeyframe: Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: false) as? [[CFString: Any]] else {
            return false
        }

        guard let firstAttachment = attachments.first else {
            return false
        }

        // Check if NOT a key frame is set to false (meaning it IS a keyframe)
        if let notSync = firstAttachment[kCMSampleAttachmentKey_NotSync] as? Bool {
            return !notSync
        }

        // If the key is not present, it's likely a keyframe
        return true
    }
}
