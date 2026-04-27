//
//  RemoteDesktopApp.swift
//  GUPT
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
                Button("About GUPT") {
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
        .animation(.easeInOut(duration: 0.3), value: selectedMode)
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
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .padding()
                
                Spacer()
                
                Text("GUPT")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.trailing, 16)
            }
            .background(Color(red: 0.08, green: 0.08, blue: 0.12))
            
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
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .padding()
                    
                    Spacer()
                    
                    Text("GUPT")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.trailing, 16)
                }
                .background(Color(red: 0.08, green: 0.08, blue: 0.12))
            }
            
            ClientView(controller: clientController)
        }
    }
}

// MARK: - Mode Selection View

struct ModeSelectionView: View {
    @Binding var selectedMode: ContentView.AppMode
    @State private var glowPhase: Double = 0

    var body: some View {
        ZStack {
            // Deep dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.10),
                    Color(red: 0.08, green: 0.06, blue: 0.14),
                    Color(red: 0.06, green: 0.08, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle animated orbs in the background
            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.05, green: 0.58, blue: 0.53).opacity(0.15), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: geo.size.width * 0.6, y: geo.size.height * 0.15)
                    .blur(radius: 60)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.12), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 350, height: 350)
                    .offset(x: geo.size.width * 0.1, y: geo.size.height * 0.55)
                    .blur(radius: 50)
            }

            VStack(spacing: 50) {
                Spacer()
                    .frame(height: 20)

                // GUPT Title with glow
                VStack(spacing: 12) {
                    Text("GUPT")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.05, green: 0.75, blue: 0.65),
                                    Color(red: 0.39, green: 0.40, blue: 0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color(red: 0.05, green: 0.75, blue: 0.65).opacity(0.3), radius: 20, x: 0, y: 0)

                    Text("Secure bridge for your workspaces")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }

                // Mode selection cards
                HStack(spacing: 40) {
                    GuptModeButton(
                        title: "Host",
                        subtitle: "Share this Mac's screen",
                        icon: "desktopcomputer",
                        accentColor: Color(red: 0.05, green: 0.58, blue: 0.53)  // Teal
                    ) {
                        selectedMode = .host
                    }

                    GuptModeButton(
                        title: "Client",
                        subtitle: "Control a remote Mac",
                        icon: "rectangle.connected.to.line.below",
                        accentColor: Color(red: 0.39, green: 0.40, blue: 0.95)  // Indigo
                    ) {
                        selectedMode = .client
                    }
                }

                Spacer()
                    .frame(height: 10)
                
                // Permission Quick Status
                HStack(spacing: 24) {
                    GuptPermissionBadge(title: "Screen Capture", isGranted: CGPreflightScreenCaptureAccess())
                    GuptPermissionBadge(title: "Accessibility", isGranted: AXIsProcessTrusted())
                }
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(50)
        }
    }
}

// MARK: - GUPT Mode Button

struct GuptModeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 24) {
                ZStack {
                    // Glow ring
                    Circle()
                        .fill(accentColor.opacity(isHovered ? 0.2 : 0.08))
                        .frame(width: 100, height: 100)
                        .shadow(color: accentColor.opacity(isHovered ? 0.4 : 0.0), radius: 20)
                    
                    Image(systemName: icon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(accentColor)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 260, height: 260)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.08 : 0.04),
                                Color.white.opacity(isHovered ? 0.04 : 0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: isHovered ? accentColor.opacity(0.2) : Color.black.opacity(0.3),
                           radius: isHovered ? 30 : 15, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                isHovered ? accentColor.opacity(0.6) : Color.white.opacity(0.08),
                                isHovered ? accentColor.opacity(0.2) : Color.white.opacity(0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - GUPT Permission Badge

struct GuptPermissionBadge: View {
    let title: String
    let isGranted: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isGranted ? Color(red: 0.2, green: 0.8, blue: 0.4) : Color.orange)
                .frame(width: 7, height: 7)
                .shadow(color: isGranted ? Color.green.opacity(0.5) : Color.orange.opacity(0.5), radius: 4)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        )
    }
}
