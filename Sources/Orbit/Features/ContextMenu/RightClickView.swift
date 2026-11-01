import SwiftUI
import OrbitCore

struct RightClickView: View {
    let utility: RightClickUtility
    let registry: UtilityRegistry
    @State private var pastePreview = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    UtilitySymbol(name: utility.descriptor.symbol)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A better place for everyday actions.").font(.title.bold())
                        Text("Your actions, without the extra menu.").foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 18) {
                    Toggle("Enable Right-Click Menu", isOn: Binding(get: { utility.isEnabled }, set: { registry.setEnabled($0, id: utility.descriptor.id) }))
                        .font(.headline)
                    Label(utility.isRunning ? "Ready in supported apps" : utility.isEnabled ? (utility.hasAccess ? "Paused" : "Accessibility access needed") : "Off", systemImage: utility.isRunning ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(.secondary)
                    if let message = utility.message {
                        Label(message, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
                    }
                    if !utility.hasAccess {
                        Text("Allow Orbit in System Settings → Privacy & Security → Accessibility to intercept secondary clicks and use app editing commands. The preview works without access.")
                            .font(.callout).foregroundStyle(.secondary)
                        HStack {
                            Button("Allow Accessibility Access…") { utility.requestAccess() }.modifier(OrbitActionButtonStyle())
                            Button("Check Access") { utility.refreshAccess() }.buttonStyle(.borderless)
                        }
                    }
                }.padding(22).modifier(OrbitSurface())
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Menu preview").font(.headline)
                        Spacer()
                        Toggle("Paste available", isOn: $pastePreview).toggleStyle(.switch).controlSize(.small)
                    }
                    VStack(spacing: 0) {
                        ContextMenuHeader(snapshot: .preview(paste: pastePreview), clipboardHasContent: pastePreview)
                        Divider()
                        ForEach(["Open", "Open With", "Reveal in Finder", "Show macOS Menu"], id: \.self) { title in
                            HStack { Text(title); Spacer(); if title == "Open With" { Image(systemName: "chevron.right").foregroundStyle(.secondary) } }
                                .font(.callout).padding(.horizontal, 18).padding(.vertical, 7)
                        }
                    }.frame(width: 452).padding(.bottom, 8).background(.background, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.1)))
                        .frame(maxWidth: .infinity)
                    Button("Preview Menu", systemImage: "play.fill") { utility.preview(paste: pastePreview) }.modifier(OrbitActionButtonStyle())
                    Text("Preview actions don’t change files or the clipboard.").font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Works with your Mac").font(.headline)
                    Text("Orbit opens directly in supported Finder file views and focused text controls. Finder actions use the captured files, and color buttons apply native macOS tags. Delete moves items to Trash. Cut prepares a move when you paste.")
                    Text("Cut, Copy, Paste, Rename, Share, and Delete stay in the top row. Actions that aren’t available in the current context are disabled. App-specific commands are available through Show macOS Menu. Unsupported contexts and right-drag gestures keep their original behavior.")
                }.font(.callout).foregroundStyle(.secondary)
            }.padding(32).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }.modifier(OrbitScrollTreatment()).navigationTitle("Right-Click Menu")
            .onAppear { utility.refreshAccess() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { utility.refreshAccess() } }
    }
}
