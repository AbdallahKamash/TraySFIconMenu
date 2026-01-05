//
//  TraySFIconMenuApp.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//


import SwiftUI
import AppKit

@main
struct TraySFIconMenuApp: App {
    var body: some Scene {
        MenuBarExtra("SF Symbols", systemImage: "bolt.fill") {
            SymbolBrowserView()
        }
        .menuBarExtraStyle(.window)
    }
}
