import AppKit

extension NSImage {
    var pixelSize: PixelSize? {
        if let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return PixelSize(width: cgImage.width, height: cgImage.height)
        }

        guard let tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }

        return PixelSize(width: bitmap.pixelsWide, height: bitmap.pixelsHigh)
    }

    func pngData(maxDimension: CGFloat = 1200) -> Data? {
        let sourceSize = size
        let scale = min(1, maxDimension / max(sourceSize.width, sourceSize.height, 1))
        let targetSize = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)

        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1)
        image.unlockFocus()

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }
}
