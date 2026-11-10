import AppKit
import Combine

/// Combines the peak schedule, live service status, usage and settings for the UI.
@MainActor
final class StatusModel: ObservableObject {
    enum Indicator { case offPeak, peak, incident }

    @Published private(set) var now = Date()
    @Published private(set) var service: ServiceStatus?
    @Published private(set) var serviceFailed = false
    @Published private(set) var usage: Usage?
    @Published private(set) var usageError: UsageError?
    @Published private(set) var isRefreshing = false
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var settings: AppSettings
    @Published private(set) var notificationsDenied = false

    let config: AppConfig
    private let schedule: PeakScheduling
    private let provider: ServiceStatusProviding
    private let usageProvider: UsageProviding
    private let loginItem: LoginItemManaging
    private let preferences: PreferencesStoring
    private let notifier: NotificationPosting
    private let planner: NotificationPlanner
    private var scheduledPlan: [PlannedNotification]?
    private var ticker: AnyCancellable?
    private var wake: AnyCancellable?
    private var tasks: [Task<Void, Never>] = []

    init(config: AppConfig, schedule: PeakScheduling, provider: ServiceStatusProviding,
         usageProvider: UsageProviding, loginItem: LoginItemManaging, preferences: PreferencesStoring,
         notifier: NotificationPosting, planner: NotificationPlanner) {
        self.config = config
        self.schedule = schedule
        self.provider = provider
        self.usageProvider = usageProvider
        self.loginItem = loginItem
        self.preferences = preferences
        self.notifier = notifier
        self.planner = planner
        self.launchAtLogin = loginItem.isEnabled
        self.settings = preferences.load()
        start()
    }

    var peak: PeakState { schedule.state(at: now) }
    var window: LocalWindow? { schedule.localWindow(near: now) }
    var weekPace: WeekPace? { WeekPace(window: usage?.week, now: now) }

    var indicator: Indicator {
        if service?.level == .degraded { return .incident }
        return peak.isPeak ? .peak : .offPeak
    }

    /// Weekly usage is high enough to ring the dot in the menu bar (80% orange, 90% red).
    var weekRing: WeekPace.Level? {
        guard settings.warnWeekInMenuBar, let used = weekPace?.used, used >= 0.8 else { return nil }
        return used >= 0.9 ? .critical : .ahead
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            await fetchStatus()
            _ = await fetchUsage()
            isRefreshing = false
        }
    }

    func toggleLaunchAtLogin() {
        try? loginItem.setEnabled(!loginItem.isEnabled)
        launchAtLogin = loginItem.isEnabled
    }

    func update(_ change: (inout AppSettings) -> Void) {
        var next = settings
        change(&next)
        guard next != settings else { return }
        let turnedOn = next.wantsNotifications && !settings.wantsNotifications
        settings = next
        preferences.save(next)
        schedulePeakNotifications(force: true)
        if turnedOn { Task { await authorizeNotifications() } }
    }

    private func start() {
        ticker = Timer.publish(every: 15, tolerance: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] in
                self?.now = $0
                self?.schedulePeakNotifications()
            }
        wake = NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                self?.now = Date()
                self?.schedulePeakNotifications(force: true)
                self?.refresh()
            }
        if settings.wantsNotifications {
            tasks.append(Task { await authorizeNotifications() })
        }
        schedulePeakNotifications(force: true)

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

    private func authorizeNotifications() async {
        _ = await notifier.requestAuthorization()
        notificationsDenied = await notifier.isDenied()
    }

    /// Reschedules only when the plan changed, e.g. after a peak window ended or settings changed.
    private func schedulePeakNotifications(force: Bool = false) {
        let plan = planner.peakPlan(now: now, settings: settings)
        guard force || plan != scheduledPlan else { return }
        scheduledPlan = plan
        notifier.replaceScheduled(plan, ids: NotificationPlanner.peakIds)
    }

    private func checkWeekWarning() {
        let (note, marks) = planner.weekWarning(pace: weekPace, settings: settings,
                                                sent: preferences.sentWeekWarnings)
        preferences.sentWeekWarnings = marks
        if let note { notifier.post(note) }
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
            now = Date()
            checkWeekWarning()
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
