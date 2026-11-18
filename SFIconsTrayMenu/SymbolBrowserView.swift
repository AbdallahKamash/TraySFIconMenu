//
//  SymbolBrowserView.swift
//  TraySFIconMenu
//
//  Created by Abdallah Kamash on 5/1/2026.
//

import SwiftUI

struct SymbolBrowserView: View {
    @State private var query = ""
    @State private var symbolData: SymbolData? = nil
    @State private var categories: [SymbolCategory] = []
    @State private var selectedCategory = "all"
    @State private var filtered: [String] = []

    @FocusState private var searchFieldFocused: Bool
    @FocusState private var isSidebarFocused: Bool
    @State private var isGridFocused = false

    @State private var selectedSymbolIndex: Int? = nil
    @State private var showCopyToast = false
    @State private var copiedSymbolName = ""
    @State private var eventMonitor: Any?
    @State private var scrollToTopID = UUID()

    @State private var resignActiveObserver: NSObjectProtocol? = nil

    private let columnsCount = 4
    private let columnWidth: CGFloat = 80
    private let columnSpacing: CGFloat = 16

    private var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(columnWidth), spacing: columnSpacing), count: columnsCount)
    }

    private func refilter() {
        guard let data = symbolData else { filtered = []; return }
        var list = data.allSymbols

        switch selectedCategory {
        case "all": break
        case "whatsnew": list = list.filter { data.whatsNew.contains($0) }
        default: list = list.filter { data.symbolCategoryMap[$0]?.contains(selectedCategory) ?? false }
        }

        let tokens = query.lowercased().split(whereSeparator: { $0 == " " }).map(String.init)
        if !tokens.isEmpty {
            // Every token must match the name or a keyword/alias. Name matches rank first.
            var nameHits: [String] = []
            var termHits: [String] = []
            for name in list {
                let terms = data.searchTerms[name] ?? []
                var allInName = true
                var allMatch = true
                for token in tokens {
                    if name.contains(token) { continue }
                    allInName = false
                    if !terms.contains(where: { $0.contains(token) }) { allMatch = false; break }
                }
                if allInName { nameHits.append(name) } else if allMatch { termHits.append(name) }
            }
            let joined = tokens.joined(separator: ".")
            nameHits.sort { a, b in
                let ap = a.hasPrefix(joined), bp = b.hasPrefix(joined)
                if ap != bp { return ap }
                if ap && a.count != b.count { return a.count < b.count }
                return a < b
            }
            list = nameHits + termHits
        }

        filtered = list
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
                    refilter()
                    scrollToTopID = UUID()
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
                            refilter()
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
                                    .contextMenu {
                                        symbolContextMenu(name)
                                    }
                                }
                            }
                            .padding(12)
                        }
                        .overlay {
                            if filtered.isEmpty && symbolData != nil {
                                Text("No symbols match “\(query)”")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onChange(of: scrollToTopID) { _,_ in
                            if !filtered.isEmpty {
                                withAnimation {
                                    proxy.scrollTo(0, anchor: .top)
                                }
                            }
                        }
                        .onKeyDown(focused: $isGridFocused) { event in
                            handleGridKeyboard(event, scrollProxy: proxy)
                        }
                    }

                    Divider()
                    HStack {
                        Text("\(filtered.count) symbols")
                        Spacer()
                        if let index = selectedSymbolIndex, index < filtered.count,
                            let since = symbolData?.availabilityDescription(for: filtered[index])
                        {
                            Text(since)
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
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
            self.query = ""
            self.scrollToTopID = UUID()
            self.isGridFocused = false

            // Observe when app resigns active to dismiss window automatically
            resignActiveObserver = NotificationCenter.default.addObserver(forName: NSApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
                closeKeyWindow()
            }

            let data = loadSymbolData()
            self.symbolData = data
            self.categories = data.categories
            if !data.categories.contains(where: { $0.key == selectedCategory }) {
                self.selectedCategory = "all"
            }
            refilter()

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
            if let obs = resignActiveObserver {
                NotificationCenter.default.removeObserver(obs)
                resignActiveObserver = nil
            }
        }
    }

    @ViewBuilder
    private func symbolContextMenu(_ name: String) -> some View {
        Button("Copy Name") { copySymbol(name) }
        Button("Copy Icon") { copyIcon(name) }
        if let family = symbolData?.variants[name], family.count > 1 {
            Menu("Variants") {
                ForEach(family, id: \.self) { variant in
                    Button {
                        copySymbol(variant)
                    } label: {
                        Label(variant, systemImage: variant)
                    }
                }
            }
        }
        if let since = symbolData?.availabilityDescription(for: name) {
            Divider()
            Text(since)
        }
    }

    private func copyIcon(_ name: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            pb.writeObjects([image])
        }

        copiedSymbolName = name
        withAnimation { showCopyToast = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedSymbolName == name {
                withAnimation { showCopyToast = false }
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

    private func closeKeyWindow() {
        if let window = NSApp.keyWindow {
            window.close()
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

