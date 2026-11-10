import AppKit

/// Draws the coloured dot shown in the menu bar, optionally with a warning ring.
enum MenuBarIcon {
    static func image(for indicator: StatusModel.Indicator, ring: NSColor? = nil) -> NSImage {
        let color: NSColor = switch indicator {
        case .offPeak: .systemGreen
        case .peak: .systemOrange
        case .incident: .systemRed
        }
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
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
}
