# RemoteDesktop - macOS Native Remote Desktop Application

A high-performance, peer-to-peer remote desktop application for macOS, built entirely in Swift using modern Apple frameworks.

## 🎯 Project Goal

Build a native macOS remote desktop solution similar to TeamViewer or Chrome Remote Desktop with:
- **Low latency** (<100ms target)
- **High performance** (30-60 fps smooth streaming)
- **Direct P2P connection** (no cloud/signaling server)
- **Modern Swift** (async/await, SwiftUI)
- **Extreme Stability** (Thread-safe networking, scalable GPU rendering)
- **Hardware acceleration** (GPU encoding/decoding)

## ✨ Features

### Implemented ✅
- **High-performance screen capture** using ScreenCaptureKit
- **Hardware-accelerated H.264 encoding/decoding** via VideoToolbox
- **Low-latency TCP networking** with thread-safe synchronized buffering
- **Scalable Metal Video Rendering** using custom GPU shaders
- **Full remote control** (mouse, keyboard, scroll)
- **Secure authentication** with password hashing
- **Multiple quality presets** (360p to 1080p)
- **Adaptive bitrate** (500 Kbps to 20 Mbps)
- **Permission management** for screen recording and accessibility

### Planned 🚧
- Adaptive quality based on network conditions
- Background/hidden host mode
- Clipboard synchronization
- File transfer
- Multi-monitor support
- Audio streaming

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│  SwiftUI Application Layer                  │
│  - Host Mode / Client Mode                  │
└─────────────────────────────────────────────┘
                    ↓
┌──────────────┬───────────────┬──────────────┐
│  Networking  │   Streaming   │   Rendering  │
│  - TLS/TCP   │   - Jitter    │   - Metal    │
│  - Messages  │   - Flow Ctrl │   - Vsync    │
└──────────────┴───────────────┴──────────────┘
                    ↓
┌──────────────┬───────────────┬──────────────┐
│   Capture    │     Codec     │  Input Ctrl  │
│  - SCKit     │  - VideoTool  │  - CGEvents  │
└──────────────┴───────────────┴──────────────┘
```

### Technology Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Networking | Network.framework (NWConnection, NWListener) |
| Screen Capture | ScreenCaptureKit |
| Video Codec | VideoToolbox (H.264) |
| Rendering | Metal |
| Input Control | CoreGraphics Events |
| Concurrency | Swift async/await, Actors |

## 📋 Requirements

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 15.0+
- **Swift**: 5.9+
- **Hardware**: Apple Silicon (M1/M2/M3) or Intel Mac with hardware video encoding

## 🚀 Quick Start

### 1. Clone and Setup

```bash
cd /Users/sampath/dev/project-gupt-mac-service-swift/RemoteDesktop
```

### 2. Create Xcode Project

**Option A: Using Xcode GUI** (Recommended)
1. Open Xcode
2. File → New → Project
3. Select macOS → App
4. Product Name: `RemoteDesktop`
5. Interface: SwiftUI
6. Save to the `RemoteDesktop` directory
7. Add existing source files to project

**Option B: Use provided files**
- All source code is already organized in correct structure
- Simply create new Xcode project and add files

See **[BUILD_GUIDE.md](BUILD_GUIDE.md)** for detailed instructions.

### 3. Configure Permissions

The app requires two system permissions:

**Screen Recording**
```
System Settings → Privacy & Security → Screen Recording → Enable RemoteDesktop
```

**Accessibility** (for input control)
```
System Settings → Privacy & Security → Accessibility → Enable RemoteDesktop
```

### 4. Link Frameworks

Add these frameworks in Xcode:
- ScreenCaptureKit.framework
- VideoToolbox.framework
- Network.framework
- CoreGraphics.framework
- Metal.framework
- MetalKit.framework
- AVFoundation.framework

### 5. Build and Run

```bash
# In Xcode
Cmd + R

# Or command line (if Package.swift created)
swift build -c release
.build/release/RemoteDesktop
```

## 🎮 Usage

### Host Mode (Share your screen)

1. Launch RemoteDesktop
2. Select "Host" mode
3. Click "Start Server"
4. Note your IP address (e.g., `192.168.1.100`)
5. Share IP + Port (`5900`) with client

### Client Mode (Connect to remote)

1. Launch RemoteDesktop
2. Select "Client" mode
3. Enter host IP address
4. Enter port (default: `5900`)
5. Click "Connect"
6. Control remote desktop with mouse/keyboard

### Network Configuration

**Local Network (same WiFi)**
- Use host's local IP (e.g., `192.168.1.100`)
- No router configuration needed

**Internet (different networks)**
- Configure port forwarding on host's router: `5900 → host IP`
- Use public IP address
- Consider security implications

## 📁 Project Structure

```
RemoteDesktop/
├── ARCHITECTURE.md          # Detailed system architecture
├── IMPLEMENTATION_PLAN.md   # 5-week development roadmap
├── BUILD_GUIDE.md          # Build and setup instructions
├── PROJECT_STATUS.md       # Current progress (29% complete)
├── FILE_STRUCTURE.md       # Complete file layout
│
└── RemoteDesktop/
    ├── App/                # Application entry point
    ├── Networking/         # Network layer (100% ✅ - Thread-safe)
    ├── Capture/            # Screen capture (100% ✅)
    ├── Codec/              # Video encoding/decoding (100% ✅)
    ├── InputControl/       # Remote input (50% ✅)
    ├── Streaming/          # Frame streaming (100% ✅)
    ├── Rendering/          # Video rendering (100% ✅ - Metal Shaders)
    └── UI/                 # SwiftUI interface (20% 🚧)
```

## 🔧 Development

### Current Status

**Completed Components** (45% of total):
- ✅ Complete network stack with TLS and synchronized buffering
- ✅ Frame streaming pipeline (End-to-End)
- ✅ Metal-based scalable rendering pipeline
- ✅ Screen capture using ScreenCaptureKit
- ✅ H.264 encoding/decoding with VideoToolbox
- ✅ Input injection (mouse/keyboard)
- ✅ Input capture
- ✅ Basic SwiftUI app shell

**In Progress**:
- 🚧 Host/Client connectivity status UI
- 🚧 Full UI implementation & polish

See [PROJECT_STATUS.md](PROJECT_STATUS.md) for detailed progress.

## 📊 Performance

### Target Metrics
- **End-to-end latency**: <100ms
- **Frame rate**: 30-60 fps
- **CPU usage (host)**: <50%
- **CPU usage (client)**: <30%
- **Bandwidth**: 2-10 Mbps (adaptive)

### Quality Presets

| Preset | Resolution | FPS | Bitrate | Use Case |
|--------|-----------|-----|---------|----------|
| Ultra Low | 360p | 15 | 500 Kbps | Slow connections |
| Low | 540p | 30 | 1 Mbps | Mobile hotspot |
| Medium | 720p | 30 | 2.5 Mbps | Standard WiFi |
| High | 1080p | 30 | 5 Mbps | Fast LAN |
| Very High | 1080p | 60 | 10 Mbps | Wired connection |

## 🛠️ Troubleshooting

### "Screen recording permission denied"
→ Grant permission in System Settings → Privacy & Security → Screen Recording

### "Connection refused"
→ Check firewall settings, verify host is running and IP is correct

### "High latency"
→ Try lower quality preset, use wired connection, reduce network congestion

### Build errors
→ Verify macOS deployment target is 13.0+, all frameworks linked

See [BUILD_GUIDE.md](BUILD_GUIDE.md) for more troubleshooting.

## 📚 Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design, data flow, protocols
- **[IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md)** - Phased development plan
- **[BUILD_GUIDE.md](BUILD_GUIDE.md)** - Setup and build instructions
- **[PROJECT_STATUS.md](PROJECT_STATUS.md)** - Current progress and next steps
- **[FILE_STRUCTURE.md](FILE_STRUCTURE.md)** - Complete file organization

## 🔐 Security

### Current Implementation
- TLS 1.3 encryption for network traffic
- SHA-256 password hashing with salt
- Session tokens with expiration
- Self-signed certificates (for testing)

### Production Recommendations
- Use proper certificate authority
- Implement public key authentication
- Add IP whitelisting
- Enable audit logging
- Rate limiting for auth attempts

## 📖 Learning Resources

This project demonstrates:
- **ScreenCaptureKit** - Modern screen capture API
- **VideoToolbox** - Hardware video encoding/decoding
- **Network.framework** - Modern networking with TLS
- **CoreGraphics Events** - Low-level input control
- **Swift Concurrency** - async/await, actors
- **SwiftUI** - Declarative UI
- **Metal** - GPU-accelerated rendering

### References
- [ScreenCaptureKit Documentation](https://developer.apple.com/documentation/screencapturekit)
- [VideoToolbox Documentation](https://developer.apple.com/documentation/videotoolbox)
- [Network Framework Guide](https://developer.apple.com/documentation/network)
- [H.264 Specification](https://www.itu.int/rec/T-REC-H.264)

## 🎯 Roadmap

### Phase 1 - MVP (Week 2-3) ✅
- [x] Complete streaming pipeline
- [x] Implement Metal renderer (Scalable Shader-based)
- [x] Wire up host/client controllers
- [x] End-to-end video streaming success

### Phase 2 - Beta (Week 3-4) 🚧
- [ ] Authentication flow
- [ ] Error handling
- [ ] Permission management UI
- [ ] Performance monitoring

### Phase 3 - Release (Week 4-5)
- [ ] Background mode
- [ ] Adaptive quality
- [ ] Polish UI
- [ ] Testing and optimization

### Phase 4 - Extra Features
- [ ] Clipboard sync
- [ ] File transfer
- [ ] Multi-monitor
- [ ] Audio streaming

---

**Current Status**: 45% complete, MVP reached, end-to-end streaming stable

**Last Updated**: 2026-04-08
