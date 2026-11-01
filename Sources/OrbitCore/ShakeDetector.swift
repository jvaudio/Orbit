import Foundation
import CoreGraphics

/// Pure detector in desktop points using monotonic timestamps, independent of event frequency.
public struct ShakeDetector {
    public struct Diagnostics {
        public let samples: Int
        public let travel: Double
        public let areaDiagonal: Double
        public let reversals: Int
    }
    public private(set) var diagnostics: Diagnostics?
    private struct Sample { let point: CGPoint; let time: TimeInterval }
    private var samples: [Sample] = []
    private var cooldownUntil: TimeInterval = 0
    private static let maximumAreaDiagonal = 520.0
    public var sensitivity: ShakeSensitivity

    public init(sensitivity: ShakeSensitivity = .medium) { self.sensitivity = sensitivity }

    public mutating func reset(at time: TimeInterval, cooldown: TimeInterval = 0.6) {
        samples.removeAll(keepingCapacity: true)
        diagnostics = nil
        cooldownUntil = time + cooldown
    }

    public mutating func add(_ point: CGPoint, at time: TimeInterval, dragging: Bool = false) -> Bool {
        diagnostics = nil
        guard point.x.isFinite, point.y.isFinite, time.isFinite else { return false }
        if dragging { reset(at: time); return false }
        guard time >= cooldownUntil else { return false }
        if let last = samples.last, time < last.time { reset(at: time); return false }
        samples.removeAll { time - $0.time > 0.75 }
        // Accumulate small deltas against the last retained position instead of rejecting slow devices.
        if let last = samples.last, Self.distance(point, last.point) < 2 { return false }
        samples.append(Sample(point: point, time: time))
        // Bound storage even for exceptionally high event-rate devices.
        if samples.count > 1024 { samples.removeFirst(samples.count - 1024) }
        keepCompactSuffix()
        guard samples.count >= 5 else { return false }
        let points = samples.map(\.point)
        let xs = points.map(\.x), ys = points.map(\.y)
        let width = xs.max()! - xs.min()!, height = ys.max()! - ys.min()!
        let diagonal = hypot(width, height)
        let travel = zip(points, points.dropFirst()).reduce(0.0) { $0 + Self.distance($1.0, $1.1) }
        let reversals = max(Self.reversals(xs), Self.reversals(ys))
        diagnostics = Diagnostics(samples: samples.count, travel: travel, areaDiagonal: diagonal, reversals: reversals)
        guard diagonal >= 12, diagonal <= Self.maximumAreaDiagonal else { return false }
        guard travel >= sensitivity.minimumTravel, travel / diagonal >= 2.5 else { return false }
        guard reversals >= 3 else { return false }
        reset(at: time)
        return true
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> Double { hypot(a.x - b.x, a.y - b.y) }

    /// A preceding journey across the desktop must not exclude a new, compact shake.
    /// Stop at the first oversized segment; do not combine disconnected pieces of a large sweep.
    private mutating func keepCompactSuffix() {
        guard let last = samples.last else { return }
        var minX = last.point.x, maxX = last.point.x
        var minY = last.point.y, maxY = last.point.y
        var first = samples.count - 1
        for index in samples.indices.dropLast().reversed() {
            let point = samples[index].point
            let nextMinX = min(minX, point.x), nextMaxX = max(maxX, point.x)
            let nextMinY = min(minY, point.y), nextMaxY = max(maxY, point.y)
            if hypot(nextMaxX - nextMinX, nextMaxY - nextMinY) > Self.maximumAreaDiagonal { break }
            minX = nextMinX; maxX = nextMaxX
            minY = nextMinY; maxY = nextMaxY
            first = index
        }
        if first > 0 { samples.removeFirst(first) }
    }

    /// Hysteresis keeps sub-eight-point wobble from counting as direction changes.
    private static func reversals(_ values: [CGFloat]) -> Int {
        guard let first = values.first else { return 0 }
        var extreme = first, direction = 0, count = 0
        for value in values.dropFirst() {
            if direction == 0 {
                if abs(value - extreme) >= 8 { direction = value > extreme ? 1 : -1; extreme = value }
            } else if direction > 0 {
                if value > extreme { extreme = value }
                else if extreme - value >= 8 { count += 1; direction = -1; extreme = value }
            } else {
                if value < extreme { extreme = value }
                else if value - extreme >= 8 { count += 1; direction = 1; extreme = value }
            }
        }
        return count
    }
}
