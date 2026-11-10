import AppKit
import SwiftUI

// Renders MenuView offscreen to PNG with stub data, so no screen-recording permission is needed.
// Usage: preview <path-to-.app> <output.png>

struct StubProvider: ServiceStatusProviding {
    let status: ServiceStatus
    func fetch() async throws -> ServiceStatus { status }
}
final class StubPreferences: PreferencesStoring {
    var showMenuBarText: Bool
    var showMenuBarUsage = true
    init(showMenuBarText: Bool) { self.showMenuBarText = showMenuBarText }
}
struct StubUsage: UsageProviding {
    let usage: Usage
    func fetch() async throws -> Usage { usage }
}
struct StubLoginItem: LoginItemManaging {
    var isEnabled: Bool { true }
    func setEnabled(_ enabled: Bool) throws {}
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

    // Find a moment inside the next peak window for the "peak" scenario.
    let nextPeak = base.state(at: Date()).isPeak ? Date() : base.state(at: Date()).nextChange + 2 * 3600
    func use(_ s: Double, _ w: Double) -> Usage {
        Usage(session: UsageWindow(percent: s, resetsAt: Date() + 2 * 3600),
              week: UsageWindow(percent: w, resetsAt: Date() + 4 * 86400), plan: "max", fetchedAt: Date())
    }
    let scenarios: [(String, TimeInterval, ServiceStatus, Usage)] = [
        ("off-peak", 0, ok, use(12, 18)),
        ("peak", nextPeak.timeIntervalSinceNow, ok, use(74, 41)),
        ("incident", nextPeak.timeIntervalSinceNow, bad, use(93, 66)),
    ]

    var rows: [[NSImage]] = []
    for dark in [false, true] {
        var row: [NSImage] = []
        for (_, offset, status, usage) in scenarios {
            let model = StatusModel(config: config,
                                    schedule: ShiftedSchedule(base: base, offset: offset),
                                    provider: StubProvider(status: status),
                                    usageProvider: StubUsage(usage: usage),
                                    loginItem: StubLoginItem(),
                                    preferences: StubPreferences(showMenuBarText: !dark))
            try? await Task.sleep(nanoseconds: 300_000_000)  // let the stub fetch land
            let bar = MenuBarLabel(model: model, l: localizer).padding(6)
            row.append(render(VStack(alignment: .trailing, spacing: 6) {
                bar
                MenuView(model: model, l: localizer)
            }.padding(8), dark: dark))
        }
        rows.append(row)
    }

    // Compose into one sheet.
    let gap: CGFloat = 16
    let cellW = rows.flatMap { $0 }.map(\.size.width).max()!
    let cellH = rows.flatMap { $0 }.map(\.size.height).max()!
    let size = NSSize(width: gap + CGFloat(scenarios.count) * (cellW + gap), height: gap + 2 * (cellH + gap))
    let sheet = NSImage(size: size, flipped: true) { _ in
        NSColor(white: 0.5, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        for (r, row) in rows.enumerated() {
            for (c, img) in row.enumerated() {
                let origin = NSPoint(x: gap + CGFloat(c) * (cellW + gap), y: gap + CGFloat(r) * (cellH + gap))
                img.draw(in: NSRect(origin: origin, size: img.size), from: .zero, operation: .sourceOver,
                         fraction: 1, respectFlipped: true, hints: nil)
            }
        }
        return true
    }
    let tiff = sheet.tiffRepresentation!
    let png = NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: args[2]))
    print("written", args[2], size)
}

NSApplication.shared.setActivationPolicy(.prohibited)
Task { await run(); exit(0) }
RunLoop.main.run()
