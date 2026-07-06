import AppKit
import SwiftUI

@main
struct CutPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Cut Paste", id: "main") {
            ContentView()
                .environmentObject(appDelegate.store)
        }
        .defaultSize(width: 1120, height: 760)
        .commands {
            CutPasteCommands(store: appDelegate.store, panelController: appDelegate.panelController)
        }

        MenuBarExtra {
            CutPasteMenuBarMenu(store: appDelegate.store, panelController: appDelegate.panelController)
        } label: {
            Label("Cut Paste", systemImage: "doc.on.clipboard")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.store)
        }
    }
}

struct CutPasteCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    let store: ClipboardStore
    let panelController: ClipboardPanelController

    var body: some Commands {
        CommandMenu("Clipboard") {
            Button("Open Cut Paste") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Show Clipboard Shelf") {
                panelController.toggle()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Button("Capture Current Clipboard") {
                store.captureCurrentClipboard()
            }
            .keyboardShortcut("c", modifiers: [.command, .option])

            Divider()

            Button("Clear Unpinned History", role: .destructive) {
                store.clearHistory(keepingPinned: true)
            }
        }
    }
}

struct CutPasteMenuBarMenu: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var store: ClipboardStore

    let panelController: ClipboardPanelController

    var body: some View {
        Button("Open Cut Paste") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Show Shelf") {
            panelController.toggle()
        }
        .keyboardShortcut("v", modifiers: [.command, .shift])

        Button("Capture Current Clipboard") {
            store.captureCurrentClipboard()
        }

        Divider()

        if store.items.isEmpty {
            Text("No clipboard history")
        } else {
            ForEach(store.items.prefix(5)) { item in
                Button {
                    store.copy(item)
                } label: {
                    Label(item.menuTitle, systemImage: item.kind.symbolName)
                }
            }
        }

        Divider()
        SettingsLink()
        Button("Quit Cut Paste") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ClipboardStore()
    let panelController = ClipboardPanelController()
    private var hotKey: GlobalHotKey?
    private var configured = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configure()
    }

    func configure() {
        guard !configured else { return }
        configured = true
        panelController.configure(store: store)
        hotKey = GlobalHotKey { [weak self] in
            self?.panelController.toggle()
        }
        let status = hotKey?.register() ?? OSStatus(-1)
        store.updateHotKeyStatus(status)
    }
}
