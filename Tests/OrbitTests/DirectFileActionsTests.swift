import XCTest
import AppKit
@testable import Orbit

@MainActor
final class DirectFileActionsTests: XCTestCase {
    private var folder: URL!
    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("OrbitDirectTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: folder) }
    private func file(_ name: String) throws -> ContextFile {
        let url = folder.appendingPathComponent(name)
        try Data("Orbit direct action test".utf8).write(to: url)
        return try ContextFile(url)
    }
    private func destination() throws -> ContextFile {
        let url = folder.appendingPathComponent("Destination")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return try ContextFile(url)
    }
    func testCopyThenMovePreservesContentsAndOnlyMoveRemovesSource() throws {
        let source = try file("Copy.txt"), target = try destination()
        try DirectFileActions.paste([source], into: target, move: false)
        XCTAssertEqual(try Data(contentsOf: source.url), try Data(contentsOf: target.url.appendingPathComponent("Copy.txt")))
        let moving = try file("Move.txt")
        try DirectFileActions.paste([moving], into: target, move: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: moving.url.path))
        XCTAssertEqual(try String(contentsOf: target.url.appendingPathComponent("Move.txt")), "Orbit direct action test")
    }
    func testBatchConflictPreventsAnyPartialCopies() throws {
        let first = try file("First.txt"), second = try file("Second.txt"), target = try destination()
        try Data("Existing".utf8).write(to: target.url.appendingPathComponent("Second.txt"))
        XCTAssertThrowsError(try DirectFileActions.paste([first, second], into: target, move: false))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.url.appendingPathComponent("First.txt").path))
        XCTAssertEqual(try String(contentsOf: target.url.appendingPathComponent("Second.txt")), "Existing")
    }
    func testRenameRefusesInvalidNamesAndReplacement() throws {
        let source = try file("Source.txt"), existing = try file("Existing.txt")
        XCTAssertThrowsError(try DirectFileActions.rename(source, to: "../escape"))
        XCTAssertThrowsError(try DirectFileActions.rename(source, to: existing.url.lastPathComponent))
        let renamed = try DirectFileActions.rename(source, to: "Renamed.txt")
        XCTAssertEqual(try String(contentsOf: renamed), "Orbit direct action test")
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.url.path))
    }
    func testReplacedFileIdentityIsRejected() throws {
        let source = try file("Source.txt")
        try FileManager.default.moveItem(at: source.url, to: folder.appendingPathComponent("Old.txt"))
        try Data("Replacement".utf8).write(to: source.url)
        XCTAssertThrowsError(try source.validate())
        XCTAssertThrowsError(try DirectFileActions.rename(source, to: "Wrong.txt"))
    }
    func testPastingFolderInsideItselfIsRejected() throws {
        let nested = folder.appendingPathComponent("Nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        XCTAssertThrowsError(try DirectFileActions.paste([ContextFile(folder)], into: ContextFile(nested), move: false))
    }
    func testNativeColorToggleAndClearPreserveCustomTags() throws {
        let source = try file("Tags.txt")
        try (source.url as NSURL).setResourceValue(["Orbit Custom Tag"], forKey: .tagNamesKey)
        let palette = FileColor.systemPalette()
        try DirectFileActions.setColor(4, files: [source], palette: palette)
        var url = source.url; url.removeAllCachedResourceValues()
        XCTAssertTrue(try DirectFileActions.tags(source).contains(palette[4].name))
        XCTAssertTrue(try DirectFileActions.tags(source).contains("Orbit Custom Tag"))
        XCTAssertEqual(try url.resourceValues(forKeys: [.labelNumberKey]).labelNumber, 4)
        try DirectFileActions.setColor(4, files: [source], palette: palette)
        XCTAssertEqual(try DirectFileActions.tags(source), ["Orbit Custom Tag"])
        try DirectFileActions.setColor(0, files: [source], palette: palette)
        try DirectFileActions.setColor(4, files: [source], palette: palette)
        try DirectFileActions.setColor(-1, files: [source], palette: palette)
        XCTAssertEqual(try DirectFileActions.tags(source), ["Orbit Custom Tag"])
    }
}
