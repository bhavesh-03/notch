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

        guard case .text(let text, _) = ClipboardMonitor.read(from: pasteboard) else {
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
        #expect(ClipboardMonitor.read(from: pasteboard) == nil)
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

        guard let payload = ClipboardMonitor.read(from: pasteboard), case .image = payload else {
            Issue.record("Expected an image preview")
            return
        }
        let monitor = ClipboardMonitor()
        monitor.recordChange(from: pasteboard)
        let entry = try #require(monitor.history.first)
        #expect(entry.thumbnail?.size == NSSize(width: 1, height: 1))
        pasteboard.clearContents()
        #expect(monitor.copy(entry, to: pasteboard))
        #expect(pasteboard.data(forType: pngType) == png)
        monitor.recordChange(from: pasteboard)
        #expect(monitor.history.count == 1)
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

        guard case .files(let files) = ClipboardMonitor.read(from: pasteboard) else {
            Issue.record("Expected a file preview")
            return
        }
        #expect(files == urls)
    }

    @Test func remembersTenItemsAcrossLaunchesAndClearsThem() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let folder = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = folder.appendingPathComponent("History.plist")
        defer { try? FileManager.default.removeItem(at: folder) }
        let monitor = ClipboardMonitor(historyURL: url)
        for i in 1...12 {
            pasteboard.clearContents()
            pasteboard.setString("Item \(i)", forType: .string)
            monitor.recordChange(from: pasteboard)
        }
        #expect(monitor.history.count == 10)
        let last = try #require(monitor.history.last)
        #expect(last.content == .text("Item 3", type: NSPasteboard.PasteboardType.string.rawValue))

        let relaunched = ClipboardMonitor(historyURL: url)
        relaunched.start(pasteboard: pasteboard)
        #expect(relaunched.history.map(\.content) == monitor.history.map(\.content))
        defer { relaunched.stop() }

        let original = String(repeating: "Original text ", count: 500)
        pasteboard.clearContents()
        pasteboard.setString(original, forType: .string)
        relaunched.recordChange(from: pasteboard)
        let first = try #require(relaunched.history.first)
        #expect(relaunched.copy(first, to: pasteboard))
        #expect(pasteboard.string(forType: .string) == original)

        relaunched.clear(pasteboard: pasteboard)
        #expect(relaunched.history.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        relaunched.recordChange(from: pasteboard)
        #expect(relaunched.history.isEmpty)
        #expect(pasteboard.string(forType: .string) == original)
    }
}
