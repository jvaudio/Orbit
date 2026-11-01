import AppKit
import ApplicationServices

/// Attribute queries and main-menu edit actions only. No context menu is opened
/// to construct Orbit's direct menu.
enum NativeMenuAccess {
    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }
    static func string(_ element: AXUIElement, _ attribute: String) -> String { value(element, attribute) as? String ?? "" }
    static func children(_ element: AXUIElement) -> [AXUIElement] { value(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] }
    static func enabled(_ element: AXUIElement) -> Bool { (value(element, kAXEnabledAttribute) as? Bool) ?? true }
    static func role(_ element: AXUIElement) -> String { string(element, kAXRoleAttribute) }
    static func name(_ element: AXUIElement) -> String {
        let title = string(element, kAXTitleAttribute)
        return title.isEmpty ? string(element, kAXDescriptionAttribute) : title
    }
    static func press(_ element: AXUIElement) -> AXError {
        var actions: CFArray?
        AXUIElementCopyActionNames(element, &actions)
        let names = actions as? [String] ?? []
        let action = names.contains(kAXPickAction) && !names.contains(kAXPressAction) ? kAXPickAction : kAXPressAction
        return AXUIElementPerformAction(element, action as CFString)
    }
}
