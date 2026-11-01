import Foundation

/// Mouse-only, balanced interception. A right drag is returned to the app rather
/// than converted into a menu. Releasing Control early still consumes its up.
public struct SecondaryClickGesture: Sendable {
    public enum Input: Sendable { case down(right: Bool, control: Bool), drag(right: Bool), up(right: Bool) }
    public enum Decision: Equatable, Sendable { case pass, hold, complete, releaseToApp }
    private var right: Bool?
    private var origin: CGPoint = .zero
    public init() {}
    public mutating func handle(_ input: Input, at point: CGPoint, intercept: Bool) -> Decision {
        switch input {
        case let .down(isRight, control):
            guard right == nil, intercept, isRight || control else { return .pass }
            right = isRight; origin = point; return .hold
        case let .drag(isRight):
            guard right == isRight else { return .pass }
            if hypot(point.x - origin.x, point.y - origin.y) > 4 {
                right = nil; return .releaseToApp
            }
            return .hold
        case let .up(isRight):
            guard right == isRight else { return .pass }
            right = nil; return .complete
        }
    }
    public mutating func reset() { right = nil }
}
