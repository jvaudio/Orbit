import SwiftUI
import AppKit

struct OrbitMenu: View {
    let model: OrbitModel

    var body: some View {
        Toggle("Find My Mouse", isOn: Binding(
            get: { model.mouse.isEnabled },
            set: { model.registry.setEnabled($0, id: model.mouse.descriptor.id) }
        ))
        Button("Preview Spotlight", systemImage: "play.fill") { model.mouse.preview() }
        if model.mouse.errorMessage != nil {
            Text("Mouse monitoring unavailable")
        }
        Divider()
        Toggle("Right-Click Menu", isOn: Binding(
            get: { model.rightClick.isEnabled },
            set: { model.registry.setEnabled($0, id: model.rightClick.descriptor.id) }
        ))
        Button("Preview Right-Click Menu") { model.rightClick.preview() }
        Divider()
        Button("Open Orbit…", systemImage: "macwindow") { model.openUtilities() }
        SettingsLink { Label("Settings…", systemImage: "gearshape") }
            .keyboardShortcut(",")
        Divider()
        Button("Quit Orbit") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
