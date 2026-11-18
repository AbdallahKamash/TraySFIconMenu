//
//  AppDelegate.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//

import Cocoa
import SwiftUI
import LaunchAtLogin

final class AppDelegate: NSObject, NSApplicationDelegate {

    

    private var statusItem: NSStatusItem!
    private let popover: NSPopover = {
        let p = NSPopover()
        p.behavior = .transient
        return p
    }()
    private var settingsWindow: NSWindow?
    private var guideWindow: NSWindow?
    private var aboutWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // When hosting unit tests, stay out of the way: no menu bar item, hotkey or windows.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "signpost.right.fill", accessibilityDescription: AppInfo.name)
            button.toolTip = AppInfo.name
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        
        popover.contentViewController = NSHostingController(rootView: SymbolBrowserView())

        
        HotKeyManager.shared.onHotKey = { [weak self] in
            self?.togglePopover()
        }
        HotKeyManager.shared.registerSaved()

        // Build the symbol catalog in the background so the first open is instant.
        preloadSymbolData()

        // First launch: show the welcome tour. Later launches: a quick "I'm in the
        // menu bar" overlay. Give the status item a moment to be laid out first.
        let hasRunBeforeKey = "hasRunBefore"
        if !UserDefaults.standard.bool(forKey: hasRunBeforeKey) {
            UserDefaults.standard.set(true, forKey: hasRunBeforeKey)
            DispatchQueue.main.async { self.openGuide() }
        } else if UserDefaults.standard.object(forKey: "showLaunchAnimation") as? Bool ?? true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                LaunchOverlay.show(for: self.statusItem)
            }
        }
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showRightClickMenu()
        } else {
            togglePopover()
        }
    }

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
        menu.addItem(NSMenuItem(title: "Guide", action: #selector(openGuide), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "About", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)  
        statusItem.menu = nil  
    }

    @objc private func openSettings() {
        
        if let existingWindow = settingsWindow {
            if existingWindow.isVisible {
                existingWindow.showCentered()
                NSApp.activate(ignoringOtherApps: true)
                return
            } else {
                
                NotificationCenter.default.removeObserver(
                    self, name: NSWindow.willCloseNotification, object: existingWindow)
                settingsWindow = nil
            }
        }

        
        // Not resizable: the content sizes the window (showCentered positions it).
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.title = "Settings"
        window.isReleasedWhenClosed = false  

        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        settingsWindow = window
        window.showCentered()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func settingsWindowWillClose(_ notification: Notification) {
        
        settingsWindow = nil

        
        if let window = notification.object as? NSWindow {
            NotificationCenter.default.removeObserver(
                self, name: NSWindow.willCloseNotification, object: window)
        }
    }

    @objc private func openGuide() {
        if let existingWindow = guideWindow {
            if existingWindow.isVisible {
                existingWindow.showCentered()
                NSApp.activate(ignoringOtherApps: true)
                return
            } else {
                NotificationCenter.default.removeObserver(
                    self, name: NSWindow.willCloseNotification, object: existingWindow)
                guideWindow = nil
            }
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentViewController = NSHostingController(
            rootView: OnboardingView { [weak self] in
                guard let self else { return }
                self.guideWindow?.close()
                // End the tour by pointing at where the app lives.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    LaunchOverlay.show(for: self.statusItem)
                }
            })
        window.title = "Welcome"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(guideWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        guideWindow = window
        window.showCentered()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func guideWindowWillClose(_ notification: Notification) {
        guideWindow = nil
        if let window = notification.object as? NSWindow {
            NotificationCenter.default.removeObserver(
                self, name: NSWindow.willCloseNotification, object: window)
        }
    }

    @objc private func openAbout() {
        if let window = aboutWindow {
            window.showCentered()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = NSHostingController(rootView: AboutView())
        window.title = "About \(AppInfo.name)"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(aboutWindowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        aboutWindow = window
        window.showCentered()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func aboutWindowWillClose(_ notification: Notification) {
        aboutWindow = nil
        if let window = notification.object as? NSWindow {
            NotificationCenter.default.removeObserver(
                self, name: NSWindow.willCloseNotification, object: window)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
   
    deinit {
        
        NotificationCenter.default.removeObserver(self)
    }
}

extension NSWindow {
    /// Centers the window exactly in the middle of the screen the mouse is on
    /// (AppKit's `center()` sits it in the upper third), then brings it forward.
    func showCentered() {
        layoutIfNeeded()  // let SwiftUI content settle the final size first
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main ?? self.screen
        if let visible = screen?.visibleFrame {
            let size = frame.size
            setFrameOrigin(NSPoint(
                x: (visible.midX - size.width / 2).rounded(),
                y: (visible.midY - size.height / 2).rounded()))
        }
        makeKeyAndOrderFront(nil)
    }
}
