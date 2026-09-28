import CoreGraphics

/// Follows whether a full-screen app's menu bar is showing, the way macOS decides it: it slides in
/// when the pointer touches the top edge of the screen, stays while the pointer is within it (or a
/// menu is open), and hides once the pointer moves below it.
struct MenuBarPresence {
    private(set) var isRevealed = false

    /// Updates from the pointer's height (AppKit coordinates, y up) and returns whether it's showing.
    mutating func update(pointerY: CGFloat, screenTop: CGFloat, menuBarHeight: CGFloat, menuOpen: Bool) -> Bool {
        if menuOpen || pointerY >= screenTop - 2 {
            isRevealed = true
        } else if pointerY < screenTop - menuBarHeight - 6 {
            isRevealed = false
        }
        return isRevealed
    }

    mutating func reset() {
        isRevealed = false
    }
}
