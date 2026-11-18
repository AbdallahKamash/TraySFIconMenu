//
//  SymbolSynonyms.swift
//  TraySFIconMenu
//
//  Extra search terms derived from a symbol's name, so it can be found by
//  whatever "points at" it: "zero" finds "0.circle", "+" finds "plus.app",
//  "dollar" finds "dollarsign", "letter a" finds "a.circle", and so on.
//

import Foundation

enum SymbolSynonyms {

    /// Returns lowercased search terms for a symbol name such as "0.circle" or "plus.square".
    static func terms(for name: String) -> [String] {
        var terms: [String] = []
        for part in name.split(separator: ".").map(String.init) {
            if part.allSatisfy(\.isNumber) {
                terms += numberTerms(part)
            } else if part.count == 1, let c = part.first, c.isLetter {
                terms += ["letter", "letter \(part)", "character"]
            } else if let extra = characterTerms[part] {
                terms += extra
            } else if part.count > 4, part.hasSuffix("sign") {
                // "dollarsign" → "dollar", "rupeesign" → "rupee", "parkingsign" → "parking".
                terms.append(String(part.dropLast(4)))
            } else if part.count > 4, part.hasSuffix("mark") {
                terms.append(String(part.dropLast(4)))
            }
        }
        return terms
    }

    // MARK: - Numbers

    private static let ones = [
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
        "seventeen", "eighteen", "nineteen",
    ]
    private static let tens = [
        "", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety",
    ]

    /// 0...999 spelled out, e.g. 21 → "twenty one", 100 → "one hundred".
    static func spell(_ n: Int) -> String {
        switch n {
        case 0..<20: return ones[n]
        case 20..<100: return n % 10 == 0 ? tens[n / 10] : "\(tens[n / 10]) \(ones[n % 10])"
        case 100..<1000:
            let rest = n % 100
            return rest == 0 ? "\(ones[n / 100]) hundred" : "\(ones[n / 100]) hundred \(spell(rest))"
        default: return String(n)
        }
    }

    /// Number components are matched by value at search time ("1", "01", "one" all find
    /// "01.circle"), so the terms here only help partial typing like "thir" → 13 / 30s.
    private static func numberTerms(_ digits: String) -> [String] {
        var terms = ["number", "digit", "numeral"]
        if let value = Int(digits), value < 1000 {
            let words = spell(value)
            terms.append(words)
            if words.contains(" ") {
                terms.append(words.replacingOccurrences(of: " ", with: "-"))
                terms.append(words.replacingOccurrences(of: " ", with: ""))
            }
        }
        return terms
    }

    // MARK: - Number words in a query

    private enum NumberWordKind { case unit, teen, ten, hundred }

    private static func numberWord(_ word: String) -> (value: Int, kind: NumberWordKind)? {
        if word == "hundred" { return (100, .hundred) }
        if word == "nought" { return (0, .unit) }
        if let i = ones.firstIndex(of: word) { return (i, i < 10 ? .unit : .teen) }
        if let i = tens.firstIndex(of: word), i >= 2 { return (i * 10, .ten) }
        return nil
    }

    /// "twentyone" → ["twenty", "one"]; other words unchanged.
    private static func splitJoinedNumber(_ word: String) -> [String] {
        for i in 2..<tens.count where word.hasPrefix(tens[i]) && word.count > tens[i].count {
            let rest = String(word.dropFirst(tens[i].count))
            if let u = ones.firstIndex(of: rest), u > 0, u < 10 { return [tens[i], rest] }
        }
        return [word]
    }

    /// Replaces runs of number words with digits: ["twenty", "one", "circle"] → ["21", "circle"],
    /// ["one", "two"] → ["1", "2"], ["zero"] → ["0"].
    static func normalizeNumberWords(_ tokens: [String]) -> [String] {
        var out: [String] = []
        var current: Int? = nil
        var last: NumberWordKind? = nil

        func flush() {
            if let c = current { out.append(String(c)) }
            current = nil
            last = nil
        }

        for token in tokens.flatMap(splitJoinedNumber) {
            guard let (value, kind) = numberWord(token) else {
                flush()
                out.append(token)
                continue
            }
            let fits: Bool
            switch kind {
            case .unit, .teen, .ten: fits = last == nil || last == .hundred || (kind == .unit && last == .ten && value > 0)
            case .hundred: fits = last == .unit && (current ?? 0) > 0
            }
            if !fits { flush() }
            if kind == .hundred {
                current = (current ?? 1) * 100
            } else {
                current = (current ?? 0) + value
            }
            last = kind
        }
        flush()
        return out
    }

    // MARK: - Characters and signs

    private static let characterTerms: [String: [String]] = [
        "plus": ["+", "add", "positive"],
        "minus": ["-", "−", "subtract", "negative", "dash"],
        "multiply": ["×", "*", "times", "x"],
        "divide": ["÷", "/", "division"],
        "equal": ["=", "equals"],
        "notequal": ["≠", "not equal"],
        "lessthan": ["<", "less than"],
        "greaterthan": [">", "greater than"],
        "percent": ["%", "percentage"],
        "number": ["#", "hash", "hashtag", "pound"],
        "at": ["@"],
        "asterisk": ["*", "star"],
        "ampersand": ["&", "and"],
        "exclamationmark": ["!", "exclamation", "bang", "warning"],
        "questionmark": ["?", "question", "help"],
        "checkmark": ["✓", "✔", "check", "tick", "done"],
        "xmark": ["×", "✕", "x", "close", "cross", "cancel"],
        "degreesign": ["°", "degree", "degrees"],
        "dollarsign": ["$", "dollar", "usd"],
        "centsign": ["¢", "cent"],
        "eurosign": ["€", "euro", "eur"],
        "eurozonesign": ["euro", "eurozone"],
        "sterlingsign": ["£", "pound", "sterling", "gbp"],
        "yensign": ["¥", "yen", "jpy"],
        "chineseyuanrenminbisign": ["¥", "yuan", "renminbi", "rmb", "cny"],
        "wonsign": ["₩", "won", "krw"],
        "rupeesign": ["₨", "rupee"],
        "indianrupeesign": ["₹", "rupee", "inr"],
        "bitcoinsign": ["₿", "bitcoin", "btc", "crypto"],
        "rublesign": ["₽", "ruble", "rouble", "rub"],
        "turkishlirasign": ["₺", "lira", "try"],
        "lirasign": ["₤", "lira"],
        "shekelsign": ["₪", "shekel", "ils"],
        "pesosign": ["₱", "peso"],
        "nairasign": ["₦", "naira"],
        "bahtsign": ["฿", "baht"],
        "dongsign": ["₫", "dong"],
        "hryvniasign": ["₴", "hryvnia"],
        "francsign": ["₣", "franc"],
        "brazilianrealsign": ["r$", "real", "brl"],
        "australiandollarsign": ["a$", "aud", "dollar"],
        "singaporedollarsign": ["s$", "sgd", "dollar"],
    ]
}

// MARK: - Search

enum SymbolSearch {

    /// Splits a query on spaces, dots and word-hyphens, then turns number words into digits.
    /// "one.circle" → ["1", "circle"], "Twenty-One Square" → ["21", "square"].
    static func tokens(from query: String) -> [String] {
        let raw = query.lowercased()
            .split(whereSeparator: { $0 == " " || $0 == "." })
            .flatMap { word -> [String] in
                let parts = word.split(separator: "-").map(String.init)
                // Only split "twenty-one"-style words; keep "-" itself searchable (minus).
                return parts.count > 1 && parts.allSatisfy({ $0.allSatisfy(\.isLetter) })
                    ? parts : [String(word)]
            }
        return SymbolSynonyms.normalizeNumberWords(raw)
    }

    /// How well one query token matches a symbol: 0 = no match, higher is better.
    private static func level(of token: String, components: [String], name: String, terms: [String]) -> Int {
        if let value = Int(token), token.allSatisfy(\.isNumber) {
            // Numbers compare by value: "1" and "01" both match "01.circle" and "1.circle".
            if components.contains(where: { $0.allSatisfy(\.isNumber) && Int($0) == value }) { return 4 }
            return name.contains(token) ? 1 : 0
        }
        if components.contains(token) { return 4 }
        if terms.contains(where: { $0 == token || $0.split(separator: " ").contains(Substring(token)) }) { return 4 }
        if components.contains(where: { $0.hasPrefix(token) }) { return 3 }
        if name.contains(token) { return 2 }
        if terms.contains(where: { $0.contains(token) }) { return 1 }
        return 0
    }

    /// Strips leading zeros from number components: "01.circle" → "1.circle".
    private static func canonical(_ components: [String]) -> String {
        components.map { c in
            c.count > 1 && c.allSatisfy(\.isNumber) ? String(Int(c) ?? 0) : c
        }.joined(separator: ".")
    }

    static func filter(_ list: [String], query: String, terms: [String: [String]]) -> [String] {
        let tokens = tokens(from: query)
        guard !tokens.isEmpty else { return list }
        let prefix = tokens.joined(separator: ".")

        struct Hit { let name: String; let minLevel: Int; let total: Int; let prefix: Bool }
        var hits: [Hit] = []
        for name in list {
            let components = name.split(separator: ".").map(String.init)
            let symbolTerms = terms[name] ?? []
            var minLevel = Int.max
            var total = 0
            for token in tokens {
                let l = level(of: token, components: components, name: name, terms: symbolTerms)
                if l == 0 { minLevel = 0; break }
                minLevel = min(minLevel, l)
                total += l
            }
            guard minLevel > 0 else { continue }
            let isPrefix = name.hasPrefix(prefix) || canonical(components).hasPrefix(prefix)
            hits.append(Hit(name: name, minLevel: minLevel, total: total, prefix: isPrefix))
        }

        hits.sort { a, b in
            if a.minLevel != b.minLevel { return a.minLevel > b.minLevel }
            if a.prefix != b.prefix { return a.prefix }
            if a.total != b.total { return a.total > b.total }
            if a.name.count != b.name.count { return a.name.count < b.name.count }
            return a.name < b.name
        }
        return hits.map(\.name)
    }
}
