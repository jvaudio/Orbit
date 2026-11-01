import XCTest
@testable import OrbitCore

final class ContextMenuTests: XCTestCase {
    func testAllSixTilesKeepTheirOrderWithAndWithoutClipboardContent() {
        let expected: [ContextAction] = [.cut, .copy, .paste, .rename, .share, .delete]
        for paste in [false, true] {
            let menu = ContextMenuSnapshot.preview(paste: paste)
            for clipboard in [false, true] {
                XCTAssertEqual(menu.topActions(clipboardHasContent: clipboard), expected)
            }
            XCTAssertEqual(menu.isEnabled(.paste), paste)
            XCTAssertTrue(menu.isEnabled(.copy))
            XCTAssertTrue(menu.isEnabled(.cut))
        }
    }
    func testUnavailableContextStillShowsAllSixTiles() {
        let menu = ContextMenuSnapshot(applicationName: "Test", applicationIdentifier: "test", commands: [])
        XCTAssertEqual(menu.topActions(clipboardHasContent: false), [.cut, .copy, .paste, .rename, .share, .delete])
        XCTAssertTrue(ContextAction.allCases.allSatisfy { !menu.isEnabled($0) })
    }
    func testCutRequiresAnExplicitEnabledCommand() {
        var menu = ContextMenuSnapshot(applicationName: "Finder", applicationIdentifier: "com.apple.finder", commands: [ContextMenuCommand(id: "copy", title: "Copy")], finderFileContext: true)
        XCTAssertFalse(menu.isEnabled(.cut))
        menu.commands.append(ContextMenuCommand(id: "cut", title: "Cut", enabled: false))
        XCTAssertFalse(menu.isEnabled(.cut))
        menu.commands[1].enabled = true
        XCTAssertTrue(menu.isEnabled(.cut))
    }
    func testOnlyPromotedActionsAreRemovedFromBody() {
        let menu = ContextMenuSnapshot.preview(paste: true)
        let body = menu.remainingCommands(clipboardHasContent: true)
        XCTAssertFalse(body.contains { $0.action != nil })
        XCTAssertFalse(body.contains { $0.action == .paste || $0.action == .delete })
        XCTAssertTrue(body.contains { $0.title == "Open With" && !$0.children.isEmpty })
    }
    func testSeparatorCleanup() {
        let separator = ContextMenuCommand(id: "sep", title: "", separator: true)
        let copy = ContextMenuCommand(id: "copy", title: "Copy")
        let open = ContextMenuCommand(id: "open", title: "Open")
        let menu = ContextMenuSnapshot(applicationName: "Test", applicationIdentifier: "test", commands: [separator, copy, separator, open, separator, separator])
        XCTAssertEqual(menu.remainingCommands(clipboardHasContent: false).map(\.title), ["Open"])
    }
    func testStableIdentifiersRecognizeLocalizedFinderCommands() {
        XCTAssertEqual(ContextAction.identify(title: "In den Papierkorb", identifier: "cmdMoveToTrash:"), .delete)
        XCTAssertEqual(ContextAction.identify(title: "Umbenennen", identifier: "cmdRename:"), .rename)
        XCTAssertEqual(ContextAction.identify(title: "Objekt hierher bewegen", identifier: "cmdMoveItemsHere:"), .paste)
        XCTAssertNil(ContextAction.identify(title: "Delete Immediately…", identifier: "cmdDeleteImmediately:"))
    }
}
