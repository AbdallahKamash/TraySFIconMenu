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
    /// The popover's window, so the key monitor only reacts to keys typed here.
    @State private var hostWindow: NSWindow?

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

        list = SymbolSearch.filter(list, query: query, index: data.searchIndex)

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

                            if !filtered.isEmpty {
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

            WindowReader { window in
                if hostWindow !== window { hostWindow = window }  // avoid update loops
            }
                .frame(width: 0, height: 0)

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

            // The popover is .transient, so it already closes itself when the app
            // loses focus; no need to close windows by hand here.

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

            // Install once; the guard stops duplicates if onAppear runs again.
            guard eventMonitor == nil else { return }
            self.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Only handle keys typed in the browser popover, never in Settings etc.
                guard let hostWindow, event.window === hostWindow else { return event }
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
        if let image = renderedSymbol(name) {
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

    /// The symbol drawn at 128pt (256px on Retina) in black, as a bitmap that pastes
    /// at a usable size. The bare `NSImage(systemSymbolName:)` is only ~17×16pt.
    private func renderedSymbol(_ name: String) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 128, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.black]))
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: name)?
            .withSymbolConfiguration(config)
        else { return nil }

        let size = symbol.size
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        symbol.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
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

