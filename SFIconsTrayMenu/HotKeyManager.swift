import Cocoa
import Carbon

struct HotKeyCombination: Equatable {
    let keyCode: UInt32
    /// Carbon modifier mask (cmdKey, shiftKey, optionKey, controlKey).
    let modifiers: UInt32
    /// What to show for the key itself, e.g. "T" or "Space".
    let keyLabel: String

    /// ⇧⌘T
    static let `default` = HotKeyCombination(keyCode: 17, modifiers: UInt32(shiftKey | cmdKey), keyLabel: "T")

    /// Modifier symbols in Apple's standard order, e.g. ["⇧", "⌘"].
    var modifierSymbols: [String] {
        var symbols: [String] = []
        if modifiers & UInt32(controlKey) != 0 { symbols.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { symbols.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { symbols.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { symbols.append("⌘") }
        return symbols
    }

    /// Each key as its own cap, e.g. ["⇧", "⌘", "T"].
    var keyCaps: [String] { modifierSymbols + [keyLabel] }

    /// e.g. "⇧⌘T"
    var displayString: String { keyCaps.joined() }

    static func == (a: HotKeyCombination, b: HotKeyCombination) -> Bool {
        a.keyCode == b.keyCode && a.modifiers == b.modifiers
    }
}

extension HotKeyCombination {
    /// Builds a combination from a key press, or nil if it can't be a global shortcut
    /// (it needs ⌘, ⌃ or ⌥ — Shift alone would steal normal typing — unless it's an F-key).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }

        let code = UInt32(event.keyCode)
        let isFunctionKey = Self.functionKeyNames[code] != nil
        let hasRealModifier = carbon & UInt32(cmdKey | optionKey | controlKey) != 0
        guard hasRealModifier || isFunctionKey else { return nil }

        self.init(keyCode: code, modifiers: carbon, keyLabel: Self.label(for: event))
    }

    private static let specialKeyNames: [UInt32: String] = [
        49: "Space", 36: "↩", 76: "⌤", 48: "⇥", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
    ]

    private static let functionKeyNames: [UInt32: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
        101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
        106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
    ]

    private static func label(for event: NSEvent) -> String {
        let code = UInt32(event.keyCode)
        if let name = specialKeyNames[code] ?? functionKeyNames[code] { return name }
        // The character on the key in the user's layout, ignoring Shift/Option effects.
        let chars = event.charactersIgnoringModifiers?.uppercased() ?? ""
        return chars.isEmpty ? "Key \(code)" : chars
    }
}

extension Notification.Name {
    static let hotKeyDidChange = Notification.Name("HotKeyDidChange")
}

@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()
    private init() {}

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    var onHotKey: (() -> Void)?

    private enum Keys {
        static let code = "hotKeyCode"
        static let modifiers = "hotKeyModifiers"
        static let label = "hotKeyLabel"
    }

    /// The user's shortcut, or ⇧⌘T if they haven't set one.
    private(set) var current: HotKeyCombination = {
        let d = UserDefaults.standard
        guard d.object(forKey: Keys.code) != nil,
            let label = d.string(forKey: Keys.label)
        else { return .default }
        return HotKeyCombination(
            keyCode: UInt32(d.integer(forKey: Keys.code)),
            modifiers: UInt32(d.integer(forKey: Keys.modifiers)),
            keyLabel: label)
    }()

    var isDefault: Bool { current == .default }

    /// Registers the saved shortcut (falls back to the default if it can't be registered).
    func registerSaved() {
        if !register(hotKey: current), !isDefault {
            current = .default
            register(hotKey: current)
        }
    }

    /// Switches to a new shortcut. Returns false (and keeps the old one) if macOS
    /// refuses it, e.g. because another app already registered the same combination.
    @discardableResult
    func update(to combo: HotKeyCombination) -> Bool {
        guard register(hotKey: combo) else {
            register(hotKey: current)
            return false
        }
        current = combo
        let d = UserDefaults.standard
        if combo == .default {
            d.removeObject(forKey: Keys.code)
            d.removeObject(forKey: Keys.modifiers)
            d.removeObject(forKey: Keys.label)
        } else {
            d.set(Int(combo.keyCode), forKey: Keys.code)
            d.set(Int(combo.modifiers), forKey: Keys.modifiers)
            d.set(combo.keyLabel, forKey: Keys.label)
        }
        NotificationCenter.default.post(name: .hotKeyDidChange, object: nil)
        return true
    }

    func resetToDefault() {
        update(to: .default)
    }

    /// Temporarily releases the shortcut, e.g. while recording a new one in Settings.
    func pause() { unregister() }

    func resume() { register(hotKey: current) }

    @discardableResult
    private func register(hotKey: HotKeyCombination) -> Bool {
        unregister()

        if eventHandlerRef == nil {
            var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
                return HotKeyManager.handleHotKeyEvent(nextHandler, theEvent, userData)
            }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &eventHandlerRef)
            if status != noErr {
                NSLog("Failed to install hot key event handler: %d", status)
            }
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x48544B31), id: UInt32(1))
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            NSLog("Failed to register hot key: %d", status)
            hotKeyRef = nil
            return false
        }
        return true
    }

    private func unregister() {
        if let hk = hotKeyRef {
            UnregisterEventHotKey(hk)
            hotKeyRef = nil
        }
    }

    @MainActor deinit {
        unregister()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    private static func handleHotKeyEvent(_ nextHandler: EventHandlerCallRef?, _ theEvent: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
        guard let userData = userData else { return noErr }
        let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        manager.onHotKey?()
        return noErr
    }
}
