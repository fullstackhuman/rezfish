// Renders Resources/AppIcon.icns: the menu bar shape on a goldenrod background.
// Run: swift scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024

    // macOS-style rounded square, inset like Apple's template (≈ 10% margin).
    let bg = NSBezierPath(roundedRect: NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s),
                          xRadius: 185 * s, yRadius: 185 * s)
    let gradient = NSGradient(colors: [
        NSColor(red: 1.00, green: 0.80, blue: 0.20, alpha: 1),   // bright gold
        NSColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1),   // goldenrod
        NSColor(red: 0.72, green: 0.45, blue: 0.05, alpha: 1),   // deep amber
    ])!
    gradient.draw(in: bg, angle: -60)

    // Same geometry as StatusIcon (18×16 grid), scaled into the square.
    let unit = 40 * s
    let ox = 152 * s, oy = 192 * s
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: ox + x * unit, y: oy + y * unit) }
    let ink = NSColor(red: 0.16, green: 0.10, blue: 0.02, alpha: 1)
    ink.setStroke(); ink.setFill()

    let screen = NSBezierPath(roundedRect: NSRect(x: p(1, 4).x, y: p(1, 4).y, width: 16 * unit, height: 11 * unit),
                              xRadius: 1.5 * unit, yRadius: 1.5 * unit)
    screen.lineWidth = 1.2 * unit
    screen.stroke()

    let stand = NSBezierPath()
    stand.move(to: p(9, 4)); stand.line(to: p(9, 1.5))
    stand.move(to: p(6, 1)); stand.line(to: p(12, 1))
    stand.lineWidth = 1.2 * unit
    stand.lineCapStyle = .round
    stand.stroke()

    let tri = NSBezierPath()
    tri.move(to: p(9, 13)); tri.line(to: p(13.5, 6)); tri.line(to: p(4.5, 6)); tri.close()
    tri.lineWidth = 1 * unit
    tri.lineJoinStyle = .round
    tri.stroke()

    NSBezierPath(ovalIn: NSRect(x: p(7.75, 7).x, y: p(7.75, 7).y, width: 2.5 * unit, height: 2.5 * unit)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = "Resources/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)] {
    let data = render(px).representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(iconset)/icon_\(name).png"))
}
let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", iconset, "-o", "Resources/AppIcon.icns"]
task.launch(); task.waitUntilExit()
try? FileManager.default.removeItem(atPath: iconset)
print(task.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
