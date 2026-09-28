import AppKit
import ApplicationServices

/// Whether the collapsed notch's ears would cover the frontmost app's menus. On a Mac with a notch,
/// macOS runs the menus up to the camera and continues them on its right, so an app with many menus
/// (Xcode, say) fills the space the ears would take. Read through Accessibility.
enum MenuBarClearance {
    /// The frames of the frontmost app's menu titles, or nil if they can't be read (no Accessibility
    /// permission yet). x is in screen coordinates, the same as AppKit's.
    static func frontmostMenuTitles() -> [CGRect]? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var menuBar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXMenuBarAttribute as CFString, &menuBar) == .success,
              let menuBar else { return nil }
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &children) == .success,
              let items = children as? [AXUIElement] else { return nil }
        return items.compactMap { frame(of: $0) }
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &point)
        AXValueGetValue(size as! AXValue, .cgSize, &extent)
        return CGRect(origin: point, size: extent)
    }

    /// Whether the frontmost app's focused window is in full screen, where macOS hides the menu bar
    /// until the pointer reaches the top. (macOS doesn't report whether the menu bar is hidden: its
    /// window and frames stay the same either way, checked by logging both states.)
    static func frontmostIsFullScreen() -> Bool {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication else { return false }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window else { return false }
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(window as! AXUIElement, "AXFullScreen" as CFString, &value)
        return (value as? Bool) ?? false
    }

    /// Whether the frontmost app has a menu open (a menu window on screen), which keeps a hidden
    /// menu bar revealed while the pointer is down in the menu.
    static func frontmostHasMenuOpen() -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return false }
        let level = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let windows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
        return windows.contains {
            $0[kCGWindowOwnerPID as String] as? Int32 == pid && $0[kCGWindowLayer as String] as? Int == level
        }
    }

    /// Whether menu titles leave room for the ears beside `notch` (a small margin counts as touching).
    static func earsFit(menuTitles: [CGRect], notch: CGRect, earWidth: CGFloat) -> Bool {
        let leftEar = (notch.minX - earWidth - 4)...notch.minX
        let rightEar = notch.maxX...(notch.maxX + earWidth + 4)
        return !menuTitles.contains { title in
            let span = title.minX...title.maxX
            return span.overlaps(leftEar) || span.overlaps(rightEar)
        }
    }
}
