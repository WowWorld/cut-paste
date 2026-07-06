import AppKit
import SwiftUI

struct ClipboardCardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    var shortcutIndex: Int?

    @State private var isHovered = false
    @State private var previewImage: NSImage?
    @State private var previewImageFingerprint: String?

    private let cardWidth: CGFloat = 260
    private let cardHeight: CGFloat = 236
    private let headerHeight: CGFloat = 44
    private let footerHeight: CGFloat = 42
    private let cornerRadius: CGFloat = 24

    var body: some View {
        VStack(spacing: 0) {
            cardHeader
                .frame(height: headerHeight)
            cardContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            cardFooter
                .frame(height: footerHeight)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(cardBackground)
        .clipShape(cardShape)
        .overlay(
            cardShape
                .strokeBorder(borderStyle, lineWidth: isSelected ? 1.8 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if item.isPinned, shortcutIndex == nil {
                pinnedRibbon
            }
        }
        .shadow(
            color: .black.opacity(isSelected ? 0.24 : (isHovered ? 0.16 : 0.11)),
            radius: isSelected ? 18 : (isHovered ? 11 : 7),
            x: 0,
            y: isSelected ? 11 : (isHovered ? 7 : 4)
        )
        .scaleEffect(isSelected ? 1.018 : (isHovered ? 1.01 : 1))
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isSelected)
        .animation(.spring(response: 0.22, dampingFraction: 0.88), value: isHovered)
        .onHover { isHovered = $0 }
        .onAppear {
            loadPreviewImageIfNeeded()
        }
        .onChange(of: item.fingerprint) { _, _ in
            loadPreviewImageIfNeeded(force: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind.displayName), \(item.title)")
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var cardBackground: some View {
        ZStack {
            cardShape
                .fill(.regularMaterial)

            cardShape
                .fill(
                    LinearGradient(
                        colors: [
                            item.kind.accentColor.opacity(isSelected ? 0.30 : 0.18),
                            Color.primary.opacity(0.035),
                            Color(nsColor: .textBackgroundColor).opacity(0.74)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )

            cardShape
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var borderStyle: LinearGradient {
        LinearGradient(
            colors: isSelected
                ? [.white.opacity(0.96), item.kind.accentColor.opacity(0.72), .white.opacity(0.42)]
                : [.white.opacity(isHovered ? 0.52 : 0.30), .white.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: item.kind.symbolName)
                .font(.system(size: 14, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(.white.opacity(0.26), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.kind.displayName)
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
                .font(.caption.weight(.black))
                .lineLimit(1)

                Text(item.createdAt.cutPasteRelativeLabel)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .opacity(0.84)
            }

            Spacer(minLength: 4)

            if let shortcutIndex {
                ShortcutBadge(index: shortcutIndex)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .background(headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.18))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        switch item.kind {
        case .image:
            if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .overlay(imageScrim)
                    .background(Color.primary.opacity(0.05))
            } else {
                placeholderContent(symbol: "photo")
            }
        case .file:
            VStack(alignment: .leading, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(item.kind.softColor)
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(item.kind.accentColor)
                }
                .frame(width: 52, height: 52)

                Text(item.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(15)
            .background(contentSurface)
        case .color:
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(cutPasteHex: item.colorHex ?? item.content))
                .overlay(colorCardOverlay)
                .overlay(alignment: .bottomLeading) {
                    Text(item.colorHex ?? item.content)
                        .font(.caption.monospaced().weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.18), in: Capsule(style: .continuous))
                        .padding(10)
                        .shadow(radius: 5)
                }
                .clipped()
        case .link:
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                    Text(linkHost)
                        .lineLimit(1)
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(item.kind.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(item.kind.softColor, in: Capsule(style: .continuous))

                Text(item.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(item.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(15)
            .background(contentSurface)
        case .text:
            VStack(alignment: .leading, spacing: 0) {
                Text(item.content.trimmedForDisplay)
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(15)
            .background(contentSurface)
        }
    }

    private var cardFooter: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "app.dashed")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(item.kind.accentColor)
                Text(item.sourceApp.clipped(to: 18))
                    .lineLimit(1)
            }
            Spacer()
            Text(item.cardFooter.clipped(to: 18))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(item.kind.accentColor)
                .background(item.kind.softColor, in: Capsule(style: .continuous))
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .background(
            ZStack {
                Color(nsColor: .textBackgroundColor).opacity(0.72)
                item.kind.softColor.opacity(0.52)
            }
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.28))
                .frame(height: 1)
        }
    }

    private func placeholderContent(symbol: String) -> some View {
        ZStack {
            contentSurface
            VStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(item.kind.accentColor)
                    .symbolRenderingMode(.hierarchical)
                Text("No Preview")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var headerBackground: some View {
        ZStack {
            item.kind.accentColor
            LinearGradient(
                colors: [
                    .white.opacity(0.22),
                    .clear,
                    .black.opacity(0.16)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var contentSurface: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor).opacity(0.88)
            LinearGradient(
                colors: [
                    item.kind.softColor.opacity(0.46),
                    .clear,
                    Color.primary.opacity(0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var imageScrim: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.10)],
            startPoint: .center,
            endPoint: .bottom
        )
    }

    private var colorCardOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [.white.opacity(0.28), .clear, .black.opacity(0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(.white.opacity(index.isMultiple(of: 2) ? 0.10 : 0.04))
                }
            }
            .blendMode(.overlay)
            .opacity(0.42)
        }
    }

    private var pinnedRibbon: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: 10, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(item.kind.accentColor, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.44), lineWidth: 1))
            .shadow(color: .black.opacity(0.20), radius: 6, y: 3)
            .padding(8)
    }

    private var linkHost: String {
        URL(string: item.content)?.host(percentEncoded: false) ?? "Link"
    }

    private func loadPreviewImageIfNeeded(force: Bool = false) {
        guard item.kind == .image else {
            previewImage = nil
            previewImageFingerprint = nil
            return
        }

        guard force || previewImageFingerprint != item.fingerprint else { return }
        previewImageFingerprint = item.fingerprint

        if let data = item.imageData {
            previewImage = NSImage(data: data)
        } else {
            previewImage = nil
        }
    }
}

private struct ShortcutBadge: View {
    let index: Int

    var body: some View {
        Text("⌘\(index)")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.24), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.30), lineWidth: 1))
    }
}
