import Foundation
import Observation

public enum ShakeSensitivity: String, CaseIterable, Identifiable, Sendable {
    case low, medium, high
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var minimumTravel: Double {
        switch self { case .low: return 450; case .medium: return 300; case .high: return 180 }
    }
}

@MainActor @Observable
public final class FindMyMouseSettings {
    @ObservationIgnored private let defaults: UserDefaults
    public var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Self.key("enabled")) } }
    public var sensitivity: ShakeSensitivity { didSet { defaults.set(sensitivity.rawValue, forKey: Self.key("sensitivity")) } }
    public var radius: Double {
        didSet {
            let bounded = Self.clamp(radius, to: 50...250, fallback: 100)
            if radius != bounded { radius = bounded }
            defaults.set(bounded, forKey: Self.key("radius"))
        }
    }
    public var dimming: Double {
        didSet {
            let bounded = Self.clamp(dimming, to: 0.2...0.8, fallback: 0.6)
            if dimming != bounded { dimming = bounded }
            defaults.set(bounded, forKey: Self.key("dimming"))
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Self.key("enabled"))
        sensitivity = ShakeSensitivity(rawValue: defaults.string(forKey: Self.key("sensitivity")) ?? "") ?? .medium
        radius = Self.clamp((defaults.object(forKey: Self.key("radius")) as? Double) ?? 100, to: 50...250, fallback: 100)
        dimming = Self.clamp((defaults.object(forKey: Self.key("dimming")) as? Double) ?? 0.6, to: 0.2...0.8, fallback: 0.6)
    }

    /// Resets appearance and sensitivity; preserves the user's enable choice.
    public func reset() {
        sensitivity = .medium
        radius = 100
        dimming = 0.6
    }

    private static func key(_ suffix: String) -> String { "orbit.findMyMouse.\(suffix)" }
    private static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}
