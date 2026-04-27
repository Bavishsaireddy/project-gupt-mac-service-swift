//
//  SettingsView.swift
//  GUPT
//
//  Application settings and configuration UI
//

import SwiftUI

/// Settings UI for the application
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultPort") private var defaultPort = 5900
    @AppStorage("autoStartHost") private var autoStartHost = false
    @AppStorage("qualityPreset") private var qualityPreset = "Medium"
    
    let presets = ["Low (360p)", "Medium (720p)", "High (1080p)", "Ultra (60fps)"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar with close button
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            
            Divider()
            
            Form {
                Section("Network Configuration") {
                    HStack {
                        Text("Relay Server URL")
                        Spacer()
                        TextField("ws://localhost:3900", text: Binding(
                            get: { SessionManager.shared.relayServerURL },
                            set: { SessionManager.shared.updateRelayServer($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                    }
                }
                
                Section("Streaming Quality") {
                    Picker("Quality Preset", selection: $qualityPreset) {
                        ForEach(presets, id: \.self) { preset in
                            Text(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("Higher quality requires more bandwidth and may increase latency.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Automation") {
                    Toggle("Launch host on app startup", isOn: $autoStartHost)
                }
                
                Section("About") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("GUPT v1.0.0")
                            .fontWeight(.bold)
                        Text("Build: 20260411")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Powered by ScreenCaptureKit and Metal.")
                            .font(.caption)
                            .padding(.top, 5)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 30)
        }
        .frame(width: 450)
    }
}
