# Build Guide - RemoteDesktop macOS Application

## Prerequisites

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later
- **Hardware**: Apple Silicon (M1/M2/M3) or Intel Mac with hardware video encoding support

## Quick Start

### Option 1: Create Xcode Project (Recommended)

1. **Open Xcode** → File → New → Project
2. Select **macOS** → **App**
3. Configure:
   - Product Name: `RemoteDesktop`
   - Team: Your development team
   - Organization Identifier: `com.yourcompany`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Uncheck: Use Core Data, Include Tests (we have custom test structure)

4. Save to: `/Users/sampath/dev/project-gupt-mac-service-swift/RemoteDesktop/`

5. **Add Source Files**:
   - In Xcode, right-click on the project
   - Add Files to "RemoteDesktop"
   - Select all folders under `RemoteDesktop/RemoteDesktop/`
   - Check "Copy items if needed"
   - Create groups

6. **Replace Info.plist**:
   - Use the provided `Info.plist` file in the project root

7. **Link Frameworks**:
   - Select project → Target → Build Phases → Link Binary With Libraries
   - Add:
     - ScreenCaptureKit.framework
     - VideoToolbox.framework
     - Network.framework
     - CoreGraphics.framework
     - Metal.framework
     - MetalKit.framework
     - AVFoundation.framework
     - SwiftUI.framework
     - AppKit.framework

8. **Configure Build Settings**:
   - Deployment Target: macOS 13.0
   - Supported Architectures: arm64, x86_64
   - Enable Hardened Runtime: Yes
   - Disable App Sandbox (required for screen capture and accessibility)

9. **Add Entitlements** (create `RemoteDesktop.entitlements`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.network.server</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.device.audio-input</key>
    <false/>
</dict>
</plist>
```

### Option 2: Command Line (For Advanced Users)

```bash
# Navigate to project directory
cd /Users/sampath/dev/project-gupt-mac-service-swift/RemoteDesktop

# Create Package.swift for initial testing
cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RemoteDesktop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "RemoteDesktop", targets: ["RemoteDesktop"])
    ],
    targets: [
        .executableTarget(
            name: "RemoteDesktop",
            path: "RemoteDesktop",
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("Network"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Metal"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
EOF

# Note: SPM doesn't fully support macOS apps with SwiftUI App lifecycle
# You'll need to use Xcode for final build
```

## Build Steps

### 1. Build the Project

In Xcode:
- Select scheme: RemoteDesktop
- Select target: My Mac
- Press Cmd+B to build

Or command line (if Package.swift created):
```bash
swift build -c release
```

### 2. Run the Application

In Xcode:
- Press Cmd+R to run

Or command line:
```bash
.build/release/RemoteDesktop
```

## Grant System Permissions

On first run, the app will request:

### Screen Recording Permission
1. System Settings → Privacy & Security → Screen Recording
2. Enable checkbox for RemoteDesktop

### Accessibility Permission
1. System Settings → Privacy & Security → Accessibility
2. Enable checkbox for RemoteDesktop

**Note**: You may need to quit and restart the app after granting permissions.

## Network Configuration

### Host Configuration

1. Check firewall settings
   ```bash
   # Check if firewall is enabled
   /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

   # If enabled, add RemoteDesktop
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/RemoteDesktop.app
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /path/to/RemoteDesktop.app
   ```

2. Note your IP address
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```

3. Default port: `5900` (configurable)

### Client Configuration

1. Ensure network connectivity to host
2. If connecting over internet, configure port forwarding on router
3. For testing, use same WiFi network

## Testing

### Local Testing (Same Mac)

1. Run the app
2. Start host mode
3. In another instance (or window), use client mode
4. Connect to `localhost` or `127.0.0.1`
5. Enter port `5900`

### LAN Testing (Two Macs)

**Mac 1 (Host)**:
1. Run app
2. Start host mode
3. Note IP address displayed (e.g., `192.168.1.100`)

**Mac 2 (Client)**:
1. Run app
2. Enter host IP: `192.168.1.100`
3. Enter port: `5900`
4. Connect

## Troubleshooting

### Build Errors

**"Cannot find 'SCStream' in scope"**
- Ensure deployment target is macOS 13.0+
- ScreenCaptureKit is available from macOS 12.3+

**Missing frameworks**
- Verify all frameworks are linked in Build Phases

**Code signing issues**
- Select a valid development team
- Trust certificate in Keychain Access

### Runtime Errors

**"Screen capture permission denied"**
- Grant Screen Recording permission in System Settings
- Restart the app

**"Failed to start listener"**
- Port 5900 may be in use (Apple Screen Sharing uses this)
- Try different port (e.g., 5901, 7000)
- Check if another instance is running

**"Connection refused"**
- Verify host IP address
- Check firewall settings
- Ensure host is running and listening

**"Video encoder failed"**
- Check if hardware encoding is available
- Try lower resolution/bitrate
- Check Console.app for detailed logs

### Performance Issues

**High latency (>200ms)**
- Check network bandwidth
- Reduce resolution or frame rate
- Use wired Ethernet instead of WiFi
- Disable other network-intensive apps

**Low frame rate**
- Reduce resolution
- Lower bitrate
- Check CPU usage in Activity Monitor
- Ensure hardware acceleration is enabled

**High CPU usage**
- Hardware encoding may not be working
- Try lower complexity settings
- Check encoding thread priority

## Development Tips

### Debugging

1. **Enable Logging**:
   ```swift
   // In Logger usage
   logger.debug("Detailed debug info")
   ```

2. **View Logs**:
   ```bash
   # Filter logs by subsystem
   log stream --predicate 'subsystem == "com.remotedesktop"' --level debug
   ```

3. **Profile Performance**:
   - Product → Profile (Cmd+I)
   - Use Time Profiler for CPU
   - Use Network instrument for bandwidth
   - Use Allocations for memory leaks

### Testing Components

Each layer can be tested independently:

- **Network**: Run NetworkTests
- **Capture**: Test ScreenCaptureManager in isolation
- **Encoder**: Feed test images to VideoEncoder
- **Decoder**: Decode test H.264 streams

### Common Modifications

**Change Port**:
```swift
// In NetworkListener initialization
let listener = NetworkListener(port: 7000)  // Change from 5900
```

**Adjust Quality**:
```swift
// Use quality presets
let config = CaptureConfiguration.mediumQuality
let codec = CodecConfiguration.mediumQuality
```

**Disable TLS** (for testing only):
```swift
let listener = NetworkListener(port: 5900, useTLS: false)
let connection = NetworkConnection(host: "192.168.1.100", port: 5900, useTLS: false)
```

## Next Steps

See IMPLEMENTATION_PLAN.md for remaining features:
- [ ] Complete Input Control implementation
- [ ] Build SwiftUI UI
- [ ] Add authentication
- [ ] Implement adaptive bitrate
- [ ] Add clipboard sync
- [ ] Multi-monitor support

## Resources

- [ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit)
- [VideoToolbox Documentation](https://developer.apple.com/documentation/videotoolbox)
- [Network Framework Documentation](https://developer.apple.com/documentation/network)
- [H.264 Specification](https://www.itu.int/rec/T-REC-H.264)

## Support

For issues and questions:
- Check ARCHITECTURE.md for system design
- Review IMPLEMENTATION_PLAN.md for features
- Check Console.app for runtime logs
- Use Xcode debugger for crashes
