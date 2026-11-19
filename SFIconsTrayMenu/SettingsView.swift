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
    
    @State private var isEnabled = LaunchAtLogin.isEnabled
    
    @AppStorage("showLaunchAnimation") private var showLaunchAnimation = true
    @AppStorage("inlineInsertEnabled") private var inlineInsertEnabled = true
    @State private var accessibilityTrusted = Accessibility.isTrusted
    @State private var hasRecents = !RecentSymbols.all.isEmpty

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        LaunchAtLogin.isEnabled = newValue
                    }
                Toggle("Show menu bar animation on launch", isOn: $showLaunchAnimation)
            }

            Section("Keyboard Shortcut") {
                LabeledContent("Open TraySFIconMenu") {
                    ShortcutRecorder()
                }
            }

            Section("Inline Insert") {
                Toggle("Insert at the cursor in Swift files (Xcode, VS Code)", isOn: $inlineInsertEnabled)
                LabeledContent("Accessibility access") {
                    if accessibilityTrusted {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Allow…") { Accessibility.requestAccess() }
                    }
                }
                LabeledContent("Recently used symbols") {
                    Button("Clear") {
                        RecentSymbols.clear()
                        hasRecents = false
                    }
                    .disabled(!hasRecents)
                }
                Text("Press the shortcut in a .swift file to search and insert a symbol at your text cursor.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320, alignment: .leading)
            }
        }
        // Plain (columns) style: a .grouped Form is a scroll view with no natural height,
        // which made the hosting window collapse to zero height.
        .padding(20)
        // Size the window to exactly what the content needs, so nothing gets truncated.
        .fixedSize()
        // Notice when the user flips the switch in System Settings.
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if accessibilityTrusted != Accessibility.isTrusted { accessibilityTrusted = Accessibility.isTrusted }
        }
    }
}
