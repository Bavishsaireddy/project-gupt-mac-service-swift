//
//  InputEventInjector.swift
//  GUPT
//
//  Inject mouse and keyboard events on the host using CoreGraphics
//

import Foundation
import CoreGraphics
import AppKit
import os.log

/// Injects input events received from remote client
class InputEventInjector {
    private let logger = Logger(subsystem: "com.gupt", category: "InputInjector")
    private var isEnabled: Bool {
        return AXIsProcessTrusted()
    }

    /// Set to true when the client is connecting from localhost to prevent
    /// the injected CGEvents from being re-captured and creating a feedback loop.
    var suppressInjection: Bool = false

    /// A private CGEventSource so that injected events are tagged as synthetic
    /// and will NOT pass back through the NSEvent local monitor chain.
    private let eventSource = CGEventSource(stateID: .privateState)

    /// Track which buttons are currently pressed so we can generate
    /// drag events (leftMouseDragged) instead of mouseMoved while dragging.
    private var leftButtonDown = false
    private var rightButtonDown = false

    // MARK: - Initialization

    init() {
        if !isEnabled {
            logger.warning("Accessibility permission not granted initially")
        }
    }

    // MARK: - Permission

    /// Request accessibility permission
    static func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Inject Events

    /// Inject an input event
    func inject(_ event: InputEventMessage) {
        guard isEnabled else {
            logger.warning("Cannot inject event: accessibility not enabled")
            return
        }

        guard !suppressInjection else {
            logger.debug("Injection suppressed (local testing mode)")
            return
        }

        switch event.eventData {
        case .mouseEvent(let mouseData):
            injectMouseEvent(type: event.eventType, data: mouseData)

        case .keyEvent(let keyData):
            injectKeyEvent(type: event.eventType, data: keyData)

        case .scrollEvent(let scrollData):
            injectScrollEvent(data: scrollData)
        }
    }

    // MARK: - Mouse Events

    private func injectMouseEvent(type: InputEventType, data: MouseEventData) {
        let screenWidth = CGDisplayBounds(CGMainDisplayID()).width
        let screenHeight = CGDisplayBounds(CGMainDisplayID()).height
        
        // Clamp normalized coordinates to [0.0, 1.0] to prevent out of bounds
        let clampedX = max(0.0, min(1.0, data.x))
        let clampedY = max(0.0, min(1.0, data.y))
        
        let location = CGPoint(x: clampedX * screenWidth, y: clampedY * screenHeight)

        switch type {
        case .mouseMove:
            let isDragging = data.isDragging ?? false
            if isDragging {
                // Use drag event type based on which button is pressed
                let button = data.button ?? .left
                moveMouse(to: location, dragging: true, button: button)
            } else {
                moveMouse(to: location, dragging: false, button: .left)
            }

        case .mouseDown:
            let button = data.button ?? .left
            if button == .left { leftButtonDown = true }
            if button == .right { rightButtonDown = true }
            mouseDown(at: location, button: button, clickCount: data.clickCount ?? 1)

        case .mouseUp:
            let button = data.button ?? .left
            if button == .left { leftButtonDown = false }
            if button == .right { rightButtonDown = false }
            mouseUp(at: location, button: button, clickCount: data.clickCount ?? 1)

        default:
            break
        }
    }

    private func moveMouse(to location: CGPoint, dragging: Bool, button: MouseButton) {
        let eventType: CGEventType
        if dragging {
            switch button {
            case .left:
                eventType = .leftMouseDragged
            case .right:
                eventType = .rightMouseDragged
            case .middle:
                eventType = .otherMouseDragged
            default:
                eventType = .leftMouseDragged
            }
        } else {
            eventType = .mouseMoved
        }

        let moveEvent = CGEvent(
            mouseEventSource: eventSource,
            mouseType: eventType,
            mouseCursorPosition: location,
            mouseButton: dragging ? (button == .right ? .right : .left) : .left
        )

        moveEvent?.post(tap: .cghidEventTap)
    }
    
    /// Artificially moves the mouse 1 pixel and back to wake up ScreenCaptureKit
    /// so it instantly emits a new Keyframe upon client connection.
    func jiggleMouse() {
        guard isEnabled, let currentLoc = CGEvent(source: nil)?.location else { return }
        let jiggleLoc = CGPoint(x: currentLoc.x + 1, y: currentLoc.y)
        if let event1 = CGEvent(mouseEventSource: eventSource, mouseType: .mouseMoved, mouseCursorPosition: jiggleLoc, mouseButton: .left),
           let event2 = CGEvent(mouseEventSource: eventSource, mouseType: .mouseMoved, mouseCursorPosition: currentLoc, mouseButton: .left) {
            event1.post(tap: .cghidEventTap)
            event2.post(tap: .cghidEventTap)
        }
    }

    private func mouseDown(at location: CGPoint, button: MouseButton, clickCount: Int) {
        let (eventType, cgButton) = mapMouseButton(button, isDown: true)

        let clickEvent = CGEvent(
            mouseEventSource: eventSource,
            mouseType: eventType,
            mouseCursorPosition: location,
            mouseButton: cgButton
        )

        // Set click count for double/triple click support
        clickEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        clickEvent?.post(tap: .cghidEventTap)
    }

    private func mouseUp(at location: CGPoint, button: MouseButton, clickCount: Int) {
        let (eventType, cgButton) = mapMouseButton(button, isDown: false)

        let clickEvent = CGEvent(
            mouseEventSource: eventSource,
            mouseType: eventType,
            mouseCursorPosition: location,
            mouseButton: cgButton
        )

        // Maintain click count on mouse up for proper double-click detection
        clickEvent?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        clickEvent?.post(tap: .cghidEventTap)
    }

    private func mapMouseButton(_ button: MouseButton, isDown: Bool) -> (CGEventType, CGMouseButton) {
        switch button {
        case .left:
            return (isDown ? .leftMouseDown : .leftMouseUp, .left)
        case .right:
            return (isDown ? .rightMouseDown : .rightMouseUp, .right)
        case .middle:
            return (isDown ? .otherMouseDown : .otherMouseUp, .center)
        default:
            return (isDown ? .leftMouseDown : .leftMouseUp, .left)
        }
    }

    // MARK: - Scroll Events

    private func injectScrollEvent(data: ScrollEventData) {
        // Create scroll event
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: eventSource,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(data.deltaY),
            wheel2: Int32(data.deltaX),
            wheel3: 0
        )

        scrollEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - Keyboard Events

    private func injectKeyEvent(type: InputEventType, data: KeyEventData) {
        switch type {
        case .keyDown, .keyUp:
            let isDown = (type == .keyDown)

            // Create key event using eventSource so it's marked synthetic
            guard let keyEvent = CGEvent(
                keyboardEventSource: eventSource,
                virtualKey: data.keyCode,
                keyDown: isDown
            ) else {
                logger.error("Failed to create keyboard event")
                return
            }

            // Set modifiers
            let modifiers = mapModifiers(data.modifiers)
            keyEvent.flags = modifiers

            // Only set characters if we are NOT holding a command/control modifier.
            // Setting unicode strings alongside Command/Control breaks macOS keyboard shortcuts!
            if let characters = data.characters, !modifiers.contains(.maskCommand), !modifiers.contains(.maskControl) {
                let unicodeString = Array(characters.utf16)
                keyEvent.keyboardSetUnicodeString(stringLength: unicodeString.count, unicodeString: unicodeString)
            }

            keyEvent.post(tap: .cghidEventTap)

        case .flagsChanged:
            // For modifier key changes, inject a flagsChanged event
            injectFlagsChanged(data: data)

        default:
            break
        }
    }

    /// Inject a flagsChanged event for modifier keys (Shift, Cmd, Option, Control)
    private func injectFlagsChanged(data: KeyEventData) {
        // Determine if the modifier key is being pressed or released
        // by checking if the corresponding modifier flag is set
        let modifiers = mapModifiers(data.modifiers)
        let isDown = !modifiers.isEmpty  // simplified: non-empty flags means key is pressed

        guard let flagsEvent = CGEvent(
            keyboardEventSource: eventSource,
            virtualKey: data.keyCode,
            keyDown: isDown
        ) else {
            logger.error("Failed to create flagsChanged event")
            return
        }

        flagsEvent.type = .flagsChanged
        flagsEvent.flags = modifiers
        flagsEvent.post(tap: .cghidEventTap)
    }

    private func mapModifiers(_ modifiers: KeyModifiers) -> CGEventFlags {
        var flags: CGEventFlags = []

        if modifiers.contains(.shift) {
            flags.insert(.maskShift)
        }
        if modifiers.contains(.control) {
            flags.insert(.maskControl)
        }
        if modifiers.contains(.option) {
            flags.insert(.maskAlternate)
        }
        if modifiers.contains(.command) {
            flags.insert(.maskCommand)
        }
        if modifiers.contains(.capsLock) {
            flags.insert(.maskAlphaShift)
        }

        return flags
    }

    // MARK: - Special Functions

    /// Simulate keyboard shortcut
    func simulateShortcut(key: UInt16, modifiers: KeyModifiers) {
        let flags = mapModifiers(modifiers)

        // Key down with modifiers
        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true) {
            keyDown.flags = flags
            keyDown.post(tap: .cghidEventTap)
        }

        // Small delay
        usleep(10000)  // 10ms

        // Key up
        if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false) {
            keyUp.flags = flags
            keyUp.post(tap: .cghidEventTap)
        }
    }

    /// Type text string
    func typeText(_ text: String) {
        for character in text {
            let string = String(character)
            guard let keyCode = mapCharacterToKeyCode(character) else {
                continue
            }

            let isUpperCase = character.isUppercase || character.isNumber == false
            let modifiers: KeyModifiers = isUpperCase ? .shift : []

            // Key down
            if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
                if !modifiers.isEmpty {
                    keyDown.flags = mapModifiers(modifiers)
                }
                keyDown.post(tap: .cghidEventTap)
            }

            usleep(10000)  // 10ms delay

            // Key up
            if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
                if !modifiers.isEmpty {
                    keyUp.flags = mapModifiers(modifiers)
                }
                keyUp.post(tap: .cghidEventTap)
            }

            usleep(10000)  // 10ms between characters
        }
    }

    private func mapCharacterToKeyCode(_ character: Character) -> UInt16? {
        // Simplified mapping - in production, use complete keycode table
        let lowercased = String(character).lowercased()

        switch lowercased {
        case "a": return 0x00
        case "s": return 0x01
        case "d": return 0x02
        case "f": return 0x03
        case "h": return 0x04
        case "g": return 0x05
        case "z": return 0x06
        case "x": return 0x07
        case "c": return 0x08
        case "v": return 0x09
        case "b": return 0x0B
        case "q": return 0x0C
        case "w": return 0x0D
        case "e": return 0x0E
        case "r": return 0x0F
        case "y": return 0x10
        case "t": return 0x11
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "6": return 0x16
        case "5": return 0x17
        case "=": return 0x18
        case "9": return 0x19
        case "7": return 0x1A
        case "-": return 0x1B
        case "8": return 0x1C
        case "0": return 0x1D
        case "]": return 0x1E
        case "o": return 0x1F
        case "u": return 0x20
        case "[": return 0x21
        case "i": return 0x22
        case "p": return 0x23
        case "l": return 0x25
        case "j": return 0x26
        case "'": return 0x27
        case "k": return 0x28
        case ";": return 0x29
        case "\\": return 0x2A
        case ",": return 0x2B
        case "/": return 0x2C
        case "n": return 0x2D
        case "m": return 0x2E
        case ".": return 0x2F
        case " ": return 0x31
        case "`": return 0x32
        default: return nil
        }
    }

    // MARK: - State

    var canInject: Bool {
        return isEnabled
    }
}

// MARK: - Key Code Constants

extension InputEventInjector {
    /// Common key codes for macOS
    enum KeyCode {
        static let returnKey: UInt16 = 0x24
        static let tab: UInt16 = 0x30
        static let space: UInt16 = 0x31
        static let delete: UInt16 = 0x33
        static let escape: UInt16 = 0x35
        static let command: UInt16 = 0x37
        static let shift: UInt16 = 0x38
        static let capsLock: UInt16 = 0x39
        static let option: UInt16 = 0x3A
        static let control: UInt16 = 0x3B
        static let rightShift: UInt16 = 0x3C
        static let rightOption: UInt16 = 0x3D
        static let rightControl: UInt16 = 0x3E
        static let function: UInt16 = 0x3F

        // Arrow keys
        static let leftArrow: UInt16 = 0x7B
        static let rightArrow: UInt16 = 0x7C
        static let downArrow: UInt16 = 0x7D
        static let upArrow: UInt16 = 0x7E

        // Function keys
        static let f1: UInt16 = 0x7A
        static let f2: UInt16 = 0x78
        static let f3: UInt16 = 0x63
        static let f4: UInt16 = 0x76
        static let f5: UInt16 = 0x60
        static let f6: UInt16 = 0x61
        static let f7: UInt16 = 0x62
        static let f8: UInt16 = 0x64
        static let f9: UInt16 = 0x65
        static let f10: UInt16 = 0x6D
        static let f11: UInt16 = 0x67
        static let f12: UInt16 = 0x6F
    }
}
