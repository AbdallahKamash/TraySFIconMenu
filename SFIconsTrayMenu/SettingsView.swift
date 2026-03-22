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
    
    @AppStorage("showSymbolNames") private var showSymbolNames = true
    @AppStorage("defaultIconSize") private var defaultIconSize: Double = 28

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $isEnabled)
                    .onChange(of: isEnabled) { newValue, _ in
                        LaunchAtLogin.isEnabled = newValue
                    }
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
