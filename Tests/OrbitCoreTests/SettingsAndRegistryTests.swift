import XCTest
@testable import OrbitCore

final class SettingsAndRegistryTests: XCTestCase {
    func testDefaultsPersistenceAndReset() async {
        await MainActor.run {
            let suite = "OrbitTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let settings = FindMyMouseSettings(defaults: defaults)
            XCTAssertFalse(settings.isEnabled)
            XCTAssertEqual(settings.radius, 100)
            XCTAssertEqual(settings.dimming, 0.6)
            XCTAssertEqual(settings.sensitivity, .medium)
            settings.isEnabled = true
            settings.radius = 175
            settings.dimming = 0.75
            settings.sensitivity = .high
            let restored = FindMyMouseSettings(defaults: defaults)
            XCTAssertTrue(restored.isEnabled)
            XCTAssertEqual(restored.radius, 175)
            XCTAssertEqual(restored.dimming, 0.75)
            XCTAssertEqual(restored.sensitivity, .high)
            restored.reset()
            XCTAssertTrue(restored.isEnabled)
            XCTAssertEqual(restored.radius, 100)
            XCTAssertEqual(restored.dimming, 0.6)
            XCTAssertEqual(restored.sensitivity, .medium)
        }
    }

    func testInvalidSavedValuesAndBounds() async {
        await MainActor.run {
            let suite = "OrbitTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            defaults.set(-20.0, forKey: "orbit.findMyMouse.radius")
            defaults.set(4.0, forKey: "orbit.findMyMouse.dimming")
            defaults.set("invalid", forKey: "orbit.findMyMouse.sensitivity")
            let settings = FindMyMouseSettings(defaults: defaults)
            XCTAssertEqual(settings.radius, 50)
            XCTAssertEqual(settings.dimming, 0.8)
            XCTAssertEqual(settings.sensitivity, .medium)
            settings.radius = 999
            settings.dimming = .nan
            XCTAssertEqual(settings.radius, 250)
            XCTAssertEqual(settings.dimming, 0.6)
        }
    }

    func testRegistryStartsOnlyEnabledAndStopsImmediatelyWithoutChangingPreference() async {
        await MainActor.run {
            let registry = UtilityRegistry()
            let first = FakeUtility(id: "first", enabled: true)
            let second = FakeUtility(id: "second", enabled: false)
            registry.register(first)
            registry.register(second)
            registry.startEnabled()
            XCTAssertEqual(first.starts, 1)
            XCTAssertEqual(second.starts, 0)
            registry.setEnabled(false, id: "first")
            XCTAssertFalse(first.isEnabled)
            XCTAssertEqual(first.stops, 1)
            registry.setEnabled(true, id: "second")
            XCTAssertTrue(second.isEnabled)
            XCTAssertEqual(second.starts, 1)
            registry.stopAll()
            XCTAssertEqual(first.stops, 2)
            XCTAssertEqual(second.stops, 1)
            XCTAssertTrue(second.isEnabled)
        }
    }
}

@MainActor
private final class FakeUtility: UtilityModule {
    let descriptor: UtilityDescriptor
    var isEnabled: Bool
    var starts = 0
    var stops = 0
    init(id: String, enabled: Bool) {
        descriptor = UtilityDescriptor(id: id, name: id, summary: "Test", symbol: "circle")
        isEnabled = enabled
    }
    func start() { starts += 1 }
    func stop() { stops += 1 }
}
