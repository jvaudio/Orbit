import SwiftUI
import ServiceManagement
import AppKit

struct GeneralSettingsView: View {
    let loginItem: LoginItemService
    let appearance: AppAppearanceSettings

    var body: some View {
        TabView {
            general
                .tabItem { Label("General", systemImage: "gearshape") }
            about
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 410)
        .onAppear { loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in loginItem.refresh() }
    }

    private var general: some View {
        @Bindable var appearance = appearance
        return Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appearance.mode) {
                    ForEach(AppAppearanceSettings.Mode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented)
            }
            Section {
                Toggle("Launch Orbit at login", isOn: Binding(
                    get: { loginItem.isEnabled },
                    set: { loginItem.setEnabled($0) }
                ))
                Text(loginItem.statusText).font(.callout).foregroundStyle(.secondary)
                if loginItem.status == .requiresApproval {
                    Button("Open Login Items Settings…") { loginItem.openSettings() }
                }
                if let error = loginItem.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange)
                }
            } header: {
                Text("Startup")
            } footer: {
                Text("Orbit lives in your menu bar. Closing the utilities window keeps your enabled tools running.")
            }
        }
        .formStyle(.grouped)
    }

    private var about: some View {
        VStack(spacing: 14) {
            OrbitBrandIcon(size: 80)
            VStack(spacing: 5) {
                Text("Orbit").font(.largeTitle.bold())
                Text("Version 0.1.0").foregroundStyle(.secondary)
            }
            Text("Small utilities for your Mac.").font(.title3)
            Label("Your settings stay on this device.", systemImage: "lock")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
