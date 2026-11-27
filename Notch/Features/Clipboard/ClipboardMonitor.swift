import AppKit
import ImageIO
import PDFKit
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

    struct Source: Codable, Equatable, Sendable {
        let name: String
        let bundleID: String?
        let isEstimated: Bool

        var icon: NSImage? {
            guard let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                return nil
            }
            return NSWorkspace.shared.icon(forFile: url.path)
        }
    }

    private struct Record: Codable, Sendable {
        let content: Payload
        let copiedAt: Date?
        let source: Source?
    }

    struct Entry: Identifiable {
        let id: UUID
        let content: Payload
        let copiedAt: Date?
        let source: Source?
        let thumbnail: NSImage?
        let mediaDetail: String?

        init(content: Payload, copiedAt: Date? = nil, source: Source? = nil, replacing previous: Entry? = nil) {
            id = previous?.id ?? UUID()
            self.content = content
            self.copiedAt = copiedAt
            self.source = source

            if let previous {
                thumbnail = previous.thumbnail
                mediaDetail = previous.mediaDetail
            } else if case .image(let data, _) = content,
                      let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                      let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
                          kCGImageSourceCreateThumbnailFromImageAlways: true,
                          kCGImageSourceCreateThumbnailWithTransform: true,
                          kCGImageSourceThumbnailMaxPixelSize: 420
                      ] as CFDictionary) {
                thumbnail = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
                if let width = properties?[kCGImagePropertyPixelWidth] as? Int,
                   let height = properties?[kCGImagePropertyPixelHeight] as? Int {
                    let orientation = properties?[kCGImagePropertyOrientation] as? Int ?? 1
                    mediaDetail = (5...8).contains(orientation) ? "\(height) × \(width)" : "\(width) × \(height)"
                } else {
                    mediaDetail = nil
                }
            } else if case .pdf(let data) = content, let document = PDFDocument(data: data) {
                thumbnail = document.page(at: 0)?.thumbnail(of: NSSize(width: 240, height: 260), for: .cropBox)
                mediaDetail = document.pageCount == 1 ? "1 page" : "\(document.pageCount) pages"
            } else {
                thumbnail = nil
                mediaDetail = nil
            }
        }
    }

    static let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")
    private static let remoteType = NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")

    static func source(from pasteboard: NSPasteboard, frontmost: NSRunningApplication?) -> Source? {
        if pasteboard.availableType(from: [sourceType]) != nil {
            guard let identifier = pasteboard.string(forType: sourceType), !identifier.isEmpty else { return nil }
            let app = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
            let bundle = url.flatMap(Bundle.init(url:))
            let name = app?.localizedName
                ?? (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? url?.deletingPathExtension().lastPathComponent
                ?? identifier
            return Source(name: name, bundleID: identifier, isEstimated: false)
        }
        if pasteboard.availableType(from: [remoteType]) != nil {
            return Source(name: "Universal Clipboard", bundleID: nil, isEstimated: false)
        }
        guard let name = frontmost?.localizedName else { return nil }
        return Source(name: name, bundleID: frontmost?.bundleIdentifier, isEstimated: true)
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
            if let data {
                let decoder = PropertyListDecoder()
                if let records = try? decoder.decode([Record].self, from: data) {
                    history = records.prefix(Self.capacity).map {
                        Entry(content: $0.content, copiedAt: $0.copiedAt, source: $0.source)
                    }
                } else if let payloads = try? decoder.decode([Payload].self, from: data) {
                    history = payloads.prefix(Self.capacity).map { Entry(content: $0) }
                }
            }
        }
        changeCount = pasteboard.changeCount
        watchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled, let self else { break }
                recordChange(from: pasteboard, frontmost: NSWorkspace.shared.frontmostApplication)
            }
        }
    }

    func stop() {
        guard watchTask != nil else { return }
        watchTask?.cancel()
        watchTask = nil
        clear()
    }

    func recordChange(from pasteboard: NSPasteboard, frontmost: NSRunningApplication? = nil) {
        let count = pasteboard.changeCount
        guard count != changeCount else { return }
        changeCount = count

        if let payload = Self.read(from: pasteboard) {
            let previous = history.first { $0.content == payload }
            let latest = Entry(content: payload, copiedAt: .now, source: Self.source(from: pasteboard, frontmost: frontmost),
                               replacing: previous)
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
        // File URLs occupy separate pasteboard items. Preserve the batch as written.
        if copied, case .files = entry.content {
            changeCount = pasteboard.changeCount
            return true
        }
        if copied {
            let bundleID = entry.source?.isEstimated == false ? entry.source?.bundleID : nil
            pasteboard.setString(bundleID ?? "", forType: Self.sourceType)
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
        let records = history.map { Record(content: $0.content, copiedAt: $0.copiedAt, source: $0.source) }
        Self.storageQueue.async {
            do {
                let directory = historyURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                        attributes: [.posixPermissions: 0o700])
                let data = try PropertyListEncoder().encode(records)
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
