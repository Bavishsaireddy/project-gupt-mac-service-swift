//
//  InputSerializer.swift
//  RemoteDesktop
//
//  Serializes local user input events for transmission over the network
//

import Foundation
import AppKit
import os.log

/// Helper class to serialize AppKit events into network protocol messages
class InputSerializer {
    private let logger = Logger(subsystem: "com.gupt", category: "InputSerializer")
    
    /// Converts an NSEvent into an InputEventMessage
    /// - Parameters:
    ///   - event: The AppKit event to serialize
    ///   - relativePoint: The mouse coordinates relative to the remote display view (normalized 0.0 - 1.0)
    /// - Returns: A serialized InputEventMessage if conversion was successful, nil otherwise
    func serialize(event: NSEvent, relativePoint: CGPoint?) -> InputEventMessage? {
        let timestamp = UInt64(event.timestamp * 1_000_000) // Microseconds
        
        switch event.type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            guard let point = relativePoint else { return nil }
            return createMouseEvent(type: .mouseMove, timestamp: timestamp, point: point, button: nil, clickCount: 0)
            
        case .leftMouseDown, .leftMouseUp:
            guard let point = relativePoint else { return nil }
            let type: InputEventType = (event.type == .leftMouseDown) ? .mouseDown : .mouseUp
            return createMouseEvent(type: type, timestamp: timestamp, point: point, button: .left, clickCount: event.clickCount)
            
        case .rightMouseDown, .rightMouseUp:
            guard let point = relativePoint else { return nil }
            let type: InputEventType = (event.type == .rightMouseDown) ? .mouseDown : .mouseUp
            return createMouseEvent(type: type, timestamp: timestamp, point: point, button: .right, clickCount: event.clickCount)
            
        case .keyDown, .keyUp:
            let type: InputEventType = (event.type == .keyDown) ? .keyDown : .keyUp
            let modifiers = extractModifiers(from: event.modifierFlags)
            let keyData = KeyEventData(
                keyCode: event.keyCode,
                characters: event.characters,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                modifiers: modifiers
            )
            return InputEventMessage(eventType: type, timestamp: timestamp, eventData: .keyEvent(keyData))
            
        case .scrollWheel:
            let scrollData = ScrollEventData(
                deltaX: Double(event.scrollingDeltaX),
                deltaY: Double(event.scrollingDeltaY),
                phase: extractScrollPhase(from: event)
            )
            return InputEventMessage(eventType: .mouseScroll, timestamp: timestamp, eventData: .scrollEvent(scrollData))
            
        case .flagsChanged:
            let modifiers = extractModifiers(from: event.modifierFlags)
            let keyData = KeyEventData(
                keyCode: event.keyCode,
                characters: nil,
                charactersIgnoringModifiers: nil,
                modifiers: modifiers
            )
            return InputEventMessage(eventType: .flagsChanged, timestamp: timestamp, eventData: .keyEvent(keyData))
            
        default:
            return nil
        }
    }
    
    // MARK: - Helpers
    
    private func createMouseEvent(type: InputEventType, timestamp: UInt64, point: CGPoint, button: MouseButton?, clickCount: Int) -> InputEventMessage {
        let mouseData = MouseEventData(
            x: Double(point.x),
            y: Double(point.y),
            button: button,
            clickCount: clickCount,
            deltaX: nil,
            deltaY: nil,
            isDragging: nil
        )
        return InputEventMessage(eventType: type, timestamp: timestamp, eventData: .mouseEvent(mouseData))
    }
    
    private func extractModifiers(from flags: NSEvent.ModifierFlags) -> KeyModifiers {
        var modifiers = KeyModifiers(rawValue: 0)
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.capsLock) { modifiers.insert(.capsLock) }
        if flags.contains(.function) { modifiers.insert(.function) }
        return modifiers
    }
    
    private func extractScrollPhase(from event: NSEvent) -> ScrollPhase {
        // AppKit's phase handling is a bit complex; simplifying for now
        if event.phase.contains(.began) { return .began }
        if event.phase.contains(.changed) { return .changed }
        if event.phase.contains(.ended) { return .ended }
        if event.phase.contains(.cancelled) { return .cancelled }
        return .changed
    }
}
