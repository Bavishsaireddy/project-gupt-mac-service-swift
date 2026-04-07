# Getting Started - RemoteDesktop [COMPLETE]

This project is a high-performance, native macOS remote desktop system (Host & Client) built with **Swift**, **ScreenCaptureKit**, **VideoToolbox**, and **Metal**.

## 💻 System Requirements
- **OS**: macOS 13.0 (Ventura) or newer.
- **Hardware**: MacBook, Mac Mini, or iMac (Intel or Apple Silicon).
- **Tools**: **Xcode 15 or newer** ([Download here](https://apps.apple.com/us/app/xcode/id497799835?mt=12)).

---

## 🛠️ Installation & Setup (On your Mac)

1. **Clone/Move Code**: Ensure the project folder is on your Mac.
2. **Open Xcode**: Double-click the **`RemoteDesktop.xcodeproj`** file.
3. **Configure Signing**:
   - In the left sidebar, click the blue **RemoteDesktop** icon.
   - Select the **RemoteDesktop** target in the center.
   - Go to the **Signing & Capabilities** tab.
   - Select your **Team** (you can use your free Apple ID account).

---

## 🚀 How to Run (PC-A & PC-B Example)

### Step 1: Start the Host (PC-A)
*The computer you want to control.*

1. In Xcode, press **Command + R** to run.
2. Click the **"Host"** button on the main screen.
3. **Grant Permissions**: 
   - A guide will appear. Follow the buttons to enable **Screen Recording** and **Accessibility** in System Settings.
   - *Note: You may need to restart the app after granting permissions.*
4. Click **"Start Server."**
5. Note the **IP Address** and **Password** shown on the screen.

### Step 2: Start the Client (PC-B)
*The computer you use to view/control PC-A.*

1. In Xcode on PC-B, press **Command + R** to run.
2. Click the **"Client"** button.
3. Enter the **IP Address** and **Password** from PC-A.
4. Click **"Connect."**

---

## 🛑 Troubleshooting

### 1. Permissions Not Working?
If you've enabled permissions but the screen is still black:
- Go to `System Settings > Privacy & Security > Screen Recording`.
- Remove "RemoteDesktop" with the `-` button and add it back or toggle it off and on.
- Restart the app.

### 2. Connection Failed?
- Ensure both Macs are on the **same WiFi/LAN**.
- Check if your Mac's firewall is blocking the app (`System Settings > Network > Firewall`).
- Try connecting to `localhost` on a single Mac first to verify the app logic.

### 3. Xcode Build Errors?
- Ensure the **Deployment Target** is set to macOS 13.0 or higher.
- Make sure all frameworks (Metal, VideoToolbox, etc.) are linked in the target settings.

---

## 📂 Project Summary
- **Languages**: 100% Swift
- **UI Framework**: SwiftUI
- **Graphics**: Metal GPU Rendering
- **Capture**: ScreenCaptureKit (Apple's latest)
- **Networking**: Network.framework (TLS Secured)
