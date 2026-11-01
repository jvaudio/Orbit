import SwiftUI

/// Keep content legible; system glass belongs to navigation and actions.
struct OrbitSurface: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityShowBorders) private var showBorders

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .background(.background.secondary, in: ConcentricRectangle(corners: .concentric(minimum: 16)))
                .overlay {
                    ConcentricRectangle(corners: .concentric(minimum: 16))
                        .stroke(.primary.opacity(borderOpacity), lineWidth: borderWidth)
                        .allowsHitTesting(false)
                }
        } else {
            content
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.primary.opacity(borderOpacity), lineWidth: borderWidth)
                        .allowsHitTesting(false)
                }
        }
    }

    private var borderOpacity: Double { contrast == .increased || showBorders ? 0.4 : 0.08 }
    private var borderWidth: Double { contrast == .increased || showBorders ? 1 : 0.5 }
}

struct OrbitScrollTreatment: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            content
        }
    }
}

struct UtilitySymbol: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 25, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
            .frame(width: 56, height: 56)
            .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityHidden(true)
    }
}

struct UtilityStatus: View {
    let enabled: Bool
    var running = true

    var body: some View {
        Label {
            Text(title).foregroundStyle(.secondary)
        } icon: {
            Image(systemName: enabled && running ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(enabled && running ? Color.green : Color.secondary)
        }
            .font(.callout)
            .accessibilityElement(children: .combine)
    }

    private var title: String { enabled ? (running ? "Ready for a shake" : "Paused") : "Off" }
}

struct ConfigureUtilityButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) { Label("Configure", systemImage: "slider.horizontal.3") }
            .modifier(OrbitActionButtonStyle())
    }
}

struct OrbitActionButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.buttonStyle(.glass).controlSize(.large)
        } else {
            content.buttonStyle(.bordered).controlSize(.large)
        }
    }
}
