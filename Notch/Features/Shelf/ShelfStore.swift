import Foundation
import UniformTypeIdentifiers

/// Files the user dropped on the notch, kept across launches.
///
/// Real files are *referenced* through security-scoped bookmarks. Content without a usable file
/// (a screenshot thumbnail, an image dragged out of an app) is *copied* into the shelf's own folder;
/// those copies belong to the shelf and are deleted when removed.
@Observable
final class ShelfStore {
    struct Item: Identifiable, Equatable {
        let id = UUID()
        let url: URL
        let bookmark: Data
        /// Whether we called startAccessingSecurityScopedResource and so must balance it with stop.
        let isAccessing: Bool
        /// A copy the shelf made and owns, as opposed to a reference to the user's original file.
        let isOwnedCopy: Bool

        var name: String { url.lastPathComponent }
    }

    static let capacity = 6

    private(set) var items: [Item] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let copiesFolder: URL

    init(defaults: UserDefaults = .standard, copiesFolder: URL = ShelfStore.defaultCopiesFolder) {
        self.defaults = defaults
        self.copiesFolder = copiesFolder
        load()
    }

    var isFull: Bool { items.count >= Self.capacity }

    // MARK: - Adding

    /// Adds dropped files by reference; ignores duplicates, non-file URLs, and anything past capacity.
    @discardableResult
    func add(_ urls: [URL]) -> Bool {
        var added = false
        for url in urls where !isFull {
            if reference(url) == .added { added = true }
        }
        if added { save() }
        return added
    }

    /// Adds whatever was dropped: a reference when there's a real, accessible file, otherwise a copy.
    func add(_ providers: [NSItemProvider]) async {
        for provider in providers where !isFull {
            if let url = await provider.loadFileURL() {
                switch reference(url) {
                case .added: save(); continue
                case .duplicate: continue
                case .unusable: break
                }
            }
            if let copy = await provider.copyContents(into: copiesFolder) {
                adoptCopy(copy)
            }
        }
    }

    private enum ReferenceResult { case added, duplicate, unusable }

    private func reference(_ url: URL) -> ReferenceResult {
        guard url.isFileURL else { return .unusable }
        let url = url.standardizedFileURL
        guard !items.contains(where: { $0.url == url }) else { return .duplicate }

        let isAccessing = url.startAccessingSecurityScopedResource()
        guard FileManager.default.isReadableFile(atPath: url.path),
              let bookmark = try? url.bookmarkData(options: Self.bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
        else {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
            return .unusable
        }

        items.append(Item(url: url, bookmark: bookmark, isAccessing: isAccessing, isOwnedCopy: false))
        return .added
    }

    private func adoptCopy(_ url: URL) {
        guard let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        items.append(Item(url: url, bookmark: bookmark, isAccessing: false, isOwnedCopy: true))
        save()
    }

    // MARK: - Removing

    func remove(_ item: Item) {
        guard let index = items.firstIndex(of: item) else { return }
        release(items.remove(at: index))
        save()
    }

    func removeAll() {
        items.forEach { release($0) }
        items.removeAll()
        save()
    }

    private func release(_ item: Item) {
        if item.isAccessing {
            item.url.stopAccessingSecurityScopedResource()
        }
        if isStillOwned(item) {
            try? FileManager.default.removeItem(at: item.url)
        }
    }

    /// An owned copy is only deleted while it's still in the shelf's folder. If the user dragged it
    /// out and Finder *moved* it (the bookmark follows the move), it's now their file — leave it.
    private func isStillOwned(_ item: Item) -> Bool {
        item.isOwnedCopy
            && item.url.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath()
                == copiesFolder.standardizedFileURL.resolvingSymlinksInPath()
    }

    // MARK: - Persistence

    static let defaultCopiesFolder = URL.applicationSupportDirectory.appendingPathComponent("Shelf", isDirectory: true)

    private static let bookmarkOptions: URL.BookmarkCreationOptions = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
    private static let storageKey = "shelf.items"
    /// Version 1 stored only an array of bookmarks, before owned copies existed.
    private static let legacyStorageKey = "shelf.bookmarks"

    private struct Record: Codable {
        let bookmark: Data
        let isOwnedCopy: Bool
    }

    private func save() {
        let records = items.map { Record(bookmark: $0.bookmark, isOwnedCopy: $0.isOwnedCopy) }
        defaults.set(try? JSONEncoder().encode(records), forKey: Self.storageKey)
    }

    private func load() {
        items = storedRecords().compactMap { Self.resolve($0) }
        defaults.removeObject(forKey: Self.legacyStorageKey)
        save()
    }

    private func storedRecords() -> [Record] {
        if let data = defaults.data(forKey: Self.storageKey),
           let records = try? JSONDecoder().decode([Record].self, from: data) {
            return records
        }
        let legacy = defaults.array(forKey: Self.legacyStorageKey) as? [Data] ?? []
        return legacy.map { Record(bookmark: $0, isOwnedCopy: false) }
    }

    /// Turns a saved record back into a usable item, or nil if the file is gone.
    private static func resolve(_ record: Record) -> Item? {
        var isStale = false
        let options: URL.BookmarkResolutionOptions = record.isOwnedCopy ? [] : .withSecurityScope
        guard let url = try? URL(resolvingBookmarkData: record.bookmark, options: options, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
            return nil
        }

        let isAccessing = record.isOwnedCopy ? false : url.startAccessingSecurityScopedResource()
        guard FileManager.default.fileExists(atPath: url.path) else {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
            return nil
        }

        var bookmark = record.bookmark
        if isStale {
            let creation: URL.BookmarkCreationOptions = record.isOwnedCopy ? [] : bookmarkOptions
            bookmark = (try? url.bookmarkData(options: creation, includingResourceValuesForKeys: nil, relativeTo: nil)) ?? bookmark
        }
        return Item(url: url, bookmark: bookmark, isAccessing: isAccessing, isOwnedCopy: record.isOwnedCopy)
    }
}

extension NSItemProvider {
    /// The dropped file URL, if the drag carries one.
    func loadFileURL() async -> URL? {
        guard hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { return nil }
        return await withCheckedContinuation { continuation in
            _ = loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }

    /// Writes the dropped content (e.g. PNG data from a screenshot thumbnail) into `folder`.
    func copyContents(into folder: URL) async -> URL? {
        guard let type = registeredContentTypes.first(where: { $0.conforms(to: .data) && !$0.conforms(to: .url) }) else {
            return nil
        }
        let name = Self.fileName(suggested: suggestedName, type: type)

        return await withCheckedContinuation { continuation in
            _ = loadFileRepresentation(for: type) { temporaryURL, _, _ in
                // The temporary file only exists until this closure returns, so copy it now.
                guard let temporaryURL else { return continuation.resume(returning: nil) }
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let destination = Self.uniqueURL(in: folder, named: name)
                    try FileManager.default.copyItem(at: temporaryURL, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    nonisolated static func fileName(suggested: String?, type: UTType) -> String {
        let base = suggested?.isEmpty == false ? suggested! : "Dropped item"
        guard (base as NSString).pathExtension.isEmpty, let ext = type.preferredFilenameExtension else { return base }
        return "\(base).\(ext)"
    }

    /// `name`, or `name 2`, `name 3`… if something with that name is already there.
    nonisolated static func uniqueURL(in folder: URL, named name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = folder.appendingPathComponent(numbered)
            counter += 1
        }
        return candidate
    }
}
