import SwiftUI

/// An illustrative desktop, not a screen capture. Redraws only when settings change.
struct SpotlightAppearancePreview: View {
    let radius: Double
    let dimming: Double
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width * 0.64, y: geometry.size.height * 0.48)
            ZStack {
                Rectangle().fill(Color.accentColor.gradient)
                    .opacity(colorScheme == .dark ? 0.25 : 0.12)
                desktopWindows(in: geometry.size)
                Canvas { context, size in
                    var backdrop = Path(CGRect(origin: .zero, size: size))
                    let scaledRadius = radius * 0.5
                    backdrop.addEllipse(in: CGRect(x: center.x - scaledRadius, y: center.y - scaledRadius, width: scaledRadius * 2, height: scaledRadius * 2))
                    context.fill(backdrop, with: .color(.black.opacity(dimming)), style: FillStyle(eoFill: true))
                }
                Image(systemName: "cursorarrow")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                    .position(center)
                VStack {
                    HStack {
                        previewLabel
                        Spacer()
                    }
                    Spacer()
                }.padding(14)
            }
        }
        .frame(height: 174)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel("Appearance preview: clear spotlight with \(Int(radius)) point radius and \(Int((dimming * 100).rounded())) percent background dimming")
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var previewLabel: some View {
        let label = Label("Appearance preview", systemImage: "viewfinder")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 11).padding(.vertical, 7)
        if #available(macOS 26, *), !reduceTransparency {
            label.glassEffect(.regular)
        } else {
            label.background(.background, in: Capsule())
        }
    }

    private func desktopWindows(in size: CGSize) -> some View {
        ZStack {
            miniatureWindow(width: size.width * 0.42, height: 100, symbol: "folder")
                .position(x: size.width * 0.28, y: 98)
            miniatureWindow(width: size.width * 0.35, height: 112, symbol: "doc.text")
                .position(x: size.width * 0.68, y: 86)
        }
    }

    private func miniatureWindow(width: Double, height: Double, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in Circle().fill(.secondary.opacity(0.3)).frame(width: 5, height: 5) }
                Spacer()
            }
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol).font(.title2).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 7) {
                    Capsule().fill(.secondary.opacity(0.2)).frame(height: 5)
                    Capsule().fill(.secondary.opacity(0.12)).frame(width: max(20, width * 0.4), height: 5)
                    Capsule().fill(.secondary.opacity(0.12)).frame(width: max(20, width * 0.3), height: 5)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(width: width, height: height)
        .background(.background, in: RoundedRectangle(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(.primary.opacity(0.1), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
    }
}
