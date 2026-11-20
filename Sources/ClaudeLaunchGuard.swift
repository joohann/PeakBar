import AppKit

/// What the user chose in the peak-hours launch warning.
struct LaunchWarningAnswer: Equatable {
    let keepOpen: Bool
    let silenceToday: Bool
}

/// Asks whether the Claude app may stay open during peak hours.
@MainActor
protocol LaunchWarning {
    func ask(appName: String, peakEnds: Date) -> LaunchWarningAnswer
}

/// Watches for the Claude app being opened. During peak hours, with the setting on and not silenced
/// for today, it asks whether to keep it open and quits it otherwise. macOS offers no way to stop an
/// app before it starts, so the app is briefly visible.
@MainActor
final class ClaudeLaunchGuard {
    private let bundleIds: Set<String>
    private let schedule: PeakScheduling
    private let settings: @MainActor () -> AppSettings
    private let preferences: PreferencesStoring
    private let warning: LaunchWarning
    private let clock: () -> Date
    private var observer: NSObjectProtocol?
    private var asking = false

    init(bundleIds: Set<String>, schedule: PeakScheduling, settings: @escaping @MainActor () -> AppSettings,
         preferences: PreferencesStoring, warning: LaunchWarning, clock: @escaping () -> Date = Date.init) {
        self.bundleIds = bundleIds
        self.schedule = schedule
        self.settings = settings
        self.preferences = preferences
        self.warning = warning
        self.clock = clock
    }

    func start() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { self?.launched(app) }
        }
    }

    /// Whether opening a watched app right now deserves the warning.
    func shouldWarn(bundleId: String?) -> Bool {
        guard let bundleId, bundleIds.contains(bundleId), settings().warnClaudeLaunch else { return false }
        let now = clock()
        return schedule.state(at: now).isPeak && preferences.launchWarningSilencedDay != Self.dayKey(now)
    }

    func launched(_ app: NSRunningApplication) {
        guard !asking, shouldWarn(bundleId: app.bundleIdentifier) else { return }
        asking = true
        defer { asking = false }
        let now = clock()
        let answer = warning.ask(appName: app.localizedName ?? "Claude", peakEnds: schedule.state(at: now).nextChange)
        if answer.silenceToday { preferences.launchWarningSilencedDay = Self.dayKey(now) }
        if !answer.keepOpen {
            if !app.terminate() { Log.launch.error("Could not quit \(app.bundleIdentifier ?? "?", privacy: .public)") }
        }
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// The warning as a standard macOS alert, in front of the app that was just opened.
@MainActor
struct AlertLaunchWarning: LaunchWarning {
    let l: Localizing

    func ask(appName: String, peakEnds: Date) -> LaunchWarningAnswer {
        let alert = NSAlert()
        alert.messageText = l.t("guard.title", Formatters.time.string(from: peakEnds))
        alert.informativeText = l.t("guard.body", appName)
        alert.addButton(withTitle: l.t("guard.quit", appName))   // default: Return quits
        alert.addButton(withTitle: l.t("guard.keepOpen"))
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = l.t("guard.silenceToday")
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        return LaunchWarningAnswer(keepOpen: response == .alertSecondButtonReturn,
                                   silenceToday: alert.suppressionButton?.state == .on)
    }
}
