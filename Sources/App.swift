import SwiftUI

@main
struct MenuBarApp: App {
    @StateObject private var model: StatusModel
    private let localizer: Localizing

    init() {
        do {
            let config = try BundleConfigLoader().load()
            let schedule = try WeeklyPeakSchedule(config: config.peak)
            let localizer = BundleLocalizer()
            let model = StatusModel(
                config: config,
                schedule: schedule,
                provider: StatuspageClient(url: config.status.url),
                usageProvider: OAuthUsageClient(
                    url: config.usage.url,
                    betaHeader: config.usage.betaHeader,
                    userAgent: "\(config.appName)/\(config.version)",
                    tokens: KeychainTokenProvider(service: config.usage.keychainService),
                    refresher: ClaudeCLIRefresher(candidatePaths: config.usage.cliPaths)
                ),
                loginItem: MainAppLoginItem(),
                preferences: UserDefaultsPreferences(),
                notifier: UserNotificationService(),
                planner: NotificationPlanner(schedule: schedule, l: localizer),
                updater: SparkleUpdater()
            )
            _model = StateObject(wrappedValue: model)
            self.localizer = localizer
        } catch {
            fatalError("Invalid config.json: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model, l: localizer)
        } label: {
            MenuBarLabel(model: model, l: localizer)
        }
        .menuBarExtraStyle(.window)
    }
}
