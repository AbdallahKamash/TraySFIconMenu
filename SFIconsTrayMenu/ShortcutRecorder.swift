//
//  ShortcutRecorder.swift
//  TraySFIconMenu
//
//  Settings control for changing the global "open TraySFIconMenu" shortcut.
//

import AppKit
import SwiftUI

/// Observes the current shortcut so views can show it and update when it changes.
@Observable
final class ShortcutStore {
    static let shared = ShortcutStore()

    private(set) var current = HotKeyManager.shared.current
    private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: .hotKeyDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.current = HotKeyManager.shared.current }
        }
    }
}

struct ShortcutRecorder: View {
    @State private var store = ShortcutStore.shared
    @State private var isRecording = false
    @State private var message: String?
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button(action: toggleRecording) {
                    Group {
                        if isRecording {
                            Text("Press new shortcut…")
                                .foregroundStyle(Color.accentColor)
                        } else {
                            HStack(spacing: 3) {
                                ForEach(Array(store.current.keyCaps.enumerated()), id: \.offset) { _, cap in
                                    Text(cap)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .padding(.horizontal, 5)
                                        .frame(minWidth: 20, minHeight: 20)
                                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                    .frame(minWidth: 150, minHeight: 22)
                }
                .help(isRecording ? "Press Esc to cancel" : "Click to record a new shortcut")

                Button("Reset to Default") {
                    stopRecording()
                    HotKeyManager.shared.resetToDefault()
                    message = nil
                }
                .disabled(store.current == .default && !isRecording)
                .fixedSize()
            }
            .fixedSize()

            if let message {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 300, alignment: .leading)
            } else if isRecording {
                Text("Use ⌘, ⌃ or ⌥ with a key (or an F-key). Esc cancels.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 300, alignment: .leading)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        message = nil
        isRecording = true
        // Release the current shortcut so pressing it again can be recorded.
        HotKeyManager.shared.pause()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        HotKeyManager.shared.resume()
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == KeyCode.escape && flags.subtracting(.capsLock).isEmpty {  // plain Esc cancels
            stopRecording()
            return
        }
        guard let combo = HotKeyCombination(event: event) else {
            message = "Add ⌘, ⌃ or ⌥ to the key, so the shortcut doesn't get in the way of typing."
            return
        }
        stopRecording()
        if combo != store.current && !HotKeyManager.shared.update(to: combo) {
            message = "\(combo.displayString) is already used by another app. Your shortcut is still \(store.current.displayString)."
        } else {
            message = nil
        }
    }
}
