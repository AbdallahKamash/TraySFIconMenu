//
//  SymbolCategory.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//

import SwiftUI

struct SymbolCategory: Identifiable {
    let id = UUID()
    let icon: String
    let key: String
    let label: String
}

struct SymbolData {
    let allSymbols: [String]
    let categories: [SymbolCategory]
    let symbolCategoryMap: [String: [String]]
    let layerSetMap: [String: (year: Int, sub: Int)]
    let searchKeywords: [String: [String]]
    let nameAliases: [String: [String]]
}

private var cachedSymbolData: SymbolData?

func loadSymbolData() -> SymbolData {
    if let cached = cachedSymbolData { return cached }
    var allSymbols: [String] = []
    var layerSetMap: [String: (year: Int, sub: Int)] = [:]

    if let url = Bundle.main.url(forResource: "layerset_availability", withExtension: "plist"),
        let data = try? Data(contentsOf: url)
    {
        var format = PropertyListSerialization.PropertyListFormat.xml
        if let root = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: &format) as? [String: Any],
            let symbolsDict = root["symbols"] as? [String: Any]
        {
            for (symbol, info) in symbolsDict {
                allSymbols.append(symbol)
                if let infoDict = info as? [String: Any],
                    let hierarchical = infoDict["hierarchical"] as? String
                {
                    let parts = hierarchical.components(separatedBy: ".")
                    let year = Int(parts[0]) ?? 0
                    let sub = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
                    layerSetMap[symbol] = (year, sub)
                }
            }
        }
    }

    allSymbols.sort()

    var categories: [SymbolCategory] = []
    if let url = Bundle.main.url(forResource: "categories", withExtension: "plist"),
        let data = try? Data(contentsOf: url)
    {
        var format = PropertyListSerialization.PropertyListFormat.xml
        if let array = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: &format) as? [[String: Any]]
        {
            categories = array.compactMap { item in
                guard let icon = item["icon"] as? String,
                    let key = item["key"] as? String,
                    let label = item["label"] as? String
                else { return nil }
                return SymbolCategory(icon: icon, key: key, label: label)
            }
        }
    }

    var symbolCategoryMap: [String: [String]] = [:]
    if let url = Bundle.main.url(forResource: "symbol_categories", withExtension: "plist"),
        let data = try? Data(contentsOf: url)
    {
        var format = PropertyListSerialization.PropertyListFormat.xml
        if let dict = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: &format) as? [String: [String]]
        {
            symbolCategoryMap = dict
        }
    }

    var searchKeywords: [String: [String]] = [:]
    if let url = Bundle.main.url(forResource: "symbol_search", withExtension: "plist"),
        let data = try? Data(contentsOf: url)
    {
        var format = PropertyListSerialization.PropertyListFormat.xml
        if let dict = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: &format) as? [String: [String]]
        {
            searchKeywords = dict
        }
    }

    var nameAliases: [String: [String]] = [:]
    if let url = Bundle.main.url(forResource: "name_aliases", withExtension: "strings"),
        let dict = NSDictionary(contentsOf: url) as? [String: String]
    {
        for (alias, original) in dict {
            nameAliases[original, default: []].append(alias)
        }
    }

    let data = SymbolData(
        allSymbols: allSymbols,
        categories: categories,
        symbolCategoryMap: symbolCategoryMap,
        layerSetMap: layerSetMap,
        searchKeywords: searchKeywords,
        nameAliases: nameAliases
    )
    cachedSymbolData = data
    return data
}
