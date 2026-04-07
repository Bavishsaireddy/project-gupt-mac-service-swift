//
//  InputEventCaptor.swift
//  RemoteDesktop
//
//  Capture mouse and keyboard events on the client
//

import Foundation
import AppKit
import os.log

/// Delegate for captured input events
protocol InputEventCaptorDelegate: AnyObject {
    func captor(_ captor: InputEventCaptor, didCaptureEvent event: InputEventMessage)
}

/// Captures local input events to send to remote host
class InputEventCaptor {
    private let logger = Logger(subsystem: "com.remotedesktop", category: "InputCaptor")
    weak var delegate: InputEventCaptorDelegate?

    private var isCapturing = false
    private var localMonitor: Any?
    private var globalMonitor: Any?

    // MARK: - Initialization

    init() {}

    deinit {
        stopCapturing()
    }

    // MARK: - Capture Control

    /// Start capturing input events
    func startCapturing() {
        guard !isCapturing else {
            logger.warning("Already capturing")
            return
        }

        // Monitor local events (within app window)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .mouseMoved, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .scrollWheel, .keyDown, .keyUp, .flagsChanged
        ]) { [weak self] event in
            self?.handleEvent(event)
            return event  // Pass through to app
        }

        // Monitor global events (system-wide - requires accessibility permission)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .mouseMoved, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .scrollWheel, .keyDown, .keyUp, .flagsChanged
        ]) { [weak self] event in
            self?.handleEvent(event)
        }

        isCapturing = true
        logger.info("Input capture started")
    }

    /// Stop capturing input events
    func stopCapturing() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        isCapturing = false
        logger.info("Input capture stopped")
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: NSEvent) {
        let inputEvent = convertToInputEvent(event)
        delegate?.captor(self, didCaptureEvent: inputEvent)
    }

    private func convertToInputEvent(_ event: NSEvent) -> InputEventMessage {
        let timestamp = UInt64(event.timestamp * 1_000_000)  // Convert to microseconds

        switch event.type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            return InputEventMessage(
                eventType: .mouseMove,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: Double(event.locationInWindow.x),
                    y: Double(event.locationInWindow.y),
                    button: nil,
                    clickCount: nil
                ))
            )

        case .leftMouseDown:
            return InputEventMessage(
                eventType: .mouseDown,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: Double(event.locationInWindow.x),
                    y: Double(event.locationInWindow.y),
                    button: .left,
                    clickCount: event.clickCount
                ))
            )

        case .leftMouseUp:
            return InputEventMessage(
                eventType: .mouseUp,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: Double(event.locationInWindow.x),
                    y: Double(event.locationInWindow.y),
                    button: .left,
                    clickCount: event.clickCount
                ))
            )

        case .rightMouseDown:
            return InputEventMessage(
                eventType: .mouseDown,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: Double(event.locationInWindow.x),
                    y: Double(event.locationInWindow.y),
                    button: .right,
                    clickCount: event.clickCount
                ))
            )

        case .rightMouseUp:
            return InputEventMessage(
                eventType: .mouseUp,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: Double(event.locationInWindow.x),
                    y: Double(event.locationInWindow.y),
                    button: .right,
                    clickCount: event.clickCount
                ))
            )

        case .scrollWheel:
            return InputEventMessage(
                eventType: .mouseScroll,
                timestamp: timestamp,
                eventData: .scrollEvent(ScrollEventData(
                    deltaX: event.scrollingDeltaX,
                    deltaY: event.scrollingDeltaY,
                    phase: mapScrollPhase(event.phase)
                ))
            )

        case .keyDown:
            return InputEventMessage(
                eventType: .keyDown,
                timestamp: timestamp,
                eventData: .keyEvent(KeyEventData(
                    keyCode: event.keyCode,
                    characters: event.characters,
                    charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                    modifiers: mapModifierFlags(event.modifierFlags)
                ))
            )

        case .keyUp:
            return InputEventMessage(
                eventType: .keyUp,
                timestamp: timestamp,
                eventData: .keyEvent(KeyEventData(
                    keyCode: event.keyCode,
                    characters: event.characters,
                    charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                    modifiers: mapModifierFlags(event.modifierFlags)
                ))
            )

        case .flagsChanged:
            return InputEventMessage(
                eventType: .flagsChanged,
                timestamp: timestamp,
                eventData: .keyEvent(KeyEventData(
                    keyCode: event.keyCode,
                    characters: nil,
                    charactersIgnoringModifiers: nil,
                    modifiers: mapModifierFlags(event.modifierFlags)
                ))
            )

        default:
            // Default to mouse move for unknown types
            return InputEventMessage(
                eventType: .mouseMove,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: 0, y: 0, button: nil, clickCount: nil
                ))
            )
        }
    }

    private func mapScrollPhase(_ phase: NSEvent.Phase) -> ScrollPhase {
        if phase.contains(.began) {
            return .began
        } else if phase.contains(.changed) {
            return .changed
        } else if phase.contains(.ended) {
            return .ended
        } else if phase.contains(.cancelled) {
            return .cancelled
        } else if phase.contains(.mayBegin) {
            return .mayBegin
        }
        return .changed
    }

    private func mapModifierFlags(_ flags: NSEvent.ModifierFlags) -> KeyModifiers {
        var modifiers = KeyModifiers()

        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        if flags.contains(.capsLock) {
            modifiers.insert(.capsLock)
        }
        if flags.contains(.function) {
            modifiers.insert(.function)
        }

        return modifiers
    }

    // MARK: - State

    var isActive: Bool {
        return isCapturing
    }
}

// MARK: - View-based Input Capture

/// SwiftUI view modifier for capturing input in a view
extension InputEventCaptor {
    /// Create input handler for SwiftUI view
    func createViewHandlers() -> (
        onHover: (Bool) -> Void,
        onTapGesture: (CGPoint) -> Void,
        onDragGesture: (CGPoint) -> Void
    ) {
        let onHover: (Bool) -> Void = { [weak self] isHovering in
            // Track hover state if needed
        }

        let onTapGesture: (CGPoint) -> Void = { [weak self] location in
            guard let self = self else { return }
            let event = InputEventMessage(
                eventType: .mouseDown,
                timestamp: NetworkMessage.currentTimestamp(),
                eventData: .mouseEvent(MouseEventData(
                    x: location.x,
                    y: location.y,
                    button: .left,
                    clickCount: 1
                ))
            )
            self.delegate?.captor(self, didCaptureEvent: event)

            // Send mouse up after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let upEvent = InputEventMessage(
                    eventType: .mouseUp,
                    timestamp: NetworkMessage.currentTimestamp(),
                    eventData: .mouseEvent(MouseEventData(
                        x: location.x,
                        y: location.y,
                        button: .left,
                        clickCount: 1
                    ))
                )
                self.delegate?.captor(self, didCaptureEvent: upEvent)
            }
        }

        let onDragGesture: (CGPoint) -> Void = { [weak self] location in
            guard let self = self else { return }
            let event = InputEventMessage(
                eventType: .mouseMove,
                timestamp: NetworkMessage.currentTimestamp(),
                eventData: .mouseEvent(MouseEventData(
                    x: location.x,
                    y: location.y,
                    button: nil,
                    clickCount: nil
                ))
            )
            self.delegate?.captor(self, didCaptureEvent: event)
        }

        return (onHover, onTapGesture, onDragGesture)
    }
}
