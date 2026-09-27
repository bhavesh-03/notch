import Foundation

/// Brings the settings and shelf copies over from the sandbox container, once, after the app stopped
/// being sandboxed (1.2). A sandboxed app keeps its data in ~/Library/Containers/<id>/Data; an
/// unsandboxed one uses ~/Library directly, and macOS doesn't carry anything across on its own.
enum SandboxMigration {
    static let doneKey = "migration.fromSandbox"

    struct Locations {
        /// The container's preferences plist.
        var preferences: URL
        /// The container's shelf folder, where the app kept its own copies of dropped content.
        var shelf: URL
        /// Where the shelf keeps copies now.
        var newShelf: URL
    }

    static var defaultLocations: Locations {
        let id = Bundle.main.bundleIdentifier ?? "com.vinzi.Notch"
        let data = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(id)/Data", isDirectory: true)
        return Locations(
            preferences: data.appendingPathComponent("Library/Preferences/\(id).plist"),
            shelf: data.appendingPathComponent("Library/Application Support/Shelf", isDirectory: true),
            newShelf: ShelfStore.defaultCopiesFolder
        )
    }

    /// Copies each saved setting the app doesn't have yet, and moves the shelf's copies. Moving (not
    /// copying) matters: the shelf refers to its files by bookmark, and a bookmark follows a moved file.
    static func runIfNeeded(defaults: UserDefaults = .standard, locations: Locations = defaultLocations) {
        guard !defaults.bool(forKey: doneKey) else { return }
        defer { defaults.set(true, forKey: doneKey) }

        if let data = try? Data(contentsOf: locations.preferences),
           let saved = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            for (key, value) in saved where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }

        let files = (try? FileManager.default.contentsOfDirectory(at: locations.shelf, includingPropertiesForKeys: nil)) ?? []
        guard !files.isEmpty else { return }
        try? FileManager.default.createDirectory(at: locations.newShelf, withIntermediateDirectories: true)
        for file in files {
            let destination = locations.newShelf.appendingPathComponent(file.lastPathComponent)
            guard !FileManager.default.fileExists(atPath: destination.path) else { continue }
            try? FileManager.default.moveItem(at: file, to: destination)
        }
    }
}
