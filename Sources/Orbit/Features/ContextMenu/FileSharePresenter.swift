import AppKit

@MainActor
final class FileSharePresenter: NSObject, NSSharingServicePickerDelegate {
    private var anchor: NSPanel?
    private var picker: NSSharingServicePicker?
    func show(_ urls: [URL], at point: NSPoint) {
        close()
        let panel = NSPanel(contentRect: NSRect(x: point.x, y: point.y, width: 1, height: 1), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .popUpMenu; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1)); panel.contentView = view
        let picker = NSSharingServicePicker(items: urls); picker.delegate = self
        self.anchor = panel; self.picker = picker
        panel.orderFrontRegardless()
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
    nonisolated func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        DispatchQueue.main.async { [weak self] in self?.close() }
    }
    func close() { anchor?.close(); anchor = nil; picker = nil }
}
