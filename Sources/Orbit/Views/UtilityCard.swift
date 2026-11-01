import SwiftUI
import OrbitCore

struct UtilityCard: View {
    let descriptor: UtilityDescriptor
    @Binding var enabled: Bool
    let configure: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                UtilitySymbol(name: descriptor.symbol)
                VStack(alignment: .leading, spacing: 6) {
                    Text(descriptor.name).font(.title3.weight(.semibold))
                    Text(descriptor.summary).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Toggle("Enable \(descriptor.name)", isOn: $enabled)
                    .labelsHidden().toggleStyle(.switch)
            }
            Divider()
            HStack {
                Label {
                    Text(enabled ? "Enabled" : "Off").foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(enabled ? Color.green : Color.secondary)
                }
                    .font(.callout)
                Spacer()
                ConfigureUtilityButton(action: configure)
            }
        }
        .padding(22)
        .modifier(OrbitSurface())
    }
}
