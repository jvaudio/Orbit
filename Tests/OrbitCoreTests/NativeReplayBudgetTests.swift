import XCTest
@testable import OrbitCore

final class NativeReplayBudgetTests: XCTestCase {
    func testEarlyIntermediateMenuDoesNotCancelLaterReadyMenu() {
        let budget = NativeReplayBudget(expiresAt: 104)
        // Observed regression: first candidate exhausted probes at ~0.4s;
        // Finder's usable menu notification arrived at ~1.85s.
        XCTAssertEqual(budget.decision(attempt: 6, limit: 6, now: 100.4), .awaitAnotherMenu)
        XCTAssertEqual(budget.decision(attempt: 0, limit: 6, now: 101.85), .retryCandidate)
        XCTAssertEqual(budget.decision(attempt: 0, limit: 6, now: 104), .expired)
    }
    func testColorProbeLimitIsSeparateFromCommandLifetime() {
        let budget = NativeReplayBudget(expiresAt: 4)
        XCTAssertEqual(budget.decision(attempt: 4, limit: 4, now: 0.3), .awaitAnotherMenu)
        XCTAssertEqual(budget.decision(attempt: 0, limit: 4, now: 1.5), .retryCandidate)
        XCTAssertEqual(budget.decision(attempt: 4, limit: 4, now: 5), .expired)
    }
}
