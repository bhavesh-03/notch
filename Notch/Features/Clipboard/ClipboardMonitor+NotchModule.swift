import SwiftUI

enum ClipboardGalleryLayout {
    static let headerHeight: CGFloat = 24
    static let headerSpacing: CGFloat = 7
    static let cardWidth: CGFloat = 150
    static let cardSpacing: CGFloat = 9
    static let galleryHeight: CGFloat = 145

    static func capturesSwipe(at point: CGPoint, in geometry: NotchGeometry, itemCount: Int) -> Bool {
        let width = geometry.expandedWidth - 2 * NotchGeometry.tabPageHorizontalInset
        let cardsWidth = CGFloat(itemCount) * cardWidth + CGFloat(max(0, itemCount - 1)) * cardSpacing
        guard cardsWidth > width else { return false }
        let top = geometry.notchRect.minY - NotchGeometry.tabPageTopInset - headerHeight - headerSpacing
        let gallery = CGRect(x: geometry.notchRect.midX - width / 2, y: top - galleryHeight,
                             width: width, height: galleryHeight)
        return gallery.contains(point)
    }
}

extension ClipboardMonitor: NotchModule {
    var feature: NotchFeature { .clipboard }
    var earPriority: Int? { nil }
    var wantsTallPage: Bool { true }

    var tab: NotchTab? {
        NotchTab(title: "Clipboard", symbol: "clipboard", style: .button)
    }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        switch placement {
        case .page:
            ClipboardHistoryPage(clipboard: self)
        case .activityDetail:
            if let entry {
                ClipboardPreview(entry: entry)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 7)
            }
        default:
            EmptyView()
        }
    }
}

private struct ClipboardHistoryPage: View {
    let clipboard: ClipboardMonitor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copiedID: UUID?
    @State private var scrollID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: ClipboardGalleryLayout.headerSpacing) {
            header
            if clipboard.history.isEmpty {
                ContentUnavailableView("Clipboard is empty", systemImage: "clipboard",
                                       description: Text("Copy text, an image, or a file to get started."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: ClipboardGalleryLayout.cardSpacing) {
                        ForEach(clipboard.history) { entry in
                            Button {
                                if clipboard.copy(entry) { copiedID = entry.id }
                            } label: {
                                ClipboardHistoryCard(entry: entry, isCopied: copiedID == entry.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Copies this item again")
                            .id(entry.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.bottom, 3)
                }
                .scrollPosition(id: $scrollID)
                .scrollTargetBehavior(.viewAligned)
                .frame(height: ClipboardGalleryLayout.galleryHeight)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .task(id: copiedID) {
            guard copiedID != nil else { return }
            try? await Task.sleep(for: .seconds(1.3))
            if !Task.isCancelled { copiedID = nil }
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Text("Clipboard")
                .font(.system(size: 13, weight: .semibold))
            Text("\(clipboard.history.count) / \(ClipboardMonitor.capacity)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
            Spacer(minLength: 5)
            if clipboard.history.count > 1 {
                arrow("Previous card", symbol: "chevron.left", step: -1)
                arrow("Next card", symbol: "chevron.right", step: 1)
            }
            Button {
                clipboard.clear()
                copiedID = nil
                scrollID = nil
            } label: {
                Label("Clear History", systemImage: "trash")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .glassControl(in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(clipboard.history.isEmpty)
        }
        .frame(height: ClipboardGalleryLayout.headerHeight)
    }

    private var scrollIndex: Int {
        clipboard.history.firstIndex { $0.id == scrollID } ?? 0
    }

    private func arrow(_ label: String, symbol: String, step: Int) -> some View {
        let destination = scrollIndex + step
        return Button {
            guard clipboard.history.indices.contains(destination) else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                scrollID = clipboard.history[destination].id
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 22, height: 22)
                .glassControl(in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
        .disabled(!clipboard.history.indices.contains(destination))
    }
}

private struct ClipboardHistoryCard: View {
    let entry: ClipboardMonitor.Entry
    let isCopied: Bool

    @State private var isHovered = false
    private let shape = RoundedRectangle(cornerRadius: 11)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .foregroundStyle(.tint)
                Text(kind)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(isCopied ? .white : .white.opacity(isHovered ? 0.9 : 0.42))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .font(.caption2)
            .padding(.horizontal, 8)
            .frame(height: 22)

            preview
                .frame(maxWidth: .infinity)
                .frame(height: 86)
                .clipped()

            HStack(spacing: 4) {
                if let icon = entry.source?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 11, height: 11)
                        .accessibilityHidden(true)
                }
                Text(entry.source?.name ?? "Unknown source")
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 2)
                if let date = entry.copiedAt {
                    Text(date, style: .relative)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityLabel(date.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.68))
            .padding(.horizontal, 8)
            .frame(height: 25)
        }
        .frame(width: ClipboardGalleryLayout.cardWidth)
        .background(.white.opacity(isHovered ? 0.14 : 0.085), in: shape)
        .overlay { shape.strokeBorder(.white.opacity(isCopied ? 0.65 : isHovered ? 0.26 : 0.12)) }
        .clipShape(shape)
        .contentShape(shape)
        .onHover { isHovered = $0 }
        .help(entry.source?.isEstimated == true ? "Copy · Source estimated from the active app" : "Copy")
        .accessibilityElement(children: .combine)
        .accessibilityValue(isCopied ? "Copied" : "")
    }

    @ViewBuilder
    private var preview: some View {
        switch entry.content {
        case .image, .pdf:
            ZStack(alignment: .bottomTrailing) {
                Color.black.opacity(0.35)
                if let image = entry.thumbnail {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(.vertical, 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: symbol)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if let detail = entry.mediaDetail {
                    Text(detail)
                        .font(.system(size: 9, weight: .semibold).monospacedDigit())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.78), in: .rect(cornerRadius: 4))
                        .padding(4)
                }
            }
        case .files(let urls):
            if let url = urls.first {
                VStack(spacing: 4) {
                    FileThumbnail(url: url, previewSize: 156)
                        .frame(height: 52)
                    Text(urls.count == 1 ? url.lastPathComponent : "\(urls.count) files · \(url.lastPathComponent)")
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, 7)
            }
        case .text(let text, _):
            if let url = webURL {
                VStack(alignment: .leading, spacing: 4) {
                    Text(url.host ?? url.absoluteString)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(String(text.prefix(220)))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(3)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(8)
            } else {
                Text(String(text.prefix(280)))
                    .font(.caption)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            }
        }
    }

    private var webURL: URL? {
        guard case .text(let text, _) = entry.content,
              let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }

    private var kind: String {
        switch entry.content {
        case .image: "Image"
        case .pdf: "PDF"
        case .files(let urls): urls.count == 1 ? "File" : "Files"
        case .text: webURL == nil ? "Text" : "Link"
        }
    }

    private var symbol: String {
        switch entry.content {
        case .image: "photo"
        case .pdf: "doc.richtext"
        case .files: "doc.on.doc"
        case .text: webURL == nil ? "text.alignleft" : "link"
        }
    }
}

struct ClipboardPreview: View {
    let entry: ClipboardMonitor.Entry

    var body: some View {
        ClipboardEntryLabel(entry: entry, concise: true)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .glassSurface(in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ClipboardEntryLabel: View {
    let entry: ClipboardMonitor.Entry
    let concise: Bool

    var body: some View {
        HStack(spacing: 9) {
            thumbnail
                .frame(width: 30, height: 30)
                .background(.white.opacity(0.09), in: .rect(cornerRadius: 6))
                .clipShape(.rect(cornerRadius: 6))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(concise ? "\(kind) copied" : (summary ?? kind))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if concise, let summary {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = entry.thumbnail {
            Image(nsImage: image).resizable().scaledToFit()
        } else if case .files(let urls) = entry.content, urls.count == 1, let file = urls.first {
            Image(nsImage: NSWorkspace.shared.icon(forFile: file.path)).resizable().scaledToFit().padding(3)
        } else {
            Image(systemName: symbol)
        }
    }

    private var symbol: String {
        switch entry.content {
        case .image: "photo"
        case .pdf: "doc.richtext"
        case .files: "doc.on.doc"
        case .text: "text.alignleft"
        }
    }

    private var kind: String {
        switch entry.content {
        case .image: "Image"
        case .pdf: "PDF"
        case .files(let files): files.count == 1 ? "File" : "\(files.count) files"
        case .text: "Text"
        }
    }

    private var summary: String? {
        switch entry.content {
        case .image, .pdf: nil
        case .files(let files): files.map(\.lastPathComponent).joined(separator: ", ")
        case .text(let text, _): String(text.prefix(160))
        }
    }
}
