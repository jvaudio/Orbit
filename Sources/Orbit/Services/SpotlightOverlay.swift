import AppKit

@MainActor
protocol SpotlightPresenting: AnyObject {
    func show(at point: CGPoint, radius: Double, dimming: Double)
    func update(at point: CGPoint, radius: Double, dimming: Double)
    func hide(immediately: Bool)
}

@MainActor
private final class SpotlightPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class SpotlightView: NSView {
    var center = CGPoint.zero
    var radius: Double = 100
    var dimming: Double = 0.6

    override func draw(_ dirtyRect: NSRect) {
        let mask = NSBezierPath(rect: bounds)
        mask.appendOval(in: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        mask.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(dimming).setFill()
        mask.fill()
    }
}

/// AppKit owns only the overlay windows; feature state stays in the utility.
@MainActor
final class SpotlightOverlay: SpotlightPresenting {
    private var panels: [SpotlightPanel] = []
    private var fadingPanels: [SpotlightPanel] = []

    func show(at point: CGPoint, radius: Double, dimming: Double) {
        hide(immediately: true)
        for screen in NSScreen.screens {
            let panel = SpotlightPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.setFrame(screen.frame, display: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            let view = SpotlightView(frame: NSRect(origin: .zero, size: screen.frame.size))
            panel.contentView = view
            panels.append(panel)
        }
        update(at: point, radius: radius, dimming: dimming)
        for panel in panels {
            panel.alphaValue = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 1 : 0
            panel.orderFrontRegardless()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.16
            for panel in panels { panel.animator().alphaValue = 1 }
        }
    }

    func update(at point: CGPoint, radius: Double, dimming: Double) {
        for panel in panels {
            guard let view = panel.contentView as? SpotlightView else { continue }
            view.center = CGPoint(x: point.x - panel.frame.minX, y: point.y - panel.frame.minY)
            view.radius = radius
            view.dimming = dimming
            view.needsDisplay = true
        }
    }

    func hide(immediately: Bool = false) {
        if immediately {
            fadingPanels.forEach { $0.orderOut(nil); $0.close() }
            fadingPanels.removeAll()
        }
        let oldPanels = panels
        panels.removeAll()
        guard !oldPanels.isEmpty else { return }
        if immediately || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            oldPanels.forEach { $0.orderOut(nil); $0.close() }
        } else {
            fadingPanels.append(contentsOf: oldPanels)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                for panel in oldPanels { panel.animator().alphaValue = 0 }
            } completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    oldPanels.forEach { $0.orderOut(nil); $0.close() }
                    self?.fadingPanels.removeAll { panel in oldPanels.contains { $0 === panel } }
                }
            }
        }
    }
}
