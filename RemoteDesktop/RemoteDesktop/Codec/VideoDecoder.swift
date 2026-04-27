//
//  VideoDecoder.swift
//  RemoteDesktop
//
//  H.264 video decoding using VideoToolbox
//

import Foundation
import VideoToolbox
import CoreMedia
import CoreVideo
import os.log

/// Delegate for decoder events
protocol VideoDecoderDelegate: AnyObject {
    func decoder(_ decoder: VideoDecoder, didDecodeFrame pixelBuffer: CVPixelBuffer, presentationTime: CMTime)
    func decoder(_ decoder: VideoDecoder, didEncounterError error: Error)
}

/// H.264 video decoder using VideoToolbox
class VideoDecoder {
    private var decompressionSession: VTDecompressionSession?
    private let logger = Logger(subsystem: "com.gupt", category: "VideoDecoder")

    weak var delegate: VideoDecoderDelegate?

    private var formatDescription: CMFormatDescription?
    private var frameCount: Int64 = 0
    private let queue = DispatchQueue(label: "com.gupt.decoder", qos: .userInteractive)

    // MARK: - Initialization

    init() {}

    deinit {
        invalidate()
    }

    // MARK: - Session Management

    /// Initialize decoding session
    func initialize(formatDescription: CMFormatDescription) throws {
        self.formatDescription = formatDescription

        var session: VTDecompressionSession?

        // Decoder configuration
        let decoderConfig: [CFString: Any] = [:]

        // Image buffer attributes
        let imageBufferAttributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue  // Enable Metal compatibility
        ]

        var outputCallback = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: decompressionOutputCallback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: decoderConfig as CFDictionary,
            imageBufferAttributes: imageBufferAttributes as CFDictionary,
            outputCallback: &outputCallback,
            decompressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            throw CodecError.sessionCreationFailed
        }

        // Configure session for low latency
        VTSessionSetProperty(
            session,
            key: kVTDecompressionPropertyKey_RealTime,
            value: kCFBooleanTrue
        )

        self.decompressionSession = session
        logger.info("Decoder initialized")
    }

    /// Reinitialize decoder with new format
    func reinitialize(formatDescription: CMFormatDescription) throws {
        invalidate()
        try initialize(formatDescription: formatDescription)
    }

    /// Invalidate decoding session
    func invalidate() {
        if let session = decompressionSession {
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
            logger.info("Decoder invalidated")
        }
    }

    // MARK: - Decoding

    /// Decode compressed frame data
    func decode(data: Data, presentationTime: CMTime, isKeyframe: Bool) {
        guard let session = decompressionSession else {
            logger.error("Cannot decode: session not initialized")
            return
        }

        // Create block buffer from data
        var blockBuffer: CMBlockBuffer?
        let dataPointer = (data as NSData).bytes
        let dataLength = data.count

        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: dataLength,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: dataLength,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr, let blockBuffer = blockBuffer else {
            logger.error("Failed to create block buffer")
            return
        }

        status = CMBlockBufferReplaceDataBytes(
            with: dataPointer,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: dataLength
        )

        guard status == noErr else {
            logger.error("Failed to fill block buffer")
            return
        }

        // Create sample buffer
        guard let formatDesc = formatDescription else {
            logger.error("No format description available")
            return
        }

        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        status = CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr, let sampleBuffer = sampleBuffer else {
            logger.error("Failed to create sample buffer")
            return
        }

        // Decode the frame
        var flagsOut: VTDecodeInfoFlags = []
        status = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: [._EnableAsynchronousDecompression],
            frameRefcon: nil,
            infoFlagsOut: &flagsOut
        )

        if status != noErr {
            logger.error("Failed to decode frame: \(status)")
            delegate?.decoder(self, didEncounterError: CodecError.decodingFailed)
        }

        frameCount += 1
    }

    /// Decode from H.264 NAL units (AVCC)
    func decodeWithHeaders(data: Data, presentationTime: CMTime, sps: Data? = nil, pps: Data? = nil) {
        // Extract SPS and PPS if this is the first frame or format changed
        if formatDescription == nil {
            if let formatDesc = createFormatDescription(sps: sps, pps: pps) {
                do {
                    try initialize(formatDescription: formatDesc)
                } catch {
                    logger.error("Failed to initialize decoder: \(error.localizedDescription)")
                    delegate?.decoder(self, didEncounterError: error)
                    return
                }
            } else {
                logger.error("Failed to create format description (missing or invalid SPS/PPS)")
                return
            }
        }

        // Decode the frame (AVCC stream)
        let isKeyframe = sps != nil || pps != nil
        decode(data: data, presentationTime: presentationTime, isKeyframe: isKeyframe)
    }

    // MARK: - Format Description

    private func createFormatDescription(sps: Data?, pps: Data?) -> CMFormatDescription? {
        guard let sps = sps, let pps = pps else {
            return nil
        }

        // Create format description using nested withUnsafeBytes for correct pointer types
        var formatDesc: CMFormatDescription?
        var status: OSStatus = noErr
        sps.withUnsafeBytes { spsPtr in
            pps.withUnsafeBytes { ppsPtr in
                let paramPtrs: [UnsafePointer<UInt8>] = [
                    spsPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    ppsPtr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                ]
                let paramSizes: [Int] = [sps.count, pps.count]
                status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: 2,
                    parameterSetPointers: paramPtrs,
                    parameterSetSizes: paramSizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: &formatDesc
                )
            }
        }

        guard status == noErr else {
            return nil
        }

        return formatDesc
    }

    // MARK: - Output Callback

    private let decompressionOutputCallback: VTDecompressionOutputCallback = { (
        decompressionOutputRefCon: UnsafeMutableRawPointer?,
        sourceFrameRefCon: UnsafeMutableRawPointer?,
        status: OSStatus,
        infoFlags: VTDecodeInfoFlags,
        imageBuffer: CVImageBuffer?,
        presentationTimeStamp: CMTime,
        presentationDuration: CMTime
    ) in
        guard status == noErr else {
            return
        }

        guard let imageBuffer = imageBuffer else {
            return
        }

        guard let decoder = decompressionOutputRefCon.map({ Unmanaged<VideoDecoder>.fromOpaque($0).takeUnretainedValue() }) else {
            return
        }

        decoder.handleDecodedFrame(pixelBuffer: imageBuffer, presentationTime: presentationTimeStamp)
    }

    private func handleDecodedFrame(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        delegate?.decoder(self, didDecodeFrame: pixelBuffer, presentationTime: presentationTime)
    }

    // MARK: - Statistics

    var decodedFrameCount: Int64 {
        return frameCount
    }
}
