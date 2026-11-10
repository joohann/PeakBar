import AppKit

/// Draws the app icon at any size (macOS icon grid: 1024 canvas, 824 body, radius 185).
enum IconDrawing {
    static func image(size: CGFloat) -> NSBitmapImageRep {
        let px = Int(size)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.scaleBy(x: size / 1024, y: size / 1024)
        drawGauge(ctx)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static let body = CGRect(x: 100, y: 100, width: 824, height: 824)

    private static func squircle(_ ctx: CGContext, colors: [NSColor]) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        let path = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
        ctx.addPath(path)
        ctx.setFillColor(colors[0].cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors.map(\.cgColor) as CFArray, locations: nil)!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
        ctx.restoreGState()
    }

    /// A usage gauge, green to orange to red, with a needle.
    private static func drawGauge(_ ctx: CGContext) {
        squircle(ctx, colors: [NSColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1),
                               NSColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1)])
        let center = CGPoint(x: 512, y: 430)
        let radius: CGFloat = 270
        ctx.setLineCap(.round)
        ctx.setLineWidth(70)
        // Track
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.08).cgColor)
        ctx.addArc(center: center, radius: radius, startAngle: .pi * 1.0, endAngle: 0, clockwise: true)
        ctx.strokePath()
        // Coloured segments
        let segments: [(CGFloat, CGFloat, NSColor)] = [
            (1.0, 0.70, .systemGreen), (0.64, 0.38, .systemOrange), (0.32, 0.0, .systemRed),
        ]
        for (start, end, color) in segments {
            ctx.setStrokeColor(color.cgColor)
            ctx.addArc(center: center, radius: radius, startAngle: .pi * start, endAngle: .pi * end, clockwise: true)
            ctx.strokePath()
        }
        // Needle
        let angle = CGFloat.pi * 0.42
        let tip = CGPoint(x: center.x + cos(angle) * (radius - 70), y: center.y + sin(angle) * (radius - 70))
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(26)
        ctx.move(to: center)
        ctx.addLine(to: tip)
        ctx.strokePath()
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - 42, y: center.y - 42, width: 84, height: 84))
    }

}
