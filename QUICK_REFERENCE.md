# Quick Reference - RemoteDesktop

## 📂 File Reference

| File | Purpose | Status | LOC |
|------|---------|--------|-----|
| **Networking/** | | | |
| NetworkProtocol.swift | Message types & structures | ✅ | 400 |
| NetworkConnection.swift | Client NWConnection wrapper | ✅ | 300 |
| NetworkListener.swift | Server NWListener wrapper | ✅ | 250 |
| MessageCodec.swift | Binary serialization | ✅ | 200 |
| SecurityManager.swift | Auth & TLS | ✅ | 150 |
| **Capture/** | | | |
| ScreenCaptureManager.swift | ScreenCaptureKit wrapper | ✅ | 250 |
| CaptureConfiguration.swift | Capture settings | ✅ | 150 |
| **Codec/** | | | |
| VideoEncoder.swift | H.264 encoding | ✅ | 350 |
| VideoDecoder.swift | H.264 decoding | ✅ | 300 |
| CodecConfiguration.swift | Codec settings | ✅ | 150 |
| **InputControl/** | | | |
| InputEventInjector.swift | CGEvent injection | ✅ | 400 |
| InputEventCaptor.swift | NSEvent capture | ✅ | 300 |
| **App/** | | | |
| RemoteDesktopApp.swift | SwiftUI entry point | ✅ | 400 |
| AppDelegate.swift | App lifecycle | ✅ | 150 |
| **TOTAL** | | | **~3500** |

## 🔑 Key Classes

### Network Layer

```swift
// Start server
let listener = NetworkListener(port: 5900, useTLS: true)
try listener.start()

// Connect client
let connection = await NetworkConnection(host: "192.168.1.100", port: 5900)
connection.delegate = self
connection.start()

// Send message
try await connection.sendPayload(payload, type: .videoFrame)
```

### Capture Layer

```swift
// Start capture
let config = CaptureConfiguration.default
let manager = ScreenCaptureManager(configuration: config)
manager.delegate = self
try await manager.startCapture()

// Implement delegate
func screenCapture(_ manager: ScreenCaptureManager,
                   didCaptureFrame sampleBuffer: CMSampleBuffer) {
    // Process frame
}
```

### Codec Layer

```swift
// Encoding
let encoder = VideoEncoder(configuration: .default)
try encoder.initialize(width: 1920, height: 1080)
encoder.delegate = self
encoder.encode(sampleBuffer: buffer)

// Decoding
let decoder = VideoDecoder()
try decoder.initialize(formatDescription: formatDesc)
decoder.delegate = self
decoder.decode(data: h264Data, presentationTime: time, isKeyframe: true)
```

### Input Control

```swift
// Inject events (host)
let injector = InputEventInjector()
injector.inject(inputEvent)

// Capture events (client)
let captor = InputEventCaptor()
captor.delegate = self
captor.startCapturing()
```

## 📡 Message Protocol

### Message Types

```swift
enum MessageType: UInt8 {
    case handshake = 0x01       // Initial connection
    case auth = 0x02            // Authentication
    case videoFrame = 0x03      // Video frame
    case inputEvent = 0x04      // Input event
    case configUpdate = 0x05    // Config change
    case keepAlive = 0x06       // Heartbeat
    case disconnect = 0x07      // Disconnect
}
```

### Frame Format

```
┌──────────────────────────────────────────┐
│ Header (17 bytes)                        │
├──────────────────────────────────────────┤
│ Type (1): 0x03                           │
│ Sequence (4): 0x00000001                 │
│ Timestamp (8): 0x0000000000000000        │
│ Payload Size (4): 0x00001000             │
├──────────────────────────────────────────┤
│ Payload (variable)                       │
│ - VideoFrameMessage (JSON)               │
│   - frameSequence                        │
│   - isKeyframe                           │
│   - width, height                        │
│   - frameData (H.264)                    │
└──────────────────────────────────────────┘
```

## ⚙️ Configuration Presets

### Capture

```swift
CaptureConfiguration.ultraLowQuality  // 360p @ 15fps
CaptureConfiguration.lowQuality       // 540p @ 30fps
CaptureConfiguration.mediumQuality    // 720p @ 30fps
CaptureConfiguration.highQuality      // 1080p @ 60fps
```

### Codec

```swift
CodecConfiguration.ultraLowQuality    // 500 Kbps
CodecConfiguration.lowQuality         // 1 Mbps
CodecConfiguration.mediumQuality      // 2.5 Mbps
CodecConfiguration.highQuality        // 10 Mbps
```

## 🎮 Key Code Reference

```swift
// Common keys
KeyCode.returnKey = 0x24
KeyCode.tab = 0x30
KeyCode.space = 0x31
KeyCode.delete = 0x33
KeyCode.escape = 0x35

// Arrows
KeyCode.leftArrow = 0x7B
KeyCode.rightArrow = 0x7C
KeyCode.downArrow = 0x7D
KeyCode.upArrow = 0x7E

// Function keys
KeyCode.f1 = 0x7A
// ... see InputEventInjector.swift for full list
```

## 🔒 Permissions

### Check

```swift
// Screen recording
let hasScreenRecording = CGPreflightScreenCaptureAccess()

// Accessibility
let hasAccessibility = AXIsProcessTrusted()
```

### Request

```swift
// Screen recording
_ = ScreenCaptureManager.requestPermission()

// Accessibility
_ = InputEventInjector.requestAccessibilityPermission()
```

## 🐛 Debug Commands

### Logging

```bash
# View all logs
log stream --predicate 'subsystem == "com.remotedesktop"' --level debug

# By category
log stream --predicate 'category == "NetworkConnection"' --level debug

# To file
log stream --predicate 'subsystem == "com.remotedesktop"' > ~/Desktop/logs.txt
```

### Network

```bash
# Check open ports
lsof -i :5900

# Monitor bandwidth
nettop -m tcp

# Test connection
nc -zv 192.168.1.100 5900
```

### Performance

```bash
# Monitor CPU
top -pid $(pgrep RemoteDesktop)

# Monitor memory
leaks RemoteDesktop

# Monitor network
nettop -p RemoteDesktop
```

## 📊 Performance Targets

```swift
// Latency breakdown (target)
Capture:    2ms
Encode:    10ms
Network:   30ms  // LAN, 100ms internet
Decode:     5ms
Render:     3ms
━━━━━━━━━━━━━━━
Total:    ~50ms  // LAN, ~150ms internet
```

## 🔧 Build Settings

### Info.plist

```xml
<key>LSMinimumSystemVersion</key>
<string>13.0</string>

<key>NSScreenCaptureUsageDescription</key>
<string>Required to capture and stream your screen</string>

<key>NSAccessibilityUsageDescription</key>
<string>Required to control mouse and keyboard remotely</string>
```

### Frameworks

```
ScreenCaptureKit.framework
VideoToolbox.framework
Network.framework
CoreGraphics.framework
Metal.framework
AVFoundation.framework
```

### Compiler Flags

```
-O              # Optimization level
-whole-module-optimization
-enable-library-evolution
```

## 📱 Common Tasks

### Change Port

```swift
// Default: 5900
let listener = NetworkListener(port: 7000)
```

### Change Quality

```swift
let config = CaptureConfiguration.mediumQuality
let codec = CodecConfiguration.mediumQuality
```

### Disable TLS (testing only)

```swift
let listener = NetworkListener(port: 5900, useTLS: false)
let connection = await NetworkConnection(host: "...", port: 5900, useTLS: false)
```

### Get Local IP

```swift
let addresses = NetworkListener.getLocalIPAddresses()
// ["192.168.1.100", "10.0.0.5"]
```

### Force Keyframe

```swift
encoder.requestKeyframe()
// Next encode will be I-frame
```

## 🧪 Unit Test Examples

### Network

```swift
func testMessageCodec() async throws {
    let codec = await MessageCodec()

    let msg = NetworkMessage(
        type: .handshake,
        sequenceNumber: 1,
        timestamp: 12345,
        payload: Data([0x01, 0x02])
    )

    let encoded = try await codec.encode(msg)
    let (decoded, _) = try await codec.decode(from: encoded)

    XCTAssertEqual(msg.type, decoded.type)
}
```

### Codec

```swift
func testEncoderDecoder() throws {
    let encoder = VideoEncoder()
    try encoder.initialize(width: 640, height: 480)

    let decoder = VideoDecoder()

    // ... test encode/decode cycle
}
```

## 💡 Tips & Tricks

### Reduce Latency

1. Disable B-frames: `AllowFrameReordering = false`
2. Set real-time priority: `kVTCompressionPropertyKey_RealTime`
3. Use QoS: `.userInteractive`
4. Enable TCP_NODELAY: `tcpOptions.noDelay = true`

### Save Bandwidth

1. Lower resolution: `CaptureConfiguration.lowQuality`
2. Reduce FPS: `frameRate = 15`
3. Lower bitrate: `bitrate = 1_000_000`
4. Increase keyframe interval: `keyframeInterval = 120`

### Debug Performance

1. Log frame timestamps
2. Measure encode/decode time
3. Track network RTT
4. Monitor frame drops

## 🚀 Next Implementation

### FrameStreamer.swift

```swift
actor FrameStreamer {
    private let connection: NetworkConnection
    private var frameSequence: UInt32 = 0

    func sendFrame(_ data: Data, isKeyframe: Bool,
                   width: Int, height: Int) async throws {
        let frame = VideoFrameMessage(
            frameSequence: frameSequence,
            isKeyframe: isKeyframe,
            width: width,
            height: height,
            frameData: data
        )
        try await connection.sendVideoFrame(frame)
        frameSequence &+= 1
    }
}
```

### FrameReceiver.swift

```swift
actor FrameReceiver {
    private let connection: NetworkConnection
    private var buffer: [UInt32: VideoFrameMessage] = [:]

    func receiveFrame() async throws -> VideoFrameMessage? {
        // Implement frame buffering and reordering
    }
}
```

### MetalRenderer.swift

```swift
class MetalRenderer {
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!

    func render(_ pixelBuffer: CVPixelBuffer,
                to layer: CAMetalLayer) {
        // Convert YUV → RGB
        // Render to layer
    }
}
```

## 📞 Support Resources

- **Architecture**: See ARCHITECTURE.md
- **Implementation Plan**: See IMPLEMENTATION_PLAN.md
- **Build Issues**: See BUILD_GUIDE.md
- **Progress**: See PROJECT_STATUS.md
- **Getting Started**: See GETTING_STARTED.md

## 📚 Apple Documentation

- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [VideoToolbox](https://developer.apple.com/documentation/videotoolbox)
- [Network Framework](https://developer.apple.com/documentation/network)
- [Core Graphics Events](https://developer.apple.com/documentation/coregraphics/quartz_event_services)
- [Metal](https://developer.apple.com/metal/)

---

**Quick Start**: Read GETTING_STARTED.md → Create Xcode project → Build → Implement streaming layer → Run!
