import SwiftUI
import OrbitCore

struct UtilitiesView: View {
    let model: OrbitModel
    @State private var selection: String? = "overview"

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Label("Overview", systemImage: "square.grid.2x2").tag("overview")
                Section("Utilities") {
                    ForEach(model.registry.modules, id: \.descriptor.id) { module in
                        Label(module.descriptor.name, systemImage: module.descriptor.symbol).tag(module.descriptor.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Orbit")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 7) {
                    OrbitBrandIcon(size: 20)
                    Text("Orbit").fontWeight(.medium)
                    Spacer()
                    Text("0.1.0").monospacedDigit()
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(16)
            }
        } detail: {
            if selection == model.mouse.descriptor.id {
                FindMyMouseView(utility: model.mouse, registry: model.registry)
            } else if selection == model.rightClick.descriptor.id {
                RightClickView(utility: model.rightClick, registry: model.registry)
            } else {
                overview
            }
        }
        .toolbar {
            if selection == model.mouse.descriptor.id {
                ToolbarItem(placement: .primaryAction) {
                    previewButton
                }
                if #available(macOS 26, *) {
                    ToolbarSpacer(.fixed, placement: .primaryAction)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                SettingsLink { Label("Settings", systemImage: "gearshape") }
                    .help("Orbit Settings")
            }
        }
    }

    @ViewBuilder
    private var previewButton: some View {
        let button = Button("Preview Spotlight", systemImage: "play.fill") { model.mouse.preview() }
            .keyboardShortcut("p")
            .help("Preview the spotlight (⌘P)")
        if #available(macOS 26, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                HStack(alignment: .top, spacing: 16) {
                    OrbitBrandIcon()
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Your Mac, a little easier.").font(.largeTitle.bold())
                        Text("Small utilities, ready when you need them.")
                            .font(.title3).foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Your utilities").font(.headline)
                        Spacer()
                        Text("\(model.registry.modules.filter { $0.isEnabled }.count) enabled")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(model.registry.modules, id: \.descriptor.id) { module in
                        UtilityCard(descriptor: module.descriptor, enabled: Binding(
                            get: { module.isEnabled },
                            set: { model.registry.setEnabled($0, id: module.descriptor.id) }
                        )) { selection = module.descriptor.id }
                    }
                }
                Label("Enabled utilities keep working when you close this window.", systemImage: "menubar.rectangle")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(32)
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .modifier(OrbitScrollTreatment())
        .navigationTitle("Overview")
    }
}
