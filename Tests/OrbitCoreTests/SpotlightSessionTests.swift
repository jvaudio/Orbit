import XCTest
import CoreGraphics
@testable import OrbitCore

final class SpotlightSessionTests: XCTestCase {
    func testOneSecondIdleTimeoutAndMovementExtension() {
        var session = SpotlightSession()
        XCTAssertFalse(session.shouldDismiss(at: 100))
        session.activate(at: .zero, time: 10)
        XCTAssertFalse(session.shouldDismiss(at: 10.99))
        session.move(to: CGPoint(x: 20, y: 0), time: 10.8)
        XCTAssertFalse(session.shouldDismiss(at: 11.79))
        XCTAssertTrue(session.shouldDismiss(at: 11.8))
        session.dismiss()
        XCTAssertFalse(session.isActive)
        XCTAssertFalse(session.shouldDismiss(at: 100))
    }

    func testJitterDoesNotExtendSessionButSmallDeltasAccumulate() {
        var session = SpotlightSession()
        session.activate(at: .zero, time: 10)
        session.move(to: CGPoint(x: 0.5, y: 0), time: 10.5)
        XCTAssertTrue(session.shouldDismiss(at: 11))
        session.move(to: CGPoint(x: 2.1, y: 0), time: 10.9)
        XCTAssertFalse(session.shouldDismiss(at: 11))
    }
}
