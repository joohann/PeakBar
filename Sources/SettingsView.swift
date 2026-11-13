import SwiftUI

/// Back of the card: all settings, grouped like System Settings. Writes go through StatusModel.update.
struct SettingsView: View {
    @ObservedObject var model: StatusModel
    let l: Localizing
    let onDone: () -> Void

    private static let startMinutes = [0, 1, 2, 5, 10, 15, 30, 60]
    private static let endMinutes = [1, 2, 5, 10, 15, 30, 60]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(l.t("settings.title")).font(.headline)
                Spacer()
                Button(l.t("action.done"), action: onDone).controlSize(.small).keyboardShortcut(.defaultAction)
            }
            group("settings.general") {
                SettingsRow(symbol: "power", tint: .gray, title: l.t("action.launchAtLogin")) {
                    SettingsSwitch(isOn: Binding(get: { model.launchAtLogin },
                                                 set: { _ in model.toggleLaunchAtLogin() }))
                }
                SettingsDivider()
                SettingsRow(symbol: "arrow.down.circle", tint: .blue, title: l.t("settings.checkForUpdates")) {
                    Button(l.t("action.checkNow"), action: model.checkForUpdates).controlSize(.mini)
                    SettingsSwitch(isOn: binding(\.checkForUpdates))
                }
            }
            group("settings.menuBar") {
                row("percent", .green, "action.showMenuBarUsage", \.showMenuBarUsage)
                SettingsDivider()
                row("clock", .orange, "action.showMenuBarText", \.showMenuBarText)
                SettingsDivider()
                row(nil, .clear, "settings.peakOnlyDuringPeak", \.peakTextOnlyDuringPeak,
                    enabled: model.settings.showMenuBarText)
                SettingsDivider()
                row("circle.circle", .red, "settings.warnWeek", \.warnWeekInMenuBar)
            }
            group("settings.notifications") {
                row("sunrise", .orange, "settings.notifyPeakStart", \.notifyPeakStart,
                    minutes: \.peakStartMinutes, options: Self.startMinutes)
                SettingsDivider()
                row("hourglass", .orange, "settings.notifyPeakSoon", \.notifyPeakSoon,
                    minutes: \.peakSoonMinutes, options: Self.endMinutes)
                SettingsDivider()
                row("sunset", .green, "settings.notifyPeakEnded", \.notifyPeakEnded)
                SettingsDivider()
                row("gauge.with.dots.needle.67percent", .purple, "settings.notifySession", \.notifySession)
                SettingsDivider()
                row("arrow.clockwise", .purple, "settings.notifySessionReset", \.notifySessionReset)
                SettingsDivider()
                row("calendar", .purple, "settings.notifyWeek", \.notifyWeek)
                SettingsDivider()
                row("exclamationmark.triangle", .red, "settings.notifyIncidents", \.notifyIncidents)
                SettingsDivider()
                row("sparkles", .blue, "settings.notifyUpdate", \.notifyUpdate,
                    enabled: model.settings.checkForUpdates)
            }
            if model.notificationsDenied && model.settings.wantsNotifications {
                Text(l.t("settings.notificationsDenied")).font(.caption).foregroundStyle(.orange)
                    .padding(.top, 6)
            }
            HStack {
                Text(l.t("settings.version", model.config.version)).font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button(l.t("action.quit", model.config.appName)) { NSApp.terminate(nil) }.controlSize(.small)
            }
            .padding(.top, 10)
        }
    }

    private func group<Content: View>(_ key: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(l.t(key)).font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
        }
        .padding(.top, 10)
    }

    /// A row with a switch; `symbol == nil` makes it an indented sub-option of the row above.
    private func row(_ symbol: String?, _ tint: Color, _ key: String, _ flag: WritableKeyPath<AppSettings, Bool>,
                     enabled: Bool = true) -> some View {
        SettingsRow(symbol: symbol, tint: tint, title: l.t(key)) {
            SettingsSwitch(isOn: binding(flag))
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    /// A row with a minutes menu ("5 min") before its switch.
    private func row(_ symbol: String, _ tint: Color, _ key: String, _ flag: WritableKeyPath<AppSettings, Bool>,
                     minutes: WritableKeyPath<AppSettings, Int>, options: [Int]) -> some View {
        let value = model.settings[keyPath: minutes]
        let on = model.settings[keyPath: flag]
        return SettingsRow(symbol: symbol, tint: tint, title: l.t(key)) {
            Menu {
                ForEach(Array(Set(options + [value])).sorted(), id: \.self) { m in
                    Button(minutesLabel(m)) { model.update { $0[keyPath: minutes] = m } }
                }
            } label: {
                Text(minutesLabel(value)).monospacedDigit()
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .controlSize(.small)
            .disabled(!on)
            .opacity(on ? 1 : 0.5)
            SettingsSwitch(isOn: binding(flag))
        }
    }

    private func minutesLabel(_ m: Int) -> String {
        m == 0 ? l.t("settings.atStart") : l.t("settings.minutes", m)
    }

    private func binding<T>(_ path: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { model.settings[keyPath: path] },
                set: { value in model.update { $0[keyPath: path] = value } })
    }
}

/// One line in a settings group: a coloured icon, a title and trailing controls.
struct SettingsRow<Trailing: View>: View {
    let symbol: String?
    let tint: Color
    let title: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(RoundedRectangle(cornerRadius: 5).fill(tint))
            } else {
                Color.clear.frame(width: 20, height: 1)
            }
            Text(title)
                .font(symbol == nil ? .callout : .body)
                .foregroundStyle(symbol == nil ? .secondary : .primary)
                .lineLimit(1)
            Spacer(minLength: 6)
            trailing
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 28)
    }
}

/// A small macOS switch without a label.
struct SettingsSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.mini)
    }
}

/// Hairline between rows, aligned with the titles.
struct SettingsDivider: View {
    var body: some View { Divider().padding(.leading, 36) }
}
