import Foundation

/// All user settings, as one value object.
struct AppSettings: Equatable {
    var showMenuBarText = true
    var showMenuBarUsage = true
    var warnWeekInMenuBar = true
    var notifyPeakSoon = true
    var peakSoonMinutes = 5
    var notifyPeakEnded = true
    var notifyWeek = true

    var wantsNotifications: Bool { notifyPeakSoon || notifyPeakEnded || notifyWeek }
}

/// Persists settings and which weekly warnings were already sent.
protocol PreferencesStoring: AnyObject {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
    var sentWeekWarnings: Set<String> { get set }
}

final class UserDefaultsPreferences: PreferencesStoring {
    private enum Key {
        static let showMenuBarText = "showMenuBarText"
        static let showMenuBarUsage = "showMenuBarUsage"
        static let warnWeekInMenuBar = "warnWeekInMenuBar"
        static let notifyPeakSoon = "notifyPeakSoon"
        static let peakSoonMinutes = "peakSoonMinutes"
        static let notifyPeakEnded = "notifyPeakEnded"
        static let notifyWeek = "notifyWeek"
        static let sentWeekWarnings = "sentWeekWarnings"
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let d = AppSettings()
        defaults.register(defaults: [
            Key.showMenuBarText: d.showMenuBarText,
            Key.showMenuBarUsage: d.showMenuBarUsage,
            Key.warnWeekInMenuBar: d.warnWeekInMenuBar,
            Key.notifyPeakSoon: d.notifyPeakSoon,
            Key.peakSoonMinutes: d.peakSoonMinutes,
            Key.notifyPeakEnded: d.notifyPeakEnded,
            Key.notifyWeek: d.notifyWeek,
        ])
    }

    func load() -> AppSettings {
        AppSettings(
            showMenuBarText: defaults.bool(forKey: Key.showMenuBarText),
            showMenuBarUsage: defaults.bool(forKey: Key.showMenuBarUsage),
            warnWeekInMenuBar: defaults.bool(forKey: Key.warnWeekInMenuBar),
            notifyPeakSoon: defaults.bool(forKey: Key.notifyPeakSoon),
            peakSoonMinutes: min(max(defaults.integer(forKey: Key.peakSoonMinutes), 1), 60),
            notifyPeakEnded: defaults.bool(forKey: Key.notifyPeakEnded),
            notifyWeek: defaults.bool(forKey: Key.notifyWeek)
        )
    }

    func save(_ s: AppSettings) {
        defaults.set(s.showMenuBarText, forKey: Key.showMenuBarText)
        defaults.set(s.showMenuBarUsage, forKey: Key.showMenuBarUsage)
        defaults.set(s.warnWeekInMenuBar, forKey: Key.warnWeekInMenuBar)
        defaults.set(s.notifyPeakSoon, forKey: Key.notifyPeakSoon)
        defaults.set(s.peakSoonMinutes, forKey: Key.peakSoonMinutes)
        defaults.set(s.notifyPeakEnded, forKey: Key.notifyPeakEnded)
        defaults.set(s.notifyWeek, forKey: Key.notifyWeek)
    }

    var sentWeekWarnings: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.sentWeekWarnings) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Key.sentWeekWarnings) }
    }
}
