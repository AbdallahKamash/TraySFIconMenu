//
//  SettingsView.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//


import SwiftUI
import LaunchAtLogin

struct SettingsView: View {
    
    @State private var isEnabled = LaunchAtLogin.isEnabled
    
    @AppStorage("showLaunchAnimation") private var showLaunchAnimation = true

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
        }
        // Plain (columns) style: a .grouped Form is a scroll view with no natural height,
        // which made the hosting window collapse to zero height.
        .padding(20)
        // Size the window to exactly what the content needs, so nothing gets truncated.
        .fixedSize()
    }
}
