import Foundation

/// A menu-open notification can describe an intermediate menu. Exhausting its
/// layout probes must not consume the pending command for a later valid menu.
public struct NativeReplayBudget: Sendable {
    public enum Decision: Equatable, Sendable { case retryCandidate, awaitAnotherMenu, expired }
    public let expiresAt: TimeInterval
    public init(expiresAt: TimeInterval) { self.expiresAt = expiresAt }
    public func decision(attempt: Int, limit: Int, now: TimeInterval) -> Decision {
        guard now < expiresAt else { return .expired }
        return attempt < limit ? .retryCandidate : .awaitAnotherMenu
    }
}
