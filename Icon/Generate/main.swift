import AppKit

// Writes a complete .iconset folder; build.sh turns it into AppIcon.icns with iconutil.
let dir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        let png = IconDrawing.image(size: CGFloat(base * scale)).representation(using: .png, properties: [:])!
        try! png.write(to: dir.appendingPathComponent(name))
    }
}
