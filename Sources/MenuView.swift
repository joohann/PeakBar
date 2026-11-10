import SwiftUI

/// The panel: a card with the status on the front and settings on the back.
struct MenuView: View {
    @ObservedObject var model: StatusModel
    let l: Localizing
    @State var showsSettings = false
    @State private var angle: Double = 0

    var body: some View {
        Group {
            if showsSettings {
                SettingsView(model: model, l: l, onDone: flip)
            } else {
                StatusFront(model: model, l: l, onSettings: flip)
            }
        }
        .padding(14)
        .frame(width: 300)
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }

    /// Turns the card over: rotate to the edge, swap faces, rotate back in.
    private func flip() {
        withAnimation(.easeIn(duration: 0.12)) { angle = 90 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            showsSettings.toggle()
            angle = -90
            withAnimation(.easeOut(duration: 0.12)) { angle = 0 }
        }
    }
}

/// Front of the card. Display only; all logic lives in StatusModel.
struct StatusFront: View {
    @ObservedObject var model: StatusModel
    let l: Localizing
    let onSettings: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(nsImage: MenuBarIcon.image(for: model.peak.isPeak ? .peak : .offPeak))
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.t(model.peak.isPeak ? "state.peak" : "state.offpeak")).font(.headline)
                    Text(l.t(model.peak.isPeak ? "detail.peak" : "detail.offpeak"))
                        .font(.callout).foregroundStyle(.secondary)
                    Text(countdownText).font(.callout.monospacedDigit())
                }
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    IconButton(symbol: "arrow.clockwise", help: l.t("action.refresh"),
                               spinning: model.isRefreshing, action: model.refresh)
                    IconButton(symbol: "gearshape", help: l.t("action.settings"), action: onSettings)
                }
            }
            Divider()
            UsageSection(usage: model.usage, error: model.usageError, pace: model.weekPace, l: l)
            Divider()
            row(l.t("window.label"), windowText)
            serviceSection
        }
    }

    @ViewBuilder
    private var serviceSection: some View {
        let text: String = {
            if let s = model.service {
                return s.level == .operational ? l.t("service.operational") : s.description
            }
            return model.serviceFailed ? l.t("service.unavailable") : l.t("service.loading")
        }()
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                row(l.t("service.label"), text, alert: model.service?.level == .degraded)
                Spacer()
                IconButton(symbol: "arrow.up.right.square", help: l.t("action.openStatus")) {
                    openURL(model.config.status.pageUrl)
                }
            }
            ForEach(model.service?.incidents ?? [], id: \.self) { name in
                Text("• \(name)").font(.caption).foregroundStyle(.red)
            }
            if let s = model.service {
                Text(l.t("service.updated", Formatters.time.string(from: s.fetchedAt)))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func row(_ label: String, _ value: String, alert: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).foregroundStyle(alert ? .red : .primary)
        }
    }

    private var countdownText: String {
        let remaining = Formatters.duration(from: model.now, to: model.peak.nextChange)
        return l.t(model.peak.isPeak ? "countdown.peakEndsIn" : "countdown.peakStartsIn", remaining)
    }

    private var windowText: String {
        guard let w = model.window else { return "–" }
        return l.t("window.value", Formatters.weekdays(w.weekdays),
                   Formatters.time.string(from: w.start), Formatters.time.string(from: w.end))
    }
}

/// Small borderless icon button with a tooltip; optionally spins while busy.
struct IconButton: View {
    let symbol: String
    let help: String
    var spinning = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(spinning ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default,
                           value: spinning)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(help)
        .accessibilityLabel(help)
    }
}
