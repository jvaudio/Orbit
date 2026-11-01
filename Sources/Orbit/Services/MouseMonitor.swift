import AppKit

enum MouseInputNotifications {
    static let interceptedButtonDown = Notification.Name("orbit.input.interceptedButtonDown")
}

struct MouseInput {
    enum Kind { case movement, click }
    enum Source { case local, global }
    let kind: Kind
    let point: CGPoint
    var dragging = false
    var timestamp: TimeInterval? = nil
    var source: Source = .local
}

@MainActor
protocol MouseMonitoring: AnyObject {
    func start(_ handler: @escaping @MainActor (MouseInput) -> Void) -> Bool
    func stop()
}

/// Mouse-only monitors: no keyboard hooks, event suppression, or input injection.
@MainActor
final class MouseMonitor: MouseMonitoring {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var interceptedClick: NSObjectProtocol?
    private let localDelivery = LocalMouseMovementDelivery()

    func start(_ handler: @escaping @MainActor (MouseInput) -> Void) -> Bool {
        if globalMonitor != nil && localMonitor != nil { return true }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let consume: @MainActor (NSEvent, MouseInput.Source) -> Void = { event, source in
            handler(Self.input(for: event, source: source, primaryScreenMaxY: NSScreen.screens.first?.frame.maxY ?? 0))
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
            MainActor.assumeIsolated { consume(event, .global) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            MainActor.assumeIsolated { consume(event, .local) }
            return event
        }
        guard globalMonitor != nil && localMonitor != nil else { stop(); return false }
        interceptedClick = NotificationCenter.default.addObserver(forName: MouseInputNotifications.interceptedButtonDown, object: nil, queue: .main) { note in
            MainActor.assumeIsolated {
                guard let point = (note.userInfo?["point"] as? NSValue)?.pointValue else { return }
                handler(MouseInput(kind: .click, point: CGPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y), timestamp: note.userInfo?["time"] as? TimeInterval, source: .global))
            }
        }
        localDelivery.start()
        return true
    }

    func stop() {
        localDelivery.stop()
        if let interceptedClick { NotificationCenter.default.removeObserver(interceptedClick) }; interceptedClick = nil
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    /// Preserve the event's sample, not the pointer's potentially newer location at callback time.
    static func input(for event: NSEvent, source: MouseInput.Source, primaryScreenMaxY: CGFloat) -> MouseInput {
        let kind: MouseInput.Kind
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: kind = .click
        default: kind = .movement
        }
        let point: CGPoint
        if let quartz = event.cgEvent?.location {
            point = CGPoint(x: quartz.x, y: primaryScreenMaxY - quartz.y)
        } else if let window = event.window {
            point = window.convertPoint(toScreen: event.locationInWindow)
        } else {
            point = event.locationInWindow
        }
        let dragging = [.leftMouseDragged, .rightMouseDragged, .otherMouseDragged].contains(event.type)
        return MouseInput(kind: kind, point: point, dragging: dragging, timestamp: event.timestamp, source: source)
    }
}
