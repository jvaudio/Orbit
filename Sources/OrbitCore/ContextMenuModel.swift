import Foundation

public enum ContextAction: String, CaseIterable, Identifiable, Hashable, Sendable {
    case cut, copy, paste, rename, share, delete
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var symbol: String {
        switch self {
        case .cut: return "scissors"
        case .copy: return "doc.on.doc"
        case .paste: return "doc.on.clipboard"
        case .rename: return "character.cursor.ibeam"
        case .share: return "square.and.arrow.up"
        case .delete: return "trash"
        }
    }

    public static func identify(title: String, identifier: String, key: String = "") -> Self? {
        switch identifier {
        case "cut:": return .cut
        case "copy:": return .copy
        case "paste:", "cmdPaste:", "cmdMoveItemHere:", "cmdMoveItemsHere:", "moveHere:": return .paste
        case "cmdRename:": return .rename
        case "cmdShare:": return .share
        case "cmdMoveToTrash:": return .delete
        default: break
        }
        let normalized = title.replacingOccurrences(of: "…", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "cut": return .cut
        case "copy": return .copy
        case "paste", "paste item", "paste items", "move item here", "move items here": return .paste
        case "rename", "rename...": return .rename
        case "share", "share...": return .share
        case "delete", "move to trash": return .delete
        default: return nil
        }
    }
}

public struct MenuRouteComponent: Equatable, Sendable {
    public let title: String
    public let identifier: String
    public let role: String
    public let index: Int
    public init(title: String, identifier: String, role: String, index: Int) {
        self.title = title; self.identifier = identifier; self.role = role; self.index = index
    }
}

public struct ContextMenuCommand: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let identifier: String
    public var enabled: Bool
    public var checked: Bool
    public var separator: Bool
    public var route: [MenuRouteComponent]
    public var children: [ContextMenuCommand]
    public var action: ContextAction? { ContextAction.identify(title: title, identifier: identifier) }

    public init(id: String, title: String, identifier: String = "", enabled: Bool = true, checked: Bool = false, separator: Bool = false, route: [MenuRouteComponent] = [], children: [ContextMenuCommand] = []) {
        self.id = id; self.title = title; self.identifier = identifier; self.enabled = enabled
        self.checked = checked; self.separator = separator; self.route = route; self.children = children
    }
}

public struct ContextColorTag: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let colorIndex: Int
    public var selected: Bool
    public var enabled: Bool
    public let route: [MenuRouteComponent]
    public init(id: String, name: String, colorIndex: Int, selected: Bool = false, enabled: Bool = true, route: [MenuRouteComponent] = []) {
        self.id = id; self.name = name; self.colorIndex = colorIndex
        self.selected = selected; self.enabled = enabled; self.route = route
    }
}

public struct ContextMenuSnapshot: Sendable {
    public var applicationName: String
    public var applicationIdentifier: String
    public var commands: [ContextMenuCommand]
    public var tags: [ContextColorTag]
    public var clearTag: ContextColorTag?
    public var finderFileContext: Bool
    public init(applicationName: String, applicationIdentifier: String, commands: [ContextMenuCommand], tags: [ContextColorTag] = [], clearTag: ContextColorTag? = nil, finderFileContext: Bool = false) {
        self.applicationName = applicationName; self.applicationIdentifier = applicationIdentifier
        self.commands = commands; self.tags = tags; self.clearTag = clearTag; self.finderFileContext = finderFileContext
    }

    public func command(for action: ContextAction) -> ContextMenuCommand? {
        commands.first { $0.action == action && $0.enabled } ?? commands.first { $0.action == action }
    }

    public func topActions(clipboardHasContent: Bool) -> [ContextAction] {
        [.cut, .copy, .paste, .rename, .share, .delete]
    }

    public func isEnabled(_ action: ContextAction) -> Bool {
        return command(for: action)?.enabled == true
    }

    public func remainingCommands(clipboardHasContent: Bool) -> [ContextMenuCommand] {
        let top = Set(topActions(clipboardHasContent: clipboardHasContent))
        let filtered = commands.filter { command in
            guard let action = command.action else { return true }
            return !top.contains(action)
        }
        var result: [ContextMenuCommand] = []
        for command in filtered {
            if command.separator && (result.isEmpty || result.last?.separator == true) { continue }
            result.append(command)
        }
        if result.last?.separator == true { result.removeLast() }
        return result
    }

    public static func preview(paste: Bool = false) -> Self {
        let commands = [
            ContextMenuCommand(id: "cut", title: "Cut"),
            ContextMenuCommand(id: "copy", title: "Copy"),
            ContextMenuCommand(id: "paste", title: "Paste", enabled: paste),
            ContextMenuCommand(id: "rename", title: "Rename"),
            ContextMenuCommand(id: "share", title: "Share"),
            ContextMenuCommand(id: "delete", title: "Delete"),
            ContextMenuCommand(id: "open", title: "Open"),
            ContextMenuCommand(id: "open-with", title: "Open With", children: [ContextMenuCommand(id: "textedit", title: "TextEdit")]),
            ContextMenuCommand(id: "reveal", title: "Reveal in Finder")
        ]
        let names = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray"]
        return Self(applicationName: "Finder", applicationIdentifier: "com.apple.finder", commands: commands,
                    tags: names.enumerated().map { ContextColorTag(id: "tag-\($0.offset)", name: $0.element, colorIndex: $0.offset) },
                    clearTag: ContextColorTag(id: "clear-tag", name: "Remove standard color tags", colorIndex: -1), finderFileContext: true)
    }
}

extension MenuRouteComponent {
    /// Unique native identifiers survive changing/localized labels. Reused plugin
    /// identifiers require a unique title; never guess between duplicate commands.
    public func matchingIndex(in candidates: [MenuRouteComponent]) -> Int? {
        let roleMatches = candidates.indices.filter { candidates[$0].role == role }
        if !identifier.isEmpty {
            let identified = roleMatches.filter { candidates[$0].identifier == identifier }
            let sharedIdentifiers: Set<String> = ["executePlugInCommand:", "invoke", "action:", "importFromDevice:"]
            if identified.count == 1 && !sharedIdentifiers.contains(identifier) { return identified[0] }
            let named = identified.filter { candidates[$0].title == title }
            return named.count == 1 ? named[0] : nil
        }
        let named = roleMatches.filter { candidates[$0].title == title }
        if named.count == 1 { return named[0] }
        if title.isEmpty, named.contains(index) { return index }
        return nil
    }
}
