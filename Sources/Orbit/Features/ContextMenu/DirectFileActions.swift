import AppKit
import Darwin
import OrbitCore

struct ContextFile: Sendable {
    let url: URL
    let device: Int32
    let inode: UInt64
    init(_ url: URL) throws {
        let url = url.standardizedFileURL
        var value = stat()
        guard lstat(url.path, &value) == 0 else {
            if errno == ENOENT { throw CocoaError(.fileReadNoSuchFile) }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        self.url = url; device = value.st_dev; inode = value.st_ino
    }
    func validate() throws {
        let current = try ContextFile(url)
        guard current.device == device && current.inode == inode else { throw DirectFileError.changed }
    }
}

enum DirectFileError: LocalizedError {
    case changed, invalidName, existing(String), recursive, noFiles
    var errorDescription: String? {
        switch self {
        case .changed: return "An item changed while the menu was open. Right-click it again."
        case .invalidName: return "Enter a filename without slashes."
        case .existing(let name): return "“\(name)” already exists. Use the macOS menu for replacement options."
        case .recursive: return "A folder cannot be pasted inside itself."
        case .noFiles: return "The clipboard does not contain files."
        }
    }
}

struct FileColor: Sendable {
    let index: Int
    let name: String
    let label: Int
    @MainActor static func systemPalette() -> [FileColor] {
        let labels = NSWorkspace.shared.fileLabels
        let indices = [6, 7, 5, 2, 4, 3, 1]
        let fallback = ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Gray"]
        return indices.enumerated().map { FileColor(index: $0.offset, name: labels.indices.contains($0.element) ? labels[$0.element] : fallback[$0.offset], label: $0.element) }
    }
}

/// File APIs operate on the captured URLs, never on Finder's later selection.
/// Every mutation rechecks file identity and refuses replacement conflicts.
enum DirectFileActions {
    private static func exists(_ url: URL) throws -> Bool {
        do { _ = try ContextFile(url); return true }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return false }
    }
    static func rename(_ file: ContextFile, to name: String) throws -> URL {
        try file.validate()
        guard !name.isEmpty, name != ".", name != "..", !name.contains("/"), !name.contains("\0") else { throw DirectFileError.invalidName }
        let target = file.url.deletingLastPathComponent().appendingPathComponent(name)
        if target == file.url { return target }
        if try exists(target) { throw DirectFileError.existing(name) }
        try FileManager.default.moveItem(at: file.url, to: target)
        return target
    }
    static func paste(_ files: [ContextFile], into folder: ContextFile, move: Bool) throws {
        guard !files.isEmpty else { throw DirectFileError.noFiles }
        try folder.validate()
        var names = Set<String>()
        for file in files {
            try file.validate()
            let name = file.url.lastPathComponent
            let target = folder.url.appendingPathComponent(name)
            guard names.insert(name).inserted, try !exists(target) else { throw DirectFileError.existing(name) }
            let sourcePath = file.url.resolvingSymlinksInPath().pathComponents
            let destinationPath = folder.url.resolvingSymlinksInPath().pathComponents
            if (try file.url.resourceValues(forKeys: [.isDirectoryKey])).isDirectory == true,
               destinationPath.starts(with: sourcePath) { throw DirectFileError.recursive }
        }
        // Preflight the complete batch before performing any operation.
        for file in files {
            try file.validate(); try folder.validate()
            let target = folder.url.appendingPathComponent(file.url.lastPathComponent)
            if move { try FileManager.default.moveItem(at: file.url, to: target) }
            else { try FileManager.default.copyItem(at: file.url, to: target) }
        }
    }
    static func trash(_ files: [ContextFile]) throws {
        try files.forEach {
            try $0.validate()
            guard $0.url.pathComponents.count > 2, try $0.url.resourceValues(forKeys: [.isVolumeKey]).isVolume != true else { throw CocoaError(.fileWriteNoPermission) }
        }
        for file in files { try file.validate(); try FileManager.default.trashItem(at: file.url, resultingItemURL: nil) }
    }
    static func tags(_ file: ContextFile) throws -> [String] {
        try file.validate()
        return try file.url.resourceValues(forKeys: [.tagNamesKey]).tagNames ?? []
    }
    static func setColor(_ color: Int, files: [ContextFile], palette: [FileColor]) throws {
        let previous = try files.map { try tags($0) }
        let chosen = palette.first { $0.index == color }?.name
        let removing = chosen.map { name in previous.allSatisfy { $0.contains(name) } } ?? true
        let standard = Set(palette.map(\.name))
        for (file, old) in zip(files, previous) {
            try file.validate()
            var names = old
            if let chosen {
                if removing { names.removeAll { $0 == chosen } }
                else if !names.contains(chosen) { names.append(chosen) }
            } else { names.removeAll { standard.contains($0) } }
            // NSURL's resource setter also supports Orbit's macOS 14 target.
            try (file.url as NSURL).setResourceValue(names, forKey: .tagNamesKey)
        }
    }
}
