import SwiftUI

/// What sits in the menu bar itself: the coloured dot plus optional short text,
/// e.g. "42% · Peak 2h 15m". When the weekly limit is at risk it shows "W 86%"
/// and a ring around the dot instead of the session percentage.
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
        guard model.showsWeekWarning, let pace = model.weekPace else { return nil }
        return pace.level == .critical ? .systemRed : .systemOrange
    }

    private var text: String {
        let s = model.settings
        var parts: [String] = []
        if model.showsWeekWarning, let pace = model.weekPace {
            parts.append(l.t("bar.week", Formatters.percent(pace.used * 100)))
        } else if s.showMenuBarUsage, let session = model.usage?.session {
            parts.append(Formatters.percent(session.percent))
        }
        if s.showMenuBarText {
            parts.append(model.peak.isPeak
                ? l.t("bar.peak", Formatters.duration(from: model.now, to: model.peak.nextChange))
                : l.t("bar.offpeak"))
        }
        return parts.joined(separator: " · ")
    }
}
