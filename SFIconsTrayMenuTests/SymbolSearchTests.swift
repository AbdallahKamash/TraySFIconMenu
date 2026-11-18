//
//  SymbolSearchTests.swift
//  SFIconsTrayMenuTests
//

import AppKit
import Testing
@testable import SFIconsTrayMenu

// MARK: - Synonyms

@Suite struct SymbolSynonymsTests {
    @Test(arguments: [
        (0, "zero"), (9, "nine"), (13, "thirteen"), (20, "twenty"),
        (21, "twenty one"), (100, "one hundred"), (123, "one hundred twenty three"),
    ])
    func spellsNumbers(value: Int, words: String) {
        #expect(SymbolSynonyms.spell(value) == words)
    }

    @Test func numberTermsUseValueNotDigits() {
        let terms = SymbolSynonyms.terms(for: "01.circle")
        #expect(terms.contains("one"))
        #expect(!terms.contains("zero one"))
    }

    @Test func characterAndCurrencyTerms() {
        #expect(SymbolSynonyms.terms(for: "plus.circle").contains("+"))
        #expect(SymbolSynonyms.terms(for: "dollarsign").contains("$"))
        #expect(SymbolSynonyms.terms(for: "a.circle").contains("letter a"))
        // Generic "…sign" fallback.
        #expect(SymbolSynonyms.terms(for: "parkingsign").contains("parking"))
    }

    @Test func normalizesNumberWordsInQueries() {
        #expect(SymbolSynonyms.normalizeNumberWords(["twenty", "one", "circle"]) == ["21", "circle"])
        #expect(SymbolSynonyms.normalizeNumberWords(["twentyone"]) == ["21"])
        #expect(SymbolSynonyms.normalizeNumberWords(["one", "two"]) == ["1", "2"])
        #expect(SymbolSynonyms.normalizeNumberWords(["one", "hundred", "five"]) == ["105"])
        #expect(SymbolSynonyms.normalizeNumberWords(["zero"]) == ["0"])
    }
}

// MARK: - Search

@Suite struct SymbolSearchTests {
    static let names = [
        "0.circle", "1.circle", "01.circle", "9.circle", "09.circle", "19.circle", "21.circle",
        "90.circle", "circle", "circle.fill", "plus.circle", "dollarsign", "speaker.2",
    ]

    let index: SymbolSearch.Index = {
        var terms: [String: [String]] = [:]
        for name in names { terms[name] = SymbolSynonyms.terms(for: name) }
        terms["speaker.2", default: []].append("volume.2")  // a legacy name
        return SymbolSearch.makeIndex(names: names, terms: terms)
    }()

    func search(_ query: String) -> [String] {
        SymbolSearch.filter(Self.names, query: query, index: index)
    }

    @Test func tokenizesDotsHyphensAndNumberWords() {
        #expect(SymbolSearch.tokens(from: "one.circle") == ["1", "circle"])
        #expect(SymbolSearch.tokens(from: "Twenty-One Square") == ["21", "square"])
        #expect(SymbolSearch.tokens(from: "  ") == [])
    }

    @Test(arguments: ["01.circle", "1.circle", "one circle", "one.circle"])
    func findsLeadingZeroSymbolsByValue(query: String) {
        let top = Set(search(query).prefix(2))
        #expect(top == ["1.circle", "01.circle"])
    }

    @Test func wholeNumberMatchesRankBeforePartialOnes() {
        let results = search("nine")
        #expect(Set(results.prefix(2)) == ["9.circle", "09.circle"])
        // "nineteen"/"ninety" still match while typing, just lower down.
        #expect(results.firstIndex(of: "19.circle")! > 1)
    }

    @Test func findsByCharacterAndLegacyName() {
        #expect(search("+").first == "plus.circle")
        #expect(search("$").first == "dollarsign")
        #expect(search("volume").first == "speaker.2")
    }

    @Test func prefixAndShorterNamesRankFirst() {
        #expect(Array(search("circle").prefix(2)) == ["circle", "circle.fill"])
    }

    @Test func emptyQueryReturnsEverythingAndNonsenseReturnsNothing() {
        #expect(search("") == Self.names)
        #expect(search("zzzz").isEmpty)
    }
}

// MARK: - Bundled data (loads the real metadata from the host app)

@Suite struct SymbolDataTests {
    @Test func loadsCatalogFromBundle() {
        let data = loadSymbolData()
        #expect(data.allSymbols.count > 5000)
        #expect(data.categories.first?.key == "all")
        // Localized variants are hidden from the grid…
        #expect(!data.allSymbols.contains("0.circle.ar"))
        // …but reachable through the variants menu.
        #expect(data.variants["0.circle"]?.contains("0.circle.ar") == true)
        #expect(data.availabilityDescription(for: "star.fill")?.contains("SF Symbols 1") == true)
    }

    @Test func realSearchFindsZeroCircle() {
        let data = loadSymbolData()
        let results = SymbolSearch.filter(data.allSymbols, query: "zero", index: data.searchIndex)
        #expect(results.first == "0.circle")
    }
}

// MARK: - Shortcut

@Suite @MainActor struct HotKeyCombinationTests {
    func event(_ keyCode: UInt16, _ chars: String, _ flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
            context: nil, characters: chars, charactersIgnoringModifiers: chars, isARepeat: false,
            keyCode: keyCode)!
    }

    @Test func defaultIsShiftCommandT() {
        #expect(HotKeyCombination.default.displayString == "⇧⌘T")
    }

    @Test func acceptsRealShortcuts() {
        #expect(HotKeyCombination(event: event(49, " ", .option))?.displayString == "⌥Space")
        #expect(HotKeyCombination(event: event(1, "s", .control))?.displayString == "⌃S")
        #expect(HotKeyCombination(event: event(97, "", []))?.displayString == "F6")
    }

    @Test func rejectsKeysThatWouldBlockTyping() {
        #expect(HotKeyCombination(event: event(17, "t", [])) == nil)
        #expect(HotKeyCombination(event: event(17, "t", .shift)) == nil)
    }
}
