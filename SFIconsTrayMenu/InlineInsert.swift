//
//  InlineInsert.swift
//  TraySFIconMenu
//
//  A small one-line symbol autocomplete that opens at the text cursor in Xcode or
//  VS Code (in a .swift file) and types the chosen symbol straight into the code.
//
//  Keys: type to search · Tab completes · ↑↓ choose · Return inserts ·
//        ⌥Return inserts Image(systemName:) · Esc cancels
//

import AppKit
import Combine
import SwiftUI

// MARK: - Model

final class InlineInsertModel: ObservableObject {
    static let maxRows = 6

    @Published var query = "" { didSet { if query != oldValue { refilter() } } }
    @Published private(set) var rows: [String] = []
    @Published var selection = 0

    let context: EditorContext
    let totalSymbols: Int
    private let data: SymbolData
    private let recents: [String]

    var showingRecents: Bool { query.trimmingCharacters(in: .whitespaces).isEmpty }
    var selectedSymbol: String? { rows.indices.contains(selection) ? rows[selection] : nil }

    /// The grey rest-of-the-name shown after what you typed, e.g. "star" → ".fill".
    var completionSuffix: String {
        guard !query.isEmpty, let symbol = selectedSymbol,
            symbol.lowercased().hasPrefix(query.lowercased()), symbol.count > query.count
        else { return "" }
        return String(symbol.dropFirst(query.count))
    }

    init(context: EditorContext) {
        self.context = context
        self.data = loadSymbolData()
        self.totalSymbols = data.allSymbols.count
        let available = Set(data.allSymbols)
        self.recents = RecentSymbols.all.filter { available.contains($0) }
        refilter()
    }

    private func refilter() {
        let list = showingRecents
            ? recents
            : SymbolSearch.filter(data.allSymbols, query: query, index: data.searchIndex)
        rows = Array(list.prefix(Self.maxRows))
        selection = 0
    }

    func move(_ delta: Int) {
        guard !rows.isEmpty else { return }
        selection = (selection + delta + rows.count) % rows.count
    }

    /// Tab: fill the field with the selected symbol's full name.
    func acceptCompletion() {
        guard let symbol = selectedSymbol else { return }
        query = symbol
    }
}

// MARK: - Controller

final class InlineInsertController {
    static let shared = InlineInsertController()
    private init() {}

    static let width: CGFloat = 340
    static let fieldHeight: CGFloat = 38
    static let rowHeight: CGFloat = 28
    /// Panel corner radius; inner shapes use smaller, concentric radii (Liquid Glass style).
    static let cornerRadius: CGFloat = 18
    static let listInset: CGFloat = 6

    private var panel: InlineInsertPanel?
    private var model: InlineInsertModel?
    private var keyMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var rowsSubscription: AnyCancellable?
    /// Where the panel hangs from: below the caret (top edge fixed) or above it (bottom edge fixed).
    private var anchorY: CGFloat = 0
    private var opensUpward = false

    var isShown: Bool { panel != nil }

    func show(context: EditorContext) {
        close()
        let model = InlineInsertModel(context: context)
        self.model = model

        // Anchor at the text cursor, or at the mouse if the editor didn't tell us where it is.
        let mouse = NSEvent.mouseLocation
        let caret = context.caretRect ?? CGRect(x: mouse.x, y: mouse.y - 8, width: 1, height: 16)
        let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: caret.midX, y: caret.midY)) }
            ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)

        let height = Self.height(for: model)
        let maxHeight = Self.fieldHeight + CGFloat(InlineInsertModel.maxRows) * Self.rowHeight + Self.listInset * 2 + 1
        opensUpward = caret.minY - 6 - maxHeight < visible.minY
        anchorY = opensUpward ? caret.maxY + 6 : caret.minY - 6

        // Line the field's text up roughly with the caret, but stay on screen.
        let x = min(max(caret.minX - 34, visible.minX + 8), visible.maxX - Self.width - 8)

        let panel = InlineInsertPanel(
            contentRect: frame(x: x, height: height),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let view = InlineInsertView(model: model, fieldAtBottom: opensUpward) { [weak self] symbol, style in
            self?.insert(symbol, style: style)
        }
        // Native Liquid Glass, the same material as system menus and popovers.
        let glass = NSGlassEffectView(frame: CGRect(origin: .zero, size: panel.frame.size))
        glass.style = .regular
        glass.cornerRadius = Self.cornerRadius
        let host = NSHostingView(rootView: view)
        host.frame = glass.bounds
        host.autoresizingMask = [.width, .height]
        glass.contentView = host
        panel.contentView = glass

        // Becomes key without activating our app, so the editor stays the active app.
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        focusSearchField()

        rowsSubscription = model.$rows.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.resize() }
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handleKey(event) ? nil : event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    /// Puts the text cursor in the search field right away, so typing starts immediately.
    /// SwiftUI's own focus request can arrive before the field is in the window, so we
    /// also make the underlying NSTextField first responder directly (now and next pass).
    private func focusSearchField() {
        guard let panel else { return }
        func focus() {
            guard self.panel === panel, let content = panel.contentView else { return }
            content.layoutSubtreeIfNeeded()
            if let field = content.firstDescendant(where: { ($0 as? NSTextField)?.isEditable == true }),
                panel.firstResponder !== (field as? NSTextField)?.currentEditor()
            {
                panel.makeFirstResponder(field)
            }
        }
        focus()
        DispatchQueue.main.async { focus() }
    }

    func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        resignObserver = nil
        rowsSubscription = nil
        panel?.orderOut(nil)
        panel = nil
        model = nil
    }

    private static func height(for model: InlineInsertModel) -> CGFloat {
        let rows = max(model.rows.count, 1)  // one row for the hint / "no matches"
        return fieldHeight + CGFloat(rows) * rowHeight + listInset * 2 + 1  // + divider
    }

    private func frame(x: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: x, y: opensUpward ? anchorY : anchorY - height, width: Self.width, height: height)
    }

    private func resize() {
        guard let panel, let model else { return }
        panel.setFrame(frame(x: panel.frame.minX, height: Self.height(for: model)), display: true)
        panel.invalidateShadow()
    }

    /// Returns true when the key was handled.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard let model else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case 53:  // esc
            close()
        case 125:  // ↓
            model.move(1)
        case 126:  // ↑
            model.move(-1)
        case 48:  // tab
            model.acceptCompletion()
        case 36, 76:  // return / enter
            if let symbol = model.selectedSymbol {
                insert(symbol, style: flags.contains(.option) ? .imageCall : .automatic)
            }
        default:
            return false
        }
        return true
    }

    private func insert(_ symbol: String, style: InsertStyle) {
        guard let model else { return }
        let text = InsertText.text(for: symbol, before: model.context.textBeforeCaret, style: style)
        RecentSymbols.add(symbol)
        close()
        // Let focus fall back to the editor before typing into it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            EditorInserter.insert(text)
        }
    }
}

/// Borderless panels can't become key by default; this one must, to receive typing.
final class InlineInsertPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - View

private struct InlineInsertView: View {
    @ObservedObject var model: InlineInsertModel
    let fieldAtBottom: Bool
    var onPick: (String, InsertStyle) -> Void

    @FocusState private var fieldFocused: Bool
    private let font = Font.system(size: 13, design: .monospaced)

    var body: some View {
        VStack(spacing: 0) {
            if fieldAtBottom {
                list
                Divider().padding(.horizontal, 12)
                field
            } else {
                field
                Divider().padding(.horizontal, 12)
                list
            }
        }
        // The glass itself comes from the NSGlassEffectView the controller puts behind this view.
        .defaultFocus($fieldFocused, true)
        .onAppear { fieldFocused = true }
    }

    private var field: some View {
        HStack(spacing: 8) {
            Image(systemName: model.selectedSymbol ?? "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(model.selectedSymbol == nil ? .secondary : .primary)
                .frame(width: 22)

            ZStack(alignment: .leading) {
                // Grey completion drawn behind the field, starting where your text ends.
                Text("\(Text(model.query).foregroundStyle(.clear))\(Text(model.completionSuffix).foregroundStyle(.tertiary))")
                    .font(font)
                    .lineLimit(1)
                    .allowsHitTesting(false)
                    .padding(.leading, 2)

                TextField("", text: $model.query, prompt: Text("Insert SF Symbol…"))
                    .textFieldStyle(.plain)
                    .font(font)
                    .focused($fieldFocused)
            }

            if !model.completionSuffix.isEmpty {
                KeyHint("⇥")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: InlineInsertController.fieldHeight)
    }

    @ViewBuilder
    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.rows.isEmpty {
                Text(model.showingRecents
                     ? "Type to search \(model.totalSymbols.formatted()) symbols"
                     : "No matches")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: InlineInsertController.rowHeight)
            } else {
                ForEach(Array(model.rows.enumerated()), id: \.offset) { index, symbol in
                    row(symbol, index: index)
                }
            }
        }
        .padding(InlineInsertController.listInset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ symbol: String, index: Int) -> some View {
        let selected = index == model.selection
        return HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 22)
            Text(symbol)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if selected {
                Text(model.showingRecents ? "recent  ↩" : "↩")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .foregroundStyle(selected ? .white : .primary)
        .padding(.horizontal, 8)
        .frame(height: InlineInsertController.rowHeight)
        .background(
            // Concentric with the panel: outer radius minus the list inset.
            RoundedRectangle(
                cornerRadius: InlineInsertController.cornerRadius - InlineInsertController.listInset,
                style: .continuous
            )
            .fill(selected ? Color.accentColor : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onPick(symbol, .automatic) }
        .onTapGesture { model.selection = index }
    }
}

private struct KeyHint: View {
    let key: String
    init(_ key: String) { self.key = key }

    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(.quaternary, in: Capsule())
    }
}

private extension NSView {
    /// Depth-first search of the view hierarchy.
    func firstDescendant(where match: (NSView) -> Bool) -> NSView? {
        for subview in subviews {
            if match(subview) { return subview }
            if let found = subview.firstDescendant(where: match) { return found }
        }
        return nil
    }
}
