import XCTest
import ServiceManagement
@testable import Orbit

final class LoginItemServiceTests: XCTestCase {
    func testUpdateRestoresLostRegistrationAndRefreshesActualStatus() async {
        await MainActor.run {
            for initial in [SMAppService.Status.notRegistered, .notFound] {
                let registration = FakeLoginRegistration(status: initial)
                let service = LoginItemService(registration: registration)
                service.restoreAfterUpdate()
                XCTAssertEqual(registration.registerCalls, 1)
                XCTAssertEqual(service.status, .enabled)
                XCTAssertTrue(service.isEnabled)
            }
        }
    }

    func testUpdateDoesNotReregisterEnabledOrPendingApproval() async {
        await MainActor.run {
            for initial in [SMAppService.Status.enabled, .requiresApproval] {
                let registration = FakeLoginRegistration(status: initial)
                let service = LoginItemService(registration: registration)
                service.restoreAfterUpdate()
                XCTAssertEqual(registration.registerCalls, 0)
                XCTAssertEqual(service.status, initial)
            }
        }
    }

    func testFailedRestorationDoesNotClaimEnabledAndDisableUsesSystemState() async {
        await MainActor.run {
            let registration = FakeLoginRegistration(status: .notRegistered)
            registration.shouldFail = true
            let service = LoginItemService(registration: registration)
            service.restoreAfterUpdate()
            XCTAssertFalse(service.isEnabled)
            XCTAssertNotNil(service.errorMessage)
            registration.shouldFail = false
            service.setEnabled(true)
            service.setEnabled(false)
            XCTAssertEqual(registration.unregisterCalls, 1)
            XCTAssertFalse(service.isEnabled)
            XCTAssertNil(service.errorMessage)
        }
    }
}

@MainActor
private final class FakeLoginRegistration: LoginItemRegistration {
    var status: SMAppService.Status
    var registerCalls = 0
    var unregisterCalls = 0
    var shouldFail = false
    init(status: SMAppService.Status) { self.status = status }
    func register() throws {
        registerCalls += 1
        if shouldFail { throw NSError(domain: "OrbitLoginTests", code: 1) }
        status = .enabled
    }
    func unregister() throws { unregisterCalls += 1; status = .notRegistered }
}
