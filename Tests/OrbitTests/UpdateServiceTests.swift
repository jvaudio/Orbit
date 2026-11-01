import XCTest
@testable import Orbit

@MainActor
final class UpdateServiceTests: XCTestCase {
    func testDevelopmentDoesNotCreateOrStartUpdater() {
        var created = false
        let service = UpdateService { created = true; return FakeUpdateDriver() }
        service.start(enabled: false)
        XCTAssertFalse(created)
        XCTAssertFalse(service.canCheck)
        XCTAssertNotNil(service.errorMessage)
    }
    func testStartIsIdempotentAndCheckReadinessTracksDriver() {
        let driver = FakeUpdateDriver()
        let service = UpdateService { driver }
        service.start(enabled: true); service.start(enabled: true)
        XCTAssertEqual(driver.starts, 1)
        XCTAssertTrue(service.canCheck)
        driver.canCheck = false; driver.onChange?()
        service.check()
        XCTAssertEqual(driver.checks, 0)
        driver.canCheck = true; driver.onChange?()
        service.check()
        XCTAssertEqual(driver.checks, 1)
    }
    func testSettingsReflectDriverChangesAndFailuresCanRetry() {
        let driver = FakeUpdateDriver()
        driver.fail = true
        let service = UpdateService { driver }
        service.start(enabled: true)
        XCTAssertFalse(service.isStarted)
        XCTAssertNotNil(service.errorMessage)
        driver.fail = false; service.start(enabled: true)
        XCTAssertTrue(service.isStarted)
        XCTAssertNil(service.errorMessage)
        service.setAutomaticChecks(true); service.setAutomaticDownloads(true)
        XCTAssertTrue(driver.automaticChecks); XCTAssertTrue(driver.automaticDownloads)
        driver.automaticChecks = false; driver.onChange?()
        XCTAssertFalse(service.automaticChecks)
    }
}

@MainActor
private final class FakeUpdateDriver: UpdateDriver {
    var canCheck = true
    var automaticChecks = false
    var automaticDownloads = false
    var onChange: (() -> Void)?
    var starts = 0, checks = 0
    var fail = false
    func start() throws {
        starts += 1
        if fail { throw NSError(domain: "OrbitUpdateTests", code: 1) }
    }
    func check() { checks += 1 }
}
