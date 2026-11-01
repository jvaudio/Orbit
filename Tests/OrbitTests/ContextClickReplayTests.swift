import XCTest
import CoreGraphics
@testable import Orbit

final class ContextClickReplayTests: XCTestCase {
    func testRetainsOriginalWindowAndTargetRoutingWithoutMutatingSource() {
        let original = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: CGPoint(x: -300, y: 640), mouseButton: .right)!
        original.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: 987)
        original.setIntegerValueField(.eventTargetUnixProcessID, value: 1234)
        original.setIntegerValueField(.mouseEventClickState, value: 1)
        let events = ContextClickReplay.events(from: original, marker: 42, movePaste: false)!
        for event in [events.down, events.up] {
            XCTAssertEqual(event.getIntegerValueField(.mouseEventWindowUnderMousePointer), 987)
            XCTAssertEqual(event.getIntegerValueField(.eventTargetUnixProcessID), 1234)
            XCTAssertEqual(event.getIntegerValueField(.mouseEventClickState), 1)
            XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), 42)
            XCTAssertEqual(event.location, CGPoint(x: -300, y: 640))
        }
        XCTAssertEqual(events.down.type, .rightMouseDown)
        XCTAssertEqual(events.up.type, .rightMouseUp)
        XCTAssertEqual(original.type, .rightMouseDown)
        XCTAssertNotEqual(original.getIntegerValueField(.eventSourceUserData), 42)
    }
    func testControlClickAndMovePastePreserveRequiredModifiers() {
        let original = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left)!
        original.flags = .maskControl
        let events = ContextClickReplay.events(from: original, marker: 42, movePaste: true)!
        XCTAssertEqual(events.up.type, .leftMouseUp)
        for event in [events.down, events.up] {
            XCTAssertTrue(event.flags.contains(.maskControl))
            XCTAssertTrue(event.flags.contains(.maskAlternate))
        }
        XCTAssertFalse(original.flags.contains(.maskAlternate))
    }
}
