import AppKit
import OrbitCore

/// AppKit controls perform their tracking inside NSMenu's event-tracking loop.
/// The window's first click must work even while Orbit is a background agent.
@MainActor
final class MenuActionHeader: NSView {
    private var handlers: [Int: () -> Void] = [:]
    private(set) var actionButtons: [ContextAction: NSButton] = [:]
    private(set) var tagButtons: [NSButton] = []
    override var isFlipped: Bool { true }

    init(snapshot: ContextMenuSnapshot, clipboardHasContent: Bool,
         action: @escaping (ContextAction) -> Void, tag: @escaping (ContextColorTag) -> Void) {
        super.init(frame: NSRect(x: 0, y: 0, width: 452, height: snapshot.tags.isEmpty ? 82 : 120))
        autoresizingMask = [.width]
        let actions = snapshot.topActions(clipboardHasContent: clipboardHasContent)
        let gap: CGFloat = 5
        let width = (432 - CGFloat(actions.count - 1) * gap) / CGFloat(actions.count)
        for (index, item) in actions.enumerated() {
            let button = makeButton(frame: NSRect(x: 10 + CGFloat(index) * (width + gap), y: 10, width: width, height: 62), actionTitle: item.title) { action(item) }
            button.title = item.title
            button.font = .systemFont(ofSize: 11, weight: .medium)
            button.image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 18, weight: .medium))
            button.imagePosition = .imageAbove
            button.imageScaling = .scaleNone
            button.isEnabled = snapshot.isEnabled(item)
            let title = item == .delete && snapshot.finderFileContext ? "Delete: Move to Trash" : item.title
            button.setAccessibilityLabel(title); button.toolTip = title
            actionButtons[item] = button
        }
        let allTags = snapshot.tags + (snapshot.clearTag.map { [$0] } ?? [])
        if !snapshot.tags.isEmpty {
            let tagWidth = (432 - CGFloat(allTags.count - 1) * gap) / CGFloat(allTags.count)
            for (index, item) in allTags.enumerated() {
                let button = makeButton(frame: NSRect(x: 10 + CGFloat(index) * (tagWidth + gap), y: 82, width: tagWidth, height: 28)) { tag(item) }
                button.image = Self.tagImage(item)
                button.imagePosition = .imageOnly
                button.isEnabled = item.enabled
                button.setAccessibilityLabel(item.name)
                button.setAccessibilityValue(item.selected ? "Selected" : "Not selected")
                button.toolTip = item.name
                tagButtons.append(button)
            }
        }
    }
    required init?(coder: NSCoder) { nil }
    private func makeButton(frame: NSRect, actionTitle: String? = nil, handler: @escaping () -> Void) -> NSButton {
        let button = MenuTileButton(frame: frame)
        if let actionTitle { button.cell = CenteredActionTileCell(textCell: actionTitle) }
        let id = handlers.count + 1; handlers[id] = handler
        button.tag = id; button.target = self; button.action = #selector(invoke(_:))
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.wantsLayer = true; button.layer?.cornerRadius = 9
        button.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.055).cgColor
        addSubview(button)
        return button
    }
    @objc private func invoke(_ sender: NSButton) { handlers[sender.tag]?() }
    private static func tagImage(_ tag: ContextColorTag) -> NSImage {
        guard tag.colorIndex >= 0 else { return NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)! }
        let colors: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemBlue, .systemPurple, .systemGray]
        return NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            colors[min(tag.colorIndex, 6)].setFill()
            NSBezierPath(ovalIn: NSRect(x: 2.5, y: 2.5, width: 13, height: 13)).fill()
            if tag.selected {
                NSColor.white.setStroke()
                let check = NSBezierPath(); check.lineWidth = 1.6
                check.move(to: NSPoint(x: 5.5, y: 9)); check.line(to: NSPoint(x: 8, y: 6.5)); check.line(to: NSPoint(x: 12.5, y: 11.5)); check.stroke()
            }
            return true
        }
    }
}

final class MenuTileButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Keep the icon/label group centered rather than using NSButtonCell's
/// imageAbove layout, whose font metrics leave asymmetric vertical padding.
final class CenteredActionTileCell: NSButtonCell {
    override func drawInterior(withFrame frame: NSRect, in controlView: NSView) {
        let iconHeight: CGFloat = 22
        let gap: CGFloat = 7
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let title = NSAttributedString(string: self.title, attributes: [
            .font: font ?? NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: isEnabled ? NSColor.labelColor : NSColor.disabledControlTextColor,
            .paragraphStyle: paragraph
        ])
        let labelHeight = ceil(title.size().height)
        let contentHeight = iconHeight + gap + labelHeight
        let top = frame.midY - contentHeight / 2
        let iconY = controlView.isFlipped ? top : frame.maxY - (top - frame.minY) - iconHeight
        let labelY = controlView.isFlipped ? top + iconHeight + gap : top
        if let image {
            drawImage(image, withFrame: NSRect(x: frame.midX - 11, y: iconY, width: 22, height: iconHeight), in: controlView)
        }
        title.draw(in: NSRect(x: frame.minX + 4, y: labelY, width: frame.width - 8, height: labelHeight))
    }
}
