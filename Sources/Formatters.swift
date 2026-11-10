import Foundation

enum Formatters {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute]
        f.unitsStyle = .abbreviated
        f.maximumUnitCount = 2
        return f
    }()

    static func duration(from: Date, to: Date) -> String {
        // Round up to the next minute so "0m" never shows before a switch.
        let seconds = max(60, (to.timeIntervalSince(from) / 60).rounded(.up) * 60)
        return durationFormatter.string(from: seconds) ?? ""
    }

    /// Formats weekdays (1 = Sunday) as a range when contiguous, e.g. "Mon–Fri".
    static func weekdays(_ days: [Int]) -> String {
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        let sorted = days.sorted()
        guard let first = sorted.first, let last = sorted.last else { return "" }
        if sorted.count > 2, sorted == Array(first...last) {
            return "\(symbols[first - 1])–\(symbols[last - 1])"
        }
        return sorted.map { symbols[$0 - 1] }.joined(separator: ", ")
    }
}

extension Formatters {
    static func percent(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value / 100)) ?? "\(Int(value))%"
    }

    /// "23:00" today, otherwise "Mon 09:00".
    static func reset(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return time.string(from: date) }
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEjmm")
        return f.string(from: date)
    }
}
