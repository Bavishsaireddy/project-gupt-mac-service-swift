//
//  AppDelegate.swift
//  GUPT
//
//  Application delegate for lifecycle management
//

import Cocoa
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.gupt", category: "AppDelegate")

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application launched")

        // Check and request permissions on launch
        checkPermissions()

        // Configure application behavior
        configureApplication()
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Application terminating")
        // Clean up resources
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when last window closes (for background mode)
        return false
    }

    // MARK: - Permission Checking

    private func checkPermissions() {
        // Check screen recording permission
        let hasScreenRecording: Bool
        if #available(macOS 14.4, *) {
            // Actively request permission (forces prompt if needed)
            hasScreenRecording = CGRequestScreenCaptureAccess()
            logger.info("Screen capture access checked (macOS 14.4+): \(hasScreenRecording)")
        } else {
            // Older API just checks if we have it
            hasScreenRecording = CGPreflightScreenCaptureAccess()
        }

        if !hasScreenRecording {
            logger.warning("Screen recording permission not granted")
            showPermissionAlert(for: .screenRecording)
        }

        // Check accessibility permission
        let hasAccessibility = AXIsProcessTrusted()
        if !hasAccessibility {
            logger.warning("Accessibility permission not granted")
            showPermissionAlert(for: .accessibility)
        }
    }

    private func showPermissionAlert(for permission: PermissionType) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Permission Required"

            switch permission {
            case .screenRecording:
                alert.informativeText = "GUPT needs Screen Recording permission to capture your screen.\n\nPlease grant access in System Settings > Privacy & Security > Screen Recording"
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    self.openScreenRecordingSettings()
                }

            case .accessibility:
                alert.informativeText = "GUPT needs Accessibility permission to control mouse and keyboard remotely.\n\nPlease grant access in System Settings > Privacy & Security > Accessibility"
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Later")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    self.openAccessibilitySettings()
                }
            }
        }
    }

    private func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Application Configuration

    private func configureApplication() {
        // Set application presentation options if needed
        // For background mode, we might hide dock icon
        // NSApp.setActivationPolicy(.accessory)  // Hidden mode

        // For now, keep normal behavior
        NSApp.setActivationPolicy(.regular)
    }

    // MARK: - Menu Actions

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func openPreferences() {
        // Open settings window
        if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

// MARK: - Permission Type

enum PermissionType {
    case screenRecording
    case accessibility
}

// MARK: - Menu Setup

extension AppDelegate {
    func setupMenuBar() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        appMenu.addItem(NSMenuItem(title: "About GUPT", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Hide GUPT", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "Quit GUPT", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // Help Menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
