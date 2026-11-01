import XCTest
import OrbitCore
@testable import Orbit

@MainActor
final class RightClickUtilityTests: XCTestCase {
    func testStartsOffAndDoesNotMonitorWithoutPermission() {
        let name = "OrbitRightClickTest.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: name)!
        defer { preferences.removePersistentDomain(forName: name) }
        let utility = RightClickUtility(preferences: preferences, accessCheck: { false })
        XCTAssertFalse(utility.isEnabled)
        utility.start()
        XCTAssertFalse(utility.isRunning)
        let registry = UtilityRegistry(); registry.register(utility)
        registry.setEnabled(true, id: utility.descriptor.id)
        XCTAssertTrue(utility.isEnabled)
        XCTAssertFalse(utility.isRunning)
        XCTAssertFalse(utility.hasAccess)
        XCTAssertTrue(preferences.bool(forKey: "orbit.rightClick.enabled"))
        registry.setEnabled(false, id: utility.descriptor.id)
        XCTAssertFalse(utility.isRunning)
        XCTAssertFalse(preferences.bool(forKey: "orbit.rightClick.enabled"))
    }
    func testEnabledPreferenceSurvivesUnavailableAccessAndShutdown() {
        let name = "OrbitRightClickTest.\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: name)!
        defer { preferences.removePersistentDomain(forName: name) }
        preferences.set(true, forKey: "orbit.rightClick.enabled")
        let utility = RightClickUtility(preferences: preferences, accessCheck: { false })
        XCTAssertTrue(utility.isEnabled)
        utility.stop(); utility.stop()
        XCTAssertTrue(utility.isEnabled)
        XCTAssertFalse(utility.isRunning)
    }
}
