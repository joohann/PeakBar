import Foundation

/// Decides which notifications are due. Pure logic, no side effects.
struct NotificationPlanner {
    static let peakIds = ["peak.soon", "peak.ended"]

    let schedule: PeakScheduling
    let l: Localizing

    /// Notifications for the end of the current or next peak window.
    func peakPlan(now: Date, settings: AppSettings) -> [PlannedNotification] {
        let state = schedule.state(at: now)
        let end = state.isPeak ? state.nextChange : schedule.state(at: state.nextChange).nextChange
        var plan: [PlannedNotification] = []
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

    /// At most one weekly warning per fetch; every condition that holds is marked as sent.
    func weekWarning(pace: WeekPace?, settings: AppSettings, sent: Set<String>) -> (PlannedNotification?, Set<String>) {
        guard settings.notifyWeek, let pace else { return (nil, sent) }
        let week = String(Int(pace.resetsAt.timeIntervalSince1970))
        var marks = sent.filter { $0.hasSuffix("@" + week) }   // forget earlier weeks
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
        let fresh = due.filter { !marks.contains($0.key + "@" + week) }
        due.forEach { marks.insert($0.key + "@" + week) }
        return (fresh.first?.note, marks)
    }
}
