# macOS Remote Desktop - System Architecture

## 1. HIGH-LEVEL ARCHITECTURE

```
┌─────────────────────────────────────────────────────────────────┐
│                        REMOTE DESKTOP SYSTEM                     │
└─────────────────────────────────────────────────────────────────┘

HOST MACHINE                              RECEIVER MACHINE
┌──────────────────────┐                 ┌──────────────────────┐
│   UI Layer           │                 │   UI Layer           │
│   - SwiftUI Views    │                 │   - SwiftUI Views    │
│   - State Management │                 │   - Connection UI    │
└──────────────────────┘                 └──────────────────────┘
         │                                        │
┌──────────────────────┐                 ┌──────────────────────┐
│  Host Controller     │                 │  Client Controller   │
│  - Lifecycle Mgmt    │                 │  - Session Mgmt      │
│  - Auth Handler      │                 │  - Input Handler     │
└──────────────────────┘                 └──────────────────────┘
         │                                        │
    ┌────┴────┐                              ┌───┴────┐
    │         │                              │        │
┌───▼──┐  ┌──▼───┐                      ┌───▼──┐  ┌──▼───┐
│Screen│  │Input │                      │Video │  │Input │
│Capture  │Inject│                      │Decode│  │Send  │
└───┬──┘  └──┬───┘                      └───┬──┘  └──┬───┘
    │         │                              │        │
┌───▼─────────▼───┐                      ┌───▼────────▼───┐
│  Video Encoder  │                      │  Event Parser  │
│  (VideoToolbox) │                      │  (Mouse/Key)   │
└────────┬────────┘                      └────────┬───────┘
         │                                        │
┌────────▼────────┐                      ┌────────▼───────┐
│  Stream Manager │                      │ Stream Manager │
│  - Frame Queue  │                      │ - Frame Buffer │
│  - Flow Control │                      │ - Jitter Buffer│
└────────┬────────┘                      └────────┬───────┘
         │                                        │
┌────────▼──────────────────────────────────────▼────────┐
│              NETWORK LAYER (Network.framework)          │
│  ┌──────────────┐              ┌──────────────┐        │
│  │ NWListener   │◄────TLS─────►│ NWConnection │        │
│  │ (Host:Port)  │              │ (Client)     │        │
│  └──────────────┘              └──────────────┘        │
└─────────────────────────────────────────────────────────┘
```

## 2. CORE MODULES

### 2.1 Network Layer (`Networking/`)
**Purpose**: Handle all network communication, connection management, and data transfer

**Components**:
- `NetworkProtocol.swift` - Message protocol definitions
- `NetworkListener.swift` - Host listener (NWListener)
- `NetworkConnection.swift` - Connection wrapper (NWConnection)
- `MessageCodec.swift` - Serialize/deserialize messages
- `SecurityManager.swift` - TLS configuration, authentication

**Key Responsibilities**:
- Establish P2P connections via IP/Port
- TLS encryption
- Message framing and parsing
- Connection state management
- Reconnection logic

### 2.2 Capture Layer (`Capture/`)
**Purpose**: Capture screen content on the host machine

**Components**:
- `ScreenCaptureManager.swift` - ScreenCaptureKit wrapper
- `CaptureConfiguration.swift` - Capture settings (resolution, FPS)
- `DisplaySelector.swift` - Select displays/windows

**Key Responsibilities**:
- Initialize ScreenCaptureKit
- Stream CMSampleBuffers
- Handle display configuration changes
- Manage capture permissions

### 2.3 Encoding/Decoding Layer (`Codec/`)
**Purpose**: Video compression and decompression using VideoToolbox

**Components**:
- `VideoEncoder.swift` - H.264 encoding via VTCompressionSession
- `VideoDecoder.swift` - H.264 decoding via VTDecompressionSession
- `CodecConfiguration.swift` - Bitrate, keyframe interval, etc.
- `FramePool.swift` - Reusable buffer pool for performance

**Key Responsibilities**:
- Encode CVPixelBuffer → H.264 NAL units
- Decode H.264 → CVPixelBuffer
- Adaptive bitrate control
- Low-latency configuration

### 2.4 Streaming Layer (`Streaming/`)
**Purpose**: Manage frame delivery and playback timing

**Components**:
- `FrameStreamer.swift` - Send frames from host
- `FrameReceiver.swift` - Receive and buffer frames
- `JitterBuffer.swift` - Smooth playback timing
- `FlowController.swift` - Congestion control

**Key Responsibilities**:
- Frame sequencing
- Latency monitoring
- Packet loss handling
- Timestamp synchronization

### 2.5 Input Control Layer (`InputControl/`)
**Purpose**: Capture user input on receiver, inject on host

**Components**:
- `InputEventCaptor.swift` - Capture mouse/keyboard on receiver
- `InputEventInjector.swift` - Inject CGEvents on host
- `InputSerializer.swift` - Serialize input events
- `CoordinateMapper.swift` - Map screen coordinates

**Key Responsibilities**:
- Capture NSEvent → serialize → send
- Receive → deserialize → CGEvent → inject
- Handle special keys (Cmd, Option, etc.)
- Coordinate transformation for different resolutions

### 2.6 Rendering Layer (`Rendering/`)
**Purpose**: Display decoded video on receiver

**Components**:
- `MetalRenderer.swift` - Metal-based video rendering
- `DisplayLayer.swift` - CALayer integration
- `FramePresenter.swift` - Presentation timing

**Key Responsibilities**:
- CVPixelBuffer → GPU texture
- Vsync-aware rendering
- Resolution scaling
- Aspect ratio handling

### 2.7 Application Layer (`App/`)
**Purpose**: Application lifecycle, UI, and coordination

**Components**:
- `HostController.swift` - Host-side logic
- `ClientController.swift` - Receiver-side logic
- `SessionManager.swift` - Session state
- `PermissionManager.swift` - Request system permissions
- `BackgroundService.swift` - Hidden mode support

### 2.8 UI Layer (`UI/`)
**Purpose**: SwiftUI interface

**Components**:
- `HostView.swift` - Host UI (start/stop, display IP/port)
- `ClientView.swift` - Client UI (connect, remote display)
- `SettingsView.swift` - Configuration
- `RemoteDesktopView.swift` - Full-screen remote display

## 3. DATA FLOW

### 3.1 Video Stream (Host → Receiver)
```
ScreenCaptureKit → CMSampleBuffer
                ↓
         CVPixelBuffer extract
                ↓
         VideoEncoder (H.264)
                ↓
         Compressed NAL units
                ↓
         Frame packets (with sequence #)
                ↓
         Network send (NWConnection)
                ↓
         Network receive
                ↓
         JitterBuffer (reordering)
                ↓
         VideoDecoder
                ↓
         CVPixelBuffer
                ↓
         MetalRenderer → Screen
```

### 3.2 Input Events (Receiver → Host)
```
User interaction (Receiver)
         ↓
    NSEvent capture
         ↓
    Serialize event
         ↓
    Network send
         ↓
    Network receive (Host)
         ↓
    Deserialize
         ↓
    Create CGEvent
         ↓
    Inject via CGEventPost
         ↓
    Host system processes input
```

## 4. NETWORK PROTOCOL

### 4.1 Message Types
```swift
enum MessageType: UInt8 {
    case handshake = 0x01       // Initial connection
    case auth = 0x02            // Authentication
    case videoFrame = 0x03      // Encoded video frame
    case inputEvent = 0x04      // Mouse/keyboard event
    case configUpdate = 0x05    // Resolution/FPS change
    case keepAlive = 0x06       // Connection health
    case disconnect = 0x07      // Clean shutdown
}
```

### 4.2 Frame Packet Structure
```
┌──────────────────────────────────────────┐
│ Header (16 bytes)                        │
├──────────────────────────────────────────┤
│ Message Type (1 byte): 0x03              │
│ Sequence Number (4 bytes)                │
│ Timestamp (8 bytes)                      │
│ Payload Size (4 bytes)                   │
├──────────────────────────────────────────┤
│ Payload (variable)                       │
│ - NAL unit data                          │
└──────────────────────────────────────────┘
```

### 4.3 Input Event Packet
```
┌──────────────────────────────────────────┐
│ Header (16 bytes)                        │
├──────────────────────────────────────────┤
│ Message Type (1 byte): 0x04              │
│ Event Type (1 byte): mouse/key/scroll    │
│ Timestamp (8 bytes)                      │
│ Payload Size (4 bytes)                   │
├──────────────────────────────────────────┤
│ Event Data (variable)                    │
│ - X, Y coordinates                       │
│ - Button/key codes                       │
│ - Modifiers                              │
└──────────────────────────────────────────┘
```

## 5. THREADING MODEL

### Host
```
Main Thread:
  - UI updates
  - User interactions

Capture Thread (ScreenCaptureKit):
  - Screen capture callbacks
  - Feed to encoder

Encoding Thread:
  - VideoToolbox encoding
  - Frame preparation

Network Thread (NWConnection):
  - Send video frames
  - Receive input events

Input Injection Thread:
  - Process input events
  - CGEvent injection
```

### Receiver
```
Main Thread:
  - UI updates
  - Input capture

Network Thread:
  - Receive video frames
  - Send input events

Decoding Thread:
  - VideoToolbox decoding
  - Frame extraction

Rendering Thread (Metal):
  - GPU rendering
  - Display presentation
```

## 6. PERFORMANCE OPTIMIZATIONS

### 6.1 Low Latency Techniques
- **Hardware Acceleration**: Use VideoToolbox (GPU encoding/decoding)
- **Zero-Copy Pipelines**: Pass CVPixelBuffer references, avoid memcpy
- **Frame Dropping**: Skip old frames if queue builds up
- **Real-time Priority**: Use QoS.userInteractive for critical threads
- **Buffer Pooling**: Pre-allocate and reuse buffers

### 6.2 Bandwidth Optimization
- **Dynamic Resolution**: Scale down on congestion
- **Keyframe Strategy**: I-frames only on scene changes
- **Adaptive Bitrate**: Monitor network RTT, adjust encoder
- **Lossy Mode**: Skip frames rather than buffer

### 6.3 CPU/GPU Efficiency
- **Encoder Settings**:
  - Profile: baseline or main (not high)
  - Entropy mode: CAVLC (faster than CABAC)
  - Max frame delay: 0 (no B-frames)
- **Metal Pipeline**: Single-pass YUV → RGB conversion
- **Async Operations**: Use async/await for I/O

## 7. SECURITY CONSIDERATIONS

### Initial Implementation
1. **TLS Encryption**: Network.framework TLS 1.3
2. **Password Authentication**: SHA-256 hashed passwords
3. **Connection Whitelist**: Optional IP filtering

### Future Enhancements
- Public key authentication
- End-to-end encryption on video stream
- Session tokens with expiry
- Audit logging

## 8. MACOS PERMISSIONS

Required permissions (add to Info.plist):
```xml
<key>NSScreenCaptureUsageDescription</key>
<string>Required to capture and stream your screen</string>

<key>NSAccessibilityUsageDescription</key>
<string>Required to control mouse and keyboard remotely</string>
```

Programmatic checks:
- `CGPreflightScreenCaptureAccess()` - Check screen recording
- `AXIsProcessTrusted()` - Check accessibility

## 9. ERROR HANDLING

### Network Errors
- Connection timeout: Retry with exponential backoff
- Connection lost: Notify user, attempt reconnect
- Packet loss: Monitor, adapt bitrate

### Encoding/Decoding Errors
- Encoder failure: Restart VTCompressionSession
- Decoder failure: Request keyframe, reset decoder
- Format mismatch: Renegotiate codec parameters

### System Errors
- Permission denied: Show system preferences UI
- Display disconnected: Notify client, pause stream
- Memory pressure: Reduce resolution/framerate

## 10. EXTENSIBILITY POINTS

Designed for future features:
- **Multi-monitor**: Extend CaptureConfiguration with display array
- **Clipboard sync**: Add MessageType.clipboard
- **File transfer**: Add MessageType.fileTransfer with chunking
- **Audio streaming**: Parallel audio pipeline with AVAudioEngine
- **Adaptive bitrate**: Implement bandwidth estimation algorithm

## 11. BUILD REQUIREMENTS

- **Xcode**: 15.0+
- **macOS Deployment Target**: 13.0+ (Ventura)
- **Swift**: 5.9+
- **Frameworks**:
  - ScreenCaptureKit (macOS 12.3+)
  - VideoToolbox
  - Network
  - CoreGraphics
  - Metal
  - SwiftUI
  - AVFoundation
