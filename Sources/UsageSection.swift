import SwiftUI

/// Session and weekly usage with a bar each. Display only.
struct UsageSection: View {
    let usage: Usage?
    let error: UsageError?
    let l: Localizing

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let usage, usage.session != nil || usage.week != nil {
                if let s = usage.session { bar(l.t("usage.session"), s) }
                if let w = usage.week { bar(l.t("usage.week"), w) }
            }
            if let message {
                Text(message).font(.caption).foregroundStyle(usage == nil ? .primary : .secondary)
            }
        }
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

    private func bar(_ label: String, _ window: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                Spacer()
                Text(Formatters.percent(window.percent)).monospacedDigit().fontWeight(.medium)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(color(for: window.percent))
                        .frame(width: max(4, geo.size.width * window.percent / 100))
                }
            }
            .frame(height: 6)
            if let reset = window.resetsAt {
                Text(l.t("usage.resets", Formatters.reset(reset)))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func color(for percent: Double) -> Color {
        percent >= 90 ? .red : percent >= 70 ? .orange : .green
    }
}
