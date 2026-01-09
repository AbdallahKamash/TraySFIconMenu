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

    func makeNSView(context: Context) -> NSView {
        let view = FocusableView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let focused = focused, let view = nsView as? FocusableView {
            if focused.wrappedValue {
                DispatchQueue.main.async {
                    if let window = view.window, window.firstResponder != view {
                        window.makeFirstResponder(view)
                    }
                }
            }
        }
    }
}

class FocusableView: NSView {
    var action: ((NSEvent) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        action?(event)
    }

    override func resignFirstResponder() -> Bool {
        return true
    }
}
