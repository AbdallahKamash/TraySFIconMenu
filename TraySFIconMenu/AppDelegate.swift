//
//  AppDelegate.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//

import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    

    private var statusItem: NSStatusItem!
    private let popover: NSPopover = {
        let p = NSPopover()
        p.behavior = .transient
        return p
    }()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {

        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        
        popover.contentViewController = NSHostingController(rootView: SymbolBrowserView())

        
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
        statusItem.button?.performClick(nil)  
        statusItem.menu = nil  
    }

    @objc private func openSettings() {
        
        if let existingWindow = settingsWindow {
            if existingWindow.isVisible {
                existingWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            } else {
                
                NotificationCenter.default.removeObserver(
                    self, name: NSWindow.willCloseNotification, object: existingWindow)
                settingsWindow = nil
            }
        }

        
        let windowSize = NSSize(width: 380, height: 220)
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowRect = NSRect(
            x: screenRect.midX - windowSize.width / 2,
            y: screenRect.midY - windowSize.height / 2,
            width: windowSize.width,
            height: windowSize.height
        )

        
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.title = "Settings"
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false  

        
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
        
        settingsWindow = nil

        
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
        
        NotificationCenter.default.removeObserver(self)
    }
}
