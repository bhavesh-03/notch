import AppKit
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
        #expect(item.url.deletingLastPathComponent().deletingLastPathComponent().standardizedFileURL == copies.standardizedFileURL)
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

    @Test func copiesWithTheSameNameStaySeparateWithoutRenaming() async throws {
        let shelf = store()
        for byte: UInt8 in [1, 2] {
            let provider = pngProvider(Data([byte]))
            provider.suggestedName = "Shot"
            await shelf.add([provider])
        }
        #expect(shelf.items.map(\.name) == ["Shot.png", "Shot.png"])
        #expect(Set(shelf.items.map(\.url)).count == 2)
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

    @Test func anOwnedCopyMovedOutOfTheShelfIsNotDeleted() async throws {
        let shelf = store()
        await shelf.add([pngProvider(Data([1, 2, 3]))])
        let copy = try #require(shelf.items.first).url

        // Simulate Finder moving the copy out when it's dragged to the Desktop.
        let moved = folder.appendingPathComponent("Moved.png")
        try FileManager.default.moveItem(at: copy, to: moved)
        let relaunched = store()
        #expect(relaunched.items.first?.url.lastPathComponent == "Moved.png")

        relaunched.removeAll()
        #expect(FileManager.default.fileExists(atPath: moved.path))
    }

    @Test func clipboardExportsAFolderAndMultipleFilesWithOriginalNames() throws {
        let shelf = store()
        let a = try file("File one.txt")
        let directory = folder.appendingPathComponent("Project files", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let b = try file("File two.txt")
        shelf.add([a, directory, b])

        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        #expect(ShelfFileTransfer.copy(shelf.items, to: pasteboard))
        let pasted = try #require(pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL])
        #expect(pasted.map(\.lastPathComponent) == ["File one.txt", "Project files", "File two.txt"])
        #expect(zip(pasted, shelf.items).allSatisfy { ShelfStore.isSameFile($0, $1.url) })
        #expect(shelf.items.count == 3)
    }

    @Test func nativeDragUsesFileURLsWithTheirOriginalNames() throws {
        let shelf = store()
        shelf.add([try file("File one.txt"), try file("File two.txt")])

        let payload = ShelfFileTransfer.dragItems(shelf.items, at: .zero).compactMap {
            $0.item as? NSURL
        }
        #expect(payload.map(\.lastPathComponent) == ["File one.txt", "File two.txt"])
    }

    @Test func differentSpellingsOfOnePathAreTheSameFile() throws {
        let a = try file("a.txt")
        let link = folder.appendingPathComponent("link-to-a.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: a)
        #expect(ShelfStore.isSameFile(a, link))
        let viaParent = folder.appendingPathComponent("sub/../a.txt")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("sub"), withIntermediateDirectories: true)
        #expect(ShelfStore.isSameFile(a, viaParent))
        #expect(!ShelfStore.isSameFile(a, try file("b.txt")))

        let shelf = store()
        shelf.add([a])
        #expect(!shelf.add([link]), "a symlink to a shelved file is a duplicate")
    }

    /// The real round trip: Finder copies the item to the Desktop, and that copy is dropped back.
    @Test func aFinderCopyOfAShelvedFileIsADuplicate() async throws {
        let original = try file("report.txt")
        let desktop = folder.appendingPathComponent("Desktop", isDirectory: true)
        try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
        let desktopCopy = desktop.appendingPathComponent("report.txt")
        try FileManager.default.copyItem(at: original, to: desktopCopy)

        let shelf = store()
        shelf.add([original])
        await shelf.add([try #require(NSItemProvider(contentsOf: desktopCopy))])

        #expect(shelf.items.map(\.name) == ["report.txt"])
    }

    @Test func droppingTheSameImageTwiceKeepsOneCopy() async throws {
        let shelf = store()
        await shelf.add([pngProvider(Data([1, 2, 3]))])
        await shelf.add([pngProvider(Data([1, 2, 3]))])

        #expect(shelf.items.count == 1)
        let copies = try FileManager.default.contentsOfDirectory(atPath: copies.path)
        #expect(copies.count == 1, "the rejected copy is cleaned up")
    }

    @Test func differentNamesWithIdenticalContentsAreBothKept() throws {
        let original = try file("a.txt")
        let copy = folder.appendingPathComponent("b.txt")
        try FileManager.default.copyItem(at: original, to: copy)
        let shelf = store()
        shelf.add([original, copy])
        #expect(shelf.items.map(\.name) == ["a.txt", "b.txt"])
    }

    @Test func deliveredFileNameWinsOverAGenericFallback() {
        #expect(NSItemProvider.fileName(suggested: nil, delivered: "Quarterly report.pdf", type: .pdf) == "Quarterly report.pdf")
        #expect(NSItemProvider.fileName(suggested: "Meeting notes", delivered: "File.pdf", type: .pdf) == "Meeting notes.pdf")
        #expect(NSItemProvider.fileName(suggested: nil, delivered: UUID().uuidString + ".pdf", type: .pdf) == "PDF Document.pdf")
        let source = URL(string: "https://example.com/Quarterly%20report.pdf?download=1")
        #expect(NSItemProvider.sourceFileName(from: source, type: .pdf) == "Quarterly report.pdf")
        #expect(NSItemProvider.sourceFileName(from: source, type: .jpeg) == nil)
    }

    @Test func renamedCopiesKeepTheNewNameWhenReopened() async throws {
        let shelf = store()
        await shelf.add([pngProvider(Data([1, 2, 3]))])
        let original = try #require(shelf.items.first)
        #expect(!shelf.renameOwnedCopy(original, to: "../outside.png"))
        #expect(shelf.renameOwnedCopy(original, to: "Original image.png"))
        let renamed = try #require(store().items.first)
        #expect(renamed.name == "Original image.png")
        #expect(try Data(contentsOf: renamed.url) == Data([1, 2, 3]))
        #expect(!FileManager.default.fileExists(atPath: original.url.path))
    }

    @Test func differentFilesOfTheSameSizeAreBothKept() {
        let shelf = store()
        #expect(shelf.add([try! file("ab.txt")]))
        #expect(shelf.add([try! file("cd.txt")]))
        #expect(shelf.items.count == 2)
    }
}
