//
//  CaptureConfiguration.swift
//  RemoteDesktop
//
//  Screen capture configuration settings
//

import Foundation

/// Configuration for screen capture
struct CaptureConfiguration: Codable {
    var width: Int
    var height: Int
    var frameRate: Int
    var showCursor: Bool
    var scalesToFit: Bool
    var displayID: UInt32?

    init(
        width: Int = 1920,
        height: Int = 1080,
        frameRate: Int = 30,
        showCursor: Bool = true,
        scalesToFit: Bool = true,
        displayID: UInt32? = nil
    ) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.showCursor = showCursor
        self.scalesToFit = scalesToFit
        self.displayID = displayID
    }

    // MARK: - Presets

    /// Default configuration (1080p @ 30fps)
    static let `default` = CaptureConfiguration()

    /// High quality (1080p @ 60fps)
    static let highQuality = CaptureConfiguration(
        width: 1920,
        height: 1080,
        frameRate: 60
    )

    /// Medium quality (720p @ 30fps)
    static let mediumQuality = CaptureConfiguration(
        width: 1280,
        height: 720,
        frameRate: 30
    )

    /// Low quality (540p @ 30fps)
    static let lowQuality = CaptureConfiguration(
        width: 960,
        height: 540,
        frameRate: 30
    )

    /// Ultra low (360p @ 15fps) - for very slow connections
    static let ultraLowQuality = CaptureConfiguration(
        width: 640,
        height: 360,
        frameRate: 15
    )

    // MARK: - Adaptive Quality

    /// Get scaled configuration based on quality level (0.0 to 1.0)
    func scaled(quality: Double) -> CaptureConfiguration {
        let clampedQuality = max(0.0, min(1.0, quality))

        let scaledWidth = Int(Double(width) * clampedQuality)
        let scaledHeight = Int(Double(height) * clampedQuality)
        let scaledFrameRate = Int(Double(frameRate) * clampedQuality)

        // Ensure dimensions are even (required for video encoding)
        let adjustedWidth = (scaledWidth / 2) * 2
        let adjustedHeight = (scaledHeight / 2) * 2

        return CaptureConfiguration(
            width: max(320, adjustedWidth),
            height: max(180, adjustedHeight),
            frameRate: max(10, scaledFrameRate),
            showCursor: showCursor,
            scalesToFit: scalesToFit,
            displayID: displayID
        )
    }

    // MARK: - Validation

    /// Validate configuration parameters
    func validate() -> Bool {
        guard width > 0, height > 0, frameRate > 0 else {
            return false
        }

        // Check reasonable bounds
        guard width >= 320 && width <= 3840 else {
            return false
        }

        guard height >= 180 && height <= 2160 else {
            return false
        }

        guard frameRate >= 10 && frameRate <= 120 else {
            return false
        }

        // Ensure dimensions are even
        guard width % 2 == 0 && height % 2 == 0 else {
            return false
        }

        return true
    }

    /// Get aspect ratio
    var aspectRatio: Double {
        return Double(width) / Double(height)
    }

    /// Get total pixels
    var totalPixels: Int {
        return width * height
    }
}

// MARK: - Quality Level

enum QualityLevel: String, CaseIterable, Codable {
    case ultraLow = "Ultra Low (360p)"
    case low = "Low (540p)"
    case medium = "Medium (720p)"
    case high = "High (1080p)"
    case custom = "Custom"

    var configuration: CaptureConfiguration {
        switch self {
        case .ultraLow:
            return .ultraLowQuality
        case .low:
            return .lowQuality
        case .medium:
            return .mediumQuality
        case .high:
            return .highQuality
        case .custom:
            return .default
        }
    }

    /// Get recommended bitrate in bits per second
    var recommendedBitrate: Int {
        switch self {
        case .ultraLow:
            return 500_000      // 500 Kbps
        case .low:
            return 1_000_000    // 1 Mbps
        case .medium:
            return 2_500_000    // 2.5 Mbps
        case .high:
            return 5_000_000    // 5 Mbps
        case .custom:
            return 2_500_000    // 2.5 Mbps default
        }
    }
}

// MARK: - Resolution Preset

struct ResolutionPreset {
    let name: String
    let width: Int
    let height: Int

    static let presets: [ResolutionPreset] = [
        ResolutionPreset(name: "4K UHD", width: 3840, height: 2160),
        ResolutionPreset(name: "1080p", width: 1920, height: 1080),
        ResolutionPreset(name: "720p", width: 1280, height: 720),
        ResolutionPreset(name: "540p", width: 960, height: 540),
        ResolutionPreset(name: "360p", width: 640, height: 360)
    ]
}

// MARK: - Frame Rate Preset

struct FrameRatePreset {
    let name: String
    let fps: Int

    static let presets: [FrameRatePreset] = [
        FrameRatePreset(name: "10 fps", fps: 10),
        FrameRatePreset(name: "15 fps", fps: 15),
        FrameRatePreset(name: "24 fps", fps: 24),
        FrameRatePreset(name: "30 fps", fps: 30),
        FrameRatePreset(name: "60 fps", fps: 60)
    ]
}
