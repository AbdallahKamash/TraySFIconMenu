//
//  SymbolCategory.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//
//  Loads the bundled SF Symbols metadata. Everything here is nonisolated so the
//  catalog can be built on a background thread at launch (see `preloadSymbolData`).
//

import AppKit

nonisolated struct SymbolCategory: Identifiable, Sendable {
    var id: String { key }
    let icon: String
    let key: String
    let label: String
}

/// A symbol's first SF Symbols release, e.g. "2024.3" → SF Symbols 6.3.
nonisolated struct SymbolRelease: Comparable, Hashable, Sendable {
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

nonisolated struct SymbolData: Sendable {
    /// Symbols available on this Mac, sorted, excluding localized variants (.ar, .hi, .rtl …).
    let allSymbols: [String]
    /// Categories that have at least one available symbol.
    let categories: [SymbolCategory]
    let symbolCategoryMap: [String: Set<String>]
    let whatsNew: Set<String>
    let releases: [String: SymbolRelease]
    /// SF Symbols release key → minimum macOS version string.
    let macOSVersions: [String: String]
    /// Pre-computed search data per symbol (keywords, aliases, synonyms, name parts).
    let searchIndex: SymbolSearch.Index
    /// Symbol → its whole family (base + fill/slash/badge/localized variants), available ones only.
    let variants: [String: [String]]

    func availabilityDescription(for symbol: String) -> String? {
        guard let release = releases[symbol] else { return nil }
        let key = release.sub > 0 ? "\(release.year).\(release.sub)" : "\(release.year)"
        let mac = macOSVersions[key].map { "macOS \($0)" } ?? "\(release.year)"
        return "Since \(mac) · SF Symbols \(release.sfSymbolsVersion)"
    }
}

// MARK: - Loading

/// Thread-safe, load-once cache. The first caller builds the catalog (~150 ms);
/// everyone else gets the cached copy, waiting if a build is already in progress.
nonisolated private final class SymbolDataStore: @unchecked Sendable {
    static let shared = SymbolDataStore()
    private let lock = NSLock()
    private var data: SymbolData?

    func get() -> SymbolData {
        lock.lock()
        defer { lock.unlock() }
        if let data { return data }
        let built = buildSymbolData()
        data = built
        return built
    }
}

/// Returns the symbol catalog, building it on first use.
nonisolated func loadSymbolData() -> SymbolData {
    SymbolDataStore.shared.get()
}

/// Builds the catalog in the background so opening the browser later is instant.
nonisolated func preloadSymbolData() {
    DispatchQueue.global(qos: .utility).async { _ = loadSymbolData() }
}

nonisolated private let localeSuffixes: Set<String> = [
    "ar", "hi", "rtl", "he", "zh", "th", "ja", "ko", "sat", "mni", "ml", "kn", "bn",
    "gu", "or", "mr", "te", "pa", "ta", "si", "el", "ru", "my", "km",
]

nonisolated private func loadPlist(_ name: String) -> Any? {
    guard let url = Bundle.main.url(forResource: name, withExtension: "plist"),
        let data = try? Data(contentsOf: url)
    else { return nil }
    return try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
}

nonisolated private func loadStrings(_ name: String) -> [String: String] {
    guard let url = Bundle.main.url(forResource: name, withExtension: "strings"),
        let dict = NSDictionary(contentsOf: url) as? [String: String]
    else { return [:] }
    return dict
}

nonisolated private func isAvailable(macOS version: String?) -> Bool {
    guard let version else { return true }
    let parts = version.split(separator: ".").map { Int($0) ?? 0 }
    let required = OperatingSystemVersion(
        majorVersion: parts.count > 0 ? parts[0] : 0,
        minorVersion: parts.count > 1 ? parts[1] : 0,
        patchVersion: parts.count > 2 ? parts[2] : 0)
    return ProcessInfo.processInfo.isOperatingSystemAtLeast(required)
}

nonisolated private func buildSymbolData() -> SymbolData {
    // MARK: Availability — the full list of symbol names and when each appeared.
    var macOSVersions: [String: String] = [:]
    var releaseKeys: [String: String] = [:]
    if let root = loadPlist("name_availability") as? [String: Any] {
        releaseKeys = root["symbols"] as? [String: String] ?? [:]
        if let yearMap = root["year_to_release"] as? [String: [String: String]] {
            for (year, platforms) in yearMap { macOSVersions[year] = platforms["macOS"] }
        }
    }

    var available = Set<String>()
    var releases: [String: SymbolRelease] = [:]
    for (name, key) in releaseKeys {
        let mac = macOSVersions[key]
        // Releases newer than this metadata knows about: only show what the OS can render.
        if mac == nil {
            guard NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil else { continue }
        }
        guard isAvailable(macOS: mac) else { continue }
        available.insert(name)
        releases[name] = SymbolRelease(key)
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
    // Synonyms derived from the name itself: "0.circle" → "zero", "plus" → "+", etc.
    for name in allSymbols {
        let generated = SymbolSynonyms.terms(for: name)
        if !generated.isEmpty { searchTerms[name, default: []].append(contentsOf: generated) }
    }
    let searchIndex = SymbolSearch.makeIndex(names: allSymbols, terms: searchTerms)

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

    return SymbolData(
        allSymbols: allSymbols,
        categories: categories,
        symbolCategoryMap: symbolCategoryMap,
        whatsNew: whatsNew,
        releases: releases,
        macOSVersions: macOSVersions,
        searchIndex: searchIndex,
        variants: variants
    )
}
