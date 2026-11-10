import SwiftUI

/// Back of the card: all settings. Writes go through StatusModel.update.
struct SettingsView: View {
    @ObservedObject var model: StatusModel
    let l: Localizing
    let onDone: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l.t("settings.title")).font(.headline)
                Spacer()
                Button(l.t("action.done"), action: onDone).controlSize(.small).keyboardShortcut(.defaultAction)
            }
            Divider()
            section(l.t("settings.general")) {
                Toggle(l.t("action.launchAtLogin"), isOn: Binding(
                    get: { model.launchAtLogin }, set: { _ in model.toggleLaunchAtLogin() }))
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
                toggle("settings.notifyPeakStart", \.notifyPeakStart)
                minutes(\.peakStartMinutes, in: 0...60, enabled: model.settings.notifyPeakStart, zeroKey: "settings.atStart")
                toggle("settings.notifyPeakSoon", \.notifyPeakSoon)
                minutes(\.peakSoonMinutes, in: 1...60, enabled: model.settings.notifyPeakSoon)
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
                Button(l.t("action.quit", model.config.appName)) { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
        .toggleStyle(.checkbox)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    private func minutes(_ path: WritableKeyPath<AppSettings, Int>, in range: ClosedRange<Int>,
                         enabled: Bool, zeroKey: String? = nil) -> some View {
        let value = model.settings[keyPath: path]
        let label = value == 0 ? l.t(zeroKey ?? "settings.atStart") : l.t("settings.minutesBefore", value)
        return Stepper(value: binding(path), in: range) { Text(label).monospacedDigit() }
            .padding(.leading, 20)
            .disabled(!enabled)
    }

    private func toggle(_ key: String, _ path: WritableKeyPath<AppSettings, Bool>) -> some View {
        Toggle(l.t(key), isOn: binding(path))
    }

    private func binding<T>(_ path: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { model.settings[keyPath: path] },
                set: { value in model.update { $0[keyPath: path] = value } })
    }
}
