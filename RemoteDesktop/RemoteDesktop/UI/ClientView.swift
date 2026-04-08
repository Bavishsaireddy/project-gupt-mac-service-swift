//
//  ClientView.swift
//  RemoteDesktop
//
//  Main user interface for the client mode
//

import SwiftUI

/// Main UI for client mode
struct ClientView: View {
    @ObservedObject var controller: ClientController
    @ObservedObject var sessionManager = SessionManager.shared
    
    @State private var hostIP = ""
    @State private var hostPort = "5999"
    @State private var password = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            HStack {
                Text("Connect to Remote")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
            }
            
            Divider()
            
            if controller.isConnected {
                // If connected, show the remote display view
                RemoteDesktopView(controller: controller)
            } else {
                // If not connected, show the connection form
                HStack(alignment: .top, spacing: 40) {
                    
                    // Connection Form
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Connection Details")
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Host IP Address").foregroundColor(.secondary)
                            TextField("192.168.1.100", text: $hostIP)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 300)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Port").foregroundColor(.secondary)
                            TextField("5900", text: $hostPort)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 300)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password").foregroundColor(.secondary)
                            SecureField("Enter password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 300)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Button(action: connect) {
                            if isConnecting {
                                ProgressView().controlSize(.small).padding(.horizontal, 10)
                            } else {
                                Text("Connect")
                                    .frame(width: 100)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(hostIP.isEmpty || isConnecting)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
                    
                    // History Sidebar
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Recent Connections")
                            .font(.title2)
                        
                        if sessionManager.connectionHistory.isEmpty {
                            Text("No recent connections")
                                .foregroundColor(.secondary)
                                .font(.body)
                                .padding(.top, 10)
                        } else {
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(sessionManager.connectionHistory) { entry in
                                        HistoryRow(entry: entry) {
                                            self.hostIP = entry.host
                                            self.hostPort = "\(entry.port)"
                                        }
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .frame(width: 250)
                }
            }
            
            Spacer()
        }
        .padding(40)
    }
    
    // MARK: - Actions
    
    private func connect() {
        guard let port = UInt16(hostPort) else {
            errorMessage = "Invalid port number"
            return
        }
        
        isConnecting = true
        errorMessage = nil
        
        Task {
            do {
                try await controller.connect(host: hostIP, port: port)
                sessionManager.addHistoryEntry(host: hostIP, port: port)
                isConnecting = false
            } catch {
                isConnecting = false
                errorMessage = "Failed to connect: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Supporting Views

struct HistoryRow: View {
    let entry: ConnectionEntry
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.host)
                    .fontWeight(.medium)
                HStack {
                    Text("Port: \(entry.port)")
                    Spacer()
                    Text(entry.lastConnected, style: .relative)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}
