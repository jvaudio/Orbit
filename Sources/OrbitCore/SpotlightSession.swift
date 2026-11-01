import Foundation
import CoreGraphics

public struct SpotlightSession {
    public private(set) var isActive = false
    public private(set) var lastMovement: TimeInterval = 0
    private var movementAnchor = CGPoint.zero

    public init() {}

    public mutating func activate(at point: CGPoint, time: TimeInterval) {
        isActive = true
        lastMovement = time
        movementAnchor = point
    }

    public mutating func move(to point: CGPoint, time: TimeInterval) {
        guard isActive, hypot(point.x - movementAnchor.x, point.y - movementAnchor.y) >= 2 else { return }
        movementAnchor = point
        lastMovement = time
    }

    public func shouldDismiss(at time: TimeInterval) -> Bool { isActive && time - lastMovement >= 1 }
    public mutating func dismiss() { isActive = false }
}
