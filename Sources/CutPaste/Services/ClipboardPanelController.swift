import AppKit
import SwiftUI

@MainActor
final class ClipboardShelfPresentationState: ObservableObject {
    @Published var selectionResetToken = UUID()
}

@MainActor
final class ClipboardPanelController: ObservableObject {
    private weak var store: ClipboardStore?
    private var panel: ClipboardFloatingPanel?
    private var previousApplication: NSRunningApplication?
    private var delayedSelectionResetWorkItem: DispatchWorkItem?
    private var lastSelectionResetLeadingItemID: ClipboardItem.ID?
    private var needsSelectionResetBeforeNextShow = true
    private let presentationState = ClipboardShelfPresentationState()

    func configure(store: ClipboardStore) {
        self.store = store
        if let panel, let store = self.store {
            panel.contentViewController = NSHostingController(rootView: floatingShelfRoot(store: store))
        }
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let store else { return }
        delayedSelectionResetWorkItem?.cancel()
        delayedSelectionResetWorkItem = nil
        let shouldResetSelection = needsSelectionResetBeforeNextShow
            || store.items.first?.id != lastSelectionResetLeadingItemID
        previousApplication = NSWorkspace.shared.frontmostApplication
        if previousApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            previousApplication = nil
        }

        let panel = makePanelIfNeeded(store: store)
        position(panel: panel)
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        if shouldResetSelection {
            resetSelectionForCurrentItems()
        }
        needsSelectionResetBeforeNextShow = false

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel else { return }
        delayedSelectionResetWorkItem?.cancel()
        delayedSelectionResetWorkItem = nil
        needsSelectionResetBeforeNextShow = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            panel.orderOut(nil)
            panel.alphaValue = 1
            Task { @MainActor [weak self] in
                self?.scheduleSelectionResetAfterExit()
            }
        }
    }

    private func scheduleSelectionResetAfterExit() {
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.panel?.isVisible != true else { return }
                self.resetSelectionForCurrentItems()
                self.needsSelectionResetBeforeNextShow = false
                self.delayedSelectionResetWorkItem = nil
            }
        }
        delayedSelectionResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    private func resetSelectionForCurrentItems() {
        lastSelectionResetLeadingItemID = store?.items.first?.id
        presentationState.selectionResetToken = UUID()
    }

    private func pasteToPreviousApplication(_ item: ClipboardItem) {
        guard let store else { return }
        guard let target = previousApplication else {
            store.copy(item)
            store.permissionNotice = "已复制到剪贴板；没有可返回的目标 App，请切换到目标 App 后按 Command + V。"
            return
        }

        store.copy(item)
        hide()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            target.activate(options: [])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak store] in
            store?.sendPasteKeystroke(promptForPermission: true)
        }
    }

    private func makePanelIfNeeded(store: ClipboardStore) -> ClipboardFloatingPanel {
        if let panel {
            return panel
        }

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let frame = shelfFrame(in: screenFrame)
        let panel = ClipboardFloatingPanel(contentRect: frame)
        panel.onCancel = { [weak self] in
            self?.hide()
        }
        panel.contentViewController = NSHostingController(rootView: floatingShelfRoot(store: store))
        self.panel = panel
        return panel
    }

    private func floatingShelfRoot(store: ClipboardStore) -> some View {
        ClipboardShelfView(
            style: .floating,
            selectionResetPublisher: presentationState.$selectionResetToken.eraseToAnyPublisher(),
            onClose: { [weak self] in
                self?.hide()
            },
            onPaste: { [weak self] item in
                self?.pasteToPreviousApplication(item)
            }
        )
        .environmentObject(store)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func position(panel: NSPanel) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        panel.setFrame(shelfFrame(in: screenFrame), display: true)
    }

    private func shelfFrame(in screenFrame: NSRect) -> NSRect {
        let margin: CGFloat = 8
        let width = max(760, screenFrame.width - margin * 2)
        let height = min(screenFrame.height - margin * 2, 720)
        return NSRect(
            x: screenFrame.minX + margin,
            y: screenFrame.minY + margin,
            width: width,
            height: height
        )
    }
}

final class ClipboardFloatingPanel: NSPanel {
    var onCancel: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
