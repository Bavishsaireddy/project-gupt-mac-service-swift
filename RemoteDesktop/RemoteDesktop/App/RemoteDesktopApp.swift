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
    
    // Inject controllers as environment objects or state
    @StateObject private var hostController = HostController()
    @StateObject private var clientController = ClientController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(hostController)
                .environmentObject(clientController)
                .frame(minWidth: 900, minHeight: 700)
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
    @EnvironmentObject var hostController: HostController
    @EnvironmentObject var clientController: ClientController

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
                HostContainerView(onBack: {
                    selectedMode = .selection
                })

            case .client:
                ClientContainerView(onBack: {
                    selectedMode = .selection
                })
            }
        }
        .animation(.easeInOut, value: selectedMode)
    }
}

// MARK: - Container Views

struct HostContainerView: View {
    let onBack: () -> Void
    @EnvironmentObject var hostController: HostController
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                    Text("Back to Selection")
                }
                .buttonStyle(.plain)
                .padding()
                
                Spacer()
            }
            .background(Color(nsColor: .windowBackgroundColor))
            
            HostView(controller: hostController)
        }
    }
}

struct ClientContainerView: View {
    let onBack: () -> Void
    @EnvironmentObject var clientController: ClientController
    
    var body: some View {
        VStack(spacing: 0) {
            if !clientController.isConnected {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                        Text("Back to Selection")
                    }
                    .buttonStyle(.plain)
                    .padding()
                    
                    Spacer()
                }
                .background(Color(nsColor: .windowBackgroundColor))
            }
            
            ClientView(controller: clientController)
        }
    }
}

// MARK: - Mode Selection View

struct ModeSelectionView: View {
    @Binding var selectedMode: ContentView.AppMode

    var body: some View {
        VStack(spacing: 60) {
            VStack(spacing: 10) {
                Text("RemoteDesktop")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Professional bridge for your workspaces")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 50) {
                ModeButton(
                    title: "Host",
                    subtitle: "Share this Mac's screen",
                    icon: "desktopcomputer",
                    color: .blue
                ) {
                    selectedMode = .host
                }

                ModeButton(
                    title: "Client",
                    subtitle: "Control a remote Mac",
                    icon: "rectangle.connected.to.line.below",
                    color: .purple
                ) {
                    selectedMode = .client
                }
            }

            Spacer()
                .frame(height: 20)
            
            // Permission Quick Status
            HStack(spacing: 30) {
                PermissionBadge(title: "Capture", isGranted: CGPreflightScreenCaptureAccess())
                PermissionBadge(title: "Control", isGranted: AXIsProcessTrusted())
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(60)
    }
}

// MARK: - Shared Components

struct ModeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: icon)
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(color)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 280, height: 280)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: isHovered ? color.opacity(0.2) : Color.black.opacity(0.05),
                           radius: isHovered ? 30 : 15, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isHovered ? color.opacity(0.5) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct PermissionBadge: View {
    let title: String
    let isGranted: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isGranted ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.secondary.opacity(0.1)))
    }
}


