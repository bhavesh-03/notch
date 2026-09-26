import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Notch

@MainActor
struct ShelfStoreTests {
    let defaults: UserDefaults
    let folder: URL
    let copies: URL

    init() throws {
        defaults = UserDefaults(suiteName: "ShelfStoreTests.\(UUID().uuidString)")!
        folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        copies = folder.appendingPathComponent("Copies", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func store() -> ShelfStore {
        ShelfStore(defaults: defaults, copiesFolder: copies)
    }

    /// A drop that carries PNG data but no file, like a screenshot thumbnail.
    private func pngProvider(_ data: Data) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(for: .png, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }

    private func file(_ name: String) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data(name.utf8).write(to: url)
        return url
    }

    @Test func addedFilesAppearInOrder() throws {
        let shelf = store()
        let a = try file("a.txt"), b = try file("b.txt")
        #expect(shelf.add([a, b]))
        #expect(shelf.items.map(\.name) == ["a.txt", "b.txt"])
        #expect(shelf.items.allSatisfy { !$0.isOwnedCopy })
    }

    @Test func duplicatesAndNonFileURLsAreIgnored() throws {
        let shelf = store()
        let a = try file("a.txt")
        shelf.add([a])
        let addedAgain = shelf.add([a, URL(string: "https://example.com")!])
        #expect(!addedAgain)
        #expect(shelf.items.count == 1)
    }

    @Test func missingFilesAreNotAdded() {
        let shelf = store()
        #expect(!shelf.add([folder.appendingPathComponent("never-written.txt")]))
    }

    @Test func stopsAtCapacity() throws {
        let shelf = store()
        let urls = try (1...(ShelfStore.capacity + 2)).map { try file("\($0).txt") }
        shelf.add(urls)
        #expect(shelf.items.count == ShelfStore.capacity)
        #expect(shelf.isFull)
    }

    @Test func itemsSurviveARelaunch() throws {
        let a = try file("a.txt"), b = try file("b.txt")
        store().add([a, b])
        #expect(store().items.map(\.name) == ["a.txt", "b.txt"])
    }

    @Test func filesDeletedWhileClosedAreDroppedOnLaunch() throws {
        let a = try file("a.txt"), b = try file("b.txt")
        store().add([a, b])
        try FileManager.default.removeItem(at: a)
        #expect(store().items.map(\.name) == ["b.txt"])
    }

    @Test func removalIsPersisted() throws {
        let a = try file("a.txt"), b = try file("b.txt")
        let shelf = store()
        shelf.add([a, b])
        shelf.remove(shelf.items[0])
        #expect(store().items.map(\.name) == ["b.txt"])

        shelf.removeAll()
        #expect(store().items.isEmpty)
    }

    @Test func removingAReferenceNeverDeletesTheOriginal() throws {
        let a = try file("a.txt")
        let shelf = store()
        shelf.add([a])
        shelf.removeAll()
        #expect(FileManager.default.fileExists(atPath: a.path))
    }

    // MARK: - Dropped content without a usable file

    @Test func droppedDataIsCopiedAndOwned() async throws {
        let shelf = store()
        let provider = pngProvider(Data([0x89, 0x50, 0x4E, 0x47]))
        provider.suggestedName = "Screenshot 2026-09-27"

        await shelf.add([provider])

        let item = try #require(shelf.items.first)
        #expect(item.isOwnedCopy)
        #expect(item.name == "Screenshot 2026-09-27.png")
        #expect(item.url.deletingLastPathComponent().standardizedFileURL == copies.standardizedFileURL)
        #expect(FileManager.default.fileExists(atPath: item.url.path))
    }

    @Test func removingAnOwnedCopyDeletesIt() async throws {
        let shelf = store()
        await shelf.add([pngProvider(Data([1, 2, 3]))])
        let copy = try #require(shelf.items.first).url

        shelf.removeAll()
        #expect(!FileManager.default.fileExists(atPath: copy.path))
    }

    @Test func ownedCopiesSurviveARelaunch() async throws {
        await store().add([pngProvider(Data([1, 2, 3]))])
        let relaunched = store()
        #expect(relaunched.items.count == 1)
        #expect(relaunched.items.first?.isOwnedCopy == true)
    }

    @Test func droppedFileURLsAreReferencedNotCopied() async throws {
        let a = try file("a.txt")
        let shelf = store()
        await shelf.add([try #require(NSItemProvider(contentsOf: a))])
        #expect(shelf.items.map(\.name) == ["a.txt"])
        #expect(shelf.items.first?.isOwnedCopy == false)
    }

    @Test func copiesWithTheSameNameGetNumbered() async throws {
        let shelf = store()
        for _ in 0..<2 {
            let provider = pngProvider(Data([1]))
            provider.suggestedName = "Shot"
            await shelf.add([provider])
        }
        #expect(shelf.items.map(\.name) == ["Shot.png", "Shot 2.png"])
    }

    @Test func version1ShelvesAreMigrated() throws {
        let a = try file("a.txt")
        let bookmark = try a.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set([bookmark], forKey: "shelf.bookmarks")

        let shelf = store()
        #expect(shelf.items.map(\.name) == ["a.txt"])
        #expect(defaults.object(forKey: "shelf.bookmarks") == nil)
        #expect(store().items.map(\.name) == ["a.txt"])
    }
}
