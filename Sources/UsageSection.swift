import SwiftUI

/// Session and weekly usage. The week bar shows how much of the week has passed,
/// a forecast and a daily budget. Display only.
struct UsageSection: View {
    let usage: Usage?
    let error: UsageError?
    let pace: WeekPace?
    let l: Localizing

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let s = usage?.session {
                UsageBar(label: l.t("usage.session"), percent: s.percent, color: sessionColor(s.percent))
                if let reset = s.resetsAt { caption(l.t("usage.resets", Formatters.reset(reset))) }
            }
            if let w = usage?.week {
                UsageBar(label: l.t("usage.week"), percent: w.percent,
                         color: weekColor, marker: pace?.elapsed)
                weekDetails
            }
            if let message {
                Text(message).font(.caption).foregroundStyle(usage == nil ? .primary : .secondary)
            }
        }
    }

    @ViewBuilder
    private var weekDetails: some View {
        if let pace {
            VStack(alignment: .leading, spacing: 2) {
                if pace.used >= 1 {
                    caption(l.t("week.reached", Formatters.reset(pace.resetsAt)), color: .red)
                } else if let out = pace.runsOutAt, pace.projected != nil {
                    caption(l.t("week.runsOut", Formatters.reset(out)), color: weekColor)
                } else if let projected = pace.projected {
                    caption(l.t("week.onTrack", Formatters.percent(projected * 100)))
                }
                HStack(spacing: 0) {
                    caption(l.t("week.passed", Formatters.percent(pace.elapsed * 100)))
                    if let budget = pace.dailyBudget {
                        caption(" · " + l.t("week.budget", Formatters.percent(budget * 100)))
                    }
                }
                caption(l.t("usage.resets", Formatters.reset(pace.resetsAt)))
            }
        }
    }

    private func caption(_ text: String, color: Color = .secondary) -> some View {
        Text(text).font(.caption2).foregroundStyle(color)
    }

    private var title: String {
        guard let plan = usage?.plan, !plan.isEmpty else { return l.t("usage.label") }
        return l.t("usage.labelPlan", plan.capitalized)
    }

    private var message: String? {
        switch error {
        case .notSignedIn?: return l.t("usage.notSignedIn")
        case .keychainDenied?: return l.t("usage.keychainDenied")
        case .expired?: return l.t("usage.expired")
        case .rateLimited?: return l.t("usage.rateLimited")
        case .unavailable?: return l.t("usage.unavailable")
        case nil: return usage == nil ? l.t("usage.loading") : nil
        }
    }

    private func sessionColor(_ percent: Double) -> Color {
        percent >= 90 ? .red : percent >= 70 ? .orange : .green
    }

    private var weekColor: Color {
        switch pace?.level {
        case .critical?: return .red
        case .ahead?: return .orange
        default: return .green
        }
    }
}

/// A labelled bar with an optional time marker (0…1).
struct UsageBar: View {
    let label: String
    let percent: Double
    let color: Color
    var marker: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                Spacer()
                Text(Formatters.percent(percent)).monospacedDigit().fontWeight(.medium)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 6)
                    Capsule().fill(color)
                        .frame(width: max(4, geo.size.width * min(percent, 100) / 100), height: 6)
                    if let marker {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary)
                            .frame(width: 2, height: 12)
                            .offset(x: geo.size.width * marker - 1)
                    }
                }
                .frame(height: 12)
            }
            .frame(height: 12)
        }
    }
}
