//
//  InlineInsertPreferences.swift
//  TraySFIconMenu
//
//  Every user setting for inline insert, in one place: when it opens (which editors,
//  which files) and how it behaves (what Return inserts, how many suggestions,
//  recents, clipboard). Views bind to the keys with @AppStorage; logic reads the
//  static accessors.
//

import Foundation

enum InlineInsertPreferences {

    enum Key {
        static let enabled = "inlineInsertEnabled"
        static let scope = "inlineInsertScope"
        static let format = "inlineInsertFormat"
        static let maxSuggestions = "inlineInsertMaxSuggestions"
        static let showRecents = "inlineInsertShowRecents"
        static let restoreClipboard = "inlineInsertRestoreClipboard"
        static func editor(_ editor: Editor) -> String { "inlineInsertEditor.\(editor.rawValue)" }
    }

    // MARK: When

    /// Supported editors, each of which can be switched on or off.
    enum Editor: String, CaseIterable, Identifiable {
        case xcode, vscode, cursor

        var id: String { rawValue }

        var label: String {
            switch self {
            case .xcode: return "Xcode"
            case .vscode: return "VS Code"
            case .cursor: return "Cursor"
            }
        }

        var detail: String? {
            self == .vscode ? "Includes VS Code Insiders and VSCodium" : nil
        }

        var bundleIDs: Set<String> {
            switch self {
            case .xcode: return ["com.apple.dt.Xcode"]
            case .vscode: return ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.vscodium"]
            case .cursor: return ["com.todesktop.230313mzl4w4u92"]
            }
        }
    }

    /// Which files inline insert opens in.
    enum Scope: String, CaseIterable, Identifiable {
        case swiftFiles, anyFile
        var id: String { rawValue }
        var label: String { self == .swiftFiles ? "Swift files only" : "Any file" }
    }

    // MARK: How

    /// What Return inserts. ⌥Return always inserts the alternative.
    enum Format: String, CaseIterable, Identifiable {
        case smart, nameOnly, imageCall
        var id: String { rawValue }

        var label: String {
            switch self {
            case .smart: return "Smart (adds quotes when needed)"
            case .nameOnly: return "Symbol name only"
            case .imageCall: return "Image(systemName:)"
            }
        }

        var returnStyle: InsertStyle {
            switch self {
            case .smart: return .automatic
            case .nameOnly: return .nameOnly
            case .imageCall: return .imageCall
            }
        }

        /// ⌥Return: `Image(systemName:)`, or the smart insert when that's already the default.
        var optionReturnStyle: InsertStyle { self == .imageCall ? .automatic : .imageCall }

        var optionReturnLabel: String { self == .imageCall ? "a smart insert" : "Image(systemName:)" }
    }

    static let suggestionRange = 3...10

    // MARK: Defaults

    static let defaults: [String: Any] = [
        Key.enabled: true,
        Key.scope: Scope.swiftFiles.rawValue,
        Key.format: Format.smart.rawValue,
        Key.maxSuggestions: 6,
        Key.showRecents: true,
        Key.restoreClipboard: true,
        Key.editor(.xcode): true,
        Key.editor(.vscode): true,
        Key.editor(.cursor): true,
    ]

    /// Call once at launch so every reader (and @AppStorage) sees the same defaults.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: defaults)
    }

    // MARK: Current values

    private static var store: UserDefaults { .standard }

    static var isEnabled: Bool { store.bool(forKey: Key.enabled) }

    static func isEnabled(_ editor: Editor) -> Bool { store.bool(forKey: Key.editor(editor)) }

    /// Bundle IDs of the editors the user has switched on.
    static var enabledBundleIDs: Set<String> {
        Editor.allCases.filter { isEnabled($0) }.reduce(into: []) { $0.formUnion($1.bundleIDs) }
    }

    static var scope: Scope { Scope(rawValue: store.string(forKey: Key.scope) ?? "") ?? .swiftFiles }

    static var format: Format { Format(rawValue: store.string(forKey: Key.format) ?? "") ?? .smart }

    static var maxSuggestions: Int {
        let value = store.integer(forKey: Key.maxSuggestions)
        return min(max(value, suggestionRange.lowerBound), suggestionRange.upperBound)
    }

    static var showRecents: Bool { store.bool(forKey: Key.showRecents) }

    static var restoreClipboard: Bool { store.bool(forKey: Key.restoreClipboard) }
}
