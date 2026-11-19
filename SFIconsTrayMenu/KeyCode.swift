//
//  KeyCode.swift
//  TraySFIconMenu
//
//  Names for the virtual key codes the app compares `NSEvent.keyCode` against,
//  so the keyboard handling reads as keys rather than numbers.
//

import Carbon
import CoreGraphics

nonisolated enum KeyCode {
    static let `return`: UInt16 = 36
    static let tab: UInt16 = 48
    static let space: UInt16 = 49
    static let escape: UInt16 = 53
    /// Enter on the numeric keypad.
    static let keypadEnter: UInt16 = 76
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126

    /// The key that types `character` together with ⌘ in the current keyboard layout,
    /// or nil if the layout has no such key. "V" sits on key 9 on QWERTY but on key 47
    /// on Dvorak, so a posted ⌘V has to use the layout's own key to still mean Paste.
    static func forCommandShortcut(_ character: Character) -> CGKeyCode? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        let wanted = String(character).lowercased()
        let commandDown = UInt32(cmdKey >> 8) & 0xFF

        return layoutData.withUnsafeBytes { buffer -> CGKeyCode? in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return nil }
            for code in 0..<CGKeyCode(128) {
                var deadKeys: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout, code, UInt16(kUCKeyActionDown), commandDown, UInt32(LMGetKbdType()),
                    OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, chars.count, &length, &chars)
                if status == noErr, length > 0,
                    String(utf16CodeUnits: chars, count: length).lowercased() == wanted
                {
                    return code
                }
            }
            return nil
        }
    }
}
