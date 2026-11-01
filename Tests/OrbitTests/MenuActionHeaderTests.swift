import XCTest
import AppKit
import OrbitCore
@testable import Orbit

@MainActor
final class MenuActionHeaderTests: XCTestCase {
    func testActionButtonsForwardExactlyTheirAction() {
        var selected: [ContextAction] = []
        let header = MenuActionHeader(snapshot: .preview(paste: true), clipboardHasContent: true, action: { selected.append($0) }, tag: { _ in })
        for action in [ContextAction.cut, .copy, .paste, .rename, .share, .delete] {
            let button = header.actionButtons[action]!
            XCTAssertTrue(button.acceptsFirstMouse(for: nil))
            button.performClick(nil)
        }
        XCTAssertEqual(selected, [.cut, .copy, .paste, .rename, .share, .delete])
    }
    func testUnavailableActionsStayVisibleAndCannotInvokeHandlers() {
        let snapshot = ContextMenuSnapshot(applicationName: "Test", applicationIdentifier: "test", commands: [ContextMenuCommand(id: "paste", title: "Paste")])
        var selected: [ContextAction] = []
        let header = MenuActionHeader(snapshot: snapshot, clipboardHasContent: true, action: { selected.append($0) }, tag: { _ in })
        XCTAssertEqual(header.actionButtons.count, 6)
        XCTAssertFalse(header.actionButtons[.copy]!.isEnabled)
        XCTAssertGreaterThanOrEqual(header.actionButtons[.copy]!.frame.width, 64)
        XCTAssertFalse(header.actionButtons[.rename]!.isEnabled)
        header.actionButtons[.rename]!.performClick(nil)
        header.actionButtons[.paste]!.performClick(nil)
        XCTAssertEqual(selected, [.paste])
    }
    func testTagsForwardTheirNativeRoutes() {
        var selected: [String] = []
        let snapshot = ContextMenuSnapshot.preview()
        let header = MenuActionHeader(snapshot: snapshot, clipboardHasContent: false, action: { _ in }, tag: { selected.append($0.id) })
        XCTAssertEqual(header.tagButtons.count, 8)
        header.tagButtons.forEach { $0.performClick(nil) }
        XCTAssertEqual(selected, snapshot.tags.map(\.id) + [snapshot.clearTag!.id])
    }
}
