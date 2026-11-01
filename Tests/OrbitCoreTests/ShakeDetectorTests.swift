import XCTest
import CoreGraphics
@testable import OrbitCore

final class ShakeDetectorTests: XCTestCase {
    private func feed(_ points: [CGPoint], interval: Double = 0.06, start: Double = 10, detector: inout ShakeDetector, dragging: Bool = false) -> [Bool] {
        points.enumerated().map { detector.add($0.element, at: start + Double($0.offset) * interval, dragging: dragging) }
    }

    private var horizontal: [CGPoint] { [0, 80, 0, 80, 0, 80].map { CGPoint(x: $0, y: 0) } }

    func testIntentionalShakesInAllDirections() {
        let paths = [horizontal, horizontal.map { CGPoint(x: 0, y: $0.x) }, horizontal.map { CGPoint(x: $0.x, y: $0.x) }]
        for path in paths {
            var detector = ShakeDetector()
            XCTAssertEqual(feed(path, detector: &detector).filter { $0 }.count, 1)
        }
    }

    func testNormalMovementJitterAndLargeSweepsDoNotActivate() {
        let paths: [[CGPoint]] = [
            (0...20).map { CGPoint(x: $0 * 10, y: $0 * 2) },
            (0...50).map { CGPoint(x: $0.isMultiple(of: 2) ? 0 : 3, y: 1) },
            // 300–500-point repeated oscillations are deliberate compact shakes; reject wider sweeps.
            [0, 700, 0, 700, 0].map { CGPoint(x: $0, y: 0) },
            [0, 80, 0, 80].map { CGPoint(x: $0, y: 0) }
        ]
        for path in paths {
            var detector = ShakeDetector()
            XCTAssertFalse(feed(path, interval: 0.01, detector: &detector).contains(true))
        }
    }

    func testSlowMotionExpiresAndDraggingIsIgnored() {
        var slow = ShakeDetector(), dragging = ShakeDetector()
        XCTAssertFalse(feed(horizontal, interval: 0.4, detector: &slow).contains(true))
        XCTAssertFalse(feed(horizontal, detector: &dragging, dragging: true).contains(true))
    }

    func testCooldownAndExplicitResetPreventReactivation() {
        var detector = ShakeDetector()
        XCTAssertTrue(feed(horizontal, detector: &detector).contains(true))
        XCTAssertFalse(feed(horizontal, interval: 0.02, start: 10.4, detector: &detector).contains(true))
        XCTAssertTrue(feed(horizontal, start: 12, detector: &detector).contains(true))
        detector.reset(at: 13)
        XCTAssertFalse(feed(horizontal, interval: 0.02, start: 13, detector: &detector).contains(true))
        XCTAssertTrue(feed(horizontal, start: 14, detector: &detector).contains(true))
    }

    func testSensitivityChangesRequiredTravel() {
        let path = [0, 50, 0, 50, 0, 50].map { CGPoint(x: $0, y: 0) }
        var high = ShakeDetector(sensitivity: .high), low = ShakeDetector(sensitivity: .low)
        XCTAssertTrue(feed(path, detector: &high).contains(true))
        XCTAssertFalse(feed(path, detector: &low).contains(true))
    }

    func testNegativeCoordinatesAndDenseSamples() {
        var detector = ShakeDetector()
        let points = horizontal.map { CGPoint(x: $0.x - 1800, y: -300) }
        XCTAssertTrue(feed(points, detector: &detector).contains(true))
        var dense = ShakeDetector()
        var path: [CGPoint] = []
        for turn in 0..<6 {
            for step in 0..<80 { path.append(CGPoint(x: turn.isMultiple(of: 2) ? step : 80 - step, y: 0)) }
        }
        XCTAssertTrue(feed(path, interval: 0.001, detector: &dense).contains(true))
    }

    func testLongPauseAndInvalidInputCannotActivate() {
        var detector = ShakeDetector()
        _ = feed(Array(horizontal.prefix(4)), detector: &detector)
        XCTAssertFalse(detector.add(CGPoint(x: 0, y: 0), at: 30))
        XCTAssertFalse(detector.add(CGPoint(x: Double.nan, y: 0), at: 31))
        XCTAssertFalse(detector.add(.zero, at: .infinity))
    }

    func testNaturalCompactShakesWithAcceleratedPointerTravel() {
        // Physical diagnostics showed deliberate rapid shakes spanning 300–500 desktop points.
        for amplitude in [300, 400, 500] {
            var detector = ShakeDetector()
            let path = [0, amplitude, 0, amplitude, 0, amplitude].map { CGPoint(x: $0, y: 10) }
            XCTAssertTrue(feed(path, detector: &detector).contains(true), "Rejecting a \(amplitude)-point deliberate shake")
        }
        var dense = ShakeDetector()
        var path: [CGPoint] = []
        for turn in 0..<5 {
            for step in stride(from: 0, through: 400, by: 20) {
                path.append(CGPoint(x: turn.isMultiple(of: 2) ? step : 400 - step, y: 10))
            }
        }
        XCTAssertTrue(feed(path, interval: 0.003, detector: &dense).contains(true))
    }

    func testTravelImmediatelyBeforeShakeDoesNotPoisonDetection() {
        var detector = ShakeDetector()
        let path = [0, 1200, 1280, 1200, 1280, 1200, 1280].map { CGPoint(x: $0, y: 0) }
        XCTAssertTrue(feed(path, detector: &detector).contains(true))
    }

    func testContinuousOversizedSweepsStillDoNotActivate() {
        var detector = ShakeDetector()
        var path: [CGPoint] = []
        for turn in 0..<6 {
            for step in stride(from: 0, through: 800, by: 20) {
                path.append(CGPoint(x: turn.isMultiple(of: 2) ? step : 800 - step, y: 0))
            }
        }
        XCTAssertFalse(feed(path, interval: 0.002, detector: &detector).contains(true))
    }
}
