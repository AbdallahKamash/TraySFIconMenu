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
        InlineInsertPreferences.registerDefaults()

        // When hosting unit tests, stay out of the way: no menu bar item, hotkey or windows.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }

        // Must run before anything reads settings (the shortcut, first-run flag, recents).
        Self.importSettingsFromSandboxContainer()
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "signpost.right.fill", accessibilityDescription: AppInfo.name)
            button.toolTip = AppInfo.name
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        
        popover.contentViewController = NSHostingController(rootView: SymbolBrowserView { [weak self] in
            self?.popover.performClose(nil)
        })

        
        HotKeyManager.shared.onHotKey = { [weak self] in
            self?.handleHotKey()
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

    /// Earlier builds ran in the App Sandbox, which kept settings in a private container.
    /// The sandbox is now off (it blocks the Accessibility access inline insert needs), so
    /// copy those settings over once; otherwise the tour, shortcut and recents would reset.
    private static func importSettingsFromSandboxContainer() {
        let defaults = UserDefaults.standard
        let doneKey = "importedSandboxSettings"
        guard !defaults.bool(forKey: doneKey), let bundleID = Bundle.main.bundleIdentifier else { return }
        defaults.set(true, forKey: doneKey)
        // Only on a fresh, unsandboxed profile; never overwrite settings made since.
        guard defaults.object(forKey: "hasRunBefore") == nil else { return }

        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(bundleID)/Data/Library/Preferences/\(bundleID).plist")
        guard let old = NSDictionary(contentsOf: url) as? [String: Any] else { return }
        for (key, value) in old where !key.hasPrefix("NS") && !key.hasPrefix("Apple") && !key.hasPrefix("com.apple") {
            defaults.set(value, forKey: key)
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

    /// The app shortcut: inline insert when editing Swift in Xcode / VS Code,
    /// otherwise the menu bar browser.
    private func handleHotKey() {
        if InlineInsertController.shared.isShown {
            InlineInsertController.shared.close()
            return
        }
        if InlineInsertPreferences.isEnabled, !popover.isShown, EditorContext.editorIsFrontmost {
            if let context = EditorContext.capture() {
                InlineInsertController.shared.show(context: context)
                return
            }
            if !Accessibility.isTrusted && offerInlineInsertAccess() { return }
        }
        togglePopover()
    }

    /// Explains inline insert once, the first time the shortcut is used in an editor
    /// without Accessibility access. Returns true if the user went to grant access.
    private func offerInlineInsertAccess() -> Bool {
        let askedKey = "askedForInlineInsertAccess"
        guard !UserDefaults.standard.bool(forKey: askedKey) else { return false }
        UserDefaults.standard.set(true, forKey: askedKey)

        let alert = NSAlert()
        alert.messageText = "Insert symbols right where you type?"
        alert.informativeText = """
            In a Swift file in Xcode or VS Code, the shortcut can open a small search at your             text cursor and type the symbol into your code.

            This needs Accessibility access so TraySFIconMenu can find the cursor and type for you.             You can change this any time in Settings.
            """
        alert.addButton(withTitle: "Allow Access…")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        Accessibility.requestAccess()
        return true
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
        menu.addItem(NSMenuItem(title: "Guide…", action: #selector(openGuide), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "About \(AppInfo.name)", action: #selector(openAbout), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(AppInfo.name)", action: #selector(quitApp), keyEquivalent: "q"))

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
        let window = CenteredResizingWindow(
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

        let window = CenteredResizingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 460),
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

        let window = CenteredResizingWindow(
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

/// A window whose size comes from its SwiftUI content (Settings, Guide, About). When that
/// size changes, e.g. switching Settings tabs, AppKit would keep the bottom-left corner
/// fixed so the window drifts up and to the right. This keeps its center fixed instead.
final class CenteredResizingWindow: NSWindow {
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(centered(frameRect), display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        super.setFrame(centered(frameRect), display: displayFlag, animate: animateFlag)
    }

    private func centered(_ proposed: NSRect) -> NSRect {
        // Re-anchor size changes on a visible window (AppKit proposes keeping the top-left
        // corner). Same-size moves, and anything before the window is shown, pass through;
        // showCentered positions with setFrameOrigin, which isn't affected.
        guard isVisible, proposed.size != frame.size else { return proposed }
        var rect = proposed
        rect.origin.x = (frame.midX - proposed.width / 2).rounded()
        rect.origin.y = (frame.midY - proposed.height / 2).rounded()
        // Keep it on screen.
        if let visible = screen?.visibleFrame {
            rect.origin.x = min(max(rect.minX, visible.minX), visible.maxX - rect.width)
            rect.origin.y = min(max(rect.minY, visible.minY), visible.maxY - rect.height)
        }
        return rect
    }
}
