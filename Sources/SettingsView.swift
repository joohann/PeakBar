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
                toggle("settings.warnWeek", \.warnWeekInMenuBar)
            }
            section(l.t("settings.notifications")) {
                toggle("settings.notifyPeakSoon", \.notifyPeakSoon)
                Stepper(value: binding(\.peakSoonMinutes), in: 1...60) {
                    Text(l.t("settings.minutesBefore", model.settings.peakSoonMinutes)).monospacedDigit()
                }
                .padding(.leading, 20)
                .disabled(!model.settings.notifyPeakSoon)
                toggle("settings.notifyPeakEnded", \.notifyPeakEnded)
                toggle("settings.notifyWeek", \.notifyWeek)
                if model.notificationsDenied && model.settings.wantsNotifications {
                    Text(l.t("settings.notificationsDenied")).font(.caption).foregroundStyle(.orange)
                }
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

    private func toggle(_ key: String, _ path: WritableKeyPath<AppSettings, Bool>) -> some View {
        Toggle(l.t(key), isOn: binding(path))
    }

    private func binding<T>(_ path: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { model.settings[keyPath: path] },
                set: { value in model.update { $0[keyPath: path] = value } })
    }
}
