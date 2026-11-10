import Foundation

/// Result of evaluating the peak schedule at a moment in time.
struct PeakState: Equatable {
    let isPeak: Bool
    let nextChange: Date
}

/// Today's peak window converted to the user's time zone, for display.
struct LocalWindow: Equatable {
    let start: Date
    let end: Date
    let weekdays: [Int]   // weekdays in the user's calendar
}

protocol PeakScheduling {
    func state(at date: Date) -> PeakState
    func localWindow(near date: Date) -> LocalWindow?
}

/// Fixed weekly peak window, evaluated in its own time zone so DST is handled on both sides.
struct WeeklyPeakSchedule: PeakScheduling {
    private let calendar: Calendar
    private let weekdays: Set<Int>
    private let start: (hour: Int, minute: Int)
    private let end: (hour: Int, minute: Int)

    init(config: AppConfig.Peak) throws {
        guard let tz = TimeZone(identifier: config.timeZone),
              let start = Self.parse(config.start),
              let end = Self.parse(config.end) else {
            throw CocoaError(.coderInvalidValue)
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        self.calendar = cal
        self.weekdays = Set(config.weekdays)
        self.start = start
        self.end = end
    }

    func state(at date: Date) -> PeakState {
        // Look at windows from yesterday up to 8 days ahead; the first boundary after `date` wins.
        for window in windows(around: date) {
            if date < window.start { return PeakState(isPeak: false, nextChange: window.start) }
            if date < window.end { return PeakState(isPeak: true, nextChange: window.end) }
        }
        return PeakState(isPeak: false, nextChange: date.addingTimeInterval(86_400))
    }

    func localWindow(near date: Date) -> LocalWindow? {
        guard let window = windows(around: date).first(where: { $0.end > date }) else { return nil }
        let local = Calendar.current
        let shift = local.component(.weekday, from: window.start) - calendar.component(.weekday, from: window.start)
        let days = weekdays.sorted().map { (($0 - 1 + shift + 7) % 7) + 1 }
        return LocalWindow(start: window.start, end: window.end, weekdays: days)
    }

    private func windows(around date: Date) -> [(start: Date, end: Date)] {
        let today = calendar.startOfDay(for: date)
        return (-1...8).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  weekdays.contains(calendar.component(.weekday, from: day)),
                  let s = calendar.date(bySettingHour: start.hour, minute: start.minute, second: 0, of: day),
                  let e = calendar.date(bySettingHour: end.hour, minute: end.minute, second: 0, of: day),
                  e > s else { return nil }
            return (s, e)
        }
    }

    private static func parse(_ value: String) -> (hour: Int, minute: Int)? {
        let parts = value.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return (parts[0], parts[1])
    }
}
