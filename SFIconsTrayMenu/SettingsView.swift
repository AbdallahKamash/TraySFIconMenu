//
//  SettingsView.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//


import Combine
import LaunchAtLogin
import SwiftUI

struct SettingsView: View {
    private typealias Prefs = InlineInsertPreferences

    enum Tab: String, CaseIterable, Identifiable {
        case general, inline
        var id: String { rawValue }
        var title: String { self == .general ? "General" : "Inline Insert" }
        var icon: String { self == .general ? "gearshape" : "character.cursor.ibeam" }
    }

    /// Lets the welcome tour or the one-time prompt open Settings straight at a tab.
    @State var tab: Tab = .general

    @State private var isEnabled = LaunchAtLogin.isEnabled
    @AppStorage("showLaunchAnimation") private var showLaunchAnimation = true

    // Inline insert
    @AppStorage(Prefs.Key.enabled) private var inlineEnabled = true
    @AppStorage(Prefs.Key.editor(.xcode)) private var useXcode = true
    @AppStorage(Prefs.Key.editor(.vscode)) private var useVSCode = true
    @AppStorage(Prefs.Key.editor(.cursor)) private var useCursor = true
    @AppStorage(Prefs.Key.scope) private var scope: Prefs.Scope = .swiftFiles
    @AppStorage(Prefs.Key.format) private var format: Prefs.Format = .smart
    @AppStorage(Prefs.Key.maxSuggestions) private var maxSuggestions = 6
    @AppStorage(Prefs.Key.showRecents) private var showRecents = true
    @AppStorage(Prefs.Key.restoreClipboard) private var restoreClipboard = true
    @State private var accessibilityTrusted = Accessibility.isTrusted
    @State private var hasRecents = !RecentSymbols.all.isEmpty

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.top, 14)

            switch tab {
            case .general: generalTab
            case .inline: inlineTab
            }
        }
        // Size the window to exactly what the content needs, so nothing gets truncated.
        .fixedSize()
        // Notice when the user flips the switch in System Settings.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if accessibilityTrusted != Accessibility.isTrusted { accessibilityTrusted = Accessibility.isTrusted }
            let recents = !RecentSymbols.all.isEmpty
            if hasRecents != recents { hasRecents = recents }
        }
    }

    // Plain (columns) Form style throughout: a .grouped Form is a scroll view with no
    // natural height, which made the hosting window collapse to zero height.

    private var generalTab: some View {
        Form {
            Toggle("Launch at login", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, newValue in
                    LaunchAtLogin.isEnabled = newValue
                }
            Toggle("Show menu bar animation on launch", isOn: $showLaunchAnimation)

            spacer
            LabeledContent("Keyboard shortcut") {
                ShortcutRecorder()
            }
        }
        .padding(20)
    }

    private var inlineTab: some View {
        Form {
            Toggle("Insert symbols at the cursor while coding", isOn: $inlineEnabled)
            caption("In a supported editor, the shortcut opens a small search at your text cursor instead of the menu bar browser.")

            LabeledContent("Accessibility access") {
                if accessibilityTrusted {
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    HStack(spacing: 8) {
                        Label("Required", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Button("Allow…") { Accessibility.requestAccess() }
                    }
                }
            }

            Group {
                sectionHeader("When it opens")
                LabeledContent("Editors") {
                    VStack(alignment: .leading, spacing: 4) {
                        editorToggle(.xcode, isOn: $useXcode)
                        editorToggle(.vscode, isOn: $useVSCode)
                        editorToggle(.cursor, isOn: $useCursor)
                    }
                }
                Picker("Files", selection: $scope) {
                    ForEach(Prefs.Scope.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)

                sectionHeader("How it inserts")
                Picker("Return inserts", selection: $format) {
                    ForEach(Prefs.Format.allCases) { Text($0.label).tag($0) }
                }
                .fixedSize()
                caption(formatExample)

                LabeledContent("Suggestions") {
                    HStack(spacing: 6) {
                        Text("\(maxSuggestions)")
                            .monospacedDigit()
                            .frame(minWidth: 18, alignment: .trailing)
                        Stepper("Suggestions", value: $maxSuggestions, in: Prefs.suggestionRange)
                            .labelsHidden()
                    }
                }
                Toggle("Show recently used symbols before you type", isOn: $showRecents)
                Toggle("Restore my clipboard after inserting", isOn: $restoreClipboard)
                LabeledContent("Recently used") {
                    Button("Clear") {
                        RecentSymbols.clear()
                        hasRecents = false
                    }
                    .disabled(!hasRecents)
                }
            }
            .disabled(!inlineEnabled)
        }
        .padding(20)
    }

    private var spacer: some View {
        Color.clear.frame(height: 6)
    }

    /// A bold group title in the label column, with some space above it.
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .padding(.top, 10)
    }

    private func editorToggle(_ editor: Prefs.Editor, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(editor.label)
            if let detail = editor.detail {
                Text(detail)
            }
        }
    }

    /// A live example of what Return and ⌥Return insert with the chosen format.
    private var formatExample: String {
        let returnText: String
        switch format {
        case .smart: returnText = "star.fill inside quotes, \"star.fill\" after systemName:"
        case .nameOnly: returnText = "star.fill"
        case .imageCall: returnText = "Image(systemName: \"star.fill\")"
        }
        return "Return: \(returnText). ⌥Return inserts \(format.optionReturnLabel) instead."
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 340, alignment: .leading)  // fixed width so the window measures wrapped lines
    }
}
