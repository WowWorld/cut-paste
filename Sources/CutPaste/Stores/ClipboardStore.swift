import AppKit
import ApplicationServices
import Combine
import CryptoKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class ClipboardStore: ObservableObject {
    static let retentionDefaultsKey = "historyRetentionDays"
    static let monitoringEnabledDefaultsKey = "clipboardMonitoringEnabled"

    @Published private(set) var items: [ClipboardItem] = []
    @Published var permissionNotice: String?
    @Published var isHotKeyRegistered = false
    @Published var hotKeyStatusMessage = "Not registered"
    @Published private(set) var isMonitoringEnabled: Bool

    private let pasteboard: NSPasteboard
    private var lastPasteboardChangeCount: Int
    private var timer: Timer?
    private let maxHistoryItems = 100
    private let saveQueue = DispatchQueue(label: "io.github.wowworld.cutpaste.persistence", qos: .utility)
    private var pendingSaveWorkItem: DispatchWorkItem?

    init(pasteboard: NSPasteboard = .general) {
        UserDefaults.standard.register(defaults: [
            Self.retentionDefaultsKey: HistoryRetention.forever.rawValue,
            Self.monitoringEnabledDefaultsKey: true
        ])
        isMonitoringEnabled = UserDefaults.standard.bool(forKey: Self.monitoringEnabledDefaultsKey)
        self.pasteboard = pasteboard
        self.lastPasteboardChangeCount = pasteboard.changeCount
        migrateLegacyStorageIfNeeded()
        load()
        pruneExpiredItems()
        startMonitoring()
        save(immediate: true)
    }

    deinit {
        timer?.invalidate()
        pendingSaveWorkItem?.cancel()
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.captureCurrentClipboardIfNeeded()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func captureCurrentClipboard() {
        guard let item = readCurrentPasteboardItem() else { return }
        insertOrPromote(item)
        lastPasteboardChangeCount = pasteboard.changeCount
    }

    func captureCurrentClipboardIfNeeded() {
        guard isMonitoringEnabled else { return }
        guard pasteboard.changeCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = pasteboard.changeCount
        guard let item = readCurrentPasteboardItem() else { return }
        insertOrPromote(item)
    }

    func setMonitoringEnabled(_ isEnabled: Bool) {
        isMonitoringEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: Self.monitoringEnabledDefaultsKey)
        lastPasteboardChangeCount = pasteboard.changeCount
        permissionNotice = isEnabled ? nil : "已暂停自动监听剪贴板；你仍然可以手动 Capture 当前剪贴板。"
    }

    func filteredItems(searchText: String, filter: ClipboardFilter) -> [ClipboardItem] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !needle.isEmpty else {
            switch filter {
            case .all:
                return items
            case .links:
                return items.filter { $0.kind == .link }
            case .images:
                return items.filter { $0.kind == .image }
            case .files:
                return items.filter { $0.kind == .file }
            case .colors:
                return items.filter { $0.kind == .color }
            case .pinned:
                return items.filter(\.isPinned)
            }
        }

        return items.filter { item in
            let matchesFilter: Bool
            switch filter {
            case .all:
                matchesFilter = true
            case .links:
                matchesFilter = item.kind == .link
            case .images:
                matchesFilter = item.kind == .image
            case .files:
                matchesFilter = item.kind == .file
            case .colors:
                matchesFilter = item.kind == .color
            case .pinned:
                matchesFilter = item.isPinned
            }

            guard matchesFilter else { return false }

            return item.title.lowercased().contains(needle)
                || item.subtitle.lowercased().contains(needle)
                || item.content.lowercased().contains(needle)
                || item.sourceApp.lowercased().contains(needle)
        }
    }

    func copy(_ item: ClipboardItem) {
        pasteboard.clearContents()

        switch item.kind {
        case .image:
            if let data = imageData(for: item), let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            } else {
                pasteboard.setString(item.content, forType: .string)
            }
        case .file:
            let urls = item.filePaths.map { NSURL(fileURLWithPath: $0) }
            if urls.isEmpty {
                pasteboard.setString(item.content, forType: .string)
            } else {
                pasteboard.writeObjects(urls)
            }
        case .link:
            pasteboard.setString(item.content, forType: .string)
            pasteboard.setString(item.content, forType: .URL)
        case .text, .color:
            pasteboard.setString(item.content, forType: .string)
        }

        markUsed(item)
        lastPasteboardChangeCount = pasteboard.changeCount
        permissionNotice = nil
    }

    func copyAndPaste(_ item: ClipboardItem) {
        copy(item)
        sendPasteKeystroke(promptForPermission: true)
    }

    func sendPasteKeystroke(promptForPermission: Bool) {
        guard isAccessibilityTrusted(prompt: promptForPermission) else {
            permissionNotice = "已复制到剪贴板；如需自动粘贴，请在 System Settings > Privacy & Security > Accessibility 允许 Cut Paste。"
            return
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCodeV: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeV, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        permissionNotice = nil
    }

    func togglePinned(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        sortPinnedItems()
        save()
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearHistory(keepingPinned: Bool = true) {
        if keepingPinned {
            items.removeAll { !$0.isPinned }
        } else {
            items.removeAll()
        }
        save()
    }

    func revealInFinder(_ item: ClipboardItem) {
        guard let path = item.filePaths.first else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func applyRetentionPolicy(days: Int) {
        pruneExpiredItems(retentionDays: days)
        save(immediate: true)
    }

    func updateHotKeyStatus(_ status: OSStatus) {
        isHotKeyRegistered = status == noErr
        hotKeyStatusMessage = isHotKeyRegistered ? "Registered" : "Failed (OSStatus \(status))"
    }

    private func readCurrentPasteboardItem() -> ClipboardItem? {
        if pasteboardContainsDirectImageData(), let imageItem = readImageItem() {
            return imageItem
        }

        if let imageFileItem = readImageFileItemFromSourceApp() {
            return imageFileItem
        }

        if let fileItem = readFileItem() {
            return fileItem
        }

        if let imageItem = readImageItem() {
            return imageItem
        }

        if let string = pasteboard.string(forType: .string),
           !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return readStringItem(string, sourceApp: frontmostAppName())
        }

        return nil
    }

    private func readFileItem() -> ClipboardItem? {
        guard let urls = readFileURLs(), !urls.isEmpty else {
            return nil
        }

        let paths = urls.map(\.path)
        let fingerprint = hashString("file:" + paths.joined(separator: "|"))
        let title = urls.count == 1 ? (urls.first?.lastPathComponent ?? "File") : "\(urls.count) Files"
        let subtitle = paths.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }.first ?? "File"

        return ClipboardItem(
            kind: .file,
            title: title,
            subtitle: subtitle,
            content: paths.joined(separator: "\n"),
            sourceApp: frontmostAppName(),
            fingerprint: fingerprint,
            filePaths: paths
        )
    }

    private func readImageItem() -> ClipboardItem? {
        guard let image = NSImage(pasteboard: pasteboard), let data = image.pngData() else {
            return nil
        }

        return makeImageItem(image: image, data: data, sourceApp: frontmostAppName())
    }

    private func readImageFileItemFromSourceApp() -> ClipboardItem? {
        let sourceApp = frontmostAppName()
        guard let urls = readFileURLs(),
              urls.count == 1,
              let url = urls.first,
              url.isLikelyImageFile,
              shouldTreatFileURLAsCopiedImage(url, sourceApp: sourceApp),
              let image = NSImage(contentsOf: url),
              let data = image.pngData()
        else {
            return nil
        }

        return makeImageItem(image: image, data: data, sourceApp: sourceApp)
    }

    private func makeImageItem(image: NSImage, data: Data, sourceApp: String) -> ClipboardItem {
        let id = UUID()
        let imageFileName = "\(id.uuidString).png"
        let pixelSize = image.pixelSize ?? PixelSize(width: Int(image.size.width), height: Int(image.size.height))
        let fingerprint = hashData(data)
        let subtitle = "\(pixelSize.width) x \(pixelSize.height)"

        return ClipboardItem(
            id: id,
            kind: .image,
            title: "Image",
            subtitle: subtitle,
            content: "PNG image, \(data.count / 1024) KB",
            sourceApp: sourceApp,
            fingerprint: fingerprint,
            imageData: data,
            imageFileName: imageFileName,
            imagePixelSize: pixelSize
        )
    }

    private func readFileURLs() -> [URL]? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] else {
            return nil
        }
        return objects.map { $0 as URL }
    }

    private func pasteboardContainsDirectImageData() -> Bool {
        guard let types = pasteboard.types else { return false }
        return types.contains { type in
            switch type.rawValue {
            case "public.png", "public.tiff", "public.jpeg", "public.heic", "com.compuserve.gif":
                return true
            default:
                return UTType(type.rawValue)?.conforms(to: .image) == true
            }
        }
    }

    private func shouldTreatFileURLAsCopiedImage(_ url: URL, sourceApp: String) -> Bool {
        let appName = sourceApp.lowercased()
        if appName == "finder" {
            return false
        }
        if appName.contains("wechat") || sourceApp.contains("微信") {
            return true
        }

        let path = url.standardizedFileURL.path.lowercased()
        return path.hasPrefix("/private/var/folders/")
            || path.hasPrefix("/var/folders/")
            || path.contains("wechat")
            || path.contains("weixin")
            || path.contains("com.tencent")
            || path.contains("微信")
    }

    private func readStringItem(_ string: String, sourceApp: String) -> ClipboardItem {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let fingerprint = hashString("string:" + trimmed)

        if let colorHex = normalizedColorHex(from: trimmed) {
            return ClipboardItem(
                kind: .color,
                title: colorHex.uppercased(),
                subtitle: "Color value",
                content: colorHex,
                sourceApp: sourceApp,
                fingerprint: fingerprint,
                colorHex: colorHex
            )
        }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) {
            return ClipboardItem(
                kind: .link,
                title: url.host(percentEncoded: false) ?? trimmed.clipped(to: 42),
                subtitle: trimmed.clipped(to: 80),
                content: trimmed,
                sourceApp: sourceApp,
                fingerprint: fingerprint
            )
        }

        let firstLine = trimmed.components(separatedBy: .newlines).first?.trimmedForDisplay ?? "Text"
        return ClipboardItem(
            kind: .text,
            title: firstLine.isEmpty ? "Text" : firstLine.clipped(to: 44),
            subtitle: "\(string.count) characters",
            content: string,
            sourceApp: sourceApp,
            fingerprint: fingerprint
        )
    }

    private func insertOrPromote(_ newItem: ClipboardItem) {
        if let existingIndex = items.firstIndex(where: { $0.fingerprint == newItem.fingerprint }) {
            var existing = items.remove(at: existingIndex)
            existing.title = newItem.title
            existing.subtitle = newItem.subtitle
            existing.content = newItem.content
            existing.sourceApp = newItem.sourceApp
            existing.createdAt = Date()
            existing.imageData = newItem.imageData
            existing.imageFileName = existing.imageFileName ?? newItem.imageFileName ?? imageFileName(for: existing.id)
            existing.imagePixelSize = newItem.imagePixelSize
            existing.filePaths = newItem.filePaths
            existing.colorHex = newItem.colorHex
            items.insert(existing, at: 0)
        } else {
            items.insert(newItem, at: 0)
        }

        sortPinnedItems()
        pruneExpiredItems()
        enforceHistoryLimit()
        save()
    }

    private func markUsed(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var usedItem = items.remove(at: index)
        let usedAt = Date()
        usedItem.lastUsedAt = usedAt
        usedItem.createdAt = usedAt
        items.insert(usedItem, at: 0)
        sortPinnedItems()
        save()
    }

    private func sortPinnedItems() {
        items.sort { left, right in
            if left.isPinned != right.isPinned {
                return left.isPinned && !right.isPinned
            }
            return left.createdAt > right.createdAt
        }
    }

    private func enforceHistoryLimit() {
        let pinned = items.filter(\.isPinned)
        let regular = items.filter { !$0.isPinned }.prefix(maxHistoryItems)
        items = pinned + Array(regular)
    }

    private func pruneExpiredItems(retentionDays: Int? = nil) {
        let days = retentionDays ?? UserDefaults.standard.integer(forKey: Self.retentionDefaultsKey)
        guard days > 0 else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        items.removeAll { item in
            !item.isPinned && item.createdAt < cutoff
        }
    }

    private func normalizedColorHex(from value: String) -> String? {
        var hex = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") {
            hex.removeFirst()
        }
        guard [6, 8].contains(hex.count) else { return nil }
        let hexDigits = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard hex.unicodeScalars.allSatisfy({ hexDigits.contains($0) }) else { return nil }
        return "#" + hex.uppercased()
    }

    private func frontmostAppName() -> String {
        let currentBundleID = Bundle.main.bundleIdentifier
        let app = NSWorkspace.shared.frontmostApplication
        if app?.bundleIdentifier == currentBundleID {
            return "Cut Paste"
        }
        return app?.localizedName ?? "Unknown"
    }

    private func hashString(_ value: String) -> String {
        hashData(Data(value.utf8))
    }

    private func hashData(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private var storageDirectoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CutPaste", isDirectory: true)
    }

    private var storageURL: URL {
        storageDirectoryURL.appendingPathComponent("ClipboardHistory.json")
    }

    private var imagesDirectoryURL: URL {
        storageDirectoryURL.appendingPathComponent("Images", isDirectory: true)
    }

    private var legacyStorageDirectoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CutCopy", isDirectory: true)
    }

    private var legacyStorageURL: URL {
        legacyStorageDirectoryURL.appendingPathComponent("ClipboardHistory.json")
    }

    private var legacyImagesDirectoryURL: URL {
        legacyStorageDirectoryURL.appendingPathComponent("Images", isDirectory: true)
    }

    private func imageFileName(for id: UUID) -> String {
        "\(id.uuidString).png"
    }

    private func imageData(for item: ClipboardItem) -> Data? {
        if let data = item.imageData {
            return data
        }
        guard let imageFileName = item.imageFileName else { return nil }
        return try? Data(contentsOf: imagesDirectoryURL.appendingPathComponent(imageFileName))
    }

    private func migrateLegacyStorageIfNeeded() {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: storageDirectoryURL.path),
              fileManager.fileExists(atPath: legacyStorageDirectoryURL.path) else {
            return
        }

        do {
            try fileManager.createDirectory(at: storageDirectoryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: legacyStorageDirectoryURL, to: storageDirectoryURL)
        } catch {
            assertionFailure("Failed to migrate legacy CutCopy storage: \(error)")
        }
    }

    private func load() {
        let fileManager = FileManager.default
        let url = fileManager.fileExists(atPath: storageURL.path) ? storageURL : legacyStorageURL
        let loadedImagesDirectoryURL = url == storageURL ? imagesDirectoryURL : legacyImagesDirectoryURL
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            items = try JSONDecoder().decode([ClipboardItem].self, from: data).map { item in
                var item = item
                if item.kind == .image {
                    item.imageFileName = item.imageFileName ?? imageFileName(for: item.id)
                    if item.imageData == nil, let imageFileName = item.imageFileName {
                        item.imageData = try? Data(contentsOf: loadedImagesDirectoryURL.appendingPathComponent(imageFileName))
                    }
                }
                return item
            }
            sortPinnedItems()
        } catch {
            items = []
        }
    }

    private func save(immediate: Bool = false) {
        for index in items.indices where items[index].kind == .image && items[index].imageFileName == nil {
            items[index].imageFileName = imageFileName(for: items[index].id)
        }

        let snapshot = items
        let storageURL = storageURL
        let imagesDirectoryURL = imagesDirectoryURL

        pendingSaveWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            Self.write(snapshot: snapshot, storageURL: storageURL, imagesDirectoryURL: imagesDirectoryURL)
        }
        pendingSaveWorkItem = workItem

        let delay: DispatchTimeInterval = immediate ? .milliseconds(0) : .milliseconds(250)
        saveQueue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private nonisolated static func write(snapshot: [ClipboardItem], storageURL: URL, imagesDirectoryURL: URL) {
        do {
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)

            for item in snapshot where item.kind == .image {
                guard let imageFileName = item.imageFileName, let imageData = item.imageData else { continue }
                try imageData.write(to: imagesDirectoryURL.appendingPathComponent(imageFileName), options: [.atomic])
            }

            let activeImageFileNames = Set(snapshot.compactMap(\.imageFileName))
            let existingImageURLs = (try? FileManager.default.contentsOfDirectory(at: imagesDirectoryURL, includingPropertiesForKeys: nil)) ?? []
            for imageURL in existingImageURLs where !activeImageFileNames.contains(imageURL.lastPathComponent) {
                try? FileManager.default.removeItem(at: imageURL)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save clipboard history: \(error)")
        }
    }
}

private extension URL {
    var isLikelyImageFile: Bool {
        guard isFileURL else { return false }

        let imageExtensions: Set<String> = [
            "avif", "gif", "heic", "heif", "jpeg", "jpg", "png", "tif", "tiff", "webp"
        ]
        let fileExtension = pathExtension.lowercased()
        if imageExtensions.contains(fileExtension) {
            return true
        }

        guard let type = UTType(filenameExtension: fileExtension) else {
            return false
        }
        return type.conforms(to: .image)
    }
}
