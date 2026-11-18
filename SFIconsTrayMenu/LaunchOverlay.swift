//
//  LaunchOverlay.swift
//  TraySFIconMenu
//
//  A brief, click-through animation shown on launch: the app glyph pops up in the
//  middle of the screen, flies into the menu bar, and ripples on the tray icon
//  with a small caption, so the user knows where the app went.
//

import AppKit
import SwiftUI

@MainActor
enum LaunchOverlay {
    private static var panel: NSPanel?

    /// Plays the animation towards `statusItem`'s button. Safe to call repeatedly.
    static func show(for statusItem: NSStatusItem) {
        guard panel == nil else { return }

        let buttonFrame = statusItem.button?.window?.frame
        let screen =
            NSScreen.screens.first(where: { s in buttonFrame.map { s.frame.intersects($0) } ?? false })
            ?? NSScreen.main
        guard let screen else { return }

        // Target in SwiftUI coordinates (top-left origin within the screen).
        // If the item is hidden (e.g. behind the notch), aim at the right of the menu bar.
        let target: CGPoint
        if let f = buttonFrame, screen.frame.contains(CGPoint(x: f.midX, y: f.midY)) {
            target = CGPoint(x: f.midX - screen.frame.minX, y: screen.frame.maxY - f.midY)
        } else {
            let menuBarHeight = screen.frame.maxY - screen.visibleFrame.maxY
            target = CGPoint(x: screen.frame.width - 120, y: max(menuBarHeight, 24) / 2)
        }

        let p = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.isReleasedWhenClosed = false
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let view = LaunchOverlayView(
            screenSize: screen.frame.size,
            target: target,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        ) {
            panel?.orderOut(nil)
            panel = nil
        }
        let host = NSHostingView(rootView: view)
        host.frame = CGRect(origin: .zero, size: screen.frame.size)
        p.contentView = host
        p.setFrame(screen.frame, display: true)
        p.orderFrontRegardless()
        panel = p
    }
}

private struct LaunchOverlayView: View {
    let screenSize: CGSize
    let target: CGPoint
    let reduceMotion: Bool
    let onFinish: () -> Void

    @State private var glyphPosition: CGPoint
    @State private var glyphScale: CGFloat = 0.5
    @State private var glyphOpacity: Double = 0
    @State private var rippleScale: CGFloat = 0.6
    @State private var rippleOpacity: Double = 0
    @State private var captionVisible = false

    init(screenSize: CGSize, target: CGPoint, reduceMotion: Bool, onFinish: @escaping () -> Void) {
        self.screenSize = screenSize
        self.target = target
        self.reduceMotion = reduceMotion
        self.onFinish = onFinish
        _glyphPosition = State(initialValue: CGPoint(x: screenSize.width / 2, y: screenSize.height * 0.42))
    }

    /// Caption sits under the tray icon, kept fully on screen.
    private var captionPosition: CGPoint {
        let halfWidth: CGFloat = 150
        let x = min(max(target.x, halfWidth + 12), screenSize.width - halfWidth - 12)
        return CGPoint(x: x, y: target.y + 50)
    }

    var body: some View {
        ZStack {
            // Ripple rings on the tray icon.
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .stroke(Color.accentColor, lineWidth: 2.5)
                    .frame(width: 34, height: 34)
                    .scaleEffect(rippleScale + CGFloat(i) * 0.6)
                    .opacity(rippleOpacity * (i == 0 ? 1 : 0.6))
                    .position(target)
            }

            AppGlyph(size: 120)
                .scaleEffect(glyphScale)
                .opacity(glyphOpacity)
                .position(glyphPosition)

            caption
                .opacity(captionVisible ? 1 : 0)
                .offset(y: captionVisible ? 0 : -8)
                .position(captionPosition)
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .onAppear(perform: run)
    }

    private var caption: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("TraySFIconMenu is running")
                    .font(.system(size: 12, weight: .semibold))
                Text("Click the icon or press \(HotKeyManager.shared.current.displayString)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(Capsule())
        )
        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .fixedSize()
    }

    private func after(_ seconds: Double, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: action)
    }

    private func run() {
        if reduceMotion {
            // No movement: just fade the caption and a static ring in and out.
            withAnimation(.easeOut(duration: 0.3)) {
                captionVisible = true
                rippleScale = 1.2
                rippleOpacity = 0.8
            }
            after(2.2) {
                withAnimation(.easeIn(duration: 0.4)) {
                    captionVisible = false
                    rippleOpacity = 0
                }
            }
            after(2.7, onFinish)
            return
        }

        // 1. Pop in at the centre.
        withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
            glyphScale = 1
            glyphOpacity = 1
        }
        // 2. Fly up into the menu bar, shrinking to icon size.
        after(0.6) {
            withAnimation(.timingCurve(0.6, 0, 0.2, 1, duration: 0.55)) {
                glyphPosition = target
                glyphScale = 0.16
            }
        }
        // 3. Land: fade the glyph, ripple the tray icon, show the caption.
        after(1.12) {
            withAnimation(.easeOut(duration: 0.15)) { glyphOpacity = 0 }
            rippleOpacity = 0.9
            withAnimation(.easeOut(duration: 0.9)) {
                rippleScale = 2.4
                rippleOpacity = 0
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { captionVisible = true }
        }
        // Second, softer ripple.
        after(1.6) {
            rippleScale = 0.6
            rippleOpacity = 0.6
            withAnimation(.easeOut(duration: 0.9)) {
                rippleScale = 2.4
                rippleOpacity = 0
            }
        }
        // 4. Fade out the caption and tear down.
        after(3.2) {
            withAnimation(.easeIn(duration: 0.35)) { captionVisible = false }
        }
        after(3.7, onFinish)
    }
}
