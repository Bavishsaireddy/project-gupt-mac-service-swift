//
//  ClientView.swift
//  GUPT
//
//  Main user interface for the client mode
//

import SwiftUI

/// Main UI for client mode
struct ClientView: View {
    @ObservedObject var controller: ClientController
    @ObservedObject var sessionManager = SessionManager.shared
    
    @State private var roomCode = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var focusedField: String? = nil
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()

            if controller.isConnected {
                // If connected, show the remote display view
                RemoteDesktopView(controller: controller)
            } else {
                // If not connected, show the connection form
                VStack(spacing: 30) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connect to Remote")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("Enter the host details to start a session")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        
                        Spacer()
                        
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(10)
                                .background(Circle().fill(Color.white.opacity(0.06)))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(alignment: .top, spacing: 30) {
                        
                        // Connection Form
                        VStack(alignment: .leading, spacing: 22) {
                            Text("Connection Details")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                            
                            GuptTextField(
                                label: "Room Code",
                                placeholder: "123456",
                                text: $roomCode,
                                icon: "number"
                            )
                            
                            if let error = errorMessage {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 12))
                                    Text(error)
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(Color(red: 0.95, green: 0.4, blue: 0.4))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.red.opacity(0.1))
                                )
                            }
                            
                            Button(action: connect) {
                                HStack(spacing: 10) {
                                    if isConnecting {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "link")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    Text(isConnecting ? "Connecting..." : "Connect")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundColor(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            roomCode.isEmpty || isConnecting
                                                ? LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                                                : LinearGradient(colors: [Color(red: 0.39, green: 0.40, blue: 0.95), Color(red: 0.30, green: 0.32, blue: 0.85)], startPoint: .top, endPoint: .bottom)
                                        )
                                        .shadow(color: roomCode.isEmpty ? .clear : Color(red: 0.39, green: 0.40, blue: 0.95).opacity(0.3), radius: 12, y: 4)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(roomCode.isEmpty || isConnecting)
                        }
                        .padding(28)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                )
                        )
                        .frame(maxWidth: 400)
                        
                        // History Sidebar
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.4))
                                Text("Recent Connections")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            
                            if sessionManager.connectionHistory.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white.opacity(0.2))
                                    Text("No recent connections")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 30)
                            } else {
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(sessionManager.connectionHistory) { entry in
                                            GuptHistoryRow(entry: entry) {
                                                self.roomCode = entry.roomCode
                                            }
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.04), Color.white.opacity(0.015)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                                )
                        )
                        .frame(width: 280)
                    }
                    
                    Spacer()
                }
                .padding(40)
            }
        }
        .sheet(isPresented: $showSettings) {
             SettingsView()
        }
    }
    
    // MARK: - Actions
    
    private func connect() {
        guard !roomCode.isEmpty else { return }
        
        isConnecting = true
        errorMessage = nil
        
        Task {
            do {
                try await controller.connect(roomCode: roomCode)
                
                DispatchQueue.main.async {
                    self.isConnecting = false
                    SessionManager.shared.addHistoryEntry(roomCode: roomCode)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isConnecting = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func fillFromHistory(_ entry: ConnectionEntry) {
        roomCode = entry.roomCode
    }
}

// MARK: - GUPT Styled Components

struct GuptTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 18)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }
}

struct GuptSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 18)

                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
        }
    }
}

struct GuptHistoryRow: View {
    let entry: ConnectionEntry
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "display")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Room: \(entry.roomCode)")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    HStack(spacing: 8) {
                        Text(entry.lastConnected, style: .relative)
                            .font(.system(size: 11))
                        Text("ago")
                            .font(.system(size: 11))
                        Spacer()
                    }
                    .foregroundColor(.white.opacity(0.35))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(isHovered ? 0.06 : 0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(isHovered ? 0.1 : 0.04), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
