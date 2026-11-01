import Foundation

/// Cut intent is owned by Orbit, without changing Finder's clipboard ownership.
/// A new clipboard generation or a different file list invalidates the intent.
public struct FileCutSession: Sendable {
    private var files: [String] = []
    private var generation: Int?
    public init() {}
    @discardableResult
    public mutating func prepare(files: [String], generation: Int) -> Bool {
        clear()
        guard !files.isEmpty, files.allSatisfy({ URL(string: $0)?.isFileURL == true }) else { return false }
        self.files = files.sorted(); self.generation = generation
        return true
    }
    public func shouldMove(files: [String], generation: Int) -> Bool {
        !self.files.isEmpty && self.generation == generation && self.files == files.sorted()
    }
    public mutating func clear() { files = []; generation = nil }
}
