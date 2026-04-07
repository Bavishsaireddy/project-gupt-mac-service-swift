//
//  RemoteDesktopView.swift
//  RemoteDesktop
//
//  Interactive remote desktop display view
//

import SwiftUI
import os.log

/// Full-screen interactive remote desktop display
struct RemoteDesktopView: View {
    @ObservedObject var controller: ClientController
    private let logger = Logger(subsystem: "com.remotedesktop", category: "RemoteDesktopView")
    
    @State private var isShowingControls = false
    @State private var mousePosition: CGPoint = .zero
    
    var body: some View {
        ZStack {
            // 1. The Video Display
            RemoteDisplayView(currentFrame: $controller.currentFrame)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let point):
                        self.mousePosition = point
                        self.handleMouseMove(point)
                    case .ended:
                        break
                    }
                }
            
            // 2. Control Overlay (HUD)
            VStack {
                if isShowingControls {
                    HStack {
                        Button(action: { Task { await controller.disconnect() } }) {
                            Label("Disconnect", systemImage: "xmark.circle.fill")
                                .padding()
                                .background(Capsule().fill(Color.red.opacity(0.8)))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        PerformanceBadge()
                        
                        Spacer()
                        
                        Button(action: { /* Toggle full screen */ }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .padding()
                                .background(Circle().fill(Color.black.opacity(0.5)))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring().delay(1.0)) {
                isShowingControls = true
            }
            // Auto-hide controls after a few seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation { isShowingControls = false }
            }
        }
        .onTapGesture {
            withAnimation { isShowingControls.toggle() }
        }
    }
    
    // MARK: - Input Handling
    
    private func handleMouseMove(_ point: CGPoint) {
        // Here we would capture the mouse event and send it to the host via the controller
        // logger.debug("Mouse moved to \(point.x), \(point.y)")
    }
}

// MARK: - Supporting Views

struct PerformanceBadge: View {
    let metrics = LatencyMonitor.shared.currentMetrics
    
    var body: some View {
        HStack(spacing: 12) {
            BadgeItem(label: "FPS", value: "\(Int(metrics.fps))")
            BadgeItem(label: "Latency", value: "\(Int(metrics.totalLatency))ms")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.5)))
        .foregroundColor(.white)
    }
}

struct BadgeItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.caption).fontWeight(.bold)
        }
    }
}

// Extension to help with hover tracking in SwiftUI
extension View {
    func onContinuousHover(perform action: @escaping (HoverPhase) -> Void) -> some View {
        self.modifier(HoverModifier(action: action))
    }
}

enum HoverPhase {
    case active(CGPoint)
    case ended
}

struct HoverModifier: ViewModifier {
    let action: (HoverPhase) -> Void
    
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { proxy in
                Color.clear
                    .onHover { isHovering in
                        if !isHovering { action(.ended) }
                    }
                    // Note: True continuous hover requires TrackingAreas or sophisticated Gestures
                    // This is a simplified version for the demo.
            }
        )
    }
}
