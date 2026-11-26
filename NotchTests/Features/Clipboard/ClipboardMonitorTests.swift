import AppKit
import Testing
@testable import Notch

@MainActor
struct ClipboardMonitorTests {
    @Test func readsTextWithoutChangingTheClipboard() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        #expect(pasteboard.setString("Copied text", forType: .string))
        let count = pasteboard.changeCount

        guard case .text(let text) = ClipboardMonitor.preview(from: pasteboard) else {
            Issue.record("Expected a text preview")
            return
        }
        #expect(text == "Copied text")
        #expect(pasteboard.changeCount == count)
    }

    @Test func concealedItemsAreNeverPreviewed() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        pasteboard.declareTypes([concealed, .string], owner: nil)
        pasteboard.setData(Data(), forType: concealed)
        pasteboard.setString("Secret", forType: .string)
        #expect(ClipboardMonitor.preview(from: pasteboard) == nil)
    }

    @Test func readsACopiedImageAndGivesItPrecedenceOverText() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let png = try #require(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP43+DwHwAHAAK/K9fH4gAAAABJRU5ErkJggg=="))
        let pngType = NSPasteboard.PasteboardType("public.png")
        pasteboard.declareTypes([pngType, .string], owner: nil)
        pasteboard.setData(png, forType: pngType)
        pasteboard.setString("Image fallback", forType: .string)

        guard case .image(let image) = ClipboardMonitor.preview(from: pasteboard) else {
            Issue.record("Expected an image preview")
            return
        }
        #expect(image.size == NSSize(width: 1, height: 1))
    }

    @Test func readsAllCopiedFileURLs() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let folder = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let urls = ["First.txt", "Second.txt"].map { folder.appendingPathComponent($0) }
        for url in urls { try Data("copied".utf8).write(to: url) }
        pasteboard.clearContents()
        #expect(pasteboard.writeObjects(urls.map { $0 as NSURL }))

        guard case .files(let files) = ClipboardMonitor.preview(from: pasteboard) else {
            Issue.record("Expected a file preview")
            return
        }
        #expect(files == urls)
    }
}
