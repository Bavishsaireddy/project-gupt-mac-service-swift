# Project File Structure

```
RemoteDesktop/
├── RemoteDesktop.xcodeproj
├── README.md
├── ARCHITECTURE.md
├── IMPLEMENTATION_PLAN.md
│
├── RemoteDesktop/                          # Main application target
│   ├── App/
│   │   ├── RemoteDesktopApp.swift         # SwiftUI App entry point
│   │   ├── AppDelegate.swift               # AppDelegate for lifecycle
│   │   ├── HostController.swift            # Host-side coordinator
│   │   ├── ClientController.swift          # Client-side coordinator
│   │   ├── SessionManager.swift            # Session state management
│   │   ├── PermissionManager.swift         # System permissions
│   │   └── BackgroundService.swift         # Background mode support
│   │
│   ├── Networking/
│   │   ├── NetworkProtocol.swift           # Message type definitions
│   │   ├── NetworkListener.swift           # NWListener wrapper (host)
│   │   ├── NetworkConnection.swift         # NWConnection wrapper
│   │   ├── MessageCodec.swift              # Serialization/deserialization
│   │   ├── SecurityManager.swift           # Auth & TLS
│   │   └── NetworkError.swift              # Network error types
│   │
│   ├── Capture/
│   │   ├── ScreenCaptureManager.swift      # ScreenCaptureKit wrapper
│   │   ├── CaptureConfiguration.swift      # Capture settings
│   │   ├── DisplaySelector.swift           # Display/window selection
│   │   └── CaptureError.swift              # Capture error types
│   │
│   ├── Codec/
│   │   ├── VideoEncoder.swift              # H.264 encoding (VideoToolbox)
│   │   ├── VideoDecoder.swift              # H.264 decoding (VideoToolbox)
│   │   ├── CodecConfiguration.swift        # Codec parameters
│   │   ├── FramePool.swift                 # CVPixelBuffer pool
│   │   └── CodecError.swift                # Codec error types
│   │
│   ├── Streaming/
│   │   ├── FrameStreamer.swift             # Send frames (host)
│   │   ├── FrameReceiver.swift             # Receive frames (client)
│   │   ├── JitterBuffer.swift              # Frame reordering & buffering
│   │   ├── FlowController.swift            # Congestion control
│   │   ├── LatencyMonitor.swift            # Measure end-to-end latency
│   │   └── StreamingError.swift            # Streaming error types
│   │
│   ├── InputControl/
│   │   ├── InputEventCaptor.swift          # Capture input (client)
│   │   ├── InputEventInjector.swift        # Inject input (host)
│   │   ├── InputSerializer.swift           # Serialize/deserialize events
│   │   ├── CoordinateMapper.swift          # Coordinate transformation
│   │   └── InputEvent.swift                # Input event models
│   │
│   ├── Rendering/
│   │   ├── MetalRenderer.swift             # Metal-based rendering
│   │   ├── DisplayLayer.swift              # CAMetalLayer setup
│   │   ├── FramePresenter.swift            # Presentation timing
│   │   ├── YUVToRGBShader.metal            # Metal shader for color conversion
│   │   └── RenderError.swift               # Rendering error types
│   │
│   ├── UI/
│   │   ├── Host/
│   │   │   ├── HostView.swift              # Host main view
│   │   │   ├── HostStatusView.swift        # Connection status
│   │   │   └── HostSettingsView.swift      # Host settings
│   │   │
│   │   ├── Client/
│   │   │   ├── ClientView.swift            # Client main view
│   │   │   ├── ConnectionView.swift        # Connection input
│   │   │   ├── RemoteDesktopView.swift     # Remote display view
│   │   │   └── ClientSettingsView.swift    # Client settings
│   │   │
│   │   ├── Shared/
│   │   │   ├── SettingsView.swift          # General settings
│   │   │   ├── PermissionRequestView.swift # Permission UI
│   │   │   └── DebugOverlay.swift          # Performance stats overlay
│   │   │
│   │   └── Components/
│   │       ├── StatusIndicator.swift       # Connection status indicator
│   │       ├── LatencyBadge.swift          # Latency display
│   │       └── VideoQualitySlider.swift    # Quality control
│   │
│   ├── Models/
│   │   ├── ConnectionInfo.swift            # Connection details
│   │   ├── SessionState.swift              # Session state enum
│   │   ├── PerformanceMetrics.swift        # Performance data
│   │   └── Configuration.swift             # App configuration
│   │
│   ├── Utilities/
│   │   ├── Logger.swift                    # Logging utility
│   │   ├── NetworkUtils.swift              # IP address helpers
│   │   ├── TimestampProvider.swift         # High-resolution timestamps
│   │   └── Extensions/
│   │       ├── CVPixelBuffer+Extensions.swift
│   │       ├── NSEvent+Extensions.swift
│   │       └── Data+Extensions.swift
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets                 # App icons, images
│   │   │   ├── AppIcon.appiconset
│   │   │   └── Colors
│   │   └── Info.plist                      # App info & permissions
│   │
│   └── Supporting Files/
│       └── RemoteDesktop.entitlements      # Entitlements
│
├── RemoteDesktopTests/                     # Unit tests
│   ├── NetworkTests/
│   │   ├── MessageCodecTests.swift
│   │   └── NetworkConnectionTests.swift
│   │
│   ├── CodecTests/
│   │   └── VideoEncoderDecoderTests.swift
│   │
│   ├── StreamingTests/
│   │   └── JitterBufferTests.swift
│   │
│   └── InputTests/
│       ├── InputSerializerTests.swift
│       └── CoordinateMapperTests.swift
│
└── RemoteDesktopUITests/                   # UI tests
    └── RemoteDesktopUITests.swift
```

## Key Files Description

### Application Entry
- **RemoteDesktopApp.swift**: SwiftUI `@main` entry point
- **AppDelegate.swift**: Lifecycle events, background mode

### Host Side
- **HostController.swift**: Orchestrates capture → encode → stream
- **NetworkListener.swift**: Accepts incoming connections
- **ScreenCaptureManager.swift**: Captures screen using ScreenCaptureKit
- **VideoEncoder.swift**: Encodes to H.264
- **FrameStreamer.swift**: Sends encoded frames
- **InputEventInjector.swift**: Injects received input

### Client Side
- **ClientController.swift**: Orchestrates receive → decode → render
- **NetworkConnection.swift**: Connects to host
- **FrameReceiver.swift**: Receives frame packets
- **VideoDecoder.swift**: Decodes H.264
- **MetalRenderer.swift**: Renders to display
- **InputEventCaptor.swift**: Captures user input

### Shared Infrastructure
- **NetworkProtocol.swift**: Message format definitions
- **MessageCodec.swift**: Serialization logic
- **SecurityManager.swift**: Authentication & TLS
- **SessionManager.swift**: State management
- **PermissionManager.swift**: System permission requests

## Build Configuration

### Info.plist Key Entries
```xml
<key>LSMinimumSystemVersion</key>
<string>13.0</string>

<key>NSScreenCaptureUsageDescription</key>
<string>This app needs to capture your screen to stream it remotely</string>

<key>NSAccessibilityUsageDescription</key>
<string>This app needs accessibility access to control your mouse and keyboard remotely</string>

<key>LSUIElement</key>
<false/>  <!-- Set true for background-only mode -->
```

### Entitlements
```xml
<key>com.apple.security.network.server</key>
<true/>

<key>com.apple.security.network.client</key>
<true/>

<key>com.apple.security.device.camera</key>
<false/>

<key>com.apple.security.device.microphone</key>
<false/>
```

## Dependencies

### System Frameworks (linked)
- ScreenCaptureKit.framework
- VideoToolbox.framework
- Network.framework
- CoreGraphics.framework
- Metal.framework
- MetalKit.framework
- AVFoundation.framework
- SwiftUI.framework
- AppKit.framework

### Swift Package Dependencies
None required - all using system frameworks

## Build Targets

1. **RemoteDesktop**: Main app target
2. **RemoteDesktopTests**: Unit tests
3. **RemoteDesktopUITests**: UI automation tests

## Deployment

- **Minimum macOS**: 13.0 (Ventura)
- **Architectures**: arm64, x86_64
- **Code Signing**: Development team required
- **Sandboxing**: Disabled (requires broad system access)

## Future Structure Additions

When implementing extra features:

```
Clipboard/
├── ClipboardMonitor.swift      # Watch for clipboard changes
├── ClipboardSynchronizer.swift # Sync clipboard content
└── ClipboardSerializer.swift   # Serialize clipboard data

FileTransfer/
├── FileTransferManager.swift   # File transfer coordination
├── FileChunker.swift            # Split files into chunks
└── FileReceiver.swift           # Reassemble chunks

Audio/
├── AudioCaptureManager.swift   # Capture system audio
├── AudioEncoder.swift           # Encode audio (AAC/Opus)
└── AudioRenderer.swift          # Play received audio
```

## Development Workflow

1. Start with `Networking/` module
2. Test network layer independently
3. Move to `Capture/` and `Codec/`
4. Test encoding pipeline
5. Add `Streaming/` layer
6. Test end-to-end video
7. Add `InputControl/`
8. Build UI in `UI/`
9. Integrate all modules via controllers
10. Add error handling and polish
