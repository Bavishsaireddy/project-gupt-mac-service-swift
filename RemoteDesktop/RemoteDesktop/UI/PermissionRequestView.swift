//
//  PermissionRequestView.swift
//  GUPT
//
//  UI to guide users through granting required permissions
//

import SwiftUI
import os.log

/// View to request and monitor system permissions
struct PermissionRequestView: View {
    private let logger = Logger(subsystem: "com.gupt", category: "PermissionRequestView")
    
    @State private var hasScreenRecording = false
    @State private var hasAccessibility = false
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("Permissions Required")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("GUPT requires screen recording and accessibility permissions to capture your screen and control your input.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 16) {
                PermissionRow(
                    title: "Screen Recording",
                    description: "Required to capture and stream your screen.",
                    isGranted: hasScreenRecording,
                    action: { openSystemSettings("Privacy_ScreenCapture") }
                )
                
                PermissionRow(
                    title: "Accessibility",
                    description: "Required to control mouse and keyboard remotely.",
                    isGranted: hasAccessibility,
                    action: { openSystemSettings("Privacy_Accessibility") }
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .controlBackgroundColor)))
            
            Text("Tip: You may need to restart the app after granting permissions.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(40)
        .onReceive(timer) { _ in
            checkPermissions()
        }
    }
    
    // MARK: - Actions
    
    private func checkPermissions() {
        self.hasScreenRecording = CGPreflightScreenCaptureAccess()
        self.hasAccessibility = AXIsProcessTrusted()
    }
    
    private func openSystemSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct PermissionRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isGranted ? .green : .orange)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).fontWeight(.bold)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(isGranted ? "Granted" : "Grant...") {
                action()
            }
            .buttonStyle(.bordered)
            .disabled(isGranted)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.05)))
    }
}
