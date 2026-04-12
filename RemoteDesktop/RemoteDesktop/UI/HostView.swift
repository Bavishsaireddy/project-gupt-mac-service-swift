//
//  HostView.swift
//  GUPT
//
//  Main user interface for the host mode
//

import SwiftUI

/// Main UI for host mode
struct HostView: View {
    @ObservedObject var controller: HostController
    @ObservedObject var sessionManager = SessionManager.shared
    
    @State private var isRunning = false
    @State private var showSettings = false
    @State private var copiedField: String? = nil
    
    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.08, green: 0.08, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Host Mode")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Share your screen securely")
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
                
                // Status Card
                VStack(spacing: 20) {
                    GuptStatusIndicator(isActive: isRunning)
                    
                    if isRunning {
                        VStack(spacing: 14) {
                            GuptInfoRow(label: "Room Code", value: controller.roomCode, icon: "number", onCopy: { copyToClipboard(controller.roomCode, field: "room") }, isCopied: copiedField == "room")
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                                )
                        )

                        Text("Share this information with the client to connect.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.top, 4)
                    } else {
                        Text("Ready to start hosting.\nEnsure you have granted screen recording and accessibility permissions.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                    }
                }
                .frame(maxWidth: .infinity)
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
                
                Spacer()
                
                // Action Button
                Button(action: toggleServer) {
                    HStack(spacing: 10) {
                        Image(systemName: isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(isRunning ? "Stop Server" : "Start Server")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .frame(width: 200, height: 44)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                isRunning
                                    ? LinearGradient(colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [Color(red: 0.05, green: 0.58, blue: 0.53), Color(red: 0.04, green: 0.48, blue: 0.45)], startPoint: .top, endPoint: .bottom)
                            )
                            .shadow(color: isRunning ? Color.red.opacity(0.3) : Color(red: 0.05, green: 0.58, blue: 0.53).opacity(0.3), radius: 12, y: 4)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(40)
        }
        .sheet(isPresented: $showSettings) {
             SettingsView()
        }
    }
    
    // MARK: - Actions
    
    private func toggleServer() {
        Task {
            if isRunning {
                await controller.stop()
                isRunning = false
            } else {
                do {
                    try await controller.start()
                    isRunning = true
                } catch {
                    // Handle error (e.g. show alert)
                }
            }
        }
    }

    private func copyToClipboard(_ text: String, field: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        copiedField = field
        
        // Reset the copied state after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedField == field {
                copiedField = nil
            }
        }
    }
}

// MARK: - Supporting Views

struct GuptStatusIndicator: View {
    let isActive: Bool
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if isActive {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0.0 : 0.6)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isPulsing)
                }

                Circle()
                    .fill(isActive ? Color(red: 0.2, green: 0.8, blue: 0.4) : Color(red: 0.85, green: 0.3, blue: 0.3))
                    .frame(width: 10, height: 10)
                    .shadow(color: isActive ? Color.green.opacity(0.5) : Color.red.opacity(0.5), radius: 5)
            }
            
            Text(isActive ? "Running" : "Stopped")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isActive ? Color(red: 0.2, green: 0.8, blue: 0.4) : Color(red: 0.85, green: 0.3, blue: 0.3))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isActive ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
                .overlay(
                    Capsule().stroke(isActive ? Color.green.opacity(0.15) : Color.red.opacity(0.15), lineWidth: 0.5)
                )
        )
        .onAppear {
            isPulsing = true
        }
    }
}

struct GuptInfoRow: View {
    let label: String
    let value: String
    let icon: String
    let onCopy: () -> Void
    let isCopied: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.35))
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
                .textSelection(.enabled)

            Button(action: onCopy) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isCopied ? Color.green : .white.opacity(0.4))
                    .padding(6)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.2), value: isCopied)
        }
    }
}
