#!/bin/bash
# Exit on any error
set -e

echo "🧹 Cleaning up old builds..."
rm -rf RemoteDesktop.app
rm -rf .build

echo "🔨 Building RemoteDesktop..."
# Build the application via Swift Package Manager
swift build -c debug

echo "📦 Packaging into RemoteDesktop.app..."
# Create the standard macOS App Bundle structure
mkdir -p RemoteDesktop.app/Contents/MacOS

# Copy the built executable into the bundle
cp .build/arm64-apple-macosx/debug/RemoteDesktop RemoteDesktop.app/Contents/MacOS/

# Create a clean Info.plist so macOS correctly registers its Identifier for Permissions!
cat <<EOF > RemoteDesktop.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>RemoteDesktop</string>
    <key>CFBundleIdentifier</key>
    <string>com.remotedesktop</string>
    <key>CFBundleName</key>
    <string>RemoteDesktop</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>RemoteDesktop requires screen capture access to stream your desktop to clients.</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>LSUIElement</key>
    <integer>0</integer>
</dict>
</plist>
EOF

echo "🔐 Signing App Bundle with Entitlements..."
# Sign the app with the specific entitlements
codesign --force --deep --sign - --entitlements ./RemoteDesktop.entitlements RemoteDesktop.app

echo "🧹 Resetting TCC Permissions for fresh prompt..."
# This forces macOS to re-prompt for screen recording since the app signature changed
tccutil reset ScreenCapture com.remotedesktop 2>/dev/null || echo "Note: Could not reset TCC automatically. You may need to remove it manually from System Settings."

echo "✅ App Signature Verification:"
codesign -d --entitlements - RemoteDesktop.app

echo "\n✨ Done! Your app is ready at ./RemoteDesktop.app"
echo "⚠️ IMPORTANT: When you launch it, check System Settings > Privacy & Security > Screen Recording."
echo "If RemoteDesktop is already toggled ON but the screen is black, REMOVE it (-) and restart the app."
