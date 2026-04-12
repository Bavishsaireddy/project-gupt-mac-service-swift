//
//  RemoteDesktopView.swift
//  GUPT
//
//  Interactive remote desktop display view with floating toolbar
//

import SwiftUI
import AppKit
import MetalKit
import Metal
import CoreVideo
import os.log

/// Full-screen interactive remote desktop display
struct RemoteDesktopView: View {
    @ObservedObject var controller: ClientController
    
    var body: some View {
        // Just the video display — no overlays to interfere with mouse movement.
        // Esc → minimize, Cmd+Q → disconnect, Cmd+F → fullscreen, Cmd+Shift+C → clipboard toggle
        CursorHidingDisplayView(currentFrame: $controller.currentFrame)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .onExitCommand {
                NSApplication.shared.keyWindow?.miniaturize(nil)
            }
            .background(
                Group {
                    // Cmd+Q → disconnect
                    Button("") {
                        Task { await controller.disconnect() }
                    }
                    .keyboardShortcut("q", modifiers: .command)
                    .hidden()

                    // Cmd+F → toggle fullscreen
                    Button("") {
                        NSApplication.shared.keyWindow?.toggleFullScreen(nil)
                    }
                    .keyboardShortcut("f", modifiers: .command)
                    .hidden()

                    // Cmd+Shift+C → toggle clipboard sync
                    Button("") {
                        controller.toggleClipboardSync(!controller.clipboardSyncEnabled)
                    }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .hidden()
                }
            )
    }
}

// MARK: - Floating Toolbar

struct FloatingToolbar: View {
    let onDisconnect: () -> Void
    let onFullscreen: () -> Void
    let isFullscreen: Bool
    let clipboardSyncEnabled: Bool
    let onToggleClipboard: (Bool) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // GUPT label
            Text("GUPT")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            Divider()
                .frame(height: 16)
                .background(Color.white.opacity(0.2))

            // Performance badge
            PerformanceBadge()

            Divider()
                .frame(height: 16)
                .background(Color.white.opacity(0.2))

            // Clipboard sync toggle
            ToolbarButton(
                icon: clipboardSyncEnabled ? "doc.on.clipboard.fill" : "doc.on.clipboard",
                label: "Clipboard",
                isActive: clipboardSyncEnabled
            ) {
                onToggleClipboard(!clipboardSyncEnabled)
            }

            // Fullscreen toggle
            ToolbarButton(
                icon: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                label: isFullscreen ? "Exit Fullscreen" : "Fullscreen",
                isActive: false
            ) {
                onFullscreen()
            }

            // Disconnect
            ToolbarButton(
                icon: "xmark.circle.fill",
                label: "Disconnect",
                isActive: false,
                isDestructive: true
            ) {
                onDisconnect()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 5)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(
                isDestructive
                    ? (isHovered ? Color.red : Color.red.opacity(0.7))
                    : (isActive ? Color(red: 0.05, green: 0.75, blue: 0.65) : (isHovered ? .white : .white.opacity(0.6)))
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    isHovered
                        ? Color.white.opacity(0.1)
                        : (isActive ? Color(red: 0.05, green: 0.75, blue: 0.65).opacity(0.15) : Color.clear)
                )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Cursor-Hiding Display View

/// NSViewRepresentable that wraps the MTKView and hides the macOS cursor
/// when the mouse is over the remote desktop area.  This prevents the
/// "two cursors" problem (local cursor + remote host cursor in the stream).
struct CursorHidingDisplayView: NSViewRepresentable {
    @Binding var currentFrame: CVPixelBuffer?

    func makeNSView(context: Context) -> CursorHidingMTKContainer {
        let container = CursorHidingMTKContainer()
        container.setup()
        context.coordinator.container = container
        return container
    }

    func updateNSView(_ nsView: CursorHidingMTKContainer, context: Context) {
        if let frame = currentFrame {
            nsView.renderer?.updateFrame(frame)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var container: CursorHidingMTKContainer?
    }
}

/// Custom NSView that hosts the MTKView and manages cursor visibility
/// via a tracking area.  When the mouse enters, the cursor is hidden;
/// when it exits, the cursor is restored.
class CursorHidingMTKContainer: NSView {
    private(set) var renderer: MetalRenderer?
    private var mtkView: MTKView?
    
    // A transparent cursor image
    private var invisibleCursor: NSCursor {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        return NSCursor(image: image, hotSpot: NSPoint.zero)
    }

    // Accept first responder so keyboard events go to this view
    override var acceptsFirstResponder: Bool { true }

    func setup() {
        guard let device = MTLCreateSystemDefaultDevice() else { return }

        let mtk = MTKView()
        mtk.device = device
        mtk.colorPixelFormat = .bgra8Unorm
        mtk.framebufferOnly = false

        if let r = MetalRenderer(device: device) {
            self.renderer = r
            mtk.delegate = r
        }

        mtk.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(mtk)
        NSLayoutConstraint.activate([
            mtk.topAnchor.constraint(equalTo: topAnchor),
            mtk.bottomAnchor.constraint(equalTo: bottomAnchor),
            mtk.leadingAnchor.constraint(equalTo: leadingAnchor),
            mtk.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        self.mtkView = mtk
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // No longer using Tracking Areas for mouse hiding
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        // This natively replaces the cursor with a transparent one whenever
        // the mouse is inside the bounds of this view!
        addCursorRect(bounds, cursor: invisibleCursor)
    }

    override func mouseDown(with event: NSEvent) {
        // Become first responder when clicked so keyboard events route here
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

// MARK: - Supporting Views

struct PerformanceBadge: View {
    let metrics = LatencyMonitor.shared.currentMetrics
    
    var body: some View {
        HStack(spacing: 10) {
            BadgeItem(label: "FPS", value: "\(Int(metrics.fps))")
            BadgeItem(label: "Latency", value: "\(Int(metrics.totalLatency))ms")
        }
    }
}

struct BadgeItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}
