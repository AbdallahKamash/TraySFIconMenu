//
//  AboutView.swift
//  TraySFIconMenu
//
//  Custom About window: what the app is, who made it, and where to find it.
//

import SwiftUI

enum AppInfo {
    static let name = "TraySFIconMenu"
    static let developer = "Abdallah Kamash"
    static let githubUser = "AbdallahKamash"
    static let githubProfile = URL(string: "https://github.com/AbdallahKamash")!
    static let repository = URL(string: "https://github.com/AbdallahKamash/TraySFIconMenu")!
    static let issues = URL(string: "https://github.com/AbdallahKamash/TraySFIconMenu/issues")!

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }
}

struct AboutView: View {
    @State private var symbolCount: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 34)
                .padding(.bottom, 20)

            Divider().padding(.horizontal, 28)

            highlights
                .padding(.horizontal, 32)
                .padding(.vertical, 18)

            Divider().padding(.horizontal, 28)

            developer
                .padding(.horizontal, 32)
                .padding(.vertical, 18)

            Spacer(minLength: 0)

            Text("SF Symbols are provided by Apple and subject to Apple's license terms.\nTraySFIconMenu is an independent project and is not affiliated with Apple.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.bottom, 18)
        }
        .frame(width: 400, height: 560)
        .background(VisualEffectView(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea())
        .onAppear {
            // Cached after the first load, so this is instant once the browser has been opened.
            symbolCount = loadSymbolData().allSymbols.count
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            AppGlyph(size: 84)
            Text(AppInfo.name)
                .font(.system(size: 20, weight: .bold))
            Text(AppInfo.version)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("Every SF Symbol, one click away in your menu bar.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 10) {
            Highlight(
                icon: "square.grid.3x3",
                text: symbolCount.map { "Browse \($0.formatted()) symbols across Apple's categories" }
                    ?? "Browse the full SF Symbols catalog by category")
            Highlight(icon: "magnifyingglass", text: "Search by name, keyword, or words like “one circle”")
            Highlight(icon: "doc.on.doc", text: "Copy names or icon images, including variants")
            Highlight(icon: "keyboard", text: "Open from anywhere with \(HotKeyManager.shared.current.displayString)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var developer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Made by \(AppInfo.developer)")
                        .font(.system(size: 13, weight: .semibold))
                    Link("github.com/\(AppInfo.githubUser)", destination: AppInfo.githubProfile)
                        .font(.system(size: 12))
                }
                Spacer()
            }

            HStack(spacing: 8) {
                LinkButton(title: "Source Code", icon: "chevron.left.forwardslash.chevron.right",
                           url: AppInfo.repository)
                LinkButton(title: "Report an Issue", icon: "exclamationmark.bubble",
                           url: AppInfo.issues)
                LinkButton(title: "Star on GitHub", icon: "star", url: AppInfo.repository)
            }
        }
    }
}

private struct Highlight: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 12))
        }
    }
}

private struct LinkButton: View {
    let title: String
    let icon: String
    let url: URL
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(url)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 14))
                Text(title).font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .help(url.absoluteString)
    }
}
