import AppKit
import SwiftUI

/// A singleton on-demand window prevents background launches from opening a new scene.
@MainActor
final class UtilitiesWindowController: NSWindowController {
    init(model: OrbitModel) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Orbit"
        window.minSize = NSSize(width: 800, height: 620)
        window.toolbarStyle = .unified
        window.autorecalculatesKeyViewLoop = true
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.contentView = NSHostingView(rootView: UtilitiesView(model: model))
        window.setFrameAutosaveName("OrbitUtilities")
        if !window.setFrameUsingName("OrbitUtilities") { window.center() }
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
