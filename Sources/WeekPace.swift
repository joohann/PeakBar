import Foundation

/// How the weekly limit relates to how much of the week has passed.
struct WeekPace: Equatable {
    enum Level { case onTrack, ahead, critical }

    let used: Double          // 0…1 of the weekly limit
    let elapsed: Double       // 0…1 of the week
    let resetsAt: Date
    let runsOutAt: Date?      // set when the current pace runs out before the reset
    let projected: Double?    // expected usage at the reset, 0…∞
    let dailyBudget: Double?  // share of the limit per remaining day to stay on track

    init?(window: UsageWindow?, now: Date, length: TimeInterval = 7 * 86_400) {
        guard let window, let resetsAt = window.resetsAt else { return nil }
        let start = resetsAt.addingTimeInterval(-length)
        used = window.percent / 100
        elapsed = min(max(now.timeIntervalSince(start) / length, 0), 1)
        self.resetsAt = resetsAt
        // Too early in the week to say anything sensible about the pace.
        projected = elapsed >= 0.03 ? used / elapsed : nil
        if used > 0, used < 1, used > elapsed, elapsed > 0 {
            runsOutAt = start.addingTimeInterval(length * elapsed / used)
        } else {
            runsOutAt = nil
        }
        let daysLeft = resetsAt.timeIntervalSince(now) / 86_400
        dailyBudget = daysLeft > 0 && used < 1 ? (1 - used) / max(daysLeft, 1) : nil
    }

    var level: Level {
        if used >= 0.9 { return .critical }
        return used > elapsed && elapsed >= 0.03 ? .ahead : .onTrack
    }

}
