//
//  OnboardingView.swift
//  TraySFIconMenu
//
//  A short welcome tour shown on first launch (and from the "Guide" menu item).
//

import LaunchAtLogin
import SwiftUI

struct OnboardingView: View {
    /// Called when the user finishes the tour (not when they just close the window).
    var onFinish: () -> Void

    @State private var page = 0
    @State private var forward = true
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var shortcut = ShortcutStore.shared

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch page {
                case 0: welcomePage
                case 1: openPage
                case 2: copyPage
                default: finishPage
                }
            }
            .id(page)
            .transition(
                .asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            footer
        }
        .frame(width: 460, height: 420)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea())
    }

    // MARK: Pages

    private var welcomePage: some View {
        VStack(spacing: 18) {
            AppGlyph(size: 96)
                .padding(.top, 36)
            Text("Welcome to TraySFIconMenu")
                .font(.system(size: 22, weight: .bold))
            Text("Every SF Symbol, one click away.\nBrowse, search and copy without opening the SF Symbols app.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var openPage: some View {
        VStack(spacing: 18) {
            Text("It lives in your menu bar")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 36)

            MenuBarMock()
                .padding(.horizontal, 40)

            Text("Click the icon in the menu bar, or press")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(Array(shortcut.current.keyCaps.enumerated()), id: \.offset) { _, cap in
                    KeyCap(cap)
                }
            }

            Text("from any app. Right-click the icon for Settings (change the shortcut there) and Quit.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var copyPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Find & copy")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.top, 36)
                .padding(.bottom, 4)

            TipRow(icon: "magnifyingglass", title: "Search any way you like",
                   detail: "Names, keywords or words: “one circle”, “+”, “dollar”.")
            TipRow(icon: "return", title: "Copy the name",
                   detail: "Select a symbol and press Return or Space, or ⌘C.")
            TipRow(icon: "cursorarrow.click.2", title: "Right-click for more",
                   detail: "Copy the icon image, or pick a variant like .fill or .slash.")
            TipRow(icon: "arrow.up.and.down.and.arrow.left.and.right", title: "Keyboard first",
                   detail: "Arrows move around the grid, Tab switches between panes.")
            Spacer()
        }
        .padding(.horizontal, 44)
    }

    private var finishPage: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: page)
                .padding(.top, 44)
            Text("You're all set")
                .font(.system(size: 22, weight: .bold))
            Text("One last thing: should TraySFIconMenu start when you log in?")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .onChange(of: launchAtLogin) { _, newValue in
                    LaunchAtLogin.isEnabled = newValue
                }
                .padding(.top, 4)
            Spacer()
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button("Back") { go(to: page - 1) }
                .opacity(page == 0 ? 0 : 1)
                .disabled(page == 0)

            Spacer()

            HStack(spacing: 7) {
                ForEach(0..<pageCount, id: \.self) { i in
                    Circle()
                        .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 7, height: 7)
                        .onTapGesture { go(to: i) }
                }
            }

            Spacer()

            Button(page == pageCount - 1 ? "Start Using" : "Next") {
                if page == pageCount - 1 { onFinish() } else { go(to: page + 1) }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func go(to newPage: Int) {
        guard (0..<pageCount).contains(newPage), newPage != page else { return }
        forward = newPage > page
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { page = newPage }
    }
}

// MARK: - Pieces

/// The app's tray symbol on a rounded gradient tile.
struct AppGlyph: View {
    var size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(
                LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "signpost.right.fill")
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .shadow(color: .black.opacity(0.25), radius: size * 0.12, y: size * 0.05)
    }
}

private struct MenuBarMock: View {
    var body: some View {
        HStack(spacing: 14) {
            Spacer()
            Image(systemName: "signpost.right.fill")
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.bounce, options: .repeat(.periodic(delay: 1.2)))
                .padding(5)
                .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
            Image(systemName: "wifi").foregroundStyle(.secondary)
            Image(systemName: "battery.75percent").foregroundStyle(.secondary)
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            Text("9:41").foregroundStyle(.secondary)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))
    }
}

private struct KeyCap: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .frame(minWidth: 30, minHeight: 30)
            .background(.background, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.15)))
            .shadow(color: .black.opacity(0.12), radius: 0, y: 1.5)
    }
}

private struct TipRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
