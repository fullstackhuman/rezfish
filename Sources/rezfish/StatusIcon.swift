import AppKit

enum StatusIcon {
    /// Monitor outline with a triangle inside and a circle inside the triangle.
    /// Template image, so it follows menu bar light/dark automatically.
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 16)
        let img = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Screen
            let screen = NSBezierPath(roundedRect: NSRect(x: 1, y: 4, width: 16, height: 11), xRadius: 1.5, yRadius: 1.5)
            screen.lineWidth = 1.2
            screen.stroke()

            // Stand
            let stand = NSBezierPath()
            stand.move(to: NSPoint(x: 9, y: 4)); stand.line(to: NSPoint(x: 9, y: 1.5))
            stand.move(to: NSPoint(x: 6, y: 1)); stand.line(to: NSPoint(x: 12, y: 1))
            stand.lineWidth = 1.2
            stand.stroke()

            // Triangle
            let tri = NSBezierPath()
            tri.move(to: NSPoint(x: 9, y: 13))
            tri.line(to: NSPoint(x: 13.5, y: 6))
            tri.line(to: NSPoint(x: 4.5, y: 6))
            tri.close()
            tri.lineWidth = 1
            tri.lineJoinStyle = .round
            tri.stroke()

            // Circle
            NSBezierPath(ovalIn: NSRect(x: 7.75, y: 7, width: 2.5, height: 2.5)).fill()
            return true
        }
        img.isTemplate = true
        return img
    }
}
