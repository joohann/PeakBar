import SwiftUI

/// What sits in the menu bar itself: the coloured dot plus optional short text,
/// e.g. "42% · Peak 2h 15m". Both parts can be switched off in the panel.
struct MenuBarLabel: View {
    @ObservedObject var model: StatusModel
    let l: Localizing

    var body: some View {
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcon.image(for: model.indicator))
            if !text.isEmpty {
                Text(text).monospacedDigit()
            }
        }
    }

    private var text: String {
        var parts: [String] = []
        if model.showMenuBarUsage, let session = model.usage?.session {
            parts.append(Formatters.percent(session.percent))
        }
        if model.showMenuBarText {
            parts.append(model.peak.isPeak
                ? l.t("bar.peak", Formatters.duration(from: model.now, to: model.peak.nextChange))
                : l.t("bar.offpeak"))
        }
        return parts.joined(separator: " · ")
    }
}
