//
//  ScreenCaptureManager.swift
//  RemoteDesktop
//
//  Screen capture using ScreenCaptureKit
//

import Foundation
import ScreenCaptureKit
import CoreVideo
import os.log

/// Delegate for screen capture events
protocol ScreenCaptureDelegate: AnyObject {
    func screenCapture(_ manager: ScreenCaptureManager, didCaptureFrame sampleBuffer: CMSampleBuffer)
    func screenCapture(_ manager: ScreenCaptureManager, didEncounterError error: Error)
}

/// Manages screen capture using ScreenCaptureKit
@available(macOS 12.3, *)
class ScreenCaptureManager: NSObject {
    private var stream: SCStream?
    private var configuration: CaptureConfiguration
    private let logger = Logger(subsystem: "com.remotedesktop", category: "ScreenCapture")

    weak var delegate: ScreenCaptureDelegate?

    private var isCapturing = false
    private var availableContent: SCShareableContent?

    // MARK: - Initialization

    init(configuration: CaptureConfiguration = .default) {
        self.configuration = configuration
        super.init()
    }

    // MARK: - Capture Management

    /// Start screen capture
    func startCapture() async throws {
        guard !isCapturing else {
            logger.warning("Capture already running")
            return
        }

        // Check permission
        guard await checkPermission() else {
            throw CaptureError.permissionDenied
        }

        // Get available content
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        self.availableContent = content

        // Select display
        guard let display = selectDisplay(from: content) else {
            throw CaptureError.noDisplayAvailable
        }

        // Create content filter
        let filter = SCContentFilter(display: display, excludingWindows: [])

        // Configure stream
        let streamConfig = createStreamConfiguration()

        // Create stream
        let newStream = SCStream(filter: filter, configuration: streamConfig, delegate: self)

        // Add stream output
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)

        // Start capture
        try await newStream.startCapture()

        self.stream = newStream
        self.isCapturing = true

        logger.info("Screen capture started: \(self.configuration.width)x\(self.configuration.height) @ \(self.configuration.frameRate)fps")
    }

    /// Stop screen capture
    func stopCapture() async throws {
        guard let stream = stream, isCapturing else {
            logger.warning("No active capture to stop")
            return
        }

        try await stream.stopCapture()
        self.stream = nil
        self.isCapturing = false

        logger.info("Screen capture stopped")
    }

    /// Update capture configuration
    func updateConfiguration(_ newConfig: CaptureConfiguration) async throws {
        self.configuration = newConfig

        guard let stream = stream, isCapturing else {
            return
        }

        let streamConfig = createStreamConfiguration()
        try await stream.updateConfiguration(streamConfig)

        logger.info("Configuration updated: \(newConfig.width)x\(newConfig.height) @ \(newConfig.frameRate)fps")
    }

    // MARK: - Configuration

    private func createStreamConfiguration() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        config.width = configuration.width
        config.height = configuration.height
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(configuration.frameRate))
        config.queueDepth = 5

        // Optimize for performance
        config.showsCursor = configuration.showCursor
        config.scalesToFit = configuration.scalesToFit
        if #available(macOS 14.0, *) {
            config.captureResolution = .best
        }
        config.colorSpaceName = CGColorSpace.sRGB
        config.pixelFormat = kCVPixelFormatType_32BGRA

        return config
    }

    // MARK: - Display Selection

    private func selectDisplay(from content: SCShareableContent) -> SCDisplay? {
        // For now, select the main display
        // TODO: Allow user to select display
        return content.displays.first
    }

    /// Get available displays
    func getAvailableDisplays() async throws -> [DisplayInfo] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        return content.displays.map { display in
            DisplayInfo(
                id: display.displayID,
                name: display.displayID.description,
                width: display.width,
                height: display.height
            )
        }
    }

    // MARK: - Permission

    private func checkPermission() async -> Bool {
        // Check if we have screen recording permission
        // Note: This will prompt the user if permission not granted
        return await withCheckedContinuation { continuation in
            // Request permission
            Task {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(
                        false,
                        onScreenWindowsOnly: true
                    )
                    continuation.resume(returning: !content.displays.isEmpty)
                } catch {
                    self.logger.error("Permission check failed: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Request screen recording permission
    static func requestPermission() -> Bool {
        // This will trigger the system permission dialog
        return CGPreflightScreenCaptureAccess()
    }

    // MARK: - State

    var captureState: Bool {
        return isCapturing
    }
}

// MARK: - SCStreamDelegate

@available(macOS 12.3, *)
extension ScreenCaptureManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Stream stopped with error: \(error.localizedDescription)")
        isCapturing = false
        delegate?.screenCapture(self, didEncounterError: error)
    }
}

// MARK: - SCStreamOutput

@available(macOS 12.3, *)
extension ScreenCaptureManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }

        // Validate sample buffer
        guard sampleBuffer.isValid, let imageBuffer = sampleBuffer.imageBuffer else {
            // Check why it's invalid
            if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
               let attachments = attachmentsArray.first,
               let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
               let status = SCFrameStatus(rawValue: statusRawValue) {
                switch status {
                case .complete:
                    logger.warning("Frame complete but no imageBuffer")
                case .idle:
                    // Normal behavior when screen is unchanged
                    break
                case .blank:
                    logger.warning("Frame is blank! (Usually TCC permission denial)")
                case .suspended:
                    logger.warning("Frame suspended")
                case .stopped:
                    logger.warning("Frame stopped")
                case .started:
                    logger.warning("Frame started")
                @unknown default:
                    logger.warning("Unknown frame status: \(statusRawValue)")
                }
            } else {
                logger.warning("Invalid sample buffer and no SCStreamFrameInfo attachments")
            }
            return
        }

        // Check pixel format
        let pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer)
        guard pixelFormat == kCVPixelFormatType_32BGRA else {
            logger.warning("Unexpected pixel format: \(pixelFormat)")
            return
        }

        // Diagnostic logging for the first few frames
        struct FrameCounter { static var count = 0 }
        FrameCounter.count += 1
        
        if FrameCounter.count <= 5 {
            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly) }
            
            if let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) {
                let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
                let height = CVPixelBufferGetHeight(imageBuffer)
                let width = CVPixelBufferGetWidth(imageBuffer)
                
                // Sample the center pixel to see if it's completely black
                let centerRow = height / 2
                let centerCol = width / 2
                let byteOffset = (centerRow * bytesPerRow) + (centerCol * 4)
                
                let pixel = baseAddress.advanced(by: byteOffset).assumingMemoryBound(to: UInt32.self).pointee
                
                logger.info("Captured Frame #\(FrameCounter.count): \(width)x\(height), format: 32BGRA, center pixel argb/bgra: \(String(format:"0x%08X", pixel))")
                
                if pixel == 0 {
                    logger.warning("⚠️ Warning: Frame \(FrameCounter.count) appears to be pitch black. ScreenCaptureKit permission might be stale.")
                }
            } else {
                logger.warning("Could not access base address of image buffer for frame \(FrameCounter.count)")
            }
        }

        // Deliver to delegate
        delegate?.screenCapture(self, didCaptureFrame: sampleBuffer)
    }
}

// MARK: - Display Info

struct DisplayInfo: Codable, Identifiable {
    let id: UInt32
    let name: String
    let width: Int
    let height: Int
}

// MARK: - Errors

enum CaptureError: Error, LocalizedError {
    case permissionDenied
    case noDisplayAvailable
    case captureInitializationFailed
    case invalidConfiguration
    case streamError(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Screen recording permission denied. Please grant permission in System Preferences."
        case .noDisplayAvailable:
            return "No display available for capture"
        case .captureInitializationFailed:
            return "Failed to initialize screen capture"
        case .invalidConfiguration:
            return "Invalid capture configuration"
        case .streamError(let error):
            return "Stream error: \(error.localizedDescription)"
        }
    }
}
