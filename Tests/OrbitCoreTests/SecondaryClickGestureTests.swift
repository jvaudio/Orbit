import XCTest
@testable import OrbitCore

final class SecondaryClickGestureTests: XCTestCase {
    func testRightClickConsumesBalancedPairOnly() {
        var gesture = SecondaryClickGesture()
        XCTAssertEqual(gesture.handle(.down(right: true, control: false), at: .zero, intercept: true), .hold)
        XCTAssertEqual(gesture.handle(.up(right: true), at: .zero, intercept: true), .complete)
        XCTAssertEqual(gesture.handle(.up(right: true), at: .zero, intercept: true), .pass)
    }
    func testControlClickKeepsUpBalancedAfterControlIsReleased() {
        var gesture = SecondaryClickGesture()
        XCTAssertEqual(gesture.handle(.down(right: false, control: true), at: .zero, intercept: true), .hold)
        XCTAssertEqual(gesture.handle(.up(right: false), at: .zero, intercept: false), .complete)
    }
    func testDraggingRestoresOriginalGestureInsteadOfShowingMenu() {
        var gesture = SecondaryClickGesture()
        XCTAssertEqual(gesture.handle(.down(right: true, control: false), at: .zero, intercept: true), .hold)
        XCTAssertEqual(gesture.handle(.drag(right: true), at: CGPoint(x: 2, y: 0), intercept: true), .hold)
        XCTAssertEqual(gesture.handle(.drag(right: true), at: CGPoint(x: 20, y: 0), intercept: true), .releaseToApp)
        XCTAssertEqual(gesture.handle(.up(right: true), at: CGPoint(x: 20, y: 0), intercept: true), .pass)
    }
    func testOrdinaryClicksAndDisabledInterceptionPassThrough() {
        var gesture = SecondaryClickGesture()
        XCTAssertEqual(gesture.handle(.down(right: false, control: false), at: .zero, intercept: true), .pass)
        XCTAssertEqual(gesture.handle(.up(right: false), at: .zero, intercept: true), .pass)
        XCTAssertEqual(gesture.handle(.down(right: true, control: false), at: .zero, intercept: false), .pass)
        XCTAssertEqual(gesture.handle(.up(right: true), at: .zero, intercept: false), .pass)
    }
}
