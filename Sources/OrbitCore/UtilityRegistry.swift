import Foundation
import Observation

public struct UtilityDescriptor: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let symbol: String

    public init(id: String, name: String, summary: String, symbol: String) {
        self.id = id
        self.name = name
        self.summary = summary
        self.symbol = symbol
    }
}

@MainActor
public protocol UtilityModule: AnyObject {
    var descriptor: UtilityDescriptor { get }
    var isEnabled: Bool { get set }
    func start()
    func stop()
}

@MainActor @Observable
public final class UtilityRegistry {
    public private(set) var modules: [any UtilityModule] = []

    public init() {}

    public func register(_ module: any UtilityModule) {
        precondition(!modules.contains { $0.descriptor.id == module.descriptor.id }, "Duplicate utility identifier")
        modules.append(module)
    }

    public func startEnabled() {
        for module in modules where module.isEnabled { module.start() }
    }

    public func setEnabled(_ enabled: Bool, id: String) {
        guard let module = modules.first(where: { $0.descriptor.id == id }) else { return }
        module.isEnabled = enabled
        if enabled { module.start() } else { module.stop() }
    }

    public func stopAll() {
        for module in modules { module.stop() }
    }
}
