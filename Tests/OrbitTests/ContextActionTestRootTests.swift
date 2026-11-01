#if DEBUG
import XCTest
@testable import Orbit

@MainActor
final class ContextActionTestRootTests: XCTestCase {
    func testOnlyNamedTemporaryRootsAreAcceptedWithCanonicalPaths() {
        XCTAssertTrue(ContextActionTestWindow.accepts(URL(fileURLWithPath: "/private/tmp/orbit-instant-regression.example")))
        XCTAssertTrue(ContextActionTestWindow.accepts(URL(fileURLWithPath: "/tmp/orbit-instant-regression.example")))
        XCTAssertFalse(ContextActionTestWindow.accepts(URL(fileURLWithPath: "/Users/example/orbit-instant-regression.example")))
        XCTAssertFalse(ContextActionTestWindow.accepts(URL(fileURLWithPath: "/private/tmp/unrelated-folder")))
    }
}
#endif
