import AppKit
import SwiftUI

/// Shows the settings window.
///
/// An agent app (no Dock icon, no menu bar) can't count on SwiftUI's `Settings` scene: its
/// `openSettings` action only works from views that live in a SwiftUI scene, and the notch is an
/// `NSHostingView` in our own panel. A plain AppKit window hosting the SwiftUI view is dependable.
final class SettingsWindowController {
    private let settings: NotchSettings
    private var window: NSWindow?

    init(settings: NotchSettings) {
        self.settings = settings
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
            window.title = "Notch Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            // Kept and reused, so reopening is instant and remembers the selected tab.
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // Agent apps aren't active by default; without this the window opens behind the current app.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
