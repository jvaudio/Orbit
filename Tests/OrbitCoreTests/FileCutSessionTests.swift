import XCTest
@testable import OrbitCore

final class FileCutSessionTests: XCTestCase {
    func testMoveRequiresSameClipboardGenerationAndExactFileSet() {
        var cut = FileCutSession()
        XCTAssertTrue(cut.prepare(files: ["file:///tmp/b.txt", "file:///tmp/a.txt"], generation: 20))
        XCTAssertTrue(cut.shouldMove(files: ["file:///tmp/a.txt", "file:///tmp/b.txt"], generation: 20))
        XCTAssertFalse(cut.shouldMove(files: ["file:///tmp/a.txt", "file:///tmp/b.txt"], generation: 21))
        XCTAssertFalse(cut.shouldMove(files: ["file:///tmp/a.txt"], generation: 20))
        cut.clear()
        XCTAssertFalse(cut.shouldMove(files: ["file:///tmp/a.txt", "file:///tmp/b.txt"], generation: 20))
    }
    func testTextOrEmptyClipboardCannotPrepareMove() {
        var cut = FileCutSession()
        XCTAssertFalse(cut.prepare(files: [], generation: 1))
        XCTAssertFalse(cut.prepare(files: ["https://example.com/a.txt"], generation: 2))
        XCTAssertFalse(cut.shouldMove(files: [], generation: 2))
    }
}
