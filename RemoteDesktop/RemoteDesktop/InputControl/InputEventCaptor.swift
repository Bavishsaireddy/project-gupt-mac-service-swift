//
//  InputEventCaptor.swift
//  GUPT
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
    private let logger = Logger(subsystem: "com.gupt", category: "InputCaptor")
    weak var delegate: InputEventCaptorDelegate?

    private var isCapturing = false
    private var localMonitor: Any?
    private var globalMonitor: Any?

    /// Track which mouse buttons are currently pressed for drag detection
    private var pressedButtons: Set<MouseButton> = []

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
            .mouseMoved,
            .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .scrollWheel,
            .keyDown, .keyUp, .flagsChanged
        ]) { [weak self] event in
            self?.handleEvent(event)
            return event  // Pass through to app
        }

        // Removed globalMonitor because it captures events outside the app window, leading to weird mouse behavior
        // globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [ ...

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

        pressedButtons.removeAll()
        isCapturing = false
        logger.info("Input capture stopped")
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: NSEvent) {
        if let inputEvent = convertToInputEvent(event) {
            delegate?.captor(self, didCaptureEvent: inputEvent)
        }
    }

    private func convertToInputEvent(_ event: NSEvent) -> InputEventMessage? {
        // Double check the app focuses the correct window for keyboard events
        if event.type == .keyDown || event.type == .keyUp || event.type == .flagsChanged {
            guard event.window?.isKeyWindow == true else { return nil }
        }

        let timestamp = UInt64(event.timestamp * 1_000_000)  // Convert to microseconds

        // Convert from window coordinates to the content view's local coordinate system
        guard let contentView = event.window?.contentView else { return nil }
        let localPoint = contentView.convert(event.locationInWindow, from: nil)
        
        // Critical Fix: ONLY capture mouse events if the pointer is ACTUALLY inside the video bounds!
        // This prevents clicks on the Mac Dock or the window's title bar from being sent to the Host.
        if event.type != .keyDown && event.type != .keyUp && event.type != .flagsChanged {
            if !contentView.bounds.contains(localPoint) {
                return nil
            }
        }

        let width  = contentView.bounds.width
        let height = contentView.bounds.height

        // Normalize X to 0-1
        let relX = max(0.0, min(1.0, Double(localPoint.x / width)))

        // Normalize Y to 0-1.
        let rawRelY: Double
        if contentView.isFlipped == true {
            rawRelY = Double(localPoint.y / height)
        } else {
            rawRelY = 1.0 - Double(localPoint.y / height)
        }
        let relY = max(0.0, min(1.0, rawRelY))

        // Get mouse deltas for smooth movement reconstruction
        let deltaX = Double(event.deltaX)
        let deltaY = Double(event.deltaY)

        switch event.type {
        case .mouseMoved:
            return InputEventMessage(
                eventType: .mouseMove,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: relX,
                    y: relY,
                    button: nil,
                    clickCount: nil,
                    deltaX: deltaX,
                    deltaY: deltaY,
                    isDragging: false
                ))
            )

        case .leftMouseDragged:
            return InputEventMessage(
                eventType: .mouseMove,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: relX,
                    y: relY,
                    button: .left,
                    clickCount: nil,
                    deltaX: deltaX,
                    deltaY: deltaY,
                    isDragging: true
                ))
            )

        case .rightMouseDragged:
            return InputEventMessage(
                eventType: .mouseMove,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: relX,
                    y: relY,
                    button: .right,
                    clickCount: nil,
                    deltaX: deltaX,
                    deltaY: deltaY,
                    isDragging: true
                ))
            )

        case .otherMouseDragged:
            return InputEventMessage(
                eventType: .mouseMove,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: relX,
                    y: relY,
                    button: .middle,
                    clickCount: nil,
                    deltaX: deltaX,
                    deltaY: deltaY,
                    isDragging: true
                ))
            )

        case .leftMouseDown:
            pressedButtons.insert(.left)
            return InputEventMessage(
                eventType: .mouseDown,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: relX,
                    y: relY,
                    button: .left,
                    clickCount: event.clickCount,
                    deltaX: nil,
                    deltaY: nil,
                    isDragging: nil
                ))
            )

        case .leftMouseUp:
            pressedButtons.remove(.left)
            return InputEventMessage(
                eventType: .mouseUp,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: relX,
                    y: relY,
                    button: .left,
                    clickCount: event.clickCount,
                    deltaX: nil,
                    deltaY: nil,
                    isDragging: nil
                ))
            )

        case .rightMouseDown:
            pressedButtons.insert(.right)
            return InputEventMessage(
                eventType: .mouseDown,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: relX,
                    y: relY,
                    button: .right,
                    clickCount: event.clickCount,
                    deltaX: nil,
                    deltaY: nil,
                    isDragging: nil
                ))
            )

        case .rightMouseUp:
            pressedButtons.remove(.right)
            return InputEventMessage(
                eventType: .mouseUp,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: relX,
                    y: relY,
                    button: .right,
                    clickCount: event.clickCount,
                    deltaX: nil,
                    deltaY: nil,
                    isDragging: nil
                ))
            )

        case .otherMouseDown:
            pressedButtons.insert(.middle)
            return InputEventMessage(
                eventType: .mouseDown,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: relX,
                    y: relY,
                    button: .middle,
                    clickCount: event.clickCount,
                    deltaX: nil,
                    deltaY: nil,
                    isDragging: nil
                ))
            )

        case .otherMouseUp:
            pressedButtons.remove(.middle)
            return InputEventMessage(
                eventType: .mouseUp,
                timestamp: timestamp,
                eventData: .mouseEvent(MouseEventData(
                    x: relX,
                    y: relY,
                    button: .middle,
                    clickCount: event.clickCount,
                    deltaX: nil,
                    deltaY: nil,
                    isDragging: nil
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
                    x: 0, y: 0, button: nil, clickCount: nil,
                    deltaX: nil, deltaY: nil, isDragging: nil
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
                    clickCount: 1,
                    deltaX: nil,
                    deltaY: nil,
                    isDragging: nil
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
                        clickCount: 1,
                        deltaX: nil,
                        deltaY: nil,
                        isDragging: nil
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
                    clickCount: nil,
                    deltaX: nil,
                    deltaY: nil,
                    isDragging: nil
                ))
            )
            self.delegate?.captor(self, didCaptureEvent: event)
        }

        return (onHover, onTapGesture, onDragGesture)
    }
}
