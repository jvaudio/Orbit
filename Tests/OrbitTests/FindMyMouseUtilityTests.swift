import XCTest
import AppKit
import OrbitCore
@testable import Orbit

final class FindMyMouseUtilityTests: XCTestCase {
    func testShakeShowsOverlayAndDisableImmediatelyCleansUp() async {
        await MainActor.run {
            let harness = Harness()
            defer { harness.cleanup() }
            harness.enable()
            harness.utility.start() // Idempotent start must not duplicate monitors.
            XCTAssertEqual(harness.monitor.starts, 1)
            harness.shake()
            XCTAssertTrue(harness.utility.isSpotlightVisible)
            XCTAssertEqual(harness.overlay.shows, 1)
            harness.registry.setEnabled(false, id: "find-my-mouse")
            XCTAssertFalse(harness.utility.isRunning)
            XCTAssertFalse(harness.utility.isSpotlightVisible)
            XCTAssertFalse(harness.monitor.installed)
            XCTAssertTrue(harness.overlay.lastHideWasImmediate)
        }
    }

    func testDisabledPreviewInstallsOnlyTemporaryMonitoringAndExpires() async {
        await MainActor.run {
            let harness = Harness()
            defer { harness.cleanup() }
            harness.utility.preview()
            XCTAssertFalse(harness.utility.isEnabled)
            XCTAssertTrue(harness.utility.isSpotlightVisible)
            XCTAssertTrue(harness.monitor.installed)
            XCTAssertFalse(harness.utility.isRunning)
            harness.clock.time += 0.99
            harness.utility.checkIdle()
            XCTAssertTrue(harness.utility.isSpotlightVisible)
            harness.clock.time += 0.02
            harness.utility.checkIdle()
            XCTAssertFalse(harness.utility.isSpotlightVisible)
            XCTAssertFalse(harness.monitor.installed)
        }
    }

    func testMovementExtendsSpotlightAndClickDismissesWithCooldown() async {
        await MainActor.run {
            let harness = Harness()
            defer { harness.cleanup() }
            harness.enable()
            harness.utility.preview()
            harness.clock.time += 0.8
            harness.monitor.send(.init(kind: .movement, point: CGPoint(x: -500, y: -200)))
            harness.clock.time += 0.3
            harness.utility.checkIdle()
            XCTAssertTrue(harness.utility.isSpotlightVisible)
            XCTAssertEqual(harness.overlay.updates, 1)
            harness.monitor.send(.init(kind: .click, point: .zero))
            XCTAssertFalse(harness.utility.isSpotlightVisible)
            XCTAssertTrue(harness.monitor.installed)
            harness.shake(interval: 0.02)
            XCTAssertFalse(harness.utility.isSpotlightVisible)
        }
    }

    func testFailedMonitoringIsReportedAndCanRetry() async {
        await MainActor.run {
            let harness = Harness()
            defer { harness.cleanup() }
            harness.monitor.canStart = false
            harness.enable()
            XCTAssertFalse(harness.utility.isRunning)
            XCTAssertNotNil(harness.utility.errorMessage)
            harness.monitor.canStart = true
            harness.utility.start()
            XCTAssertTrue(harness.utility.isRunning)
            XCTAssertNil(harness.utility.errorMessage)
        }
    }

    func testSessionSleepWakeAndDisplayChangesResetState() async {
        await MainActor.run {
            let harness = Harness()
            defer { harness.cleanup() }
            harness.enable()
            harness.utility.preview()
            let workspace = NSWorkspace.shared.notificationCenter
            workspace.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
            XCTAssertFalse(harness.utility.isRunning)
            XCTAssertFalse(harness.utility.isSpotlightVisible)
            workspace.post(name: NSWorkspace.willSleepNotification, object: nil)
            workspace.post(name: NSWorkspace.didWakeNotification, object: nil)
            XCTAssertFalse(harness.utility.isRunning)
            workspace.post(name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
            XCTAssertTrue(harness.utility.isRunning)
            harness.utility.preview()
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            XCTAssertFalse(harness.utility.isSpotlightVisible)
            XCTAssertTrue(harness.utility.isRunning)
            XCTAssertTrue(harness.utility.isEnabled)
        }
    }

    func testDraggingNeverActivatesSpotlight() async {
        await MainActor.run {
            let harness = Harness()
            defer { harness.cleanup() }
            harness.enable()
            harness.shake(dragging: true)
            XCTAssertEqual(harness.overlay.shows, 0)
        }
    }

    func testDelayedCallbacksKeepOriginalMovementTiming() async {
        await MainActor.run {
            let harness = Harness()
            defer { harness.cleanup() }
            harness.enable()
            harness.clock.time = 20
            for (index, x) in [0, 80, 0, 80, 0, 80].enumerated() {
                harness.monitor.send(.init(kind: .movement, point: CGPoint(x: x, y: 0), timestamp: 16 + Double(index) * 0.4))
            }
            XCTAssertFalse(harness.utility.isSpotlightVisible, "Slow motion must not become a shake when callbacks arrive together")
            for (index, x) in [0, 80, 0, 80, 0, 80].enumerated() {
                harness.monitor.send(.init(kind: .movement, point: CGPoint(x: x, y: 0), timestamp: 19 + Double(index) * 0.06))
            }
            XCTAssertTrue(harness.utility.isSpotlightVisible)
        }
    }
}

@MainActor
private final class Harness {
    let suite = "OrbitFeatureTests.\(UUID().uuidString)"
    let defaults: UserDefaults
    let monitor = FakeMonitor()
    let overlay = FakeOverlay()
    let clock = FakeClock()
    let utility: FindMyMouseUtility
    let registry = UtilityRegistry()

    init() {
        defaults = UserDefaults(suiteName: suite)!
        let clock = clock
        utility = FindMyMouseUtility(settings: FindMyMouseSettings(defaults: defaults), monitor: monitor, overlay: overlay, now: { clock.time })
        registry.register(utility)
    }
    func enable() { registry.setEnabled(true, id: "find-my-mouse") }
    func shake(interval: Double = 0.06, dragging: Bool = false) {
        for x in [0, 80, 0, 80, 0, 80] {
            monitor.send(.init(kind: .movement, point: CGPoint(x: x, y: 0), dragging: dragging))
            clock.time += interval
        }
    }
    func cleanup() { utility.shutdown(); defaults.removePersistentDomain(forName: suite) }
}

@MainActor
private final class FakeClock { var time = 10.0 }

@MainActor
private final class FakeMonitor: MouseMonitoring {
    var installed = false
    var canStart = true
    var starts = 0
    var handler: (@MainActor (MouseInput) -> Void)?
    func start(_ handler: @escaping @MainActor (MouseInput) -> Void) -> Bool {
        starts += 1
        installed = canStart
        self.handler = canStart ? handler : nil
        return canStart
    }
    func stop() { installed = false; handler = nil }
    func send(_ input: MouseInput) { handler?(input) }
}

@MainActor
private final class FakeOverlay: SpotlightPresenting {
    var shows = 0
    var updates = 0
    var lastHideWasImmediate = false
    func show(at point: CGPoint, radius: Double, dimming: Double) { shows += 1 }
    func update(at point: CGPoint, radius: Double, dimming: Double) { updates += 1 }
    func hide(immediately: Bool) { lastHideWasImmediate = immediately }
}
