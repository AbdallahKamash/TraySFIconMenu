//
//  AppDelegate.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//

import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
<<<<<<< HEAD

    // MARK: - Hot Key

=======
    
    // MARK: - Hot Key
    
>>>>>>> 16f71fbb117296093f101a199d08fdd4fa25cf3c
    private var statusItem: NSStatusItem!
    private let popover: NSPopover = {
        let p = NSPopover()
        p.behavior = .transient
        return p
    }()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {

        // Create tray icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Popover for main view
        popover.contentViewController = NSHostingController(rootView: SymbolBrowserView())
<<<<<<< HEAD

=======
        
>>>>>>> 16f71fbb117296093f101a199d08fdd4fa25cf3c
        // Register global hot key (⌥⌘T) to toggle the tray popover
        HotKeyManager.shared.onHotKey = { [weak self] in
            self?.togglePopover()
        }
        HotKeyManager.shared.registerDefault()
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showRightClickMenu()
        } else {
            togglePopover()
        }
    }
<<<<<<< HEAD

=======
    
>>>>>>> 16f71fbb117296093f101a199d08fdd4fa25cf3c
    private func showPopoverFromStatusItem() {
        guard let button = statusItem.button else { return }
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
        if popover.isShown {
            popover.performClose(nil)
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
<<<<<<< HEAD

=======
    
>>>>>>> 16f71fbb117296093f101a199d08fdd4fa25cf3c
    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if !NSApp.isActive {
                NSApp.activate(ignoringOtherApps: true)
            }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showRightClickMenu() {
        let menu = NSMenu()

        menu.addItem(
            NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "About", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)  // show menu
        statusItem.menu = nil  // remove menu immediately after showing
    }

    @objc private func openSettings() {
        // Check if window already exists and is visible
        if let existingWindow = settingsWindow {
            if existingWindow.isVisible {
                existingWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            } else {
                // Window exists but is not visible (was closed), so clean it up
                NotificationCenter.default.removeObserver(
                    self, name: NSWindow.willCloseNotification, object: existingWindow)
                settingsWindow = nil
            }
        }

        // Define the window size
        let windowSize = NSSize(width: 380, height: 220)
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowRect = NSRect(
            x: screenRect.midX - windowSize.width / 2,
            y: screenRect.midY - windowSize.height / 2,
            width: windowSize.width,
            height: windowSize.height
        )

        // Create window with frame
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        // Set SwiftUI view
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.title = "Settings"
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false  // Important: prevent premature deallocation

        // Observe window closing
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func settingsWindowWillClose(_ notification: Notification) {
        // Clear the reference when window closes
        settingsWindow = nil

        // Remove the observer
        if let window = notification.object as? NSWindow {
            NotificationCenter.default.removeObserver(
                self, name: NSWindow.willCloseNotification, object: window)
        }
    }

    @objc private func openAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    deinit {
        // Clean up observers
        NotificationCenter.default.removeObserver(self)
    }
}

