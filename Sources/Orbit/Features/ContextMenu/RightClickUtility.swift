import AppKit
import ApplicationServices
import Observation
import OrbitCore
import OSLog

@MainActor @Observable
final class RightClickUtility: UtilityModule {
    let descriptor = UtilityDescriptor(id: "right-click", name: "Right-Click Menu", summary: "Everyday actions and color tags, instantly at the pointer.", symbol: "cursorarrow.click.2")
    var isEnabled: Bool { didSet { preferences.set(isEnabled, forKey: "orbit.rightClick.enabled") } }
    private(set) var hasAccess = false
    private(set) var isRunning = false
    var message: String?
    @ObservationIgnored private let preferences: UserDefaults
    @ObservationIgnored private let accessCheck: () -> Bool
    @ObservationIgnored private let logger = Logger(subsystem: "com.jerryvoelker.Orbit", category: "RightClick")
    @ObservationIgnored private let presenter = ContextMenuPresentation()
    @ObservationIgnored private let share = FileSharePresenter()
    @ObservationIgnored private let fileQueue = DispatchQueue(label: "com.jerryvoelker.Orbit.file-actions", qos: .userInitiated)
    @ObservationIgnored private var interceptor: SecondaryClickInterceptor?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var cutSession = FileCutSession()
    @ObservationIgnored private var cutFiles: [ContextFile] = []

    init(preferences: UserDefaults = .standard, accessCheck: @escaping () -> Bool = { AXIsProcessTrusted() }) {
        self.preferences = preferences; self.accessCheck = accessCheck
        isEnabled = preferences.bool(forKey: "orbit.rightClick.enabled"); hasAccess = accessCheck()
    }
    func refreshAccess() {
        hasAccess = accessCheck()
        if !hasAccess && isRunning { stop() }
        if isEnabled && hasAccess && !isRunning { start() }
    }
    func requestAccess() {
        hasAccess = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func start() {
        guard isEnabled, !isRunning else { return }
        hasAccess = accessCheck(); guard hasAccess else { return }
        let filter = SecondaryClickInterceptor(onClick: { [weak self] click in
            MainActor.assumeIsolated { self?.received(click) }
        }, onFailure: { [weak self] in
            MainActor.assumeIsolated {
                self?.stop()
                self?.message = "Mouse interception stopped. Native right-clicks are available. Check access and enable the utility again."
            }
        })
        interceptor = filter
        guard filter.start() else {
            interceptor = nil
            message = "Mouse interception could not start. Check Accessibility access, then try enabling again."
            return
        }
        isRunning = true; message = nil
        logger.notice("Instant menu mouse filter started")
    }
    func stop() {
        generation += 1; interceptor?.stop(); interceptor = nil
        presenter.dismiss(); share.close(); cutSession.clear(); cutFiles = []; isRunning = false
    }
    func preview(paste: Bool = false) {
        let token = generation
        let point = NSApp.keyWindow.map { NSPoint(x: $0.frame.midX, y: $0.frame.maxY - 150) } ?? NSEvent.mouseLocation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.generation == token else { return }
            self.presenter.show(snapshot: .preview(paste: paste), clipboardHasContent: paste, at: point,
                action: { [weak self] _ in self?.message = "Preview only — no files or clipboard contents were changed." },
                tag: { [weak self] _ in self?.message = "Preview only — live colors use macOS file tags." },
                command: { [weak self] _ in self?.message = "Preview only — live commands use the captured context." },
                fallback: { [weak self] in self?.message = "In a live menu, this opens the original macOS menu." })
        }
    }
    private func received(_ click: SecondaryClickInterceptor.Click) {
        guard isRunning else { SecondaryClickInterceptor.passThrough(click); return }
        let token = generation
        let started = ProcessInfo.processInfo.systemUptime
        guard let context = DirectContextResolver.resolve(at: click.down.location),
              ProcessInfo.processInfo.systemUptime - started < 0.8 else {
            interceptor?.finish(); SecondaryClickInterceptor.passThrough(click)
            return
        }
        guard generation == token else { interceptor?.finish(); return }
        let point = NSPoint(x: click.down.location.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - click.down.location.y)
        show(context: context, at: point) { [weak self] in
            guard let self, self.isRunning else { return }
            guard let current = DirectContextResolver.resolve(at: click.down.location), current.app.processIdentifier == context.app.processIdentifier,
                  self.sameContext(context, current) else { self.report(DirectFileError.changed); return }
            self.logger.notice("Explicit native menu fallback requested")
            SecondaryClickInterceptor.passThrough(click)
        }
        interceptor?.finish()
    }
    private func show(context: DirectMenuContext, at point: NSPoint, anchorView: NSView? = nil, fallback: @escaping () -> Void) {
        let palette = FileColor.systemPalette()
        let snapshot = snapshot(for: context, palette: palette)
        let clipboard = !(NSPasteboard.general.types ?? []).isEmpty
        logger.notice("Showing direct Orbit menu without opening native menu")
        presenter.show(snapshot: snapshot, clipboardHasContent: clipboard, at: point,
            action: { [weak self] in self?.perform($0, context: context, at: point) },
            tag: { [weak self] color in
                guard case let .finder(files, _) = context.content else { return }
                self?.runFiles { try DirectFileActions.setColor(color.colorIndex, files: files, palette: palette) }
            }, command: { [weak self] command in
                if let action = command.action { self?.perform(action, context: context, at: point); return }
                guard case let .finder(files, _) = context.content else { return }
                if command.id == "open" {
                    do { try files.forEach { try $0.validate() }; files.forEach { NSWorkspace.shared.open($0.url) } }
                    catch { self?.report(error) }
                } else if command.id == "reveal" {
                    NSWorkspace.shared.activateFileViewerSelecting(files.map(\.url))
                } else if command.id.hasPrefix("open-with:"), let app = URL(string: command.identifier) {
                    do {
                        try files.forEach { try $0.validate() }
                        NSWorkspace.shared.open(files.map(\.url), withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                            if let error { DispatchQueue.main.async { self?.report(error) } }
                        }
                    } catch { self?.report(error) }
                }
            }, fallback: fallback, anchorView: anchorView)
    }
#if DEBUG
    /// Opens the production menu/handlers for explicit test targets. No input is
    /// injected and no external application's selection is manipulated.
    func showMenuForActionTesting(target: URL, root: URL, anchor: NSView) throws {
        let resolved = target.resolvingSymlinksInPath().standardizedFileURL
        let base = root.resolvingSymlinksInPath().standardizedFileURL
        guard ContextActionTestWindow.accepts(base), resolved.pathComponents.starts(with: base.pathComponents),
              let window = anchor.window else { throw DirectFileError.changed }
        let directory = try resolved.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        let files = directory ? [] : [try ContextFile(resolved)]
        let folder = try ContextFile(directory ? resolved : resolved.deletingLastPathComponent())
        let context = DirectMenuContext(app: .current, window: nil, content: .finder(files: files, folder: folder))
        let point = window.convertPoint(toScreen: anchor.convert(NSPoint(x: 0, y: anchor.bounds.maxY), to: nil))
        show(context: context, at: point, anchorView: anchor) { [weak self] in
            self?.message = "Native pass-through is tested separately with a physical Finder click."
        }
    }
#endif
    private func snapshot(for context: DirectMenuContext, palette: [FileColor]) -> ContextMenuSnapshot {
        var commands: [ContextMenuCommand] = []
        var tags: [ContextColorTag] = []
        var clear: ContextColorTag?
        var fileContext = false
        func add(_ action: ContextAction, enabled: Bool) {
            commands.append(ContextMenuCommand(id: action.rawValue, title: action.title, enabled: enabled))
        }
        switch context.content {
        case let .finder(files, folder):
            fileContext = !files.isEmpty
            let editable = !files.isEmpty && files.allSatisfy { FileManager.default.isWritableFile(atPath: $0.url.path) }
            let removable = !files.isEmpty && files.allSatisfy { $0.url.pathComponents.count > 2 && FileManager.default.isDeletableFile(atPath: $0.url.path) }
            add(.cut, enabled: removable); add(.copy, enabled: !files.isEmpty)
            add(.paste, enabled: !FileClipboard.fileURLs(from: .general).isEmpty && FileManager.default.isWritableFile(atPath: folder.url.path))
            add(.rename, enabled: files.count == 1 && removable)
            add(.share, enabled: !files.isEmpty); add(.delete, enabled: removable)
            if !files.isEmpty {
                commands.append(ContextMenuCommand(id: "open", title: "Open"))
                if files.count == 1 {
                    let apps = NSWorkspace.shared.urlsForApplications(toOpen: files[0].url)
                    if !apps.isEmpty {
                        commands.append(ContextMenuCommand(id: "open-with", title: "Open With", children: apps.map { app in
                            ContextMenuCommand(id: "open-with:\(app.absoluteString)", title: FileManager.default.displayName(atPath: app.path), identifier: app.absoluteString)
                        }))
                    }
                }
                commands.append(ContextMenuCommand(id: "reveal", title: "Reveal in Finder"))
                let tagSets = files.map { Set((try? DirectFileActions.tags($0)) ?? []) }
                tags = palette.map { color in ContextColorTag(id: "color-\(color.index)", name: color.name, colorIndex: color.index, selected: tagSets.allSatisfy { $0.contains(color.name) }, enabled: editable) }
                clear = ContextColorTag(id: "clear-colors", name: "Remove standard color tags", colorIndex: -1, enabled: editable)
            }
        case let .text(_, _, native):
            for action in [ContextAction.cut, .copy, .paste] { add(action, enabled: native[action].map(NativeMenuAccess.enabled) ?? false) }
            for action in [ContextAction.rename, .share, .delete] { add(action, enabled: false) }
        }
        return ContextMenuSnapshot(applicationName: context.app.localizedName ?? "App", applicationIdentifier: context.app.bundleIdentifier ?? "", commands: commands, tags: tags, clearTag: clear, finderFileContext: fileContext)
    }
    private func sameContext(_ a: DirectMenuContext, _ b: DirectMenuContext) -> Bool {
        switch (a.content, b.content) {
        case let (.finder(filesA, folderA), .finder(filesB, folderB)):
            return Set(filesA.map(\.url)) == Set(filesB.map(\.url)) && folderA.url == folderB.url
        case let (.text(targetA, _, _), .text(targetB, _, _)): return CFEqual(targetA, targetB)
        default: return false
        }
    }
    private func perform(_ action: ContextAction, context: DirectMenuContext, at point: NSPoint) {
        switch context.content {
        case let .text(target, range, commands):
            let root = AXUIElementCreateApplication(context.app.processIdentifier)
            guard let focused = DirectContextResolver.elementValue(root, kAXFocusedUIElementAttribute), CFEqual(focused, target),
                  rangesEqual(range, DirectContextResolver.selectedRange(target)), let command = commands[action], NativeMenuAccess.enabled(command) else {
                report(DirectFileError.changed); return
            }
            let result = NativeMenuAccess.press(command)
            if result != .success { report(NSError(domain: "Orbit.TextAction", code: Int(result.rawValue), userInfo: [NSLocalizedDescriptionKey: "The app could not perform this edit. Use Show macOS Menu."])) }
        case let .finder(files, folder):
            switch action {
            case .copy, .cut:
                do {
                    try files.forEach { try $0.validate() }
                    guard !files.isEmpty else { return }
                    let board = NSPasteboard.general; board.clearContents()
                    guard board.writeObjects(files.map { $0.url as NSURL }) else { throw DirectFileError.noFiles }
                    cutSession.clear(); cutFiles = []
                    if action == .cut {
                        cutFiles = files
                        cutSession.prepare(files: FileClipboard.fileURLs(from: board), generation: board.changeCount)
                    }
                } catch { report(error) }
            case .paste:
                let strings = FileClipboard.fileURLs(from: .general)
                let clipboardGeneration = NSPasteboard.general.changeCount
                let moving = cutSession.shouldMove(files: strings, generation: clipboardGeneration)
                do {
                    let sources = moving ? cutFiles : try strings.compactMap(URL.init(string:)).map { try ContextFile($0) }
                    runFiles({ try DirectFileActions.paste(sources, into: folder, move: moving) }, completion: { [weak self] in
                        guard let self, moving else { return }
                        if self.cutSession.shouldMove(files: strings, generation: clipboardGeneration) {
                            self.cutSession.clear(); self.cutFiles = []
                        }
                        // Do not overwrite a newer clipboard while a large file
                        // operation is running. Subsequent pastes use the moved URLs.
                        let board = NSPasteboard.general
                        if board.changeCount == clipboardGeneration, FileClipboard.fileURLs(from: board) == strings {
                            board.clearContents()
                            board.writeObjects(sources.map { folder.url.appendingPathComponent($0.url.lastPathComponent) as NSURL })
                        }
                    })
                } catch { report(error) }
            case .rename:
                guard files.count == 1 else { return }
                let file = files[0]
                let alert = NSAlert(); alert.messageText = "Rename"; alert.informativeText = "Enter a new name for “\(file.url.lastPathComponent)”."
                alert.addButton(withTitle: "Rename"); alert.addButton(withTitle: "Cancel")
                let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 340, height: 24)); field.stringValue = file.url.lastPathComponent
                alert.accessoryView = field; alert.window.initialFirstResponder = field
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn {
                    let name = field.stringValue
                    runFiles { _ = try DirectFileActions.rename(file, to: name) }
                }
            case .share:
                do { try files.forEach { try $0.validate() }; share.show(files.map(\.url), at: point) }
                catch { report(error) }
            case .delete: runFiles { try DirectFileActions.trash(files) }
            }
        }
    }
    private func rangesEqual(_ a: CFRange?, _ b: CFRange?) -> Bool {
        switch (a, b) {
        case let (a?, b?): return a.location == b.location && a.length == b.length
        case (nil, nil): return true
        default: return false
        }
    }
    private func runFiles(_ work: @escaping () throws -> Void, completion: @escaping () -> Void = {}) {
        fileQueue.async { [weak self] in
            do { try work(); DispatchQueue.main.async { self?.message = nil; completion() } }
            catch { DispatchQueue.main.async { self?.report(error) } }
        }
    }
    private func report(_ error: Error) {
        message = error.localizedDescription
        NSApp.activate(ignoringOtherApps: true)
        NSAlert(error: error).runModal()
    }
}
