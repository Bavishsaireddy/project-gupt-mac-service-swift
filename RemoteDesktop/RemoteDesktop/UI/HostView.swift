//
//  HostView.swift
//  RemoteDesktop
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
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            HStack {
                Text("Host Mode")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Status Card
            VStack(spacing: 20) {
                StatusIndicator(isActive: isRunning)
                
                if isRunning {
                    VStack(spacing: 12) {
                        InfoRow(label: "IP Address", value: getLocalIP(), isMonospaced: true)
                        InfoRow(label: "Port", value: "5999", isMonospaced: true)
                        InfoRow(label: "Password", value: sessionManager.currentPassword, isMonospaced: true)
                        
                        Text("Share this information with the client to connect.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
                } else {
                    Text("Ready to start hosting. Ensure you have granted screen recording and accessibility permissions.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
            
            Spacer()
            
            // Action Button
            Button(action: toggleServer) {
                Text(isRunning ? "Stop Server" : "Start Server")
                    .font(.headline)
                    .frame(width: 200, height: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRunning ? .red : .blue)
            .controlSize(.large)
        }
        .padding(40)
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
    
    private func getLocalIP() -> String {
        return NetworkListener.getLocalIPAddresses().first(where: { !$0.contains(":") }) ?? "Unknown"
    }
}

// MARK: - Supporting Views

struct StatusIndicator: View {
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 12, height: 12)
                .shadow(color: isActive ? .green.opacity(0.5) : .red.opacity(0.5), radius: 5)
            
            Text(isActive ? "Running" : "Stopped")
                .font(.headline)
                .foregroundColor(isActive ? .green : .red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(isActive ? Color.green.opacity(0.1) : Color.red.opacity(0.1)))
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
                .textSelection(.enabled)
        }
    }
}
