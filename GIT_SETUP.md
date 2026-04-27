# Git Setup Guide

## Initial Repository Setup

The `.gitignore` file has been created to exclude:
- Xcode build artifacts
- User-specific settings
- macOS system files
- Certificates and keys (security)
- IDE configuration files
- Temporary files

## Files to Commit

### Documentation (Already created) ✅
```
ARCHITECTURE.md
IMPLEMENTATION_PLAN.md
BUILD_GUIDE.md
PROJECT_STATUS.md
GETTING_STARTED.md
QUICK_REFERENCE.md
FILE_STRUCTURE.md
README.md
GIT_SETUP.md
.gitignore
```

### Source Code ✅
```
RemoteDesktop/
├── RemoteDesktop/
│   ├── Networking/
│   │   ├── NetworkProtocol.swift
│   │   ├── NetworkConnection.swift
│   │   ├── NetworkListener.swift
│   │   ├── MessageCodec.swift
│   │   └── SecurityManager.swift
│   │
│   ├── Capture/
│   │   ├── ScreenCaptureManager.swift
│   │   └── CaptureConfiguration.swift
│   │
│   ├── Codec/
│   │   ├── VideoEncoder.swift
│   │   ├── VideoDecoder.swift
│   │   └── CodecConfiguration.swift
│   │
│   ├── InputControl/
│   │   ├── InputEventInjector.swift
│   │   └── InputEventCaptor.swift
│   │
│   └── App/
│       ├── RemoteDesktopApp.swift
│       └── AppDelegate.swift
│
├── Info.plist
└── (Xcode project files - will be created)
```

## Git Commands

### Initialize Repository

```bash
cd /Users/sampath/dev/project-gupt-mac-service-swift

# Check git status
git status

# Stage all files
git add .

# Check what will be committed
git status

# Review files to commit
git diff --cached --stat
```

### First Commit

```bash
# Commit with detailed message
git commit -m "feat: initial implementation of remote desktop foundation

Architecture and implementation:
- Complete network layer with TLS support (5 files)
- Screen capture using ScreenCaptureKit (2 files)
- H.264 video encoding/decoding via VideoToolbox (3 files)
- Input control with CGEvents (2 files)
- SwiftUI application shell (2 files)
- Comprehensive documentation (8 files)

Status: 29% complete, foundational layers implemented

Components completed:
✅ Networking (100%) - P2P connections, message protocol, security
✅ Capture (100%) - High-performance screen capture
✅ Codec (100%) - Hardware-accelerated H.264 encoding/decoding
✅ Input Control (50%) - Mouse/keyboard injection and capture
✅ App Shell (10%) - Basic SwiftUI interface

To implement:
- Frame streaming pipeline
- Metal rendering
- Host/Client controllers
- Full UI implementation

Technology stack:
- Swift 5.9+, SwiftUI
- ScreenCaptureKit, VideoToolbox, Network.framework
- macOS 13.0+, hardware acceleration

Target: <100ms latency, 30-60 fps, P2P connection

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

### Alternative: Simpler First Commit

```bash
git commit -m "Initial commit: Remote Desktop foundation (29% complete)

- Network layer: TLS connections, message protocol
- Capture layer: ScreenCaptureKit integration
- Codec layer: H.264 encoding/decoding
- Input control: Mouse/keyboard injection
- Documentation: Architecture, implementation plan, guides

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

### Check Commit

```bash
# View commit
git log --oneline

# View files in commit
git show --stat

# View full commit
git show
```

## What's Ignored

The `.gitignore` ensures these are **NOT** committed:

### Build Artifacts ❌
```
build/
DerivedData/
*.app
*.dSYM
.build/
```

### User-Specific ❌
```
xcuserdata/
*.xcuserstate
.swiftpm/
```

### System Files ❌
```
.DS_Store
._*
.Spotlight-V100
```

### Security (Critical!) ❌
```
*.p12
*.pem
*.key
*.cer
*.mobileprovision
**/secrets.plist
```

### IDE Files ❌
```
.vscode/
.idea/
*.sublime-workspace
```

## Branch Strategy (Recommended)

```bash
# Main branch for stable code
git branch -M main

# Development branch
git checkout -b develop

# Feature branches
git checkout -b feature/streaming-layer
git checkout -b feature/metal-renderer
git checkout -b feature/controllers
```

## Typical Workflow

```bash
# Create feature branch
git checkout -b feature/streaming-layer

# Make changes...
# (implement FrameStreamer.swift, etc.)

# Stage changes
git add RemoteDesktop/RemoteDesktop/Streaming/

# Commit
git commit -m "feat: implement frame streaming pipeline

- Add FrameStreamer for sending frames
- Add FrameReceiver for receiving frames
- Add JitterBuffer for frame reordering
- Handle packet loss and out-of-order delivery

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Merge back to develop
git checkout develop
git merge feature/streaming-layer

# Delete feature branch
git branch -d feature/streaming-layer
```

## Commit Message Convention

Use conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting)
- `refactor`: Code restructuring
- `perf`: Performance improvement
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**

```bash
# Feature
git commit -m "feat(renderer): add Metal-based video renderer"

# Bug fix
git commit -m "fix(encoder): handle frame drops correctly"

# Documentation
git commit -m "docs: update architecture with rendering pipeline"

# Performance
git commit -m "perf(encoder): optimize buffer reuse"

# Refactor
git commit -m "refactor(network): simplify message codec"
```

## Remote Repository

### Add Remote (GitHub/GitLab)

```bash
# Add origin
git remote add origin https://github.com/yourusername/remote-desktop-macos.git

# Or SSH
git remote add origin git@github.com:yourusername/remote-desktop-macos.git

# Verify
git remote -v

# Push to remote
git push -u origin main
```

### Push Development Branch

```bash
git push -u origin develop
```

## Tags for Releases

```bash
# Tag current version
git tag -a v0.1.0 -m "Initial foundation - 29% complete

Components:
- Network layer
- Capture layer
- Codec layer
- Input control
- Basic UI shell"

# Push tags
git push origin --tags

# List tags
git tag -l
```

## View Repository Status

```bash
# Compact status
git status -s

# See what's tracked
git ls-files

# See what's ignored
git status --ignored

# Repository size
git count-objects -vH
```

## Clean Repository

```bash
# Remove untracked files (dry run)
git clean -n

# Remove untracked files (for real)
git clean -f

# Remove untracked directories too
git clean -fd

# Remove ignored files too (careful!)
git clean -fdx
```

## Useful Git Aliases

Add to `~/.gitconfig`:

```ini
[alias]
    st = status -s
    co = checkout
    br = branch
    ci = commit
    lg = log --oneline --graph --decorate --all
    last = log -1 HEAD
    unstage = reset HEAD --
    amend = commit --amend
    undo = reset --soft HEAD^
```

Usage:
```bash
git st          # Short status
git lg          # Pretty log
git last        # Last commit
git amend       # Amend last commit
```

## Pre-commit Checks

Before committing, verify:

```bash
# 1. Check status
git status

# 2. Verify no secrets
git diff --cached | grep -i "password\|secret\|key\|token\|api"

# 3. Check Swift syntax (if files changed)
find RemoteDesktop -name "*.swift" -exec swiftc -syntax {} \;

# 4. Review changes
git diff --cached

# 5. Commit
git commit
```

## Repository Size

Current estimated size:
```
Source code:     ~150 KB (14 Swift files)
Documentation:   ~100 KB (8 MD files)
Total:           ~250 KB (very small)
```

After Xcode project creation:
```
+ Xcode project: ~50 KB
+ Assets:        ~100 KB
Total:           ~400 KB (still small)
```

## .gitattributes (Optional)

Create `.gitattributes` for line ending consistency:

```bash
# Auto detect text files
* text=auto

# Swift files
*.swift text diff=swift

# Xcode files
*.pbxproj text
*.xcworkspacedata text
*.xcscheme text

# Documentation
*.md text

# Binary files
*.png binary
*.jpg binary
*.app binary
*.framework binary
```

## Summary

✅ `.gitignore` created and configured
✅ Ready to commit all source files
✅ Security files excluded
✅ Build artifacts excluded
✅ Clean repository structure

**Next steps:**
1. Review files: `git status`
2. Stage files: `git add .`
3. Commit: Use commit message above
4. Optional: Add remote and push

Your repository will be clean, secure, and professional! 🎉
