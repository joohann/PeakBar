import OSLog

/// Diagnostics only. Never log tokens or response bodies.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "app"
    static let usage = Logger(subsystem: subsystem, category: "usage")
}
