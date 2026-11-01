import AppKit

/// The app icon's orbital ring and tool modules, rendered as a native template image.
@MainActor
enum OrbitMenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            defer { context.restoreGState() }

            // Crop the original 1024-point artwork to its mark, retaining a small optical margin.
            let scale = 18.0 / 760.0
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -132, y: -124)
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let ring = NSBezierPath(ovalIn: NSRect(x: 216, y: 236, width: 592, height: 592))
            ring.lineWidth = 72
            ring.stroke()
            for origin in [NSPoint(x: 420, y: 144), NSPoint(x: 164, y: 588), NSPoint(x: 676, y: 588)] {
                NSBezierPath(roundedRect: NSRect(origin: origin, size: NSSize(width: 184, height: 184)), xRadius: 48, yRadius: 48).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Orbit"
        return image
    }()
}
