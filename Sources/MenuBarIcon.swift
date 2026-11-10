import AppKit

/// Draws the coloured dot shown in the menu bar.
enum MenuBarIcon {
    static func image(for indicator: StatusModel.Indicator) -> NSImage {
        let color: NSColor = switch indicator {
        case .offPeak: .systemGreen
        case .peak: .systemOrange
        case .incident: .systemRed
        }
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let dot = NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 4))
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
}
