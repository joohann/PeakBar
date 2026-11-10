import AppKit
import Combine

/// Combines the peak schedule, live service status and subscription usage for the UI.
@MainActor
final class StatusModel: ObservableObject {
    enum Indicator { case offPeak, peak, incident }

    @Published private(set) var now = Date()
    @Published private(set) var service: ServiceStatus?
    @Published private(set) var serviceFailed = false
    @Published private(set) var usage: Usage?
    @Published private(set) var usageError: UsageError?
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var showMenuBarText: Bool
    @Published private(set) var showMenuBarUsage: Bool

    let config: AppConfig
    private let schedule: PeakScheduling
    private let provider: ServiceStatusProviding
    private let usageProvider: UsageProviding
    private let loginItem: LoginItemManaging
    private let preferences: PreferencesStoring
    private var ticker: AnyCancellable?
    private var wake: AnyCancellable?
    private var tasks: [Task<Void, Never>] = []

    init(config: AppConfig, schedule: PeakScheduling, provider: ServiceStatusProviding,
         usageProvider: UsageProviding, loginItem: LoginItemManaging, preferences: PreferencesStoring) {
        self.config = config
        self.schedule = schedule
        self.provider = provider
        self.usageProvider = usageProvider
        self.loginItem = loginItem
        self.preferences = preferences
        self.launchAtLogin = loginItem.isEnabled
        self.showMenuBarText = preferences.showMenuBarText
        self.showMenuBarUsage = preferences.showMenuBarUsage
        start()
    }

    var peak: PeakState { schedule.state(at: now) }
    var window: LocalWindow? { schedule.localWindow(near: now) }

    var indicator: Indicator {
        if service?.level == .degraded { return .incident }
        return peak.isPeak ? .peak : .offPeak
    }

    func refresh() {
        Task {
            await fetchStatus()
            _ = await fetchUsage()
        }
    }

    func toggleLaunchAtLogin() {
        try? loginItem.setEnabled(!loginItem.isEnabled)
        launchAtLogin = loginItem.isEnabled
    }

    func toggleMenuBarText() {
        preferences.showMenuBarText.toggle()
        showMenuBarText = preferences.showMenuBarText
    }

    func toggleMenuBarUsage() {
        preferences.showMenuBarUsage.toggle()
        showMenuBarUsage = preferences.showMenuBarUsage
    }

    private func start() {
        ticker = Timer.publish(every: 15, tolerance: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] in self?.now = $0 }
        wake = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                self?.now = Date()
                self?.refresh()
            }
        let statusInterval = max(60, config.status.pollSeconds)
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchStatus()
                try? await Task.sleep(nanoseconds: UInt64(statusInterval * 1e9))
            }
        })
        // The usage endpoint is rate limited: at most every 5 minutes, backing off up to 30 minutes.
        let usageInterval = max(300, config.usage.pollSeconds)
        tasks.append(Task { [weak self] in
            var delay = usageInterval
            while !Task.isCancelled {
                guard let ok = await self?.fetchUsage() else { return }
                delay = ok ? usageInterval : min(delay * 2, 1800)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1e9))
            }
        })
    }

    private func fetchStatus() async {
        do {
            service = try await provider.fetch()
            serviceFailed = false
        } catch {
            serviceFailed = true
        }
        now = Date()
    }

    /// Returns false when the next attempt should back off.
    private func fetchUsage() async -> Bool {
        do {
            usage = try await usageProvider.fetch()
            usageError = nil
            return true
        } catch let error as UsageError {
            Log.usage.info("usage fetch failed: \(String(describing: error), privacy: .public)")
            usageError = error
        } catch {
            Log.usage.info("usage fetch failed: network")
            usageError = .unavailable
        }
        return false
    }
}
