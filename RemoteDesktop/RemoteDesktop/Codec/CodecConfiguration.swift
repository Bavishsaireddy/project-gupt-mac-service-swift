//
//  CodecConfiguration.swift
//  RemoteDesktop
//
//  Video codec configuration parameters
//

import Foundation

/// Configuration for video encoding/decoding
struct CodecConfiguration: Codable {
    var bitrate: Int                // Bits per second
    var keyframeInterval: Int       // Maximum keyframe interval in frames
    var expectedFrameRate: Int      // Expected frame rate
    var enableHardwareAcceleration: Bool

    init(
        bitrate: Int = 5_000_000,  // 5 Mbps default
        keyframeInterval: Int = 60, // Keyframe every 2 seconds at 30fps
        expectedFrameRate: Int = 30,
        enableHardwareAcceleration: Bool = true
    ) {
        self.bitrate = bitrate
        self.keyframeInterval = keyframeInterval
        self.expectedFrameRate = expectedFrameRate
        self.enableHardwareAcceleration = enableHardwareAcceleration
    }

    // MARK: - Presets

    /// Default configuration (5 Mbps, 30 fps)
    static let `default` = CodecConfiguration()

    /// High quality (10 Mbps, 60 fps)
    static let highQuality = CodecConfiguration(
        bitrate: 10_000_000,
        keyframeInterval: 120,
        expectedFrameRate: 60
    )

    /// Medium quality (2.5 Mbps, 30 fps)
    static let mediumQuality = CodecConfiguration(
        bitrate: 2_500_000,
        keyframeInterval: 60,
        expectedFrameRate: 30
    )

    /// Low quality (1 Mbps, 30 fps)
    static let lowQuality = CodecConfiguration(
        bitrate: 1_000_000,
        keyframeInterval: 60,
        expectedFrameRate: 30
    )

    /// Ultra low (500 Kbps, 15 fps)
    static let ultraLowQuality = CodecConfiguration(
        bitrate: 500_000,
        keyframeInterval: 30,
        expectedFrameRate: 15
    )

    // MARK: - Adaptive Bitrate

    /// Scale bitrate based on quality factor (0.0 to 1.0)
    func scaled(quality: Double) -> CodecConfiguration {
        let clampedQuality = max(0.0, min(1.0, quality))
        let scaledBitrate = Int(Double(bitrate) * clampedQuality)

        return CodecConfiguration(
            bitrate: max(100_000, scaledBitrate),  // Min 100 Kbps
            keyframeInterval: keyframeInterval,
            expectedFrameRate: expectedFrameRate,
            enableHardwareAcceleration: enableHardwareAcceleration
        )
    }

    /// Adjust bitrate
    mutating func adjustBitrate(to newBitrate: Int) {
        self.bitrate = max(100_000, min(50_000_000, newBitrate))  // 100 Kbps to 50 Mbps
    }

    /// Increase bitrate by percentage
    mutating func increaseBitrate(by percentage: Double) {
        let newBitrate = Int(Double(bitrate) * (1.0 + percentage))
        adjustBitrate(to: newBitrate)
    }

    /// Decrease bitrate by percentage
    mutating func decreaseBitrate(by percentage: Double) {
        let newBitrate = Int(Double(bitrate) * (1.0 - percentage))
        adjustBitrate(to: newBitrate)
    }

    // MARK: - Calculated Properties

    /// Estimated bits per frame
    var bitsPerFrame: Int {
        return bitrate / expectedFrameRate
    }

    /// Keyframe interval in seconds
    var keyframeIntervalSeconds: Double {
        return Double(keyframeInterval) / Double(expectedFrameRate)
    }

    /// Estimated bandwidth in Mbps
    var bandwidthMbps: Double {
        return Double(bitrate) / 1_000_000.0
    }

    // MARK: - Validation

    func validate() -> Bool {
        guard bitrate >= 100_000 && bitrate <= 100_000_000 else {
            return false
        }

        guard keyframeInterval > 0 && keyframeInterval <= 300 else {
            return false
        }

        guard expectedFrameRate > 0 && expectedFrameRate <= 120 else {
            return false
        }

        return true
    }
}

// MARK: - Codec Errors

enum CodecError: Error, LocalizedError {
    case sessionCreationFailed
    case sessionConfigurationFailed
    case encodingFailed
    case decodingFailed
    case invalidFormat
    case unsupportedCodec
    case hardwareNotAvailable
    // Networking codec errors
    case payloadTooLarge
    case insufficientData
    case invalidMessageType

    var errorDescription: String? {
        switch self {
        case .sessionCreationFailed:
            return "Failed to create codec session"
        case .sessionConfigurationFailed:
            return "Failed to configure codec session"
        case .encodingFailed:
            return "Video encoding failed"
        case .decodingFailed:
            return "Video decoding failed"
        case .invalidFormat:
            return "Invalid video format"
        case .unsupportedCodec:
            return "Codec not supported on this device"
        case .hardwareNotAvailable:
            return "Hardware acceleration not available"
        case .payloadTooLarge:
            return "Message payload exceeds maximum size"
        case .insufficientData:
            return "Insufficient data to decode message"
        case .invalidMessageType:
            return "Invalid message type"
        }
    }
}

// MARK: - Bitrate Presets

struct BitratePreset {
    let name: String
    let bitrate: Int

    static let presets: [BitratePreset] = [
        BitratePreset(name: "Ultra Low (500 Kbps)", bitrate: 500_000),
        BitratePreset(name: "Low (1 Mbps)", bitrate: 1_000_000),
        BitratePreset(name: "Medium (2.5 Mbps)", bitrate: 2_500_000),
        BitratePreset(name: "High (5 Mbps)", bitrate: 5_000_000),
        BitratePreset(name: "Very High (10 Mbps)", bitrate: 10_000_000),
        BitratePreset(name: "Ultra High (20 Mbps)", bitrate: 20_000_000)
    ]
}

// MARK: - Codec Info

struct CodecInfo {
    static let supportedCodecs = ["H.264"]
    static let preferredCodec = "H.264"

    /// Check if hardware encoding is available
    static func isHardwareEncodingAvailable() -> Bool {
        // Check for VideoToolbox hardware support
        // On Apple Silicon and modern Intel Macs, H.264 hardware encoding is available
        #if arch(arm64)
        return true  // Apple Silicon always has hardware encoding
        #else
        // Check for Intel Quick Sync
        return true  // Most modern Macs have hardware encoding
        #endif
    }

    /// Check if hardware decoding is available
    static func isHardwareDecodingAvailable() -> Bool {
        return isHardwareEncodingAvailable()
    }
}
