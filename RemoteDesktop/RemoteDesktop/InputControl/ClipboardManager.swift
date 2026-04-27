//
//  ClipboardManager.swift
//  GUPT
//
//  Bidirectional clipboard sync between host and client
//

import Foundation
import AppKit
import os.log

/// Delegate for clipboard change events
protocol ClipboardManagerDelegate: AnyObject {
    func clipboardManager(_ manager: ClipboardManager, didDetectChange text: String)
}

/// Monitors the system pasteboard for changes and enables bidirectional clipboard sync
class ClipboardManager {
    private let logger = Logger(subsystem: "com.gupt", category: "ClipboardManager")
    weak var delegate: ClipboardManagerDelegate?

    private var pollingTimer: Timer?
    private var lastChangeCount: Int = 0
    private var isMonitoring = false

    // MARK: - Initialization

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitoring

    /// Start polling the pasteboard for changes
    func startMonitoring() {
        // Must schedule on the main thread — Timer requires a running RunLoop.
        // startMonitoring() may be called from a background (network) queue.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isMonitoring else { return }

            self.lastChangeCount = NSPasteboard.general.changeCount
            self.isMonitoring = true

            // Poll every 250ms — lightweight and responsive
            self.pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.checkForChanges()
            }

            self.logger.info("Clipboard monitoring started")
        }
    }

    /// Stop polling
    func stopMonitoring() {
        DispatchQueue.main.async { [weak self] in
            self?.pollingTimer?.invalidate()
            self?.pollingTimer = nil
            self?.isMonitoring = false
            self?.logger.info("Clipboard monitoring stopped")
        }
    }

    // MARK: - Change Detection

    private func checkForChanges() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }

        lastChangeCount = currentCount

        // Read the current text from the pasteboard
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            return
        }

        logger.debug("Clipboard changed: \(text.prefix(50))...")
        delegate?.clipboardManager(self, didDetectChange: text)
    }

    // MARK: - Writing

    /// Write text to the local pasteboard (called when receiving clipboard from remote)
    func writeToLocalPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Update our tracking so we don't re-detect this write as a new "change" 
        // to broadcast back to the remote side.
        lastChangeCount = pasteboard.changeCount

        logger.debug("Wrote remote clipboard to local pasteboard: \(text.prefix(50))...")
    }

    // MARK: - State

    var isActive: Bool {
        return isMonitoring
    }
}
