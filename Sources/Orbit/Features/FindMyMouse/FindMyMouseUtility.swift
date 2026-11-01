import AppKit
import Observation
import OrbitCore
import OSLog

@MainActor @Observable
final class FindMyMouseUtility: UtilityModule {
    let descriptor = UtilityDescriptor(id: "find-my-mouse", name: "Find My Mouse", summary: "Shake to put your pointer in the spotlight.", symbol: "cursorarrow.rays")
    let settings: FindMyMouseSettings
    private(set) var isRunning = false
    private(set) var isSpotlightVisible = false
    private(set) var errorMessage: String?
    var isEnabled: Bool {
        get { settings.isEnabled }
        set { settings.isEnabled = newValue }
    }

    @ObservationIgnored private let overlay: any SpotlightPresenting
    @ObservationIgnored private let monitor: any MouseMonitoring
    @ObservationIgnored private let now: () -> TimeInterval
    @ObservationIgnored private var detector = ShakeDetector()
    @ObservationIgnored private var session = SpotlightSession()
    @ObservationIgnored private var monitorsInstalled = false
    @ObservationIgnored private var idleTimer: Timer?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var sleeping = false
    @ObservationIgnored private var sessionIsActive = true
    @ObservationIgnored private let diagnosticsEnabled = CommandLine.arguments.contains("--mouse-diagnostics")
    @ObservationIgnored private var diagnosticLocalCount = 0
    @ObservationIgnored private var diagnosticGlobalCount = 0
    @ObservationIgnored private var lastDiagnosticLog: TimeInterval = 0
    private var suspended: Bool { sleeping || !sessionIsActive }
    @ObservationIgnored private let logger = Logger(subsystem: "com.jerryvoelker.Orbit", category: "FindMyMouse")

    init(settings: FindMyMouseSettings, monitor: (any MouseMonitoring)? = nil, overlay: (any SpotlightPresenting)? = nil, now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.settings = settings
        self.monitor = monitor ?? MouseMonitor()
        self.overlay = overlay ?? SpotlightOverlay()
        self.now = now
        observe(NSWorkspace.willSleepNotification, in: NSWorkspace.shared.notificationCenter) { $0.sleeping = true; $0.stop() }
        observe(NSWorkspace.sessionDidResignActiveNotification, in: NSWorkspace.shared.notificationCenter) { $0.sessionIsActive = false; $0.stop() }
        observe(NSWorkspace.didWakeNotification, in: NSWorkspace.shared.notificationCenter) { $0.sleeping = false; $0.resume() }
        observe(NSWorkspace.sessionDidBecomeActiveNotification, in: NSWorkspace.shared.notificationCenter) { $0.sessionIsActive = true; $0.resume() }
        observe(NSApplication.didChangeScreenParametersNotification, in: .default) { $0.resetTransientState() }
    }

    func start() {
        guard isEnabled, !suspended else { return }
        installMonitors()
        isRunning = monitorsInstalled
        logger.info("Mouse utility started: \(self.isRunning)")
    }

    func stop() {
        resetTransientState()
        removeMonitors()
        logger.info("Mouse utility stopped")
    }

    func preview() {
        guard !suspended else { return }
        installMonitors()
        show(at: NSEvent.mouseLocation, time: now())
    }

    func refreshAppearance() {
        guard session.isActive else { return }
        overlay.update(at: NSEvent.mouseLocation, radius: settings.radius, dimming: settings.dimming)
    }

    private func observe(_ name: Notification.Name, in center: NotificationCenter, action: @escaping @MainActor (FindMyMouseUtility) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self { action(self) } }
        }
        observers.append((center, token))
    }

    private func installMonitors() {
        guard !monitorsInstalled else { return }
        monitorsInstalled = monitor.start { [weak self] input in self?.handle(input) }
        if !monitorsInstalled {
            errorMessage = "Mouse monitoring could not start. Try turning Find My Mouse off and on again."
            removeMonitors()
        } else { errorMessage = nil }
    }

    private func removeMonitors() {
        monitor.stop()
        monitorsInstalled = false
        isRunning = false
    }

    private func handle(_ input: MouseInput) {
        let time = now()
        switch input.kind {
        case .click:
            dismiss()
        case .movement:
            if input.source == .local { diagnosticLocalCount += 1 } else { diagnosticGlobalCount += 1 }
            let point = input.point
            if session.isActive {
                session.move(to: point, time: time)
                overlay.update(at: point, radius: settings.radius, dimming: settings.dimming)
            } else if isEnabled && !suspended {
                detector.sensitivity = settings.sensitivity
                if detector.add(point, at: input.timestamp ?? time, dragging: input.dragging) {
                    show(at: point, time: time)
                }
            }
            logMovementDiagnostics(at: time, dragging: input.dragging)
        }
    }

    private func show(at point: CGPoint, time: TimeInterval) {
        session.activate(at: point, time: time)
        isSpotlightVisible = true
        overlay.show(at: point, radius: settings.radius, dimming: settings.dimming)
        logger.notice("Spotlight activated")
        idleTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.checkIdle()
            }
        }
        timer.tolerance = 0.02
        idleTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func dismiss(immediately: Bool = false) {
        if session.isActive { logger.info("Spotlight dismissed") }
        session.dismiss()
        isSpotlightVisible = false
        idleTimer?.invalidate()
        idleTimer = nil
        overlay.hide(immediately: immediately)
        detector.reset(at: now())
        if !isEnabled { removeMonitors() }
    }

    private func resetTransientState() { dismiss(immediately: true) }
    private func logMovementDiagnostics(at time: TimeInterval, dragging: Bool) {
        guard diagnosticsEnabled, time - lastDiagnosticLog >= 1 else { return }
        lastDiagnosticLog = time
        let metrics = detector.diagnostics
        logger.notice("Movement: local=\(self.diagnosticLocalCount) global=\(self.diagnosticGlobalCount) dragging=\(dragging) samples=\(metrics?.samples ?? 0) travel=\(Int(metrics?.travel ?? 0)) area=\(Int(metrics?.areaDiagonal ?? 0)) reversals=\(metrics?.reversals ?? 0)")
        diagnosticLocalCount = 0
        diagnosticGlobalCount = 0
    }
    func checkIdle() { if session.shouldDismiss(at: now()) { dismiss() } }
    private func resume() { resetTransientState(); if isEnabled && !suspended { start() } }

    func shutdown() {
        stop()
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
    }
}
