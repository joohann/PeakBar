import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// A macOS desktop with the full menu bar, PeakBar's item highlighted and its panel open underneath.
struct DesktopView: View {
    @ObservedObject var model: StatusModel
    let l: Localizing
    let dark: Bool
    var showsSettings = false
    var size = CGSize(width: 960, height: 600)

    var body: some View {
        ZStack(alignment: .top) {
            wallpaper
            VStack(spacing: 0) {
                menuBar
                HStack(alignment: .top, spacing: 0) {
                    Spacer()
                    MenuView(model: model, l: l, showsSettings: showsSettings)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                    Spacer().frame(width: 172)
                }
                .padding(.top, 6)
                Spacer(minLength: 0)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var wallpaper: some View {
        LinearGradient(
            colors: dark
                ? [Color(red: 0.10, green: 0.13, blue: 0.27), Color(red: 0.20, green: 0.12, blue: 0.30)]
                : [Color(red: 0.45, green: 0.58, blue: 0.80), Color(red: 0.70, green: 0.62, blue: 0.85)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var clockText: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM  HH:mm"
        return f.string(from: model.now)
    }

    /// Full menu bar: Apple menu and Finder's menus on the left, status items and clock on the right.
    private var menuBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "apple.logo").font(.system(size: 14, weight: .medium))
            Text("Finder").fontWeight(.bold)
            ForEach(["File", "Edit", "View", "Go", "Window", "Help"], id: \.self) { Text($0) }
            Spacer()
            MenuBarLabel(model: model, l: l)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.22)))
            Image(systemName: "wifi").font(.system(size: 14, weight: .medium))
            Image(systemName: "battery.75percent").font(.system(size: 17))
            Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .medium))
            Image(systemName: "switch.2").font(.system(size: 13, weight: .medium))
            Text(clockText)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .padding(.horizontal, 16)
        .frame(height: 28)
        .background(Color.black.opacity(dark ? 0.35 : 0.12))
    }
}

/// A generic laptop drawn in code (no product artwork): lid with bezel and camera, and a base.
struct LaptopView<Screen: View>: View {
    let screen: Screen
    let screenSize: CGSize

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(white: 0.12))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color(white: 0.42), lineWidth: 2))
                screen
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.top, 22).padding(.horizontal, 18)
                Circle().fill(Color(white: 0.25)).frame(width: 7, height: 7).padding(.top, 8)
            }
            .frame(width: screenSize.width + 36, height: screenSize.height + 22 + 26)
            // Base: a thin slab, slightly wider than the lid, with a finger notch.
            ZStack(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 18,
                                       bottomTrailingRadius: 18, topTrailingRadius: 3, style: .continuous)
                    .fill(LinearGradient(colors: [Color(white: 0.86), Color(white: 0.62)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: screenSize.width + 160, height: 20)
                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 8,
                                       bottomTrailingRadius: 8, topTrailingRadius: 0)
                    .fill(Color(white: 0.70))
                    .frame(width: 140, height: 7)
            }
        }
        .padding(30)
    }
}

/// Renders any view at the window's backing scale (2x on Retina), without extra framing.
@MainActor
func snapshot(_ view: some View, dark: Bool) -> NSBitmapImageRep {
    let host = NSHostingView(rootView: view)
    host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    host.frame = NSRect(origin: .zero, size: host.fittingSize)
    let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.appearance = host.appearance
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
    host.cacheDisplay(in: host.bounds, to: rep)
    return rep
}

/// Writes an endlessly looping animated GIF with crossfades between the frames.
enum GifWriter {
    struct Frame { let image: CGImage; let hold: Double }

    static func write(_ frames: [Frame], width: Int, fadeSteps: Int = 6, fadeDelay: Double = 0.06, to url: URL) {
        let scaled = frames.map { Frame(image: resize($0.image, width: width), hold: $0.hold) }
        var output: [(CGImage, Double)] = []
        for (i, frame) in scaled.enumerated() {
            output.append((frame.image, frame.hold))
            let next = scaled[(i + 1) % scaled.count].image
            for step in 1...fadeSteps {
                output.append((blend(frame.image, next, Double(step) / Double(fadeSteps + 1)), fadeDelay))
            }
        }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString,
                                                         output.count, nil) else { return }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for (image, delay) in output {
            CGImageDestinationAddImage(dest, image, [kCGImagePropertyGIFDictionary:
                [kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay]] as CFDictionary)
        }
        CGImageDestinationFinalize(dest)
    }

    private static func context(_ w: Int, _ h: Int) -> CGContext {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }

    static func resize(_ image: CGImage, width: Int) -> CGImage {
        let height = Int(Double(image.height) * Double(width) / Double(image.width))
        let ctx = context(width, height)
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }

    private static func blend(_ a: CGImage, _ b: CGImage, _ t: Double) -> CGImage {
        let ctx = context(a.width, a.height)
        let rect = CGRect(x: 0, y: 0, width: a.width, height: a.height)
        ctx.draw(a, in: rect)
        ctx.setAlpha(t)
        ctx.draw(b, in: rect)
        return ctx.makeImage()!
    }
}

/// Scenes for the README: laptop stills (light and dark) and an animated GIF through four states.
@MainActor
func renderDocs(dir: String, config: AppConfig, base: PeakScheduling, localizer: Localizing, peakStart: Date) async {
    struct Scene { let t: Date; let status: ServiceStatus; let session: Double; let week: Double; let weekDays: Double; let settings: Bool }
    let peak = peakStart + 2 * 3600             // 16:00 on a weekday
    let morning = peakStart - 3 * 3600          // 11:00, off-peak
    func ok(_ t: Date) -> ServiceStatus { ServiceStatus(level: .operational, description: "", incidents: [], fetchedAt: t - 120) }
    func bad(_ t: Date) -> ServiceStatus {
        ServiceStatus(level: .degraded, description: "Partial System Outage",
                      incidents: ["Elevated errors on the API"], fetchedAt: t - 120)
    }
    let scenes = [
        Scene(t: morning, status: ok(morning), session: 12, week: 34, weekDays: 4, settings: false),
        Scene(t: peak, status: ok(peak), session: 74, week: 68, weekDays: 3, settings: false),
        Scene(t: peak, status: bad(peak), session: 93, week: 91, weekDays: 2, settings: false),
        Scene(t: peak, status: ok(peak), session: 74, week: 68, weekDays: 3, settings: true),
    ]
    let screen = CGSize(width: 960, height: 600)

    func laptop(_ s: Scene, dark: Bool) async -> NSBitmapImageRep {
        let usage = Usage(session: UsageWindow(percent: s.session, resetsAt: s.t + 2.5 * 3600),
                          week: UsageWindow(percent: s.week, resetsAt: s.t + s.weekDays * 86400),
                          plan: "max", fetchedAt: s.t)
        let model = StatusModel(config: config, schedule: base,
                                provider: StubProvider(status: s.status), usageProvider: StubUsage(usage: usage),
                                loginItem: StubLoginItem(), preferences: StubPreferences(), notifier: StubNotifier(),
                                planner: NotificationPlanner(schedule: base, l: localizer), clock: { s.t })
        try? await Task.sleep(nanoseconds: 300_000_000)
        let desktop = DesktopView(model: model, l: localizer, dark: dark, showsSettings: s.settings, size: screen)
        return snapshot(LaptopView(screen: desktop, screenSize: screen), dark: dark)
    }

    for dark in [false, true] {
        let rep = await laptop(scenes[1], dark: dark)
        try! rep.representation(using: .png, properties: [:])!
            .write(to: URL(fileURLWithPath: "\(dir)/laptop-\(dark ? "dark" : "light").png"))
    }
    var frames: [GifWriter.Frame] = []
    for scene in scenes {
        frames.append(.init(image: await laptop(scene, dark: false).cgImage!, hold: 2.6))
    }
    GifWriter.write(frames, width: 1000, to: URL(fileURLWithPath: "\(dir)/demo.gif"))
}
