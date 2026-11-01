import AppKit
import SwiftUI
import OrbitCore
import OSLog

struct ContextMenuHeader: View {
    let snapshot: ContextMenuSnapshot
    let clipboardHasContent: Bool
    var action: (ContextAction) -> Void = { _ in }
    var tag: (ContextColorTag) -> Void = { _ in }
    private let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .gray]

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(snapshot.topActions(clipboardHasContent: clipboardHasContent)) { item in
                    Button { action(item) } label: {
                        VStack(spacing: 7) {
                            Image(systemName: item.symbol).font(.system(size: 18, weight: .medium)).frame(width: 22, height: 22)
                            Text(item.title).font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity).frame(height: 62)
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain).disabled(!snapshot.isEnabled(item))
                    .help(item == .delete && snapshot.finderFileContext ? "Move to Trash" : item.title)
                    .accessibilityLabel(item == .delete && snapshot.finderFileContext ? "Delete: Move to Trash" : item.title)
                }
            }
            if !snapshot.tags.isEmpty {
                HStack(spacing: 5) {
                    ForEach(snapshot.tags) { item in
                        Button { tag(item) } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6).fill(.primary.opacity(0.045))
                                Circle().fill(colors[max(0, min(item.colorIndex, 6))]).frame(width: 13, height: 13)
                                if item.selected { Image(systemName: "checkmark").font(.system(size: 8, weight: .bold)).foregroundStyle(.white) }
                            }.frame(maxWidth: .infinity).frame(height: 28)
                        }.buttonStyle(.plain).disabled(!item.enabled).help(item.name)
                            .accessibilityLabel(item.name).accessibilityValue(item.selected ? "Selected" : "Not selected")
                    }
                    if let clear = snapshot.clearTag {
                        Button { tag(clear) } label: {
                            Image(systemName: "xmark").font(.system(size: 10)).frame(width: 28, height: 28)
                        }.buttonStyle(.plain).help(clear.name).accessibilityLabel(clear.name)
                    }
                }
            }
        }.padding(10).frame(width: 452)
    }
}

@MainActor
final class ContextMenuPresentation: NSObject, NSMenuDelegate {
    private let logger = Logger(subsystem: "com.jerryvoelker.Orbit", category: "ContextMenu")
    private var menu: NSMenu?
    private var handlers: [Int: () -> Void] = [:]
    private var nextID = 0
    func dismiss() { menu?.cancelTracking(); menu = nil; handlers.removeAll() }

    func show(snapshot: ContextMenuSnapshot, clipboardHasContent: Bool, at point: NSPoint,
              action: @escaping (ContextAction) -> Void, tag: @escaping (ContextColorTag) -> Void,
              command: @escaping (ContextMenuCommand) -> Void, fallback: @escaping () -> Void, anchorView: NSView? = nil) {
        dismiss(); handlers.removeAll(); nextID = 0
        let menu = NSMenu(); menu.autoenablesItems = false; menu.delegate = self
        self.menu = menu
        let header = NSMenuItem()
        let view = MenuActionHeader(snapshot: snapshot, clipboardHasContent: clipboardHasContent,
            action: { [weak self] item in
                self?.logger.notice("Action tile selected: \(item.rawValue, privacy: .public)")
                self?.finish { action(item) }
            }, tag: { [weak self] item in self?.finish { tag(item) } })
        header.isEnabled = true
        header.view = view
        menu.addItem(header); menu.addItem(.separator())
        func append(_ commands: [ContextMenuCommand], to parent: NSMenu) {
            for entry in commands {
                if entry.separator { parent.addItem(.separator()); continue }
                let item = makeItem(entry.title) { command(entry) }
                item.isEnabled = entry.enabled
                item.state = entry.checked ? .on : .off
                if !entry.children.isEmpty {
                    let submenu = NSMenu(); submenu.autoenablesItems = false
                    append(entry.children, to: submenu); item.submenu = submenu
                }
                parent.addItem(item)
            }
        }
        append(snapshot.remainingCommands(clipboardHasContent: clipboardHasContent), to: menu)
        menu.addItem(.separator())
        menu.addItem(makeItem("Show macOS Menu", handler: fallback))
        logger.notice("Opening contextual menu")
        let location = anchorView.flatMap { view in view.window.map { view.convert($0.convertPoint(fromScreen: point), from: nil) } } ?? point
        menu.popUp(positioning: nil, at: location, in: anchorView)
        logger.notice("Contextual menu closed")
        self.menu = nil
        handlers.removeAll()
    }
    func menuWillOpen(_ menu: NSMenu) { logger.notice("Contextual menu will open") }
    private func makeItem(_ title: String, handler: @escaping () -> Void) -> NSMenuItem {
        nextID += 1; handlers[nextID] = handler
        let item = NSMenuItem(title: title, action: #selector(invoke(_:)), keyEquivalent: "")
        item.target = self; item.tag = nextID
        return item
    }
    @objc private func invoke(_ sender: NSMenuItem) { if let handler = handlers[sender.tag] { finish(handler) } }
    private func finish(_ handler: @escaping () -> Void) {
        menu?.cancelTracking()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { handler() }
    }
}
