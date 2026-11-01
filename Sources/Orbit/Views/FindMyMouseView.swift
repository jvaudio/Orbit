import SwiftUI
import OrbitCore

struct FindMyMouseView: View {
    let utility: FindMyMouseUtility
    let registry: UtilityRegistry

    var body: some View {
        @Bindable var settings = utility.settings
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                SpotlightAppearancePreview(radius: settings.radius, dimming: settings.dimming)
                activation
                appearance
                HStack(alignment: .top, spacing: 24) {
                    Label("Apple’s shake-to-enlarge cursor works alongside Orbit.", systemImage: "cursorarrow.motionlines")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Button("Reset to Defaults", systemImage: "arrow.counterclockwise") { settings.reset() }
                        .modifier(OrbitActionButtonStyle())
                        .fixedSize()
                        .help("Reset sensitivity and appearance; keep your enable choice")
                }
            }
            .padding(28)
            .frame(maxWidth: 800, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .modifier(OrbitScrollTreatment())
        .navigationTitle("Find My Mouse")
        .onChange(of: settings.radius) { utility.refreshAppearance() }
        .onChange(of: settings.dimming) { utility.refreshAppearance() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            UtilitySymbol(name: utility.descriptor.symbol)
            VStack(alignment: .leading, spacing: 6) {
                Text("Find My Mouse").font(.largeTitle.weight(.bold))
                Text("A small shake brings your pointer into focus.")
                    .font(.title3).foregroundStyle(.secondary)
            }
        }
    }

    private var activation: some View {
        @Bindable var settings = utility.settings
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enable Find My Mouse").font(.headline)
                    UtilityStatus(enabled: utility.isEnabled, running: utility.isRunning)
                }
                Spacer()
                Toggle("Enable Find My Mouse", isOn: Binding(
                    get: { utility.isEnabled },
                    set: { registry.setEnabled($0, id: utility.descriptor.id) }
                )).labelsHidden().toggleStyle(.switch)
            }
            if let error = utility.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            Divider()
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shake sensitivity").font(.headline)
                    Text("Higher needs less movement.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Picker("Shake sensitivity", selection: $settings.sensitivity) {
                    ForEach(ShakeSensitivity.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented)
                .frame(maxWidth: 260)
            }
            Text("Jiggle your mouse or trackpad pointer quickly in a small area. Normal movement and dragging are ignored.")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(20)
        .modifier(OrbitSurface())
    }

    private var appearance: some View {
        @Bindable var settings = utility.settings
        return VStack(alignment: .leading, spacing: 18) {
            Text("Appearance").font(.headline)
            VStack(spacing: 8) {
                HStack {
                    Text("Spotlight radius")
                    Spacer()
                    Text("\(Int(settings.radius)) pt").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $settings.radius, in: 50...250, step: 5) { Text("Spotlight radius") }.labelsHidden()
            }
            VStack(spacing: 8) {
                HStack {
                    Text("Background dimming")
                    Spacer()
                    Text("\(Int((settings.dimming * 100).rounded()))%")
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $settings.dimming, in: 0.2...0.8, step: 0.05) { Text("Background dimming") }.labelsHidden()
            }
            Divider()
            Label("All displays dim. Click or pause for a second to dismiss.", systemImage: "display.2")
                .font(.callout).foregroundStyle(.secondary)
        }
        .padding(20)
        .modifier(OrbitSurface())
    }
}
