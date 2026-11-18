//
//  SymbolCategory.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//

import SwiftUI

struct SymbolCategory: Identifiable {
    var id: String { key }
    let icon: String
    let key: String
    let label: String
}

/// A symbol's first SF Symbols release, e.g. "2024.3" → SF Symbols 6.3.
struct SymbolRelease: Comparable, Hashable {
    let year: Int
    let sub: Int

    init(_ string: String) {
        let parts = string.split(separator: ".")
        year = parts.first.flatMap { Int($0) } ?? 0
        sub = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
    }

    /// SF Symbols 1 shipped in 2019.
    var sfSymbolsVersion: String {
        let major = year - 2018
        return sub > 0 ? "\(major).\(sub)" : "\(major)"
    }

    static func < (a: SymbolRelease, b: SymbolRelease) -> Bool {
        (a.year, a.sub) < (b.year, b.sub)
    }
}

struct SymbolData {
    /// Symbols available on this Mac, sorted, excluding localized variants (.ar, .hi, .rtl …).
    let allSymbols: [String]
    /// Categories that have at least one available symbol.
    let categories: [SymbolCategory]
    let symbolCategoryMap: [String: Set<String>]
    let whatsNew: Set<String>
    let releases: [String: SymbolRelease]
    /// SF Symbols release key → minimum macOS version string.
    let macOSVersions: [String: String]
    /// Lowercased search terms per symbol (keywords + current/legacy aliases).
    let searchTerms: [String: [String]]
    /// Symbol → its whole family (base + fill/slash/badge/localized variants), available ones only.
    let variants: [String: [String]]

    func availabilityDescription(for symbol: String) -> String? {
        guard let release = releases[symbol] else { return nil }
        let key = release.sub > 0 ? "\(release.year).\(release.sub)" : "\(release.year)"
        let mac = macOSVersions[key].map { "macOS \($0)" } ?? "\(release.year)"
        return "Since \(mac) · SF Symbols \(release.sfSymbolsVersion)"
    }
}

private let localeSuffixes: Set<String> = [
    "ar", "hi", "rtl", "he", "zh", "th", "ja", "ko", "sat", "mni", "ml", "kn", "bn",
    "gu", "or", "mr", "te", "pa", "ta", "si", "el", "ru", "my", "km",
]

private func loadPlist(_ name: String) -> Any? {
    guard let url = Bundle.main.url(forResource: name, withExtension: "plist"),
        let data = try? Data(contentsOf: url)
    else { return nil }
    return try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
}

private func loadStrings(_ name: String) -> [String: String] {
    guard let url = Bundle.main.url(forResource: name, withExtension: "strings"),
        let dict = NSDictionary(contentsOf: url) as? [String: String]
    else { return [:] }
    return dict
}

private func isAvailable(macOS version: String?) -> Bool {
    guard let version else { return true }
    let parts = version.split(separator: ".").map { Int($0) ?? 0 }
    let required = OperatingSystemVersion(
        majorVersion: parts.count > 0 ? parts[0] : 0,
        minorVersion: parts.count > 1 ? parts[1] : 0,
        patchVersion: parts.count > 2 ? parts[2] : 0)
    return ProcessInfo.processInfo.isOperatingSystemAtLeast(required)
}

private var cachedSymbolData: SymbolData?

func loadSymbolData() -> SymbolData {
    if let cached = cachedSymbolData { return cached }

    // MARK: Availability — the full list of symbol names and when each appeared.
    var macOSVersions: [String: String] = [:]
    var releaseKeys: [String: String] = [:]
    if let root = loadPlist("name_availability") as? [String: Any] {
        releaseKeys = root["symbols"] as? [String: String] ?? [:]
        if let yearMap = root["year_to_release"] as? [String: [String: String]] {
            for (year, platforms) in yearMap { macOSVersions[year] = platforms["macOS"] }
        }
    }
    // Fall back to the older layerset file if name_availability is missing.
    if releaseKeys.isEmpty,
        let root = loadPlist("layerset_availability") as? [String: Any],
        let symbols = root["symbols"] as? [String: [String: String]]
    {
        for (name, info) in symbols { releaseKeys[name] = info["hierarchical"] ?? "" }
    }

    var available = Set<String>()
    var releases: [String: SymbolRelease] = [:]
    for (name, key) in releaseKeys {
        let mac = key.isEmpty ? nil : macOSVersions[key]
        // Unknown future releases (not in the map) are only shown if the OS can render them.
        if mac == nil && !key.isEmpty && !macOSVersions.isEmpty {
            guard NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil else { continue }
        }
        guard isAvailable(macOS: mac) else { continue }
        available.insert(name)
        if !key.isEmpty { releases[name] = SymbolRelease(key) }
    }

    func isLocalizedVariant(_ name: String) -> Bool {
        guard let dot = name.lastIndex(of: ".") else { return false }
        let suffix = String(name[name.index(after: dot)...])
        return localeSuffixes.contains(suffix) && available.contains(String(name[..<dot]))
    }

    let allSymbols = available.filter { !isLocalizedVariant($0) }.sorted()

    // MARK: Categories
    var symbolCategoryMap: [String: Set<String>] = [:]
    if let dict = loadPlist("symbol_categories") as? [String: [String]] {
        for (name, cats) in dict where available.contains(name) {
            symbolCategoryMap[name] = Set(cats)
        }
    }

    var whatsNew = Set(symbolCategoryMap.compactMap { $0.value.contains("whatsnew") ? $0.key : nil })
    if whatsNew.isEmpty, let latest = releases.values.map(\.year).max() {
        whatsNew = Set(releases.compactMap { $0.value.year == latest ? $0.key : nil })
    }

    var populated = Set(symbolCategoryMap.values.flatMap { $0 })
    populated.insert("all")
    if !whatsNew.isEmpty { populated.insert("whatsnew") }

    var categories: [SymbolCategory] = []
    if let array = loadPlist("categories") as? [[String: Any]] {
        categories = array.compactMap { item in
            guard let icon = item["icon"] as? String,
                let key = item["key"] as? String,
                let label = item["label"] as? String,
                populated.contains(key)
            else { return nil }
            let safeIcon =
                NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil
                ? icon : "square.grid.2x2"
            return SymbolCategory(icon: safeIcon, key: key, label: label)
        }
    }

    // MARK: Search terms — keywords plus current and legacy (renamed) names.
    var searchTerms: [String: [String]] = [:]
    if let dict = loadPlist("symbol_search") as? [String: [String]] {
        for (name, words) in dict where available.contains(name) {
            searchTerms[name] = words.map { $0.lowercased() }
        }
    }
    for file in ["name_aliases", "legacy_aliases"] {
        for (alias, current) in loadStrings(file) where available.contains(current) {
            searchTerms[current, default: []].append(alias.lowercased())
        }
    }

    // MARK: Variant families
    var families: [[String]] = []
    if let url = Bundle.main.url(forResource: "base_symbols_map", withExtension: "json"),
        let data = try? Data(contentsOf: url),
        let map = try? JSONDecoder().decode([String: [String]].self, from: data)
    {
        for (base, others) in map {
            families.append(([base] + others).filter { available.contains($0) })
        }
    }
    var variants: [String: [String]] = [:]
    for family in families where family.count > 1 {
        for name in family { variants[name] = family }
    }
    // Attach localized variants (e.g. "0.circle.ar") to their base's family.
    for name in available.sorted() where isLocalizedVariant(name) {
        let base = String(name[..<name.lastIndex(of: ".")!])
        var family = variants[base] ?? [base]
        family.append(name)
        for member in family { variants[member] = family }
    }

    let data = SymbolData(
        allSymbols: allSymbols,
        categories: categories,
        symbolCategoryMap: symbolCategoryMap,
        whatsNew: whatsNew,
        releases: releases,
        macOSVersions: macOSVersions,
        searchTerms: searchTerms,
        variants: variants
    )
    cachedSymbolData = data
    return data
}
