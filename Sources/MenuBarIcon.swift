import AppKit

/// Draws what is shown in the menu bar: a green (off-peak) or orange (peak) dot, optionally with a
/// weekly-usage ring, and during a Claude disruption a yellow caution triangle before the dot.
/// One image, because a menu bar label shows a single image.
enum MenuBarIcon {
    private static let side: CGFloat = 18
    private static let gap: CGFloat = 3

    static func image(for indicator: StatusModel.Indicator, ring: NSColor? = nil, caution: Bool = false) -> NSImage {
        let color: NSColor = indicator == .peak ? .systemOrange : .systemGreen
        let triangle = caution ? cautionSymbol() : nil
        let width = side + (triangle.map { $0.size.width + gap } ?? 0)
        let image = NSImage(size: NSSize(width: width, height: side), flipped: false) { _ in
            var x: CGFloat = 0
            if let triangle {
                let s = triangle.size
                triangle.draw(in: NSRect(x: 0, y: (side - s.height) / 2, width: s.width, height: s.height))
                x = s.width + gap
            }
            let rect = NSRect(x: x, y: 0, width: side, height: side)
            if let ring {
                let outer = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
                outer.lineWidth = 2
                ring.setStroke()
                outer.stroke()
            }
            let dot = NSBezierPath(ovalIn: rect.insetBy(dx: ring == nil ? 4 : 5, dy: ring == nil ? 4 : 5))
            color.setFill()
            dot.fill()
            NSColor.black.withAlphaComponent(0.25).setStroke()
            dot.lineWidth = 0.5
            dot.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }

    /// The system caution sign: a yellow triangle with a dark exclamation mark, readable on light and dark bars.
    private static func cautionSymbol() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            .applying(.init(paletteColors: [.black, .systemYellow]))
        return NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }
}
