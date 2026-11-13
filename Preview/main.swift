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
    var notifiedUpdateVersion: String?
    func load() -> AppSettings { settings }
    func save(_ s: AppSettings) { settings = s }
}
final class StubNotifier: NotificationPosting {
    func requestAuthorization() async -> Bool { true }
    func isDenied() async -> Bool { false }
    func replaceScheduled(_ plan: [PlannedNotification], ids: [String]) {}
    func post(_ notification: PlannedNotification) {}
    var onOpen: ((String) -> Void)?
}
/// Lets a scenario announce an update, as a background check would.
@MainActor
final class StubUpdater: UpdateManaging {
    var automaticallyChecks = true
    var onUpdateFound: ((String) -> Void)?
    var onUpdateHandled: (() -> Void)?
    func checkNow() {}
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
    // Options such as -AppleLanguages "(de)" come after the positional arguments.
    let args = Array(CommandLine.arguments.prefix { !$0.hasPrefix("-") })
    let bundle = Bundle(path: args[1])!
    let config = try! BundleConfigLoader(bundle: bundle).load()
    // -previewLanguage de renders the panels in that language; the README images stay English.
    let localizer = BundleLocalizer(bundle: bundle, language: UserDefaults.standard.string(forKey: "previewLanguage"))
    let base = try! WeeklyPeakSchedule(config: config.peak)

    // One fixed moment for every image, so re-rendering only changes them when the design changes:
    // Wednesday 11 November 2026, 16:00 in Amsterdam (peak hours), and 11:00 the same day (off-peak).
    let peakMoment = ISO8601DateFormatter().date(from: "2026-11-11T15:00:00Z")!
    let offPeakMoment = peakMoment - 5 * 3600
    func ok(_ t: Date) -> ServiceStatus {
        ServiceStatus(level: .operational, description: "All Systems Operational", incidents: [], fetchedAt: t - 120)
    }
    func bad(_ t: Date) -> ServiceStatus {
        ServiceStatus(level: .degraded, description: "Partial System Outage",
                      incidents: ["Elevated errors on Claude Opus"], fetchedAt: t - 120)
    }
    func use(_ t: Date, _ s: Double, _ w: Double, daysLeft: Double) -> Usage {
        Usage(session: UsageWindow(percent: s, resetsAt: t + 2.5 * 3600),
              week: UsageWindow(percent: w, resetsAt: t + daysLeft * 86400), plan: "max", fetchedAt: t)
    }
    let names = ["ontrack", "ahead", "critical", "settings", "update"]
    let scenarios: [(Date, ServiceStatus, Usage, Bool, String?)] = [
        (offPeakMoment, ok(offPeakMoment), use(offPeakMoment, 12, 18, daysLeft: 4), false, nil),  // on track
        (peakMoment, ok(peakMoment), use(peakMoment, 74, 68, daysLeft: 3), false, nil),            // ahead, runs out early
        (peakMoment, bad(peakMoment), use(peakMoment, 93, 91, daysLeft: 2), false, nil),           // critical
        (offPeakMoment, ok(offPeakMoment), use(offPeakMoment, 12, 18, daysLeft: 4), true, nil),    // settings (back)
        (offPeakMoment, ok(offPeakMoment), use(offPeakMoment, 12, 18, daysLeft: 4), false, "1.3.0"), // update found
    ]

    var rows: [[NSImage]] = []
    for dark in [false, true] {
        var row: [NSImage] = []
        for (t, status, usage, back, update) in scenarios {
            let updater = StubUpdater()
            let model = StatusModel(config: config, schedule: base,
                                    provider: StubProvider(status: status),
                                    usageProvider: StubUsage(usage: usage),
                                    loginItem: StubLoginItem(), preferences: StubPreferences(),
                                    notifier: StubNotifier(),
                                    planner: NotificationPlanner(schedule: base, l: localizer),
                                    updater: updater, clock: { t })
            if let update { updater.onUpdateFound?(update) }
            try? await Task.sleep(nanoseconds: 300_000_000)  // let the stub fetches land
            row.append(render(VStack(alignment: .trailing, spacing: 6) {
                MenuBarLabel(model: model, l: localizer).padding(6)
                MenuView(model: model, l: localizer, showsSettings: back)
            }.padding(8), dark: dark))
            if args.count > 3 {
                // README images: the panel under the right end of the menu bar, all the same size,
                // on the same wallpaper as the laptop slides. E.g. docs/panel-ahead-dark.png
                let name = names[row.count - 1]
                let file = "\(args[3])/panel-\(name)-\(dark ? "dark" : "light").png"
                let scene = DesktopView(model: model, l: localizer, dark: dark, showsSettings: back,
                                        size: CGSize(width: 500, height: 660), compact: true)
                try! snapshot(scene, dark: dark).representation(using: .png, properties: [:])!
                    .write(to: URL(fileURLWithPath: file))
            }
        }
        rows.append(row)
    }

    if args.count > 3 {
        await renderDocs(dir: args[3], config: config, base: base, localizer: localizer, peakStart: peakMoment - 2 * 3600)
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
