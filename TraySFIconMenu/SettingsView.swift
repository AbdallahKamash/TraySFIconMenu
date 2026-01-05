//
//  SettingsView.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//


import SwiftUI
import LaunchAtLogin

struct SettingsView: View {
    @StateObject private var launchAtLogin = LaunchAtLogin.observable
    
    @AppStorage("showSymbolNames") private var showSymbolNames = true
    @AppStorage("defaultIconSize") private var defaultIconSize: Double = 28

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin.isEnabled)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
