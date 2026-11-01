import SwiftUI
import AppKit
import OrbitCore
import Observation
import ServiceManagement

@main
struct OrbitApp: App {
    @NSApplicationDelegateAdaptor(OrbitAppDelegate.self) private var delegate

    init() {
        // A short-lived command used by the updater; never starts a second GUI instance.
        if CommandLine.arguments.contains("--login-item-status") {
            print(LoginItemService.statusName(SMAppService.mainApp.status))
            exit(EXIT_SUCCESS)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            OrbitMenu(model: delegate.model)
        } label: {
            Image(nsImage: OrbitMenuBarIcon.image)
                .accessibilityLabel("Orbit")
        }
        Settings {
            GeneralSettingsView(loginItem: delegate.model.loginItem, appearance: delegate.model.appearance)
        }
        .commands {
            CommandGroup(before: .appSettings) {
                Button("Open Orbit…") { delegate.model.openUtilities() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
    }
}

@MainActor
final class OrbitAppDelegate: NSObject, NSApplicationDelegate {
    let model = OrbitModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        model.appearance.apply()
        if CommandLine.arguments.contains("--restore-login-item") {
            model.loginItem.restoreAfterUpdate()
        }
        model.registry.startEnabled()
        if CommandLine.arguments.contains("--show-utilities") || !UserDefaults.standard.bool(forKey: "orbit.hasOpenedUtilities") {
            model.openUtilities()
        }
#if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "--context-test-root"), CommandLine.arguments.indices.contains(index + 1) {
            model.openContextActionTests(root: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        }
#endif
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // LaunchServices can send a reopen event even for a background launch.
        // Opening the utilities window is explicit after the first run.
        return false
    }
    func applicationWillTerminate(_ notification: Notification) { model.shutdown() }
}

@MainActor @Observable
final class OrbitModel {
    let registry = UtilityRegistry()
    let mouse = FindMyMouseUtility(settings: FindMyMouseSettings())
    let rightClick = RightClickUtility()
    let loginItem = LoginItemService()
    let appearance = AppAppearanceSettings()
    @ObservationIgnored private var utilitiesWindow: UtilitiesWindowController?

#if DEBUG
    @ObservationIgnored private var contextActionTests: ContextActionTestWindow?
    func openContextActionTests(root: URL) {
        contextActionTests = ContextActionTestWindow(root: root, utility: rightClick)
        contextActionTests?.showWindow(nil); contextActionTests?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
#endif
    init() { registry.register(mouse); registry.register(rightClick) }

    func openUtilities() {
        if utilitiesWindow == nil { utilitiesWindow = UtilitiesWindowController(model: self) }
        utilitiesWindow?.showWindow(nil)
        utilitiesWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        UserDefaults.standard.set(true, forKey: "orbit.hasOpenedUtilities")
    }

    func shutdown() { registry.stopAll(); mouse.shutdown() }
}
