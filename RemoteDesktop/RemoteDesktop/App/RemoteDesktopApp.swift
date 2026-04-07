//
//  RemoteDesktopApp.swift
//  RemoteDesktop
//
//  Main application entry point
//

import SwiftUI

@main
struct RemoteDesktopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About RemoteDesktop") {
                    NSApplication.shared.orderFrontStandardAboutPanel()
                }
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

/// Main content view with mode selection
struct ContentView: View {
    @State private var selectedMode: AppMode = .selection

    enum AppMode {
        case selection
        case host
        case client
    }

    var body: some View {
        ZStack {
            switch selectedMode {
            case .selection:
                ModeSelectionView(selectedMode: $selectedMode)

            case .host:
                HostMainView(onBack: {
                    selectedMode = .selection
                })

            case .client:
                ClientMainView(onBack: {
                    selectedMode = .selection
                })
            }
        }
    }
}

/// Mode selection view
struct ModeSelectionView: View {
    @Binding var selectedMode: ContentView.AppMode

    var body: some View {
        VStack(spacing: 40) {
            Text("RemoteDesktop")
                .font(.system(size: 48, weight: .bold))

            Text("Choose a mode to get started")
                .font(.title3)
                .foregroundColor(.secondary)

            HStack(spacing: 60) {
                // Host Mode Button
                ModeButton(
                    title: "Host",
                    subtitle: "Share your screen",
                    icon: "desktopcomputer",
                    color: .blue
                ) {
                    selectedMode = .host
                }

                // Client Mode Button
                ModeButton(
                    title: "Client",
                    subtitle: "Connect to a remote screen",
                    icon: "rectangle.connected.to.line.below",
                    color: .green
                ) {
                    selectedMode = .client
                }
            }

            Spacer()
                .frame(height: 40)

            VStack(spacing: 8) {
                Text("Requires Permissions:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 20) {
                    PermissionStatusBadge(
                        title: "Screen Recording",
                        isGranted: checkScreenRecordingPermission()
                    )

                    PermissionStatusBadge(
                        title: "Accessibility",
                        isGranted: checkAccessibilityPermission()
                    )
                }

                Button("Grant Permissions") {
                    openSystemPreferences()
                }
                .buttonStyle(.link)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(60)
    }

    private func checkScreenRecordingPermission() -> Bool {
        if #available(macOS 12.3, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return false
    }

    private func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    private func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Mode button component
struct ModeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(color)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.title)
                        .fontWeight(.semibold)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 250, height: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: isHovered ? color.opacity(0.3) : Color.black.opacity(0.1),
                           radius: isHovered ? 20 : 10)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// Permission status badge
struct PermissionStatusBadge: View {
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
                .font(.caption)

            Text(title)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

/// Placeholder settings view
struct SettingsView: View {
    @AppStorage("defaultPort") private var defaultPort = 5900
    @AppStorage("autoStartHost") private var autoStartHost = false

    var body: some View {
        Form {
            Section("Network") {
                TextField("Default Port", value: $defaultPort, format: .number)
                    .frame(width: 200)
            }

            Section("Host") {
                Toggle("Auto-start host mode", isOn: $autoStartHost)
            }

            Section("About") {
                Text("RemoteDesktop v1.0")
                Text("High-performance remote desktop for macOS")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

// MARK: - Placeholder Views (to be implemented)

struct HostMainView: View {
    let onBack: () -> Void
    @State private var isRunning = false

    var body: some View {
        VStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding()

            Spacer()

            VStack(spacing: 20) {
                Text("Host Mode")
                    .font(.largeTitle)

                if isRunning {
                    VStack(spacing: 12) {
                        Text("Server Running")
                            .font(.title2)
                            .foregroundColor(.green)

                        Text("IP Address: \(getLocalIPAddress())")
                            .font(.title3)
                            .monospaced()

                        Text("Port: 5900")
                            .font(.title3)
                            .monospaced()

                        Text("Share this information with clients to connect")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                }

                Button(isRunning ? "Stop Server" : "Start Server") {
                    isRunning.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(isRunning ? .red : .blue)
                .controlSize(.large)
            }

            Spacer()
        }
    }

    private func getLocalIPAddress() -> String {
        let addresses = NetworkListener.getLocalIPAddresses()
        return addresses.first(where: { !$0.contains(":") }) ?? "Unknown"
    }
}

struct ClientMainView: View {
    let onBack: () -> Void
    @State private var hostIP = ""
    @State private var hostPort = "5900"
    @State private var isConnected = false

    var body: some View {
        VStack {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding()

            Spacer()

            VStack(spacing: 20) {
                Text("Client Mode")
                    .font(.largeTitle)

                if !isConnected {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Host IP Address")
                                .font(.headline)
                            TextField("192.168.1.100", text: $hostIP)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 300)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Port")
                                .font(.headline)
                            TextField("5900", text: $hostPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 300)
                        }

                        Button("Connect") {
                            isConnected = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(hostIP.isEmpty)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Text("Connected")
                            .font(.title2)
                            .foregroundColor(.green)

                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 400)
                            .overlay(
                                Text("Remote Desktop Display\n(To be implemented)")
                                    .foregroundColor(.white)
                            )

                        Button("Disconnect") {
                            isConnected = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            }

            Spacer()
        }
    }
}
