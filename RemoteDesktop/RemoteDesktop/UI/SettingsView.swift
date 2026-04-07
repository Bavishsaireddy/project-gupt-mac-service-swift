//
//  SettingsView.swift
//  RemoteDesktop
//
//  Application settings and configuration UI
//

import SwiftUI

/// Settings UI for the application
struct SettingsView: View {
    @AppStorage("defaultPort") private var defaultPort = 5900
    @AppStorage("autoStartHost") private var autoStartHost = false
    @AppStorage("qualityPreset") private var qualityPreset = "Medium"
    
    let presets = ["Low (360p)", "Medium (720p)", "High (1080p)", "Ultra (60fps)"]
    
    var body: some View {
        Form {
            Section("Network Configuration") {
                HStack {
                    Text("Default Listening Port")
                    Spacer()
                    TextField("5900", value: $defaultPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
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
                    Text("RemoteDesktop v1.0.0")
                        .fontWeight(.bold)
                    Text("Build: 20240407")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Powered by ScreenCaptureKit and Metal.")
                        .font(.caption)
                        .padding(.top, 5)
                }
            }
        }
        .padding(30)
        .frame(width: 450)
    }
}
