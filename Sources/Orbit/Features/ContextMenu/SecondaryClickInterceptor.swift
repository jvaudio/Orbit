import AppKit
import OrbitCore

/// The event tap runs on its own run loop. Its callback never queries
/// Accessibility, touches files, or waits for the main thread.
final class SecondaryClickInterceptor: @unchecked Sendable {
    struct Click { let down: CGEvent; let up: CGEvent }
    static let marker: Int64 = 0x4f52424954
    private let lock = NSLock()
    private var gesture = SecondaryClickGesture()
    private var heldDown: CGEvent?
    private var busy = false
    private var active = false
    private var port: CFMachPort?
    private var loop: CFRunLoop?
    private var thread: Thread?
    private let onClick: (Click) -> Void
    private let onFailure: () -> Void
    init(onClick: @escaping (Click) -> Void, onFailure: @escaping () -> Void) {
        self.onClick = onClick; self.onFailure = onFailure
    }
    func start() -> Bool {
        lock.lock(); active = true; lock.unlock()
        let ready = DispatchSemaphore(value: 0)
        let worker = Thread { [self] in
            let mask = [CGEventType.rightMouseDown, .rightMouseUp, .rightMouseDragged, .leftMouseDown, .leftMouseUp, .leftMouseDragged]
                .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
            let callback: CGEventTapCallBack = { proxy, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                return Unmanaged<SecondaryClickInterceptor>.fromOpaque(info).takeUnretainedValue().receive(proxy, type: type, event: event)
            }
            let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque())
            let runLoop = CFRunLoopGetCurrent()
            lock.lock(); port = created; loop = runLoop; let shouldRun = active; lock.unlock()
            guard let created, shouldRun else {
                if let created { CGEvent.tapEnable(tap: created, enable: false); CFMachPortInvalidate(created) }
                lock.lock(); port = nil; loop = nil; lock.unlock()
                ready.signal(); return
            }
            let source = CFMachPortCreateRunLoopSource(nil, created, 0)!
            CFRunLoopAddSource(runLoop, source, .commonModes)
            ready.signal()
            CFRunLoopRun()
            CGEvent.tapEnable(tap: created, enable: false)
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            CFMachPortInvalidate(created)
            lock.lock(); port = nil; loop = nil; lock.unlock()
        }
        worker.name = "Orbit secondary click filter"; thread = worker; worker.start()
        guard ready.wait(timeout: .now() + 2) == .success else { stop(); return false }
        lock.lock(); let started = port != nil; lock.unlock()
        if !started { stop() }
        return started
    }
    func finish() { lock.lock(); busy = false; lock.unlock() }
    func stop() {
        lock.lock()
        active = false; busy = false; gesture.reset()
        let held = heldDown; heldDown = nil
        let currentPort = port; let currentLoop = loop
        lock.unlock()
        if let currentPort { CGEvent.tapEnable(tap: currentPort, enable: false) }
        if let currentLoop { CFRunLoopStop(currentLoop); CFRunLoopWakeUp(currentLoop) }
        if let held, let up = held.copy() {
            held.setIntegerValueField(.eventSourceUserData, value: Self.marker)
            up.type = held.type == .leftMouseDown ? .leftMouseUp : .rightMouseUp
            up.setIntegerValueField(.eventSourceUserData, value: Self.marker)
            held.post(tap: .cgSessionEventTap); up.post(tap: .cgSessionEventTap)
        }
    }
    private func receive(_ proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Leave native input alone until Orbit is explicitly restarted.
            lock.lock(); active = false; gesture.reset(); heldDown = nil; lock.unlock()
            DispatchQueue.main.async { self.onFailure() }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.marker { return Unmanaged.passUnretained(event) }
        let input: SecondaryClickGesture.Input
        switch type {
        case .rightMouseDown: input = .down(right: true, control: false)
        case .leftMouseDown: input = .down(right: false, control: event.flags.contains(.maskControl))
        case .rightMouseUp: input = .up(right: true)
        case .leftMouseUp: input = .up(right: false)
        case .rightMouseDragged: input = .drag(right: true)
        case .leftMouseDragged: input = .drag(right: false)
        default: return Unmanaged.passUnretained(event)
        }
        lock.lock()
        let own = event.getIntegerValueField(.eventTargetUnixProcessID) == getpid()
        let decision = gesture.handle(input, at: event.location, intercept: active && !busy && !own)
        switch decision {
        case .pass: lock.unlock(); return Unmanaged.passUnretained(event)
        case .hold:
            let isDown = type == .rightMouseDown || type == .leftMouseDown
            if isDown { heldDown = event.copy() }
            lock.unlock()
            if isDown {
                let point = event.location; let time = Double(event.timestamp) / 1_000_000_000
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: MouseInputNotifications.interceptedButtonDown, object: nil,
                        userInfo: ["point": NSValue(point: point), "time": time])
                }
            }
            return nil
        case .releaseToApp:
            let down = heldDown; heldDown = nil; lock.unlock()
            if let down { down.setIntegerValueField(.eventSourceUserData, value: Self.marker); down.tapPostEvent(proxy) }
            return Unmanaged.passUnretained(event)
        case .complete:
            let down = heldDown; heldDown = nil; busy = true; lock.unlock()
            guard let down, let up = event.copy() else { finish(); return Unmanaged.passUnretained(event) }
            DispatchQueue.main.async { self.onClick(Click(down: down, up: up)) }
            return nil
        }
    }
    /// Used only for unsupported contexts or the explicit native-menu fallback.
    static func passThrough(_ click: Click) {
        guard let down = click.down.copy(), let up = click.up.copy() else { return }
        down.setIntegerValueField(.eventSourceUserData, value: marker)
        up.setIntegerValueField(.eventSourceUserData, value: marker)
        down.timestamp = DispatchTime.now().uptimeNanoseconds
        down.post(tap: .cgSessionEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            up.timestamp = DispatchTime.now().uptimeNanoseconds; up.post(tap: .cgSessionEventTap)
        }
    }
}
