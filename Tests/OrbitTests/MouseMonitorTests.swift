import XCTest
import AppKit
@testable import Orbit

final class MouseMonitorTests: XCTestCase {
    func testEventConversionUsesRecordedPositionAndTime() async {
        await MainActor.run {
            let cgEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: -400, y: 250), mouseButton: .left)!
            cgEvent.timestamp = 12_000_000_000
            let event = NSEvent(cgEvent: cgEvent)!
            let input = MouseMonitor.input(for: event, source: .global, primaryScreenMaxY: 1000)
            XCTAssertEqual(input.point, CGPoint(x: -400, y: 750))
            XCTAssertEqual(input.timestamp!, event.timestamp)
            XCTAssertFalse(input.dragging)
        }
    }

    func testDraggingComesFromEventRatherThanCurrentButtonState() async {
        await MainActor.run {
            let event = NSEvent(cgEvent: CGEvent(mouseEventSource: nil, mouseType: .rightMouseDragged, mouseCursorPosition: .zero, mouseButton: .right)!)!
            let input = MouseMonitor.input(for: event, source: .local, primaryScreenMaxY: 900)
            XCTAssertTrue(input.dragging)
        }
    }

    func testOwnWindowsRequestMovementAndRestoreOriginalValues() async {
        await MainActor.run {
            _ = NSApplication.shared
            let first = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            let second = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            first.isReleasedWhenClosed = false
            second.isReleasedWhenClosed = false
            defer { first.close(); second.close() }
            first.acceptsMouseMovedEvents = false
            second.acceptsMouseMovedEvents = true
            let delivery = LocalMouseMovementDelivery()
            delivery.start(windows: [first, second])
            XCTAssertTrue(first.acceptsMouseMovedEvents)
            XCTAssertTrue(second.acceptsMouseMovedEvents)
            delivery.start(windows: [first])
            delivery.stop()
            XCTAssertFalse(first.acceptsMouseMovedEvents)
            XCTAssertTrue(second.acceptsMouseMovedEvents)
        }
    }

    func testWindowsOpenedAfterEnablingAlsoReceiveMovement() async {
        await MainActor.run {
            _ = NSApplication.shared
            let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.acceptsMouseMovedEvents = false
            defer { window.close() }
            let delivery = LocalMouseMovementDelivery()
            delivery.start(windows: [])
            NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
            XCTAssertTrue(window.acceptsMouseMovedEvents)
            NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
            delivery.stop()
            XCTAssertFalse(window.acceptsMouseMovedEvents)
        }
    }
}

@MainActor
final class InterceptedMouseClickTests: XCTestCase {
    func testConsumedClicksAreDeliveredAndObserverStopsWithMonitoring() {
        let monitor = MouseMonitor()
        var clicks = 0
        XCTAssertTrue(monitor.start { if $0.kind == .click { clicks += 1 } })
        NotificationCenter.default.post(name: MouseInputNotifications.interceptedButtonDown, object: nil,
            userInfo: ["point": NSValue(point: CGPoint(x: 10, y: 20)), "time": 10.0])
        XCTAssertEqual(clicks, 1)
        monitor.stop()
        NotificationCenter.default.post(name: MouseInputNotifications.interceptedButtonDown, object: nil,
            userInfo: ["point": NSValue(point: CGPoint(x: 10, y: 20))])
        XCTAssertEqual(clicks, 1)
    }
}
