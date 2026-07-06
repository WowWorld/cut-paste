import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ClipboardStore
    @AppStorage(ClipboardStore.retentionDefaultsKey) private var retentionDays = HistoryRetention.forever.rawValue

    private var selectedRetention: Binding<Int> {
        Binding(
            get: { retentionDays },
            set: { newValue in
                retentionDays = newValue
                store.applyRetentionPolicy(days: newValue)
            }
        )
    }

    var body: some View {
        Form {
            Section("Shortcut") {
                LabeledContent("Global hotkey") {
                    Text("Command + Shift + V")
                        .font(.body.monospaced().weight(.semibold))
                }

                LabeledContent("Status") {
                    Text(store.hotKeyStatusMessage)
                        .foregroundStyle(store.isHotKeyRegistered ? .green : .orange)
                }

                if !store.isHotKeyRegistered {
                    Text("如果快捷键被其他 App 占用，Cut Paste 无法注册。请退出占用快捷键的 App 后重启 Cut Paste，或后续改用自定义快捷键。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Paste") {
                LabeledContent("Automatic paste") {
                    Text(store.isAccessibilityTrusted(prompt: false) ? "Allowed" : "Needs Accessibility")
                        .foregroundStyle(store.isAccessibilityTrusted(prompt: false) ? .green : .orange)
                }
                Button("Request Accessibility Permission") {
                    _ = store.isAccessibilityTrusted(prompt: true)
                }
            }

            Section("History") {
                Toggle("Monitor clipboard automatically", isOn: Binding(
                    get: { store.isMonitoringEnabled },
                    set: { store.setMonitoringEnabled($0) }
                ))

                Picker("Keep history", selection: selectedRetention) {
                    ForEach(HistoryRetention.allCases) { retention in
                        Text(retention.displayName).tag(retention.rawValue)
                    }
                }
                .pickerStyle(.menu)

                Text("Pinned 项不会因为保存时间设置被自动清理。图片内容会保存为独立文件，历史 JSON 只保存轻量元数据。")
                    .foregroundStyle(.secondary)

                Button("Capture Current Clipboard") {
                    store.captureCurrentClipboard()
                }
                Button("Clear Unpinned History", role: .destructive) {
                    store.clearHistory(keepingPinned: true)
                }
            }
        }
        .formStyle(.grouped)
        .padding(18)
        .frame(width: 560, height: 460)
    }
}
