import AppKit
import SwiftUI

// Renders the panel offscreen to PNG with stub data, so no screen-recording permission is needed.
// Usage: preview <path-to-.app> <output.png>

struct StubProvider: ServiceStatusProviding {
    let status: ServiceStatus
    func fetch() async throws -> ServiceStatus { status }
}
struct StubUsage: UsageProviding {
    let usage: Usage
    func fetch() async throws -> Usage { usage }
}
struct StubLoginItem: LoginItemManaging {
    var isEnabled: Bool { true }
    func setEnabled(_ enabled: Bool) throws {}
}
final class StubPreferences: PreferencesStoring {
    var settings = AppSettings()
    var sentWeekWarnings: Set<String> = []
    var sentSessionWarnings: Set<String> = []
    func load() -> AppSettings { settings }
    func save(_ s: AppSettings) { settings = s }
}
final class StubNotifier: NotificationPosting {
    func requestAuthorization() async -> Bool { true }
    func isDenied() async -> Bool { false }
    func replaceScheduled(_ plan: [PlannedNotification], ids: [String]) {}
    func post(_ notification: PlannedNotification) {}
}
/// Shifts the clock so a specific moment can be previewed.
struct ShiftedSchedule: PeakScheduling {
    let base: PeakScheduling
    let offset: TimeInterval
    func state(at date: Date) -> PeakState {
        let s = base.state(at: date + offset)
        return PeakState(isPeak: s.isPeak, nextChange: s.nextChange - offset)
    }
    func localWindow(near date: Date) -> LocalWindow? { base.localWindow(near: date + offset) }
}

@MainActor
func render(_ view: some View, dark: Bool) -> NSImage {
    let host = NSHostingView(rootView: view
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10)))
    host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    host.frame = NSRect(origin: .zero, size: host.fittingSize)
    let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.appearance = host.appearance
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: rep)
    let image = NSImage(size: host.bounds.size)
    image.addRepresentation(rep)
    return image
}

@MainActor
func run() async {
    let args = CommandLine.arguments
    let bundle = Bundle(path: args[1])!
    let config = try! BundleConfigLoader(bundle: bundle).load()
    let localizer = BundleLocalizer(bundle: bundle)
    let base = try! WeeklyPeakSchedule(config: config.peak)

    let ok = ServiceStatus(level: .operational, description: "All Systems Operational", incidents: [], fetchedAt: Date())
    let bad = ServiceStatus(level: .degraded, description: "Partial System Outage",
                            incidents: ["Elevated errors on Claude Opus"], fetchedAt: Date())
    func use(_ s: Double, _ w: Double, daysLeft: Double) -> Usage {
        Usage(session: UsageWindow(percent: s, resetsAt: Date() + 2 * 3600),
              week: UsageWindow(percent: w, resetsAt: Date() + daysLeft * 86400), plan: "max", fetchedAt: Date())
    }
    let nextPeak = base.state(at: Date()).isPeak ? Date() : base.state(at: Date()).nextChange + 2 * 3600
    let scenarios: [(TimeInterval, ServiceStatus, Usage, Bool)] = [
        (0, ok, use(12, 18, daysLeft: 4), false),                               // on track
        (nextPeak.timeIntervalSinceNow, ok, use(74, 68, daysLeft: 3), false),   // ahead, runs out early
        (nextPeak.timeIntervalSinceNow, bad, use(93, 91, daysLeft: 2), false),  // critical
        (0, ok, use(12, 18, daysLeft: 4), true),                                // settings (back)
    ]

    var rows: [[NSImage]] = []
    for dark in [false, true] {
        var row: [NSImage] = []
        for (offset, status, usage, back) in scenarios {
            let schedule = ShiftedSchedule(base: base, offset: offset)
            let model = StatusModel(config: config, schedule: schedule,
                                    provider: StubProvider(status: status),
                                    usageProvider: StubUsage(usage: usage),
                                    loginItem: StubLoginItem(), preferences: StubPreferences(),
                                    notifier: StubNotifier(),
                                    planner: NotificationPlanner(schedule: schedule, l: localizer))
            try? await Task.sleep(nanoseconds: 300_000_000)  // let the stub fetches land
            row.append(render(VStack(alignment: .trailing, spacing: 6) {
                MenuBarLabel(model: model, l: localizer).padding(6)
                MenuView(model: model, l: localizer, showsSettings: back)
            }.padding(8), dark: dark))
            if args.count > 3, let last = row.last {
                // Individual images for the README, e.g. docs/panel-ahead-dark.png
                let name = ["ontrack", "ahead", "critical", "settings"][row.count - 1]
                let file = "\(args[3])/panel-\(name)-\(dark ? "dark" : "light").png"
                let rep = NSBitmapImageRep(data: last.tiffRepresentation!)!
                try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: file))
            }
        }
        rows.append(row)
    }

    if args.count > 3 {
        await renderDocs(dir: args[3], config: config, base: base, localizer: localizer, peakStart: nextPeak - 2 * 3600)
    }

    // Compose into one sheet, top-aligned.
    let gap: CGFloat = 16
    let cellW = rows.flatMap { $0 }.map(\.size.width).max()!
    let rowH = rows.map { $0.map(\.size.height).max()! }
    let size = NSSize(width: gap + CGFloat(scenarios.count) * (cellW + gap), height: gap + rowH.reduce(0) { $0 + $1 + gap })
    let sheet = NSImage(size: size, flipped: true) { _ in
        NSColor(white: 0.5, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        var y = gap
        for (r, row) in rows.enumerated() {
            for (c, img) in row.enumerated() {
                img.draw(in: NSRect(origin: NSPoint(x: gap + CGFloat(c) * (cellW + gap), y: y), size: img.size),
                         from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            }
            y += rowH[r] + gap
        }
        return true
    }
    let png = NSBitmapImageRep(data: sheet.tiffRepresentation!)!.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: args[2]))
    print("written", args[2], size)
}

NSApplication.shared.setActivationPolicy(.prohibited)
Task { await run(); exit(0) }
RunLoop.main.run()
