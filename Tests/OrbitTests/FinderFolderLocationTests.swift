import XCTest
@testable import Orbit

final class FinderFolderLocationTests: XCTestCase {
    func testPathBarUsesWindowFolderRatherThanSelectedChild() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("Destination")
        let selected = folder.appendingPathComponent("Selected Folder")
        try FileManager.default.createDirectory(at: selected, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertEqual(DirectContextResolver.uniquePathBarFolder(urls: [root, folder, selected], windowTitle: "Destination")?.path, folder.path)
        XCTAssertNil(DirectContextResolver.uniquePathBarFolder(urls: [root, selected], windowTitle: "Destination"))
    }
    func testAmbiguousRepeatedFolderNamesAndFilesAreRejected() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("Repeated")
        let selected = folder.appendingPathComponent("Repeated")
        try FileManager.default.createDirectory(at: selected, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertNil(DirectContextResolver.uniquePathBarFolder(urls: [folder, selected], windowTitle: "Repeated"))
        let file = root.appendingPathComponent("File.txt")
        try Data().write(to: file)
        XCTAssertNil(DirectContextResolver.uniquePathBarFolder(urls: [file], windowTitle: "File.txt"))
        XCTAssertNil(DirectContextResolver.uniquePathBarFolder(urls: [folder], windowTitle: ""))
    }
}
