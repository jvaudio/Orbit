import Foundation
import Observation
import ServiceManagement

@MainActor
protocol LoginItemRegistration: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

@MainActor
private final class SystemLoginItemRegistration: LoginItemRegistration {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

@MainActor @Observable
final class LoginItemService {
    @ObservationIgnored private let registration: any LoginItemRegistration
    private(set) var status: SMAppService.Status
    private(set) var errorMessage: String?
    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var statusText: String {
        switch status {
        case .enabled: return "Orbit will open in the menu bar when you log in."
        case .requiresApproval: return "Allow Orbit in System Settings → General → Login Items."
        case .notRegistered: return "Launch at login is off."
        case .notFound: return "Keep Orbit in Applications, then try again."
        @unknown default: return "Login item status is unavailable."
        }
    }

    init(registration: (any LoginItemRegistration)? = nil) {
        let registration = registration ?? SystemLoginItemRegistration()
        self.registration = registration
        status = registration.status
    }

    func refresh() { status = registration.status }

    static func statusName(_ status: SMAppService.Status) -> String {
        switch status {
        case .enabled: return "enabled"
        case .requiresApproval: return "requires-approval"
        case .notRegistered, .notFound: return "disabled"
        @unknown default: return "unknown"
        }
    }

    /// Used only when Run captured an enabled registration before replacing the app.
    func restoreAfterUpdate() {
        refresh()
        if status != .enabled && status != .requiresApproval { setEnabled(true) }
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled { try registration.register() }
            else { try registration.unregister() }
        } catch {
            errorMessage = "Could not update launch at login: \(error.localizedDescription) Keep Orbit in Applications and try again."
        }
        refresh()
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
