import SwiftUI

/// Back of the card: all settings. Writes go through StatusModel.update.
struct SettingsView: View {
    @ObservedObject var model: StatusModel
    let l: Localizing
    let onDone: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(l.t("settings.title")).font(.headline)
                Spacer()
                Button(l.t("action.done"), action: onDone).controlSize(.small).keyboardShortcut(.defaultAction)
            }
            Divider()
            section(l.t("settings.general")) {
                Toggle(l.t("action.launchAtLogin"), isOn: Binding(
                    get: { model.launchAtLogin }, set: { _ in model.toggleLaunchAtLogin() }))
                HStack(spacing: 4) {
                    toggle("settings.checkForUpdates", \.checkForUpdates)
                    Spacer(minLength: 8)
                    Button(l.t("action.checkNow"), action: model.checkForUpdates).controlSize(.mini)
                }
                toggle("settings.notifyUpdate", \.notifyUpdate)
                    .padding(.leading, 20)
                    .disabled(!model.settings.checkForUpdates)
            }
            section(l.t("settings.menuBar")) {
                toggle("action.showMenuBarUsage", \.showMenuBarUsage)
                toggle("action.showMenuBarText", \.showMenuBarText)
                toggle("settings.peakOnlyDuringPeak", \.peakTextOnlyDuringPeak)
                    .padding(.leading, 20)
                    .disabled(!model.settings.showMenuBarText)
                toggle("settings.warnWeek", \.warnWeekInMenuBar)
            }
            section(l.t("settings.notifyPeak")) {
                toggle("settings.notifyPeakStart", \.notifyPeakStart, minutes: \.peakStartMinutes, in: 0...60)
                toggle("settings.notifyPeakSoon", \.notifyPeakSoon, minutes: \.peakSoonMinutes, in: 1...60)
                toggle("settings.notifyPeakEnded", \.notifyPeakEnded)
            }
            section(l.t("settings.notifyUsage")) {
                toggle("settings.notifySession", \.notifySession)
                toggle("settings.notifySessionReset", \.notifySessionReset)
                toggle("settings.notifyWeek", \.notifyWeek)
            }
            section(l.t("settings.notifyStatus")) {
                toggle("settings.notifyIncidents", \.notifyIncidents)
            }
            if model.notificationsDenied && model.settings.wantsNotifications {
                Text(l.t("settings.notificationsDenied")).font(.caption).foregroundStyle(.orange)
            }
            Divider()
            HStack {
                Button(l.t("action.openStatus")) { openURL(model.config.status.pageUrl) }
                Spacer()
                Text(l.t("settings.version", model.config.version)).font(.caption).foregroundStyle(.tertiary)
                Spacer()
                Button(l.t("action.quit", model.config.appName)) { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
        .toggleStyle(.checkbox)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    /// A toggle with its minutes stepper on the same line, e.g. "Peak hours start   5 min before".
    private func toggle(_ key: String, _ flag: WritableKeyPath<AppSettings, Bool>,
                        minutes: WritableKeyPath<AppSettings, Int>, in range: ClosedRange<Int>) -> some View {
        let value = model.settings[keyPath: minutes]
        let on = model.settings[keyPath: flag]
        let label = value == 0 ? l.t("settings.atStart") : l.t("settings.minutesBefore", value)
        return HStack(spacing: 4) {
            toggle(key, flag)
            Spacer(minLength: 8)
            Group {
                Text(label).monospacedDigit().foregroundStyle(.secondary)
                Stepper("", value: binding(minutes), in: range).labelsHidden().controlSize(.mini)
            }
            .disabled(!on)
            .opacity(on ? 1 : 0.5)
        }
    }

    private func toggle(_ key: String, _ path: WritableKeyPath<AppSettings, Bool>) -> some View {
        Toggle(l.t(key), isOn: binding(path))
    }

    private func binding<T>(_ path: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { model.settings[keyPath: path] },
                set: { value in model.update { $0[keyPath: path] = value } })
    }
}

