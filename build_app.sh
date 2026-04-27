#!/bin/bash
# Exit on any error
set -e

echo "🧹 Cleaning up old builds..."
rm -rf GUPT.app
rm -rf RemoteDesktop.app
rm -rf .build

echo "🔨 Building GUPT (Universal)..."
# Build the application via Swift Package Manager for both Intel and Apple Silicon
swift build -c debug --arch x86_64 --arch arm64

echo "📦 Packaging into GUPT.app..."
# Create the standard macOS App Bundle structure
mkdir -p GUPT.app/Contents/MacOS

# Copy the built executable into the bundle
cp .build/apple/Products/Debug/RemoteDesktop GUPT.app/Contents/MacOS/GUPT

# Create a clean Info.plist so macOS correctly registers its Identifier for Permissions!
cat <<EOF > GUPT.app/Contents/Info.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GUPT</string>
    <key>CFBundleIdentifier</key>
    <string>com.gupt</string>
    <key>CFBundleName</key>
    <string>GUPT</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>GUPT requires screen capture access to stream your desktop to clients.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>GUPT requires accessibility access to control your mouse and keyboard remotely.</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>LSUIElement</key>
    <integer>0</integer>
</dict>
</plist>
EOF

echo "🔐 Signing App Bundle with Entitlements..."
# Sign the app with the specific entitlements
codesign --force --deep --sign - --entitlements ./RemoteDesktop.entitlements GUPT.app

echo "🧹 Resetting TCC Permissions for fresh prompt..."
# This forces macOS to re-prompt for screen recording and accessibility since the app signature changed
tccutil reset ScreenCapture com.gupt 2>/dev/null || echo "Note: Could not reset ScreenCapture TCC automatically."
tccutil reset Accessibility com.gupt 2>/dev/null || echo "Note: Could not reset Accessibility TCC automatically."

echo "✅ App Signature Verification:"
codesign -d --entitlements - GUPT.app

echo "\n✨ Done! Your app is ready at ./GUPT.app"
echo "⚠️ IMPORTANT: When you launch it, check System Settings > Privacy & Security > Screen Recording."
echo "If GUPT is already toggled ON but the screen is black, REMOVE it (-) and restart the app."
