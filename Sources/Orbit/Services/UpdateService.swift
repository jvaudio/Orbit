import AppKit
import Combine
import Observation
import ServiceManagement
import Sparkle

@MainActor
protocol UpdateDriver: AnyObject {
    var canCheck: Bool { get }
    var automaticChecks: Bool { get set }
    var automaticDownloads: Bool { get set }
    var onChange: (() -> Void)? { get set }
    func start() throws
    func check()
}

/// Owns one updater for the app lifetime. Tests and development builds never
/// schedule network checks or replace the installed development app.
@MainActor @Observable
final class UpdateService {
    private(set) var isStarted = false
    private(set) var canCheck = false
    private(set) var automaticChecks = false
    private(set) var automaticDownloads = false
    private(set) var errorMessage: String?
    @ObservationIgnored private var driver: (any UpdateDriver)?
    @ObservationIgnored private let makeDriver: () -> any UpdateDriver

    init(makeDriver: (() -> any UpdateDriver)? = nil) {
        self.makeDriver = makeDriver ?? { SparkleUpdateDriver() }
    }
    func start(enabled: Bool) {
        guard enabled else { errorMessage = "Update checks are available in release builds."; return }
        guard !isStarted else { return }
        let driver = makeDriver()
        do {
            try driver.start()
            self.driver = driver
            driver.onChange = { [weak self] in self?.refresh() }
            isStarted = true; errorMessage = nil
            refresh()
        } catch {
            errorMessage = "Updates could not start: \(error.localizedDescription)"
        }
    }
    func check() { guard canCheck else { return }; driver?.check(); refresh() }
    func setAutomaticChecks(_ value: Bool) { driver?.automaticChecks = value; refresh() }
    func setAutomaticDownloads(_ value: Bool) { driver?.automaticDownloads = value; refresh() }
    private func refresh() {
        canCheck = driver?.canCheck ?? false
        automaticChecks = driver?.automaticChecks ?? false
        automaticDownloads = driver?.automaticDownloads ?? false
    }
}

@MainActor
private final class SparkleUpdateDriver: NSObject, UpdateDriver, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController!
    private var observations: [NSKeyValueObservation] = []
    var onChange: (() -> Void)?
    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
        let updater = controller.updater
        observations = [
            updater.observe(\.canCheckForUpdates) { [weak self] _, _ in Task { @MainActor in self?.onChange?() } },
            updater.observe(\.automaticallyChecksForUpdates) { [weak self] _, _ in Task { @MainActor in self?.onChange?() } },
            updater.observe(\.automaticallyDownloadsUpdates) { [weak self] _, _ in Task { @MainActor in self?.onChange?() } }
        ]
    }
    var canCheck: Bool { controller.updater.canCheckForUpdates }
    var automaticChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
    var automaticDownloads: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { controller.updater.automaticallyDownloadsUpdates = newValue }
    }
    func start() throws { try controller.updater.start() }
    func check() { controller.checkForUpdates(nil) }
    nonisolated func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        MainActor.assumeIsolated {
            let status = SMAppService.mainApp.status
            UserDefaults.standard.set(status == .enabled || status == .requiresApproval,
                                      forKey: LoginItemService.updateRestoreKey)
        }
    }
}
