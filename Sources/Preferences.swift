import Foundation

/// All user settings, as one value object.
struct AppSettings: Equatable {
    // Menu bar
    var showMenuBarText = true
    var peakTextOnlyDuringPeak = true
    var showMenuBarUsage = true
    var warnWeekInMenuBar = true
    // Peak hours
    var notifyPeakStart = true
    var peakStartMinutes = 5      // 0 = at the start
    var notifyPeakSoon = true
    var peakSoonMinutes = 5
    var notifyPeakEnded = true
    // Usage
    var notifySession = true
    var notifySessionReset = true
    var notifyWeek = true
    // Claude status
    var notifyIncidents = true
    // Updates
    var checkForUpdates = true
    var notifyUpdate = true

    var wantsNotifications: Bool {
        notifyPeakStart || notifyPeakSoon || notifyPeakEnded
            || notifySession || notifySessionReset || notifyWeek || notifyIncidents
            || (checkForUpdates && notifyUpdate)
    }
}

/// Persists settings and which usage warnings were already sent.
protocol PreferencesStoring: AnyObject {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
    var sentWeekWarnings: Set<String> { get set }
    var sentSessionWarnings: Set<String> { get set }
    /// The last version an update notification was posted for, so each version notifies once.
    var notifiedUpdateVersion: String? { get set }
}

final class UserDefaultsPreferences: PreferencesStoring {
    private typealias Flag = (key: String, path: WritableKeyPath<AppSettings, Bool>)
    private typealias Number = (key: String, path: WritableKeyPath<AppSettings, Int>, range: ClosedRange<Int>)

    private static let flags: [Flag] = [
        ("showMenuBarText", \.showMenuBarText),
        ("peakTextOnlyDuringPeak", \.peakTextOnlyDuringPeak),
        ("showMenuBarUsage", \.showMenuBarUsage),
        ("warnWeekInMenuBar", \.warnWeekInMenuBar),
        ("notifyPeakStart", \.notifyPeakStart),
        ("notifyPeakSoon", \.notifyPeakSoon),
        ("notifyPeakEnded", \.notifyPeakEnded),
        ("notifySession", \.notifySession),
        ("notifySessionReset", \.notifySessionReset),
        ("notifyWeek", \.notifyWeek),
        ("notifyIncidents", \.notifyIncidents),
        ("checkForUpdates", \.checkForUpdates),
        ("notifyUpdate", \.notifyUpdate),
    ]
    private static let numbers: [Number] = [
        ("peakStartMinutes", \.peakStartMinutes, 0...60),
        ("peakSoonMinutes", \.peakSoonMinutes, 1...60),
    ]
    private enum Key {
        static let sentWeekWarnings = "sentWeekWarnings"
        static let sentSessionWarnings = "sentSessionWarnings"
        static let notifiedUpdateVersion = "notifiedUpdateVersion"
    }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let d = AppSettings()
        var registered: [String: Any] = [:]
        Self.flags.forEach { registered[$0.key] = d[keyPath: $0.path] }
        Self.numbers.forEach { registered[$0.key] = d[keyPath: $0.path] }
        defaults.register(defaults: registered)
    }

    func load() -> AppSettings {
        var s = AppSettings()
        for f in Self.flags { s[keyPath: f.path] = defaults.bool(forKey: f.key) }
        for n in Self.numbers {
            s[keyPath: n.path] = min(max(defaults.integer(forKey: n.key), n.range.lowerBound), n.range.upperBound)
        }
        return s
    }

    func save(_ s: AppSettings) {
        for f in Self.flags { defaults.set(s[keyPath: f.path], forKey: f.key) }
        for n in Self.numbers { defaults.set(s[keyPath: n.path], forKey: n.key) }
    }

    var sentWeekWarnings: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.sentWeekWarnings) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Key.sentWeekWarnings) }
    }

    var sentSessionWarnings: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.sentSessionWarnings) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Key.sentSessionWarnings) }
    }

    var notifiedUpdateVersion: String? {
        get { defaults.string(forKey: Key.notifiedUpdateVersion) }
        set { defaults.set(newValue, forKey: Key.notifiedUpdateVersion) }
    }
}
