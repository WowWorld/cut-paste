import AppKit
import SwiftUI

struct CommandNumberShortcutReader: NSViewRepresentable {
    var isEnabled: Bool
    var isTextInputActive: Bool = false
    var onShortcut: (Int) -> Void
    var onReturn: () -> Void = {}
    var onTextInput: ((String) -> Void)?

    func makeNSView(context: Context) -> ShortcutHostingView {
        let view = ShortcutHostingView()
        context.coordinator.hostingView = view
        context.coordinator.isEnabled = isEnabled
        context.coordinator.isTextInputActive = isTextInputActive
        context.coordinator.onShortcut = onShortcut
        context.coordinator.onReturn = onReturn
        context.coordinator.onTextInput = onTextInput
        context.coordinator.installMonitor()
        return view
    }

    func updateNSView(_ nsView: ShortcutHostingView, context: Context) {
        context.coordinator.hostingView = nsView
        context.coordinator.isEnabled = isEnabled
        context.coordinator.isTextInputActive = isTextInputActive
        context.coordinator.onShortcut = onShortcut
        context.coordinator.onReturn = onReturn
        context.coordinator.onTextInput = onTextInput
    }

    static func dismantleNSView(_ nsView: ShortcutHostingView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var hostingView: ShortcutHostingView?
        var isEnabled = false
        var isTextInputActive = false
        var onShortcut: ((Int) -> Void)?
        var onReturn: (() -> Void)?
        var onTextInput: ((String) -> Void)?
        private var monitor: Any?

        deinit {
            removeMonitor()
        }

        func installMonitor() {
            guard monitor == nil else { return }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isEnabled, let window = self.hostingView?.window, window.isKeyWindow else {
                    return event
                }

                if self.shouldHandleCommandShortcut(event: event), let index = self.quickPasteIndex(from: event) {
                    self.onShortcut?(index)
                    return nil
                }

                if self.shouldHandleReturn(event: event) {
                    self.onReturn?()
                    return nil
                }

                if let text = self.searchText(from: event), let onTextInput = self.onTextInput {
                    onTextInput(text)
                    return nil
                }

                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func shouldHandleCommandShortcut(event: NSEvent) -> Bool {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return flags == .command
        }

        private func shouldHandleReturn(event: NSEvent) -> Bool {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags.isEmpty else { return false }
            guard !isTextInputActive else { return false }

            return event.keyCode == 36
                || event.keyCode == 76
                || event.charactersIgnoringModifiers == "\r"
                || event.charactersIgnoringModifiers == "\u{3}"
        }

        private func quickPasteIndex(from event: NSEvent) -> Int? {
            guard let text = event.charactersIgnoringModifiers, text.count == 1 else { return nil }
            guard let digit = Int(text), (1...9).contains(digit) else { return nil }
            return digit - 1
        }

        private func searchText(from event: NSEvent) -> String? {
            guard !isTextInputActive else { return nil }

            var flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            flags.remove(.shift)
            flags.remove(.capsLock)
            guard flags.isEmpty else { return nil }

            guard let text = event.characters, !text.isEmpty else { return nil }
            guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return nil }
            guard text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return nil }
            return text
        }
    }
}

final class ShortcutHostingView: NSView {
    override var acceptsFirstResponder: Bool { false }
}
