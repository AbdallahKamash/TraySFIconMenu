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
    @AppStorage(InlineInsertPreferences.Key.enabled) private var inlineEnabled = true
    @State private var accessibilityTrusted = Accessibility.isTrusted

    private let pageCount = 5

    /// `startPage` lets the tour open at a given page (e.g. straight to Inline Insert setup).
    init(startPage: Int = 0, onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        _page = State(initialValue: startPage)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch page {
                case 0: welcomePage
                case 1: openPage
                case 2: copyPage
                case 3: inlinePage
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
        .frame(width: 460, height: 460)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea())
        // Picks up the Accessibility switch as soon as it's turned on in System Settings.
        .everySecond {
            if accessibilityTrusted != Accessibility.isTrusted { accessibilityTrusted = Accessibility.isTrusted }
        }
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

    private var inlinePage: some View {
        VStack(spacing: 14) {
            Text("Insert while you code")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 30)

            InlineInsertMock()
                .padding(.horizontal, 44)

            Text("In a Swift file in Xcode, VS Code or Cursor, press \(shortcut.current.displayString) to search right at your text cursor. Return types the symbol into your code.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)

            VStack(spacing: 0) {
                SetupRow(number: 1, title: "Turn on inline insert",
                         detail: "You can switch it off any time in Settings.") {
                    Toggle("", isOn: $inlineEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                Divider().padding(.leading, 44)
                SetupRow(number: 2, title: "Allow Accessibility access",
                         detail: "Lets the app find your cursor and type for you. Nothing leaves your Mac.") {
                    if accessibilityTrusted {
                        Label("Allowed", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.green)
                            .font(.system(size: 12, weight: .medium))
                    } else {
                        Button("Allow Access…") { Accessibility.requestAccess() }
                            .controlSize(.small)
                    }
                }
                .opacity(inlineEnabled ? 1 : 0.45)
                .disabled(!inlineEnabled)
            }
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 36)

            Text("Choose editors, files and insert style in Settings → Inline Insert.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
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

/// A tiny illustration: a line of code with the inline panel open under the cursor.
private struct InlineInsertMock: View {
    private let rows = ["star.fill", "star", "star.circle.fill"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 0) {
                Text("Image").foregroundStyle(.purple)
                Text("(systemName: ")
                Text("\"").foregroundStyle(.red)
                Rectangle().fill(Color.accentColor).frame(width: 1.5, height: 14)
                Text("\")").foregroundStyle(.red)
            }
            .font(.system(size: 12, design: .monospaced))

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill").frame(width: 16)
                    Text("\(Text("star").foregroundStyle(.primary))\(Text(".fill").foregroundStyle(.tertiary))")
                }
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 8)
                .frame(height: 24)
                Divider().padding(.horizontal, 6)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, symbol in
                    HStack(spacing: 6) {
                        Image(systemName: symbol).frame(width: 16)
                        Text(symbol)
                        Spacer()
                        if index == 0 { Text("↩").font(.system(size: 9)).opacity(0.75) }
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(index == 0 ? .white : .primary)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(index == 0 ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .padding(.horizontal, 4)
            }
            .padding(.bottom, 4)
            .frame(width: 190)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.leading, 120)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.primary.opacity(0.1)))
    }
}

/// A numbered setup step with a control on the right.
private struct SetupRow<Control: View>: View {
    let number: Int
    let title: String
    let detail: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
