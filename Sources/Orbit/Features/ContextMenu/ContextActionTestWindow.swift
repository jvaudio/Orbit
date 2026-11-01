#if DEBUG
import AppKit

/// Debug-only UI for exercising the actual production menu with CUA, whose
/// app-targeted clicks bypass the global event tap. Restricted to test folders.
@MainActor
final class ContextActionTestWindow: NSWindowController {
    static func accepts(_ root: URL) -> Bool {
        let normalized = root.resolvingSymlinksInPath().standardizedFileURL
        let temporary = URL(fileURLWithPath: "/private/tmp").resolvingSymlinksInPath().standardizedFileURL
        return normalized.lastPathComponent.hasPrefix("orbit-instant-regression.") && normalized.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path == temporary.path
    }
    private let root: URL
    private let utility: RightClickUtility
    private let picker = NSPopUpButton()
    private let open = NSButton(title: "Open Orbit Menu", target: nil, action: nil)
    private let note = NSTextField(wrappingLabelWithString: "")
    init(root: URL, utility: RightClickUtility) {
        self.root = root; self.utility = utility
        let window = NSWindow(contentRect: NSRect(x: 300, y: 300, width: 700, height: 300), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Orbit Context Action Tests"; window.isReleasedWhenClosed = false
        super.init(window: window)
        let title = NSTextField(labelWithString: "Instant menu action regression")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: "Debug test surface · explicit temporary targets. Opens Orbit’s production menu and action handlers.")
        let refresh = NSButton(title: "Refresh Targets", target: self, action: #selector(refreshTargets))
        open.target = self; open.action = #selector(openMenu)
        let buttons = NSStackView(views: [open, refresh]); buttons.orientation = .horizontal
        let stack = NSStackView(views: [title, detail, picker, buttons, note]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let view = NSView(); window.contentView = view; view.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24), picker.widthAnchor.constraint(equalTo: stack.widthAnchor)])
        refreshTargets()
    }
    required init?(coder: NSCoder) { nil }
    @objc private func refreshTargets() {
        let selected = picker.selectedItem?.representedObject as? URL
        picker.removeAllItems()
        guard Self.accepts(root) else { note.stringValue = "Invalid test root"; return }
        var urls = [root]
        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let url as URL in enumerator {
                guard urls.count < 64 else { break }
                if url.resolvingSymlinksInPath().pathComponents.starts(with: root.resolvingSymlinksInPath().pathComponents) { urls.append(url) }
            }
        }
        for url in urls.sorted(by: { $0.path < $1.path }) {
            let folder = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            let relative = url == root ? "." : String(url.path.dropFirst(root.path.count + 1))
            picker.addItem(withTitle: "\(folder ? "Folder" : "File"): \(relative)")
            picker.lastItem?.representedObject = url
        }
        if let index = picker.itemArray.firstIndex(where: { ($0.representedObject as? URL) == selected }) { picker.selectItem(at: index) }
        note.stringValue = root.path
    }
    @objc private func openMenu() {
        guard let target = picker.selectedItem?.representedObject as? URL else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            do { try self.utility.showMenuForActionTesting(target: target, root: self.root, anchor: self.open) }
            catch { self.note.stringValue = error.localizedDescription }
        }
    }
}
#endif
