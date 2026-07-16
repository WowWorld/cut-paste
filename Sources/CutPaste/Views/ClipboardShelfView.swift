import Combine
import AppKit
import SwiftUI

enum ClipboardShelfStyle {
    case library
    case floating
}

struct ClipboardShelfView: View {
    @EnvironmentObject private var store: ClipboardStore

    let style: ClipboardShelfStyle
    var selectionResetPublisher: AnyPublisher<UUID, Never> = Empty<UUID, Never>().eraseToAnyPublisher()
    var onClose: (() -> Void)?
    var onPaste: ((ClipboardItem) -> Void)?

    @State private var searchText = ""
    @State private var selectedFilter: ClipboardFilter = .all
    @State private var selectedItemID: ClipboardItem.ID?
    @State private var selectionScrollRequest = 0
    @State private var isAddSheetPresented = false
    @FocusState private var isSearchFocused: Bool

    private var visibleItems: [ClipboardItem] {
        store.filteredItems(searchText: searchText, filter: selectedFilter)
    }

    private var selectedItem: ClipboardItem? {
        if let selectedItemID, let item = visibleItems.first(where: { $0.id == selectedItemID }) {
            return item
        }
        return visibleItems.first
    }

    private var quickPasteItems: [ClipboardItem] {
        Array(visibleItems.prefix(9))
    }

    var body: some View {
        let currentVisibleItems = visibleItems
        let currentVisibleItemIDs = currentVisibleItems.map(\.id)
        let currentSelectedItem = selectedItem(in: currentVisibleItems)
        let currentQuickPasteItems = Array(currentVisibleItems.prefix(9))

        VStack(spacing: style == .floating ? 6 : 12) {
            shelfBody(visibleItems: currentVisibleItems, selectedItem: currentSelectedItem)
        }
        .onAppear {
            validateSelection()
        }
        .onChange(of: currentVisibleItemIDs) { _, _ in validateSelection() }
        .onReceive(selectionResetPublisher) { _ in
            resetSelectionToFirst()
        }
        .background(
            CommandNumberShortcutReader(
                isEnabled: style == .floating || !currentQuickPasteItems.isEmpty,
                isTextInputActive: isSearchFocused,
                onShortcut: { index in
                    quickPaste(at: index)
                },
                onReturn: {
                    pasteSelectedItem()
                },
                onTextInput: { text in
                    beginSearch(with: text)
                }
            )
        )
    }

    private func shelfBody(visibleItems: [ClipboardItem], selectedItem: ClipboardItem?) -> some View {
        VStack(alignment: .leading, spacing: style == .floating ? 8 : 16) {
            header(visibleCount: visibleItems.count, pinnedCount: store.items.filter(\.isPinned).count)
            filterBar

            if visibleItems.isEmpty {
                EmptyShelfView(searchText: searchText, selectedFilter: selectedFilter) {
                    store.captureCurrentClipboard()
                }
                .frame(height: style == .floating ? 210 : 220)
            } else {
                cardScroller(visibleItems: visibleItems, selectedItemID: selectedItem?.id)
            }

            if let notice = store.permissionNotice {
                HStack(spacing: 8) {
                    Image(systemName: "accessibility")
                    Text(notice)
                    Spacer(minLength: 10)
                    Button("OK") { store.permissionNotice = nil }
                        .buttonStyle(.borderless)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
            }
        }
        .padding(style == .floating ? 10 : 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(.white.opacity(style == .floating ? 0.38 : 0.30), lineWidth: 1)
        )
        .shadow(color: .black.opacity(style == .floating ? 0.28 : 0.22), radius: 32, x: 0, y: 20)
        .sheet(isPresented: $isAddSheetPresented) {
            AddItemSheet(isPresented: $isAddSheetPresented) { content in
                store.addManualItem(content: content)
            }
        }
    }

    private func header(visibleCount: Int, pinnedCount: Int) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Clipboard Shelf")
                    .font(.system(size: style == .floating ? 18 : 25, weight: .bold, design: .rounded))
                Text("\(visibleCount) items · \(pinnedCount) pinned")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            SearchField(text: $searchText, isFocused: $isSearchFocused) {
                pasteSelectedItem()
            }
                .frame(width: style == .floating ? 240 : 340)

            Button {
                isAddSheetPresented = true
            } label: {
                Label("添加", systemImage: "square.and.pencil")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(PillButtonStyle(tint: Color(red: 0.90, green: 0.50, blue: 0.10)))
            .help("手动添加固定内容，永久保留")

            Button {
                store.captureCurrentClipboard()
            } label: {
                Label("Capture", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(PillButtonStyle())
            .help("立即读取当前剪贴板")

            Menu {
                Button("Clear Unpinned History", role: .destructive) {
                    store.clearHistory(keepingPinned: true)
                }
                Button("Clear All History", role: .destructive) {
                    store.clearHistory(keepingPinned: false)
                }
            } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                    .frame(width: style == .floating ? 30 : 34, height: style == .floating ? 30 : 34)
            }
            .menuStyle(.borderlessButton)
            .background(.regularMaterial, in: Circle())

            if style == .floating, let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: style == .floating ? 30 : 32, height: style == .floating ? 30 : 32)
                }
                .buttonStyle(.plain)
                .background(.regularMaterial, in: Circle())
                .help("Close")
            }
        }
    }

    private func cardScroller(visibleItems: [ClipboardItem], selectedItemID: ClipboardItem.ID?) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardCardView(
                            item: item,
                            isSelected: selectedItemID == item.id,
                            shortcutIndex: index < 9 ? index + 1 : nil
                        )
                        .id(item.id)
                        .gesture(cardTapGesture(for: item))
                        .help(index < 9 ? "Command + \(index + 1) 快速粘贴" : "Double-click to paste")
                        .contextMenu {
                            Button("Copy") { store.copy(item) }
                            if style == .floating {
                                Button("Paste") { paste(item) }
                            }
                            Button(item.isPinned ? "Unpin" : "Pin") { store.togglePinned(item) }
                            Divider()
                            Button("Delete", role: .destructive) { store.delete(item) }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
            }
            .onAppear {
                scrollSelectedCard(with: proxy, animated: false)
            }
            .onChange(of: selectedItemID) { _, _ in
                scrollSelectedCard(with: proxy)
            }
            .onChange(of: selectionScrollRequest) { _, _ in
                scrollSelectedCard(with: proxy)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: style == .floating ? 258 : 242)
    }

    private var filterBar: some View {
        HStack(spacing: 9) {
            ForEach(ClipboardFilter.allCases) { filter in
                Button {
                    releaseKeyboardFocus()
                    selectedFilter = filter
                } label: {
                    Label(filter.displayName, systemImage: filter.symbolName)
                        .font(.caption2.weight(.bold))
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, style == .floating ? 9 : 11)
                        .padding(.vertical, style == .floating ? 5 : 7)
                        .foregroundStyle(selectedFilter == filter ? .white : .primary.opacity(0.76))
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedFilter == filter ? Color.primary.opacity(0.78) : Color.primary.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text(style == .floating ? "Enter or ⌘1-⌘9 paste" : "Double-click, Enter, or press ⌘1-⌘9 to paste")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .opacity(style == .floating ? 1 : 0.72)
        }
    }

    private func validateSelection() {
        guard !visibleItems.isEmpty else {
            updateSelection(nil, scrollIfUnchanged: false)
            return
        }
        if let selectedItemID, visibleItems.contains(where: { $0.id == selectedItemID }) {
            requestSelectedCardScroll()
            return
        }
        updateSelection(visibleItems.first?.id, scrollIfUnchanged: false)
    }

    private func selectedItem(in visibleItems: [ClipboardItem]) -> ClipboardItem? {
        if let selectedItemID, let item = visibleItems.first(where: { $0.id == selectedItemID }) {
            return item
        }
        return visibleItems.first
    }

    private func resetSelectionToFirst() {
        releaseKeyboardFocus()
        searchText = ""
        selectedFilter = .all
        updateSelection(visibleItems.first?.id, scrollIfUnchanged: true)
    }

    private func select(_ item: ClipboardItem) {
        releaseKeyboardFocus()
        updateSelection(item.id, scrollIfUnchanged: true)
    }

    private func cardTapGesture(for item: ClipboardItem) -> some Gesture {
        ExclusiveGesture(
            TapGesture(count: 2),
            TapGesture(count: 1)
        )
        .onEnded { value in
            switch value {
            case .first:
                select(item)
                paste(item)
            case .second:
                select(item)
            }
        }
    }

    private func updateSelection(_ id: ClipboardItem.ID?, scrollIfUnchanged: Bool) {
        if selectedItemID == id {
            if scrollIfUnchanged {
                requestSelectedCardScroll()
            }
        } else {
            selectedItemID = id
        }
    }

    private func requestSelectedCardScroll() {
        selectionScrollRequest += 1
    }

    private func releaseKeyboardFocus() {
        isSearchFocused = false
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    private func beginSearch(with text: String) {
        guard style == .floating else { return }
        searchText += text
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }

    private func scrollSelectedCard(with proxy: ScrollViewProxy, animated: Bool = true) {
        guard let selectedItemID else { return }
        guard let anchor = scrollAnchor(for: selectedItemID) else { return }

        if animated {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88, blendDuration: 0.04)) {
                proxy.scrollTo(selectedItemID, anchor: anchor)
            }
        } else {
            proxy.scrollTo(selectedItemID, anchor: anchor)
        }
    }

    private func scrollAnchor(for selectedItemID: ClipboardItem.ID) -> UnitPoint? {
        guard let index = visibleItems.firstIndex(where: { $0.id == selectedItemID }) else {
            return nil
        }

        if index == visibleItems.startIndex {
            return .leading
        }
        if index == visibleItems.index(before: visibleItems.endIndex) {
            return .trailing
        }
        return .center
    }

    private func paste(_ item: ClipboardItem) {
        if let onPaste {
            onPaste(item)
        } else {
            store.copy(item)
            store.permissionNotice = "已复制到剪贴板。要粘贴到其他 App，请切回目标 App 后按 Command + V。"
        }
    }

    private func quickPaste(at zeroBasedIndex: Int) {
        guard quickPasteItems.indices.contains(zeroBasedIndex) else { return }
        let item = quickPasteItems[zeroBasedIndex]
        select(item)
        paste(item)
    }

    private func pasteSelectedItem() {
        releaseKeyboardFocus()
        guard let selectedItem else { return }
        paste(selectedItem)
    }
}

private struct SearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .onSubmit {
                    onSubmit()
                }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(.white.opacity(0.22), lineWidth: 1))
    }
}

private struct PillButtonStyle: ButtonStyle {
    var tint: Color = Color(red: 0.04, green: 0.50, blue: 0.95)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .foregroundStyle(.white)
            .background(tint.opacity(configuration.isPressed ? 0.72 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct EmptyShelfView: View {
    let searchText: String
    let selectedFilter: ClipboardFilter
    let onCapture: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3.weight(.bold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Capture Current Clipboard", action: onCapture)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            Spacer()
        }
        .padding(24)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var title: String {
        searchText.isEmpty ? "还没有剪贴板记录" : "没有匹配结果"
    }

    private var message: String {
        if !searchText.isEmpty {
            return "换一个搜索词，或切回 All 分类查看完整历史。"
        }
        if selectedFilter != .all {
            return "这个分类暂时为空。复制对应类型内容后，它会自动出现在 Shelf。"
        }
        return "复制文字、链接、图片或 Finder 文件后，Cut Paste 会自动保存历史；你也可以手动读取当前剪贴板。"
    }
}

private struct AddItemSheet: View {
    @Binding var isPresented: Bool
    let onAdd: (String) -> Void

    @State private var content = ""
    @FocusState private var isFocused: Bool

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "pin.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.90, green: 0.50, blue: 0.10))
                Text("添加固定内容")
                    .font(.title2.weight(.bold))
            }

            Text("输入需要永久保留的内容。保存后将固定在 Shelf 顶部，除非主动删除，否则不会被自动清理。支持纯文本、链接和颜色值（如 #FF8800）。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    Text("在此输入内容…")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $content)
                    .font(.body)
                    .focused($isFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )
            .frame(minHeight: 150)

            HStack(spacing: 12) {
                Spacer()
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    onAdd(content)
                    content = ""
                    isPresented = false
                } label: {
                    Label("添加并固定", systemImage: "pin.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(trimmedContent.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            DispatchQueue.main.async {
                isFocused = true
            }
        }
    }
}
