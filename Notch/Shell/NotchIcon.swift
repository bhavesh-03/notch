import AppKit
import SwiftUI

/// An icon by name: an SF Symbol, or an app's own icon for names like "app:com.apple.calculator"
/// (for things SF Symbols has no glyph for, like a calculator).
struct NotchIcon: View {
    let name: String
    /// The side of an app icon; symbols size with the font like any other.
    var size: CGFloat = 16

    static let appPrefix = "app:"

    var body: some View {
        if let image = Self.appIcon(name) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: name.hasPrefix(Self.appPrefix) ? "app.dashed" : name)
        }
    }

    static func isAppIcon(_ name: String) -> Bool { name.hasPrefix(appPrefix) }

    static func appIcon(_ name: String) -> NSImage? {
        guard isAppIcon(name),
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: String(name.dropFirst(appPrefix.count)))
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
