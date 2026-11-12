import Foundation

/// Decides which notifications are due. Pure logic, no side effects.
struct NotificationPlanner {
    static let peakIds = ["peak.start", "peak.soon", "peak.ended"]
    static let sessionResetIds = ["session.reset"]
    static let updateId = "update.available"

    let schedule: PeakScheduling
    let l: Localizing

    // MARK: Peak hours

    /// Notifications for the next peak start and the end of the current or next peak window.
    func peakPlan(now: Date, settings: AppSettings) -> [PlannedNotification] {
        let state = schedule.state(at: now)
        let nextStart = state.isPeak ? schedule.state(at: state.nextChange).nextChange : state.nextChange
        let end = state.isPeak ? state.nextChange : schedule.state(at: nextStart).nextChange
        var plan: [PlannedNotification] = []

        if settings.notifyPeakStart {
            let minutes = settings.peakStartMinutes
            let at = nextStart.addingTimeInterval(-Double(minutes) * 60)
            if at > now {
                plan.append(PlannedNotification(
                    id: "peak.start",
                    title: minutes == 0 ? l.t("notify.peakStart.now") : l.t("notify.peakStart.title", minutes),
                    body: l.t("notify.peakStart.body", Formatters.time.string(from: end)),
                    date: at))
            }
        }
        if settings.notifyPeakSoon {
            let minutes = settings.peakSoonMinutes
            let soon = end.addingTimeInterval(-Double(minutes) * 60)
            if soon > now {
                plan.append(PlannedNotification(
                    id: "peak.soon",
                    title: l.t("notify.peakSoon.title", minutes),
                    body: l.t("notify.peakSoon.body", Formatters.time.string(from: end)),
                    date: soon))
            }
        }
        if settings.notifyPeakEnded {
            plan.append(PlannedNotification(
                id: "peak.ended",
                title: l.t("notify.peakEnded.title"),
                body: l.t("notify.peakEnded.body"),
                date: end))
        }
        return plan
    }

    // MARK: Updates

    /// One notification per new version, only when update checks and their notification are on.
    func updateNote(version: String, settings: AppSettings, notified: String?) -> PlannedNotification? {
        guard settings.checkForUpdates, settings.notifyUpdate, version != notified else { return nil }
        return PlannedNotification(id: Self.updateId, title: l.t("notify.update.title", version),
                                   body: l.t("notify.update.body"), date: nil)
    }

    // MARK: Session

    /// A notification at the moment the 5-hour session resets.
    func sessionResetPlan(session: UsageWindow?, now: Date, settings: AppSettings) -> [PlannedNotification] {
        guard settings.notifySessionReset, let reset = session?.resetsAt, reset > now else { return [] }
        return [PlannedNotification(id: "session.reset", title: l.t("notify.sessionReset.title"),
                                    body: l.t("notify.sessionReset.body"), date: reset)]
    }

    /// Warns once at 80% and once at 90% per session window.
    func sessionWarning(session: UsageWindow?, settings: AppSettings,
                        sent: Set<String>) -> (PlannedNotification?, Set<String>) {
        guard settings.notifySession, let session, let reset = session.resetsAt else { return (nil, sent) }
        let window = String(Int(reset.timeIntervalSince1970))
        let body = l.t("usage.resets", Formatters.reset(reset))
        let due = [90, 80].filter { session.percent >= Double($0) }.map { threshold in
            (key: "\(threshold)", note: PlannedNotification(
                id: "session.\(threshold)",
                title: l.t("notify.session.title", Formatters.percent(session.percent)),
                body: body, date: nil))
        }
        return pickFirst(due, window: window, sent: sent)
    }

    // MARK: Week

    /// At most one weekly warning per fetch; every condition that holds is marked as sent.
    func weekWarning(pace: WeekPace?, settings: AppSettings, sent: Set<String>) -> (PlannedNotification?, Set<String>) {
        guard settings.notifyWeek, let pace else { return (nil, sent) }
        let window = String(Int(pace.resetsAt.timeIntervalSince1970))
        let percent = Formatters.percent(pace.used * 100)

        var due: [(key: String, note: PlannedNotification)] = []
        if let runsOut = pace.runsOutAt, pace.elapsed >= 0.03 {
            due.append(("out", PlannedNotification(
                id: "week.out", title: l.t("notify.weekOut.title"),
                body: l.t("week.runsOut", Formatters.reset(runsOut)), date: nil)))
        }
        for threshold in [90, 75] where pace.used * 100 >= Double(threshold) {
            due.append(("\(threshold)", PlannedNotification(
                id: "week.\(threshold)", title: l.t("notify.week.title", percent),
                body: l.t("usage.resets", Formatters.reset(pace.resetsAt)), date: nil)))
        }
        return pickFirst(due, window: window, sent: sent)
    }

    // MARK: Claude status

    /// Notifies on a change between operational and degraded, not on the first check.
    func incidentNote(previous: ServiceStatus.Level?, current: ServiceStatus,
                      settings: AppSettings) -> PlannedNotification? {
        guard settings.notifyIncidents, let previous, previous != current.level else { return nil }
        switch current.level {
        case .degraded:
            return PlannedNotification(id: "status.incident", title: l.t("notify.incident.title"),
                                       body: current.incidents.first ?? current.description, date: nil)
        case .operational:
            return PlannedNotification(id: "status.resolved", title: l.t("notify.resolved.title"),
                                       body: l.t("service.operational"), date: nil)
        }
    }

    // MARK: Helpers

    /// Returns the first unsent warning; marks all due ones as sent and forgets earlier windows.
    private func pickFirst(_ due: [(key: String, note: PlannedNotification)], window: String,
                           sent: Set<String>) -> (PlannedNotification?, Set<String>) {
        var marks = sent.filter { $0.hasSuffix("@" + window) }
        let fresh = due.first { !marks.contains($0.key + "@" + window) }
        due.forEach { marks.insert($0.key + "@" + window) }
        return (fresh?.note, marks)
    }
}
