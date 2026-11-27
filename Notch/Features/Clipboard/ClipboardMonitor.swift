import AppKit
import ImageIO
import UniformTypeIdentifiers

@Observable
final class ClipboardMonitor {
    static let capacity = 10
    private static let storageQueue = DispatchQueue(label: "Notch.ClipboardHistory", qos: .utility)

    enum Payload: Codable, Equatable, Sendable {
        case image(Data, type: String)
        case pdf(Data)
        case files([URL])
        case text(String, type: String)
    }

    struct Entry: Identifiable {
        let id = UUID()
        let content: Payload
        let thumbnail: NSImage?

        init(content: Payload) {
            self.content = content
            if case .image(let data, _) = content,
               let source = CGImageSourceCreateWithData(data as CFData, nil),
               let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                   kCGImageSourceCreateThumbnailFromImageAlways: true,
                   kCGImageSourceCreateThumbnailWithTransform: true,
                   kCGImageSourceThumbnailMaxPixelSize: 320
               ] as CFDictionary) {
                thumbnail = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            } else {
                thumbnail = nil
            }
        }
    }

    private(set) var history: [Entry] = []
    private(set) var entry: Entry?
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var watchTask: Task<Void, Never>?
    @ObservationIgnored private var changeCount = 0
    @ObservationIgnored private let historyURL: URL?

    init(historyURL: URL? = nil) {
        self.historyURL = historyURL
    }

    static let defaultHistoryURL = ShelfStore.defaultCopiesFolder.deletingLastPathComponent()
        .appendingPathComponent("Clipboard", isDirectory: true)
        .appendingPathComponent("History.plist")

    func start(pasteboard: NSPasteboard = .general) {
        guard watchTask == nil else { return }
        if let historyURL {
            let data = Self.storageQueue.sync { try? Data(contentsOf: historyURL) }
            if let data, let payloads = try? PropertyListDecoder().decode([Payload].self, from: data) {
                history = payloads.prefix(Self.capacity).map { Entry(content: $0) }
            }
        }
        changeCount = pasteboard.changeCount
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let self else { break }
                recordChange(from: pasteboard)
            }
        }
    }

    func stop() {
        guard watchTask != nil else { return }
        watchTask?.cancel()
        watchTask = nil
        clear()
    }

    func recordChange(from pasteboard: NSPasteboard) {
        let count = pasteboard.changeCount
        guard count != changeCount else { return }
        changeCount = count

        if let payload = Self.read(from: pasteboard) {
            let latest = history.first { $0.content == payload } ?? Entry(content: payload)
            history.removeAll { $0.id == latest.id }
            history.insert(latest, at: 0)
            if history.count > Self.capacity { history.removeLast() }
            entry = latest
            save()
        } else {
            entry = nil
        }
        onChange?()
    }

    @discardableResult
    func copy(_ entry: Entry, to pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()
        let copied: Bool
        switch entry.content {
        case .files(let urls):
            copied = pasteboard.writeObjects(urls.map { $0 as NSURL })
        case .image(let data, let type):
            copied = pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type))
        case .pdf(let data):
            copied = pasteboard.setData(data, forType: .pdf)
        case .text(let text, let type):
            copied = pasteboard.setString(text, forType: .string)
            if type == NSPasteboard.PasteboardType.URL.rawValue {
                pasteboard.setString(text, forType: .URL)
            }
        }
        changeCount = pasteboard.changeCount
        return copied
    }

    func clear(pasteboard: NSPasteboard = .general) {
        changeCount = pasteboard.changeCount
        history.removeAll()
        entry = nil
        if let historyURL {
            Self.storageQueue.sync { try? FileManager.default.removeItem(at: historyURL) }
        }
        onChange?()
    }

    private func save() {
        guard let historyURL else { return }
        let payloads = history.map(\.content)
        Self.storageQueue.async {
            do {
                let directory = historyURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                        attributes: [.posixPermissions: 0o700])
                let data = try PropertyListEncoder().encode(payloads)
                try data.write(to: historyURL, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: historyURL.path)
            } catch {
                // History stays usable for this session if storage is unavailable.
            }
        }
    }

    static func read(from pasteboard: NSPasteboard) -> Payload? {
        let excluded = [
            "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
            "org.nspasteboard.AutoGeneratedType"
        ].map { NSPasteboard.PasteboardType($0) }
        guard pasteboard.availableType(from: excluded) == nil else { return nil }

        if let files = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !files.isEmpty {
            return .files(files)
        }

        for type in pasteboard.types ?? [] where UTType(type.rawValue)?.conforms(to: .image) == true {
            if let data = pasteboard.data(forType: type), CGImageSourceCreateWithData(data as CFData, nil) != nil {
                return .image(data, type: type.rawValue)
            }
        }
        if let data = pasteboard.data(forType: .pdf) { return .pdf(data) }

        for type in [NSPasteboard.PasteboardType.URL, .string] {
            if let text = pasteboard.string(forType: type), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .text(text, type: type.rawValue)
            }
        }
        return nil
    }
}
