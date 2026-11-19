//
//  RecentSymbols.swift
//  TraySFIconMenu
//
//  Most-recently used symbols, newest first. Shared by the browser and inline insert.
//

import Foundation

enum RecentSymbols {
    private static let key = "recentSymbols"
    static let limit = 12

    static var all: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func add(_ name: String) {
        var list = all.filter { $0 != name }
        list.insert(name, at: 0)
        UserDefaults.standard.set(Array(list.prefix(limit)), forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
