import AppKit

extension NSImage {
    func asMacOSAppIcon() -> NSImage? {
        let size = self.size
        let scale: CGFloat = 2.0
        let pixelSize = NSSize(width: size.width * scale, height: size.height * scale)
        
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: Int(pixelSize.width),
            height: Int(pixelSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        let rect = CGRect(origin: .zero, size: pixelSize)
        let cornerRadius = pixelSize.width * 0.178
        
        let shadowOffset = CGSize(width: 0, height: -5 * scale)
        let shadowBlur: CGFloat = 14 * scale
        let shadowColor = NSColor.black.withAlphaComponent(0.22).cgColor
        
        context.saveGState()
        
        let shadowRect = rect.offsetBy(dx: shadowOffset.width, dy: shadowOffset.height)
        let shadowPath = CGPath(
            roundedRect: shadowRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        
        context.addPath(shadowPath)
        context.setShadow(offset: CGSize(width: 0, height: 2 * scale), blur: shadowBlur, color: shadowColor)
        context.setFillColor(NSColor.black.cgColor)
        context.fillPath()
        
        context.restoreGState()
        
        context.saveGState()
        
        let iconPath = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        context.addPath(iconPath)
        context.clip()
        
        context.draw(cgImage, in: rect)
        
        context.restoreGState()
        
        let borderPath = CGPath(
            roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: cornerRadius - 0.5,
            cornerHeight: cornerRadius - 0.5,
            transform: nil
        )
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.1).cgColor)
        context.setLineWidth(1.0)
        context.addPath(borderPath)
        context.strokePath()
        
        let highlightRect = CGRect(
            x: 0,
            y: pixelSize.height * 0.5,
            width: pixelSize.width,
            height: pixelSize.height * 0.5
        )
        _ = CGPath(
            roundedRect: highlightRect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        
        context.saveGState()
        
        let iconClipPath = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        context.addPath(iconClipPath)
        context.clip()
        
        let highlightGradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [
                NSColor.white.withAlphaComponent(0.0).cgColor,
                NSColor.white.withAlphaComponent(0.06).cgColor
            ] as CFArray,
            locations: [0.0, 1.0]
        )!
        
        context.drawLinearGradient(
            highlightGradient,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.midY),
            options: []
        )
        
        context.restoreGState()
        
        guard let resultCGImage = context.makeImage() else {
            return nil
        }
        
        let result = NSImage(cgImage: resultCGImage, size: size)
        result.isTemplate = false
        return result
    }
}
