import XCTest
@testable import OrbitCore

final class MenuRouteTests: XCTestCase {
    func testUniqueIdentifiersSurviveChangingLabelsAndPositions() {
        let saved = MenuRouteComponent(title: "Tags… Customize Folder…", identifier: "cmdSetLabel:", role: "AXMenuItem", index: 5)
        let live = [MenuRouteComponent(title: "Tags…", identifier: "cmdSetLabel:", role: "AXMenuItem", index: 0)]
        XCTAssertEqual(saved.matchingIndex(in: live), 0)
    }
    func testReusedPluginIdentifiersRequireUniqueName() {
        let saved = MenuRouteComponent(title: "Move To", identifier: "executePlugInCommand:", role: "AXMenuItem", index: 0)
        let live = [MenuRouteComponent(title: "Copy To", identifier: "executePlugInCommand:", role: "AXMenuItem", index: 0), MenuRouteComponent(title: "Move To", identifier: "executePlugInCommand:", role: "AXMenuItem", index: 1)]
        XCTAssertEqual(saved.matchingIndex(in: live), 1)
        XCTAssertNil(saved.matchingIndex(in: [live[1], live[1]]))
        XCTAssertNil(saved.matchingIndex(in: [live[0]]))
    }
    func testMissingNamedControlsAreNeverGuessedByPosition() {
        let saved = MenuRouteComponent(title: "Add Blue", identifier: "", role: "AXRadioButton", index: 0)
        XCTAssertNil(saved.matchingIndex(in: [MenuRouteComponent(title: "Add Red", identifier: "", role: "AXRadioButton", index: 0)]))
    }
}
