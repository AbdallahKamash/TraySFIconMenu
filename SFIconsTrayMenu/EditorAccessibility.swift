//
//  EditorAccessibility.swift
//  TraySFIconMenu
//
//  Talks to Xcode / VS Code through the macOS Accessibility API: is a .swift file
//  open, where is the text cursor, what's just before it, and typing text back in.
//  All of this needs the user to allow TraySFIconMenu under
//  System Settings → Privacy & Security → Accessibility.
//

import AppKit
import ApplicationServices

// MARK: - Permission

enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt (first time) and opens the Accessibility settings pane.
    static func requestAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options),
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Editor context

/// A snapshot of the editor at the moment the shortcut was pressed.
struct EditorContext {
    let appName: String
    /// The open .swift file, or nil when it isn't one (only possible with the "Any file" setting).
    let fileName: String?
    /// Text cursor in Cocoa screen coordinates (bottom-left origin), if we could find it.
    let caretRect: CGRect?
    /// Up to ~60 characters before the cursor, used to decide how to insert.
    let textBeforeCaret: String

    /// Every editor inline insert knows how to work with.
    static let editorBundleIDs: Set<String> = InlineInsertPreferences.Editor.allCases
        .reduce(into: []) { $0.formUnion($1.bundleIDs) }

    /// True when the frontmost app is an editor the user has switched on in Settings.
    static var editorIsFrontmost: Bool {
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return InlineInsertPreferences.enabledBundleIDs.contains(id)
    }

    /// Reads the frontmost editor. Returns nil unless it's an editor the user switched on,
    /// Accessibility access is granted, and (with the default "Swift files only" setting)
    /// a .swift file is open.
    static func capture() -> EditorContext? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return capture(app: app)
    }

    /// Same as `capture()`, for a specific editor app.
    static func capture(app: NSRunningApplication) -> EditorContext? {
        guard Accessibility.isTrusted,
            let bundleID = app.bundleIdentifier,
            InlineInsertPreferences.enabledBundleIDs.contains(bundleID)
        else { return nil }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        // Don't hang the shortcut if the editor is busy.
        AXUIElementSetMessagingTimeout(appElement, 0.3)
        // Electron apps (VS Code, Cursor) only build their accessibility tree on request.
        if bundleID != "com.apple.dt.Xcode" {
            AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        }

        guard let window = appElement.element(kAXFocusedWindowAttribute) else { return nil }
        let fileName = swiftFileName(
            document: window.string(kAXDocumentAttribute), title: window.string(kAXTitleAttribute))
        if fileName == nil && InlineInsertPreferences.scope == .swiftFiles { return nil }

        let focused = appElement.element(kAXFocusedUIElementAttribute)
        return EditorContext(
            appName: app.localizedName ?? "Editor",
            fileName: fileName,
            caretRect: focused.flatMap { caretRect(in: $0) },
            textBeforeCaret: focused.flatMap { textBeforeCaret(in: $0) } ?? "")
    }

    /// Finds "Something.swift" in the window's document URL (Xcode) or title
    /// (VS Code: "● File.swift — Project").
    static func swiftFileName(document: String?, title: String?) -> String? {
        if let document, let url = URL(string: document), url.pathExtension.lowercased() == "swift" {
            return url.lastPathComponent
        }
        for text in [title, document].compactMap({ $0 }) {
            if let range = text.range(of: #"[^\s/\\—–|●]+\.swift\b"#, options: [.regularExpression, .caseInsensitive]) {
                return String(text[range])
            }
        }
        return nil
    }

    // MARK: Caret

    private static func selectedRange(of element: AXUIElement) -> CFRange? {
        guard let value = element.value(kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        var range = CFRange()
        return AXValueGetValue(value as! AXValue, .cfRange, &range) ? range : nil
    }

    private static func bounds(of range: CFRange, in element: AXUIElement) -> CGRect? {
        var r = range
        guard let rangeValue = AXValueCreate(.cfRange, &r) else { return nil }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString, rangeValue, &result) == .success,
            let result, CFGetTypeID(result) == AXValueGetTypeID()
        else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(result as! AXValue, .cgRect, &rect), rect.height > 0 else { return nil }
        return rect
    }

    /// The text cursor's rectangle, converted to Cocoa screen coordinates.
    private static func caretRect(in element: AXUIElement) -> CGRect? {
        var axRect: CGRect?
        if let range = selectedRange(of: element) {
            // A zero-length range often has no bounds; fall back to the next or previous character.
            axRect = bounds(of: CFRange(location: range.location, length: 0), in: element)
                ?? bounds(of: CFRange(location: range.location, length: 1), in: element)
                ?? (range.location > 0
                    ? bounds(of: CFRange(location: range.location - 1, length: 1), in: element).map {
                        CGRect(x: $0.maxX, y: $0.minY, width: 1, height: $0.height)
                    } : nil)
        }
        // VS Code keeps a small hidden text area at the cursor; its frame is close enough.
        if axRect == nil, let frame = element.frame, frame.height < 60 {
            axRect = frame
        }
        guard let rect = axRect, let primary = NSScreen.screens.first else { return nil }
        // Accessibility uses a top-left origin on the primary screen; Cocoa uses bottom-left.
        return CGRect(x: rect.minX, y: primary.frame.height - rect.maxY, width: max(rect.width, 1), height: rect.height)
    }

    private static func textBeforeCaret(in element: AXUIElement, length: Int = 60) -> String? {
        guard let range = selectedRange(of: element), range.location > 0 else { return nil }
        let start = max(0, range.location - length)
        var r = CFRange(location: start, length: range.location - start)
        guard let rangeValue = AXValueCreate(.cfRange, &r) else { return nil }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, rangeValue, &result) == .success
        else { return nil }
        return result as? String
    }
}

// MARK: - Typing into the editor

enum EditorInserter {
    /// Pastes `text` into the frontmost app with ⌘V, then (optionally) puts the user's
    /// clipboard back.
    static func insert(_ text: String, restoreClipboard: Bool = true) {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ourChange = pasteboard.changeCount

        postCommandV()
        guard restoreClipboard else { return }

        // Restore once the editor has read the clipboard, unless something else copied meanwhile.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard pasteboard.changeCount == ourChange else { return }
            pasteboard.clearContents()
            if !saved.isEmpty { pasteboard.writeObjects(saved) }
        }
    }

    private static func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

// MARK: - Smart insertion text

nonisolated enum InsertStyle: Sendable {
    /// Decide from the code around the cursor.
    case automatic
    /// Always just `star.fill`.
    case nameOnly
    /// `Image(systemName: "star.fill")`
    case imageCall
}

nonisolated enum InsertText {
    /// What to type for `symbol`, given the code just before the cursor.
    ///  - after an opening quote → `star.fill`
    ///  - after `systemName:` / `systemImage:` / `systemSymbolName:` → `"star.fill"`
    ///  - otherwise → `star.fill`
    /// `.imageCall` always gives `Image(systemName: "star.fill")` (just the name inside quotes).
    static func text(for symbol: String, before: String, style: InsertStyle) -> String {
        let trimmed = before.replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
        let insideQuotes = before.last == "\"" && before.filter { $0 == "\"" }.count % 2 == 1

        switch style {
        case .nameOnly:
            return symbol
        case .imageCall:
            return insideQuotes ? symbol : "Image(systemName: \"\(symbol)\")"
        case .automatic:
            if insideQuotes { return symbol }
            let labels = ["systemName:", "systemImage:", "systemSymbolName:"]
            if labels.contains(where: { trimmed.hasSuffix($0) }) {
                return (before.last == ":" ? " " : "") + "\"\(symbol)\""
            }
            return symbol
        }
    }
}

// MARK: - AXUIElement helpers

private extension AXUIElement {
    func value(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success ? value : nil
    }

    func string(_ attribute: String) -> String? { value(attribute) as? String }

    func element(_ attribute: String) -> AXUIElement? {
        guard let value = value(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    /// Frame in Accessibility (top-left origin) coordinates.
    var frame: CGRect? {
        guard let p = value(kAXPositionAttribute), let s = value(kAXSizeAttribute),
            CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(p as! AXValue, .cgPoint, &point)
        AXValueGetValue(s as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }
}
