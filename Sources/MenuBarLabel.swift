import SwiftUI

/// What sits in the menu bar itself: the coloured dot plus optional short text,
/// e.g. "42% · Peak 2h 15m". The percentage is always the session; when weekly
/// usage is high the dot gets an orange (80%) or red (90%) ring.
struct MenuBarLabel: View {
    @ObservedObject var model: StatusModel
    let l: Localizing

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcon.image(for: model.indicator, ring: ring))
            if !text.isEmpty {
                Text(text).monospacedDigit()
            }
        }
    }

    private var ring: NSColor? {
        switch model.weekRing {
        case .critical?: return .systemRed
        case .some: return .systemOrange
        case nil: return nil
        }
    }

    private var text: String {
        let s = model.settings
        var parts: [String] = []
        if s.showMenuBarUsage, let session = model.usage?.session {
            parts.append(Formatters.percent(session.percent))
        }
        if s.showMenuBarText, model.peak.isPeak || !s.peakTextOnlyDuringPeak {
            parts.append(model.peak.isPeak
                ? l.t("bar.peak", Formatters.duration(from: model.now, to: model.peak.nextChange))
                : l.t("bar.offpeak"))
        }
        return parts.joined(separator: " · ")
    }
}
