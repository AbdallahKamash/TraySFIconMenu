//
//  SymbolBrowserView.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//

import SwiftUI

struct SymbolBrowserView: View {
    @State private var query = ""
    @State private var symbols: [String] = []
    @State private var categories: [SymbolCategory] = []
    @State private var selectedCategory = "all"
    @State private var symbolCategoryMap: [String: [String]] = [:]
    @State private var layerSetMap: [String: (year: Int, sub: Int)] = [:]
    @State private var searchKeywords: [String: [String]] = [:]
    @State private var nameAliases: [String: [String]] = [:]

    @FocusState private var searchFieldFocused: Bool
    @FocusState private var isSidebarFocused: Bool
    @State private var isGridFocused = false

    @State private var selectedSymbolIndex: Int? = nil
    @State private var showCopyToast = false
    @State private var copiedSymbolName = ""
    @State private var eventMonitor: Any?

    private let columnsCount = 4
    private let columnWidth: CGFloat = 80
    private let columnSpacing: CGFloat = 16

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(columnWidth), spacing: columnSpacing), count: columnsCount)
    }

    private var filtered: [String] {
        var list = symbols

        if selectedCategory != "all" {
            if selectedCategory == "whatsnew" {
                let sortedReleases = layerSetMap.values
                    .sorted { a, b in
                        if a.year == b.year { return a.sub > b.sub }
                        return a.year > b.year
                    }
                let topReleases = Array(sortedReleases.prefix(2))
                list = list.filter { symbol in
                    if let release = layerSetMap[symbol] {
                        return topReleases.contains(where: { $0 == release })
                    }
                    return false
                }
            } else {
                list = list.filter { symbolCategoryMap[$0]?.contains(selectedCategory) ?? false }
            }
        }

        if !query.isEmpty {
            list = list.filter { name in
                let nameMatch = name.localizedCaseInsensitiveContains(query)
                let keywordMatch =
                    searchKeywords[name]?.contains(where: {
                        $0.localizedCaseInsensitiveContains(query)
                    }) ?? false
                let aliasMatch =
                    nameAliases[name]?.contains(where: {
                        $0.localizedCaseInsensitiveContains(query)
                    }) ?? false
                return nameMatch || keywordMatch || aliasMatch
            }
        }

        return list
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                
                List(categories, selection: $selectedCategory) { cat in
                    HStack(spacing: 8) {
                        Image(systemName: cat.icon)
                            .frame(width: 18, height: 18)
                        Text(cat.label)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(.vertical, 4)
                    .tag(cat.key)
                }
                .listStyle(.sidebar)
                .frame(width: 160)
                .focused($isSidebarFocused)
                .onChange(of: selectedCategory) { _, _ in
                    selectedSymbolIndex = nil
                }

                Divider()

                
                VStack(spacing: 0) {
                    
                    TextField("Search SF Symbols", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .padding([.horizontal, .top], 12)
                        .padding(.bottom, 8)
                        .focused($searchFieldFocused)
                        .onChange(of: query) { _, _ in
                            selectedSymbolIndex = nil
                        }
                        .onSubmit {
                            
                            if let count = filtered.count as Int?, count > 0 {
                                searchFieldFocused = false
                                isGridFocused = true
                                selectedSymbolIndex = 0
                            }
                        }

                    ScrollViewReader { proxy in
                        ScrollView([.vertical]) {
                            LazyVGrid(columns: columns, spacing: 20) {
                                ForEach(Array(filtered.enumerated()), id: \.offset) { index, name in
                                    SymbolCell(
                                        name: name,
                                        isSelected: selectedSymbolIndex == index
                                    ) {
                                        searchFieldFocused = false
                                        isGridFocused = true
                                        selectedSymbolIndex = index
                                    }
                                    .id(index)
                                }
                            }
                            .padding(12)
                        }
                        .onKeyDown(focused: $isGridFocused) { event in
                            handleGridKeyboard(event, scrollProxy: proxy)
                        }
                    }
                }
            }

            if showCopyToast {
                VStack {
                    Spacer()
                    Text("Copied: \(copiedSymbolName)")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                                .cornerRadius(8)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8).stroke(
                                Color.primary.opacity(0.1), lineWidth: 0.5)
                        )
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(), value: showCopyToast)
            }
        }
        .onAppear {
            let data = loadSymbolData()
            self.symbols = data.allSymbols
            self.categories = data.categories
            self.symbolCategoryMap = data.symbolCategoryMap
            self.layerSetMap = data.layerSetMap
            self.searchKeywords = data.searchKeywords
            self.nameAliases = data.nameAliases

            self.selectedSymbolIndex = nil

            DispatchQueue.main.async {
                self.searchFieldFocused = true
            }

            
            self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if searchFieldFocused {
                    if event.keyCode == 125 || event.keyCode == 48 {  
                        if !filtered.isEmpty {
                            searchFieldFocused = false
                            isGridFocused = true
                            selectedSymbolIndex = 0
                            return nil  
                        }
                    }
                } else if isSidebarFocused {
                    if event.keyCode == 48 {  
                        isSidebarFocused = false
                        searchFieldFocused = true
                        return nil  
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
    }

    private func copySymbol(_ name: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(name, forType: .string)

        copiedSymbolName = name
        withAnimation { showCopyToast = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedSymbolName == name {
                withAnimation { showCopyToast = false }
            }
        }
    }

    private func handleGridKeyboard(_ event: NSEvent, scrollProxy: ScrollViewProxy) {
        let count = filtered.count

        
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty,
            chars.rangeOfCharacter(from: .alphanumerics) != nil,
            !event.modifierFlags.contains(.command)
        {

            isGridFocused = false
            searchFieldFocused = true
            selectedSymbolIndex = nil
            query += chars
            return
        }

        
        if event.keyCode == 48 {  
            selectedSymbolIndex = nil
            isGridFocused = false
            isSidebarFocused = true
            return
        }

        guard count > 0 else { return }

        var nextIndex = selectedSymbolIndex ?? 0

        
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "c" {
            if nextIndex < count {
                copySymbol(filtered[nextIndex])
            }
            return
        }

        switch event.keyCode {
        case 123:  
            nextIndex = (nextIndex <= 0) ? count - 1 : nextIndex - 1
        case 124:  
            nextIndex = (nextIndex >= count - 1) ? 0 : nextIndex + 1
        case 125:  
            let target = nextIndex + columnsCount
            if target < count {
                nextIndex = target
            } else {
                nextIndex = nextIndex % columnsCount
            }
        case 126:  
            let target = nextIndex - columnsCount
            if target >= 0 {
                nextIndex = target
            } else {
                
                searchFieldFocused = true
                isGridFocused = false
                selectedSymbolIndex = nil
                return
            }
        case 36, 49:  
            if nextIndex < count {
                copySymbol(filtered[nextIndex])
            }
            return
        default:
            return
        }

        selectedSymbolIndex = nextIndex
        scrollProxy.scrollTo(nextIndex, anchor: .center)
    }
}
