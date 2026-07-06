import AppKit
import SwiftUI

struct ClipboardPreviewView: View {
    let item: ClipboardItem
    let showsPasteAction: Bool
    let onCopy: () -> Void
    let onPaste: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    let onReveal: () -> Void

    private var hasImageData: Bool {
        item.kind == .image && item.imageData != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if hasImageData {
                imageFocusedLayout
            } else {
                standardLayout
            }

            Divider()
                .opacity(0.55)

            metadataBar
        }
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.34), lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            DownwardTip()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.70))
                .frame(width: 34, height: 18)
                .offset(y: 15)
                .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 14)
    }

    private var standardLayout: some View {
        HStack(alignment: .top, spacing: 18) {
            leadingIcon

            previewContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            actionButtons
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var imageFocusedLayout: some View {
        HStack(alignment: .top, spacing: 18) {
            if let data = item.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.30), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Image Preview", systemImage: item.kind.symbolName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(item.title)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)

                Text(item.content)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let size = item.imagePixelSize {
                    Text("\(size.width) x \(size.height)")
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(item.kind.accentColor)
                }

                Spacer(minLength: 8)

                actionButtons
            }
            .frame(width: 230)
            .frame(maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var metadataBar: some View {
        HStack(spacing: 8) {
            Label(item.sourceApp, systemImage: "app.dashed")
            Text("·")
            Text(item.createdAt.cutPasteRelativeLabel)
            Text("·")
            Text(item.cardFooter)
            Spacer()
            if item.kind == .file {
                Button("Reveal in Finder", action: onReveal)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var leadingIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(item.kind.accentColor)
            Image(systemName: item.kind.symbolName)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: 62, height: 62)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.kind {
        case .image:
            imageFallbackPreview
        case .file:
            filePreview
        case .color:
            colorPreview
        case .link:
            linkPreview
        case .text:
            textPreview
        }
    }

    private var imageFallbackPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.title2.weight(.bold))
            Text(item.content)
                .font(.callout)
                .foregroundStyle(.secondary)
            if let size = item.imagePixelSize {
                Text("Pixel size: \(size.width) x \(size.height)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var filePreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.title2.weight(.bold))
            ForEach(item.filePaths.prefix(3), id: \.self) { path in
                Label(URL(fileURLWithPath: path).lastPathComponent, systemImage: "doc")
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
            }
            if item.filePaths.count > 3 {
                Text("+ \(item.filePaths.count - 3) more files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var colorPreview: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(cutPasteHex: item.colorHex ?? item.content))
                .frame(width: 150, height: 92)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.38), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 8) {
                Text(item.colorHex ?? item.content)
                    .font(.title2.monospaced().weight(.bold))
                Text("Color value copied from \(item.sourceApp)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var linkPreview: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(item.title)
                .font(.title2.weight(.bold))
                .lineLimit(1)
            Text(item.content)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 7) {
                Image(systemName: "safari")
                Text(URL(string: item.content)?.host(percentEncoded: false) ?? "Link")
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(item.kind.softColor, in: Capsule())
        }
    }

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(item.title)
                .font(.title2.weight(.bold))
                .lineLimit(1)
            Text(item.content)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(5)
                .textSelection(.enabled)
        }
    }

    private var actionButtons: some View {
        VStack(alignment: .trailing, spacing: 9) {
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
                    .frame(width: 104)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if showsPasteAction {
                Button(action: onPaste) {
                    Label("Paste", systemImage: "arrow.down.doc.fill")
                        .frame(width: 104)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            HStack(spacing: 8) {
                Button(action: onTogglePin) {
                    Image(systemName: item.isPinned ? "pin.slash" : "pin")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help(item.isPinned ? "Unpin" : "Pin")

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help("Delete")
            }
        }
    }
}

private struct DownwardTip: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
