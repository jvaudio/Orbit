import AppKit
import ApplicationServices
import OrbitCore
import OSLog

struct DirectMenuContext {
    enum Content {
        case finder(files: [ContextFile], folder: ContextFile)
        case text(target: AXUIElement, range: CFRange?, commands: [ContextAction: AXUIElement])
    }
    let app: NSRunningApplication
    let window: AXUIElement?
    let content: Content
}

/// Resolves only explicit file targets or the focused, editable text control.
/// Ambiguous views (including Finder's sidebar) are left to the original app.
enum DirectContextResolver {
    private static let logger = Logger(subsystem: "com.jerryvoelker.Orbit", category: "ContextResolver")
    static func resolve(at point: CGPoint) -> DirectMenuContext? {
        let system = AXUIElementCreateSystemWide()
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &hit) == .success, let hit else { return nil }
        var pid: pid_t = 0; AXUIElementGetPid(hit, &pid)
        guard pid != getpid(), let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        let root = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(root, 0.03)
        var ancestors: [AXUIElement] = []
        var current: AXUIElement? = hit
        for _ in 0..<12 {
            guard let element = current else { break }
            ancestors.append(element)
            if NativeMenuAccess.role(element) == kAXWindowRole { break }
            current = elementValue(element, kAXParentAttribute)
        }
        let window = ancestors.first { NativeMenuAccess.role($0) == kAXWindowRole } ?? elementValue(root, kAXFocusedWindowAttribute)
        if app.bundleIdentifier == "com.apple.finder" {
            return finder(app: app, window: window, ancestors: ancestors)
        }
        guard let text = ancestors.first(where: { [kAXTextAreaRole, kAXTextFieldRole].contains(NativeMenuAccess.role($0)) }),
              NativeMenuAccess.string(text, kAXSubroleAttribute) != kAXSecureTextFieldSubrole,
              let focused = elementValue(root, kAXFocusedUIElementAttribute), CFEqual(text, focused) else { return nil }
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(text, kAXSelectedTextAttribute as CFString, &settable)
        guard settable.boolValue || NativeMenuAccess.role(text) == kAXTextAreaRole else { return nil }
        let commands = editingCommands(root)
        guard !commands.isEmpty else { return nil }
        return DirectMenuContext(app: app, window: window, content: .text(target: text, range: selectedRange(text), commands: commands))
    }
    static func elementValue(_ element: AXUIElement, _ key: String) -> AXUIElement? {
        guard let value = NativeMenuAccess.value(element, key), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    static func fileURL(_ element: AXUIElement, key: String = kAXURLAttribute) -> URL? {
        let value = NativeMenuAccess.value(element, key)
        let url = (value as? URL) ?? (value as? String).flatMap(URL.init(string:))
        guard let url, url.isFileURL else { return nil }
        return url.standardizedFileURL
    }
    private static func nearbyURLs(_ element: AXUIElement, depth: Int = 0) -> [URL] {
        if let url = fileURL(element) { return [url] }
        guard depth < 3 else { return [] }
        let children = NativeMenuAccess.children(element)
        guard children.count < 32 else { return [] }
        return children.flatMap { nearbyURLs($0, depth: depth + 1) }
    }
    private static func finder(app: NSRunningApplication, window: AXUIElement?, ancestors: [AXUIElement]) -> DirectMenuContext? {
        guard !ancestors.contains(where: {
            NativeMenuAccess.role($0) == kAXToolbarRole || NativeMenuAccess.string($0, kAXIdentifierAttribute).lowercased().contains("sidebar") ||
            NativeMenuAccess.string($0, kAXDescriptionAttribute).lowercased() == "sidebar"
        }) else { return nil }
        let list = ancestors.first { [kAXOutlineRole, kAXListRole, kAXBrowserRole].contains(NativeMenuAccess.role($0)) }
        var clicked: URL?
        for element in ancestors {
            if (list.map { CFEqual(element, $0) } ?? false) || NativeMenuAccess.role(element) == kAXWindowRole { break }
            let urls = Array(Set(nearbyURLs(element)))
            if urls.count == 1 { clicked = urls[0]; break }
        }
        if let clicked {
            var selected: [URL] = []
            if let list {
                let rows = (NativeMenuAccess.value(list, kAXSelectedRowsAttribute) as? [AXUIElement]) ?? (NativeMenuAccess.value(list, kAXSelectedChildrenAttribute) as? [AXUIElement]) ?? []
                guard rows.count <= 128 else { return nil }
                selected = rows.flatMap { nearbyURLs($0) }
            }
            let urls = selected.contains(clicked) ? Array(Set(selected)) : [clicked]
            guard !urls.isEmpty, let files = try? urls.map({ try ContextFile($0) }) else { return nil }
            let singleFolder = files.count == 1 && (try? clicked.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])).map { $0.isDirectory == true && $0.isPackage != true } == true
            let folderURL = singleFolder ? clicked : clicked.deletingLastPathComponent()
            guard folderURL.path != "/", let folder = try? ContextFile(folderURL) else { return nil }
            return DirectMenuContext(app: app, window: window, content: .finder(files: files, folder: folder))
        }
        guard list != nil, let window, let folderURL = finderFolderURL(window),
              (try? folderURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
              let folder = try? ContextFile(folderURL) else {
            let roles = ancestors.map { NativeMenuAccess.role($0) }.joined(separator: ",")
            let document = window.flatMap { fileURL($0, key: kAXDocumentAttribute) } != nil
            logger.notice("Finder background unresolved: list=\(list != nil), documentURL=\(document), ancestorRoles=\(roles, privacy: .public)")
            return nil
        }
        return DirectMenuContext(app: app, window: window, content: .finder(files: [], folder: folder))
    }
    /// Finder does not expose AXDocument on all window configurations. Read
    /// only the window's breadcrumb control; never infer a destination from the
    /// selected rows, which may belong to a search or a different folder.
    private static func finderFolderURL(_ window: AXUIElement) -> URL? {
        if let url = fileURL(window, key: kAXDocumentAttribute) { return url }
        let title = NativeMenuAccess.string(window, kAXTitleAttribute)
        var pathBars: [AXUIElement] = []
        var budget = 60
        func findPathBars(_ element: AXUIElement, depth: Int) {
            guard depth < 5, budget > 0 else { return }; budget -= 1
            let role = NativeMenuAccess.role(element)
            if role == kAXToolbarRole || role == kAXOutlineRole || role == kAXBrowserRole { return }
            if role == kAXListRole && NativeMenuAccess.string(element, kAXDescriptionAttribute).lowercased() == "path" {
                pathBars.append(element); return
            }
            for child in NativeMenuAccess.children(element) { findPathBars(child, depth: depth + 1) }
        }
        findPathBars(window, depth: 0)
        guard pathBars.count == 1 else { return nil }
        var urls: [URL] = []
        var componentBudget = 40
        func readComponents(_ element: AXUIElement, depth: Int) {
            guard depth < 5, componentBudget > 0 else { return }; componentBudget -= 1
            if let url = fileURL(element) { urls.append(url) }
            for child in NativeMenuAccess.children(element) { readComponents(child, depth: depth + 1) }
        }
        readComponents(pathBars[0], depth: 0)
        let folder = uniquePathBarFolder(urls: urls, windowTitle: title)
        logger.notice("Finder path-bar folder lookup: components=\(urls.count), resolved=\(folder != nil)")
        return folder
    }
    static func uniquePathBarFolder(urls: [URL], windowTitle: String) -> URL? {
        guard !windowTitle.isEmpty else { return nil }
        let matches = Set(urls.filter {
            $0.isFileURL && $0.path != "/" && $0.lastPathComponent == windowTitle &&
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.map { $0.standardizedFileURL })
        return matches.count == 1 ? matches.first : nil
    }
    static func selectedRange(_ element: AXUIElement) -> CFRange? {
        guard let value = NativeMenuAccess.value(element, kAXSelectedTextRangeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        return AXValueGetValue(value as! AXValue, .cfRange, &range) ? range : nil
    }
    private static func editingCommands(_ root: AXUIElement) -> [ContextAction: AXUIElement] {
        guard let bar = elementValue(root, kAXMenuBarAttribute) else { return [:] }
        var result: [ContextAction: AXUIElement] = [:]
        var budget = 160
        let deadline = ProcessInfo.processInfo.systemUptime + 0.2
        func visit(_ element: AXUIElement, depth: Int) {
            guard budget > 0, depth < 4, ProcessInfo.processInfo.systemUptime < deadline else { return }; budget -= 1
            if NativeMenuAccess.role(element) == kAXMenuItemRole {
                let id = NativeMenuAccess.string(element, kAXIdentifierAttribute)
                let key = NativeMenuAccess.string(element, kAXMenuItemCmdCharAttribute).lowercased()
                let named = ContextAction.identify(title: NativeMenuAccess.name(element), identifier: id)
                let modifiers = NativeMenuAccess.value(element, kAXMenuItemCmdModifiersAttribute) as? Int
                let shortcut = modifiers == 0 ? ["x": ContextAction.cut, "c": .copy, "v": .paste][key] : nil
                let action = named ?? shortcut
                if let action, [.cut, .copy, .paste].contains(action), result[action] == nil { result[action] = element }
            }
            for child in NativeMenuAccess.children(element) { visit(child, depth: depth + 1) }
        }
        // Standard editing menus occur early; avoid traversing app-specific
        // deeply nested service menus or opening anything to discover commands.
        for item in NativeMenuAccess.children(bar).prefix(5) { visit(item, depth: 0) }
        return result
    }
}
