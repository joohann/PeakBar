import SwiftUI

/// Content of the menu bar panel. Display only; all logic lives in StatusModel.
struct MenuView: View {
    @ObservedObject var model: StatusModel
    let l: Localizing
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            UsageSection(usage: model.usage, error: model.usageError, l: l)
            Divider()
            row(l.t("window.label"), windowText)
            serviceSection
            Divider()
            Toggle(l.t("action.launchAtLogin"), isOn: Binding(
                get: { model.launchAtLogin },
                set: { _ in model.toggleLaunchAtLogin() }
            ))
            .toggleStyle(.checkbox)
            Toggle(l.t("action.showMenuBarUsage"), isOn: Binding(
                get: { model.showMenuBarUsage },
                set: { _ in model.toggleMenuBarUsage() }
            ))
            .toggleStyle(.checkbox)
            Toggle(l.t("action.showMenuBarText"), isOn: Binding(
                get: { model.showMenuBarText },
                set: { _ in model.toggleMenuBarText() }
            ))
            .toggleStyle(.checkbox)
            HStack {
                Button(l.t("action.openStatus")) { openURL(model.config.status.pageUrl) }
                Button(l.t("action.refresh")) { model.refresh() }
                Spacer()
                Button(l.t("action.quit", model.config.appName)) { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(nsImage: MenuBarIcon.image(for: model.peak.isPeak ? .peak : .offPeak))
            VStack(alignment: .leading, spacing: 2) {
                Text(l.t(model.peak.isPeak ? "state.peak" : "state.offpeak")).font(.headline)
                Text(l.t(model.peak.isPeak ? "detail.peak" : "detail.offpeak"))
                    .font(.callout).foregroundStyle(.secondary)
                Text(countdownText).font(.callout.monospacedDigit())
            }
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
            row(l.t("service.label"), text, alert: model.service?.level == .degraded)
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
