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
        // Control-click counts as a right-click, as everywhere else on the Mac.
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
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
            if !Accessibility.isTrusted {
                if offerInlineInsertAccess() { return }
                // Already explained once: open the tray, with a notice saying why.
                if !popover.isShown { InlineAccessNotice.shared.isVisible = true }
            }
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
            In a Swift file in Xcode or VS Code, the shortcut can open a small search at your \
            text cursor and type the symbol into your code.

            This needs Accessibility access so \(AppInfo.name) can find the cursor and type for you. \
            You can change this any time in Settings.
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

        // Attach the menu just for this click, so a left click still opens the browser.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Windows

    @objc private func openSettings() {
        show(\.settingsWindow) {
            makeWindow(title: "Settings", size: CGSize(width: 440, height: 300), content: SettingsView())
        }
    }

    @objc private func openGuide() {
        show(\.guideWindow) {
            let tour = OnboardingView { [weak self] in
                guard let self else { return }
                self.guideWindow?.close()
                // End the tour by pointing at where the app lives.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    LaunchOverlay.show(for: self.statusItem)
                }
            }
            return makeWindow(
                title: "Welcome", size: CGSize(width: 460, height: 460), hidesTitleBar: true, content: tour)
        }
    }

    @objc private func openAbout() {
        show(\.aboutWindow) {
            makeWindow(
                title: "About \(AppInfo.name)", size: CGSize(width: 400, height: 560), hidesTitleBar: true,
                content: AboutView())
        }
    }

    /// Brings the window stored at `keyPath` to the front, building it with `make` if it
    /// isn't open. Closing a window drops it (see `windowWillClose`), so the next open
    /// starts from a fresh one.
    private func show(_ keyPath: ReferenceWritableKeyPath<AppDelegate, NSWindow?>, make: () -> NSWindow) {
        let window: NSWindow
        if let existing = self[keyPath: keyPath] {
            window = existing
        } else {
            window = make()
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowWillClose(_:)),
                name: NSWindow.willCloseNotification, object: window)
            self[keyPath: keyPath] = window
        }
        window.showCentered()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// A fixed-size window around SwiftUI content. Not resizable: the content sizes the
    /// window (showCentered positions it). `hidesTitleBar` lets the content run under a
    /// transparent title bar, for the tour and About.
    private func makeWindow(
        title: String, size: CGSize, hidesTitleBar: Bool = false, content: some View
    ) -> NSWindow {
        let window = CenteredResizingWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: hidesTitleBar ? [.titled, .closable, .fullSizeContentView] : [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = NSHostingController(rootView: content)
        window.title = title
        window.isReleasedWhenClosed = false
        if hidesTitleBar {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
        }
        return window
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
        if window === settingsWindow { settingsWindow = nil }
        if window === guideWindow { guideWindow = nil }
        if window === aboutWindow { aboutWindow = nil }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
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
