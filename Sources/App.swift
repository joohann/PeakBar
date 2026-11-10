import SwiftUI

@main
struct MenuBarApp: App {
    @StateObject private var model: StatusModel
    private let localizer: Localizing = BundleLocalizer()

    init() {
        do {
            let config = try BundleConfigLoader().load()
            let model = StatusModel(
                config: config,
                schedule: try WeeklyPeakSchedule(config: config.peak),
                provider: StatuspageClient(url: config.status.url),
                usageProvider: OAuthUsageClient(
                    url: config.usage.url,
                    betaHeader: config.usage.betaHeader,
                    userAgent: "\(config.appName)/\(config.version)",
                    tokens: KeychainTokenProvider(service: config.usage.keychainService),
                    refresher: ClaudeCLIRefresher(candidatePaths: config.usage.cliPaths)
                ),
                loginItem: MainAppLoginItem(),
                preferences: UserDefaultsPreferences()
            )
            _model = StateObject(wrappedValue: model)
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
