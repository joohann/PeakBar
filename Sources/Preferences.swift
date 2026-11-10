import Foundation

/// User preferences that persist between launches.
protocol PreferencesStoring: AnyObject {
    var showMenuBarText: Bool { get set }
    var showMenuBarUsage: Bool { get set }
}

final class UserDefaultsPreferences: PreferencesStoring {
    private enum Key { static let showMenuBarText = "showMenuBarText"
        static let showMenuBarUsage = "showMenuBarUsage" }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.showMenuBarText: true, Key.showMenuBarUsage: true])
    }

    var showMenuBarText: Bool {
        get { defaults.bool(forKey: Key.showMenuBarText) }
        set { defaults.set(newValue, forKey: Key.showMenuBarText) }
    }

    var showMenuBarUsage: Bool {
        get { defaults.bool(forKey: Key.showMenuBarUsage) }
        set { defaults.set(newValue, forKey: Key.showMenuBarUsage) }
    }
}
