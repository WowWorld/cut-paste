import SwiftUI

extension ClipboardKind {
    var displayName: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .image: "Image"
        case .file: "File"
        case .color: "Color"
        }
    }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "safari"
        case .image: "photo.on.rectangle.angled"
        case .file: "doc.fill"
        case .color: "eyedropper.halffull"
        }
    }

    var accentColor: Color {
        switch self {
        case .text: Color(red: 0.03, green: 0.52, blue: 0.98)
        case .link: Color(red: 0.00, green: 0.48, blue: 1.00)
        case .image: Color(red: 1.00, green: 0.18, blue: 0.22)
        case .file: Color(red: 0.05, green: 0.58, blue: 0.95)
        case .color: Color(red: 0.11, green: 0.72, blue: 0.29)
        }
    }

    var softColor: Color {
        accentColor.opacity(0.14)
    }
}

extension ClipboardFilter {
    var displayName: String {
        switch self {
        case .all: "All"
        case .links: "Links"
        case .images: "Images"
        case .files: "Files"
        case .colors: "Colors"
        case .pinned: "Pinned"
        }
    }

    var symbolName: String {
        switch self {
        case .all: "square.grid.2x2"
        case .links: "link"
        case .images: "photo"
        case .files: "folder"
        case .colors: "paintpalette"
        case .pinned: "pin.fill"
        }
    }
}

extension ClipboardItem {
    var cardFooter: String {
        switch kind {
        case .text:
            return "\(content.count) characters"
        case .link:
            return URL(string: content)?.host(percentEncoded: false) ?? "URL"
        case .image:
            if let imagePixelSize {
                return "\(imagePixelSize.width) x \(imagePixelSize.height)"
            }
            return subtitle
        case .file:
            return filePaths.count == 1 ? "1 file" : "\(filePaths.count) files"
        case .color:
            return colorHex ?? content
        }
    }

    var menuTitle: String {
        let label = title.trimmedForDisplay
        return label.isEmpty ? kind.displayName : label.clipped(to: 28)
    }
}

extension Color {
    init(cutPasteHex hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }

        var value: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        if cleanHex.count == 8 {
            red = Double((value >> 24) & 0xff) / 255
            green = Double((value >> 16) & 0xff) / 255
            blue = Double((value >> 8) & 0xff) / 255
            alpha = Double(value & 0xff) / 255
        } else {
            red = Double((value >> 16) & 0xff) / 255
            green = Double((value >> 8) & 0xff) / 255
            blue = Double(value & 0xff) / 255
            alpha = 1
        }

        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
}
