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
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j7ioAAAAASUVORK5CYII="))
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

    @Test func readsAllCopiedFileURLs() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let urls = [URL(fileURLWithPath: "/tmp/First.txt"), URL(fileURLWithPath: "/tmp/Second.txt")]
        pasteboard.clearContents()
        #expect(pasteboard.writeObjects(urls.map { $0 as NSURL }))

        guard case .files(let files) = ClipboardMonitor.preview(from: pasteboard) else {
            Issue.record("Expected a file preview")
            return
        }
        #expect(files == urls)
    }
}
