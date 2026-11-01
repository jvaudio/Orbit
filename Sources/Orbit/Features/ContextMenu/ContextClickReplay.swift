import CoreGraphics

/// Retains the window-routing fields from the source event. Constructing a new
/// mouse event only from screen coordinates loses that context in targeted posts.
enum ContextClickReplay {
    static func events(from original: CGEvent, marker: Int64, movePaste: Bool) -> (down: CGEvent, up: CGEvent)? {
        guard let down = original.copy(), let up = original.copy() else { return nil }
        down.setIntegerValueField(.eventSourceUserData, value: marker)
        up.setIntegerValueField(.eventSourceUserData, value: marker)
        up.type = down.type == .leftMouseDown ? .leftMouseUp : .rightMouseUp
        if movePaste { down.flags.insert(.maskAlternate); up.flags.insert(.maskAlternate) }
        return (down, up)
    }
}
