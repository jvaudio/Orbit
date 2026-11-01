import AppKit

/// Global monitors exclude our own app, whose windows must explicitly accept move events.
@MainActor
final class LocalMouseMovementDelivery {
    private let originals = NSMapTable<NSWindow, NSNumber>.weakToStrongObjects()
    private var observer: NSObjectProtocol?

    func start(windows: [NSWindow]? = nil) {
        guard observer == nil else { return }
        for window in windows ?? NSApp?.windows ?? [] { enable(window) }
        observer = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                if let window = notification.object as? NSWindow { self?.enable(window) }
            }
        }
    }

    private func enable(_ window: NSWindow) {
        guard !window.ignoresMouseEvents else { return }
        if originals.object(forKey: window) == nil {
            originals.setObject(NSNumber(value: window.acceptsMouseMovedEvents), forKey: window)
        }
        window.acceptsMouseMovedEvents = true
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        for window in originals.keyEnumerator().allObjects as? [NSWindow] ?? [] {
            if let original = originals.object(forKey: window) { window.acceptsMouseMovedEvents = original.boolValue }
        }
        originals.removeAllObjects()
    }
}
