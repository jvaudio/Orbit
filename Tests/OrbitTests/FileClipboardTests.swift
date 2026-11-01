import XCTest
import AppKit
@testable import Orbit

@MainActor
final class FileClipboardTests: XCTestCase {
    func testModernFileURLsAreReadWithoutChangingClipboardGeneration() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let url = URL(fileURLWithPath: "/private/tmp/orbit paste test.txt")
        board.writeObjects([url as NSURL])
        let count = board.changeCount
        XCTAssertEqual(FileClipboard.fileURLs(from: board), [url.absoluteString])
        XCTAssertEqual(board.changeCount, count)
    }
    func testLegacyFilenameListsAndPlainText() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        board.declareTypes([NSPasteboard.PasteboardType("NSFilenamesPboardType")], owner: nil)
        board.setPropertyList(["/private/tmp/legacy.txt"], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        XCTAssertEqual(FileClipboard.fileURLs(from: board), ["file:///private/tmp/legacy.txt"])
        board.clearContents(); board.setString("/private/tmp/not-a-file-copy.txt", forType: .string)
        XCTAssertTrue(FileClipboard.fileURLs(from: board).isEmpty)
    }
}
