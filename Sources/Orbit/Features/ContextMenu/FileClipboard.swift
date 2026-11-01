import AppKit

/// Finder supports modern URL items and legacy filename-list pasteboards.
/// Read both without adding types or taking clipboard ownership from Finder.
enum FileClipboard {
    static func fileURLs(from pasteboard: NSPasteboard) -> [String] {
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [NSURL] ?? []
        var urls = objects.map { $0 as URL }.filter(\.isFileURL)
        if urls.isEmpty {
            urls = (pasteboard.pasteboardItems ?? []).compactMap { item in
                guard let string = item.string(forType: .fileURL), let url = URL(string: string), url.isFileURL else { return nil }
                return url
            }
        }
        if urls.isEmpty, let paths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls = paths.filter { $0.hasPrefix("/") }.map { URL(fileURLWithPath: $0) }
        }
        return Array(Set(urls.map { $0.standardizedFileURL.absoluteString })).sorted()
    }
}
