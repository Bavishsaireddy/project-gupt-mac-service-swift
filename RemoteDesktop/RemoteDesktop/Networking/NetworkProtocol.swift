//
//  NetworkProtocol.swift
//  GUPT
//
//  Network message protocol definitions
//

import Foundation

/// Message types for network communication
enum MessageType: UInt8, Codable {
    case handshake = 0x01       // Initial connection negotiation
    case auth = 0x02            // Authentication request/response
    case videoFrame = 0x03      // Encoded video frame data
    case inputEvent = 0x04      // Mouse/keyboard input event
    case configUpdate = 0x05    // Configuration change (resolution, FPS)
    case keepAlive = 0x06       // Connection health check
    case disconnect = 0x07      // Clean disconnect
    case ack = 0x08             // Acknowledgment
    case clipboard = 0x09       // Clipboard sync
}

/// Network message with header and payload
struct NetworkMessage: Codable {
    let type: MessageType
    let sequenceNumber: UInt32
    let timestamp: UInt64       // Microseconds since epoch
    let payload: Data

    init(type: MessageType, sequenceNumber: UInt32, timestamp: UInt64, payload: Data) {
        self.type = type
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.payload = payload
    }

    /// Get current timestamp in microseconds
    static func currentTimestamp() -> UInt64 {
        let now = DispatchTime.now()
        return UInt64(now.uptimeNanoseconds / 1000)
    }
}

// MARK: - Handshake Message

struct HandshakeMessage: Codable {
    let version: String
    let deviceName: String
    let capabilities: Capabilities

    struct Capabilities: Codable {
        let maxResolution: Resolution
        let supportedCodecs: [String]
        let maxFrameRate: Int
    }

    struct Resolution: Codable {
        let width: Int
        let height: Int
    }
}

// MARK: - Authentication Message

struct AuthMessage: Codable {
    let username: String?
    let passwordHash: String    // SHA-256 hash
    let salt: String
}

struct AuthResponseMessage: Codable {
    let success: Bool
    let sessionToken: String?
    let message: String?
}

// MARK: - Video Frame Message

struct VideoFrameMessage: Codable {
    let frameSequence: UInt32
    let isKeyframe: Bool
    let width: Int
    let height: Int
    let frameData: Data
    let compressionFormat: String   // "h264"
    let sps: Data?
    let pps: Data?

    /// Create from encoded frame data
    init(frameSequence: UInt32, isKeyframe: Bool, width: Int, height: Int, frameData: Data, sps: Data? = nil, pps: Data? = nil) {
        self.frameSequence = frameSequence
        self.isKeyframe = isKeyframe
        self.width = width
        self.height = height
        self.frameData = frameData
        self.compressionFormat = "h264"
        self.sps = sps
        self.pps = pps
    }
}

// MARK: - Input Event Message

enum InputEventType: UInt8, Codable {
    case mouseMove = 0x01
    case mouseDown = 0x02
    case mouseUp = 0x03
    case mouseScroll = 0x04
    case keyDown = 0x05
    case keyUp = 0x06
    case flagsChanged = 0x07
}

enum MouseButton: UInt8, Codable {
    case left = 0
    case right = 1
    case middle = 2
    case button4 = 3
    case button5 = 4
}

struct InputEventMessage: Codable {
    let eventType: InputEventType
    let timestamp: UInt64
    let eventData: EventData

    enum EventData: Codable {
        case mouseEvent(MouseEventData)
        case keyEvent(KeyEventData)
        case scrollEvent(ScrollEventData)

        enum CodingKeys: String, CodingKey {
            case type, data
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .mouseEvent(let data):
                try container.encode("mouse", forKey: .type)
                try container.encode(data, forKey: .data)
            case .keyEvent(let data):
                try container.encode("key", forKey: .type)
                try container.encode(data, forKey: .data)
            case .scrollEvent(let data):
                try container.encode("scroll", forKey: .type)
                try container.encode(data, forKey: .data)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            switch type {
            case "mouse":
                let data = try container.decode(MouseEventData.self, forKey: .data)
                self = .mouseEvent(data)
            case "key":
                let data = try container.decode(KeyEventData.self, forKey: .data)
                self = .keyEvent(data)
            case "scroll":
                let data = try container.decode(ScrollEventData.self, forKey: .data)
                self = .scrollEvent(data)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown event type")
            }
        }
    }
}

struct MouseEventData: Codable {
    let x: Double
    let y: Double
    let button: MouseButton?
    let clickCount: Int?
    let deltaX: Double?
    let deltaY: Double?
    let isDragging: Bool?
}

struct KeyEventData: Codable {
    let keyCode: UInt16
    let characters: String?
    let charactersIgnoringModifiers: String?
    let modifiers: KeyModifiers
}

struct KeyModifiers: Codable, OptionSet {
    let rawValue: UInt32

    static let shift = KeyModifiers(rawValue: 1 << 0)
    static let control = KeyModifiers(rawValue: 1 << 1)
    static let option = KeyModifiers(rawValue: 1 << 2)
    static let command = KeyModifiers(rawValue: 1 << 3)
    static let capsLock = KeyModifiers(rawValue: 1 << 4)
    static let function = KeyModifiers(rawValue: 1 << 5)
}

struct ScrollEventData: Codable {
    let deltaX: Double
    let deltaY: Double
    let phase: ScrollPhase
}

enum ScrollPhase: UInt8, Codable {
    case began = 1
    case changed = 2
    case ended = 3
    case cancelled = 4
    case mayBegin = 5
}

// MARK: - Configuration Update Message

struct ConfigUpdateMessage: Codable {
    let resolution: Resolution?
    let frameRate: Int?
    let bitrate: Int?

    struct Resolution: Codable {
        let width: Int
        let height: Int
    }
}

// MARK: - Keep Alive Message

struct KeepAliveMessage: Codable {
    let timestamp: UInt64
    let latencyMs: Double?
}

// MARK: - Disconnect Message

struct DisconnectMessage: Codable {
    let reason: String
}

// MARK: - Clipboard Message

struct ClipboardMessage: Codable {
    let text: String
    let timestamp: UInt64
}

// MARK: - Message Size Constants

enum MessageConstants {
    static let headerSize = 17  // 1 (type) + 4 (sequence) + 8 (timestamp) + 4 (payload size)
    static let maxPayloadSize = 10_000_000  // 10 MB max per message to handle large JSON keyframes
    static let keepAliveInterval: TimeInterval = 5.0  // seconds
}
