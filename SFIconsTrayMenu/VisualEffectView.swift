//
//  VisualEffectView.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//

import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Reports the NSWindow a SwiftUI view lives in.
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onWindow(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onWindow(nsView.window) }
    }
}

extension View {
    func onKeyDown(focused: Binding<Bool>? = nil, perform action: @escaping (NSEvent) -> Void)
        -> some View
    {
        self.background(KeyDownView(focused: focused, action: action))
    }
}

struct KeyDownView: NSViewRepresentable {
    var focused: Binding<Bool>?
    let action: (NSEvent) -> Void

    func makeNSView(context: Context) -> FocusableView {
        let view = FocusableView()
        view.action = action
        return view
    }

    func updateNSView(_ view: FocusableView, context: Context) {
        // Keep the handler current: it captures the SwiftUI view's latest values.
        view.action = action
        guard focused?.wrappedValue == true else { return }
        DispatchQueue.main.async {
            if let window = view.window, window.firstResponder !== view {
                window.makeFirstResponder(view)
            }
        }
    }
}

final class FocusableView: NSView {
    var action: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        action?(event)
    }
}

extension View {
    /// Runs `action` once a second for as long as the view is on screen. Used to notice
    /// changes made outside the app, such as the Accessibility switch in System Settings.
    func everySecond(_ action: @escaping @MainActor () -> Void) -> some View {
        task {
            while true {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                action()
            }
        }
    }
}
