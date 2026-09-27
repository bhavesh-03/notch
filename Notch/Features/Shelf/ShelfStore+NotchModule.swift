import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

extension ShelfStore: NotchModule {
    var earPriority: Int? { nil }

    /// Lives in its own tab rather than a Home column.
    var hasExpandedSection: Bool { false }

    var tab: NotchTab? { NotchTab(title: "Files", symbol: "tray.full.fill") }

    var acceptsFileDrops: Bool { true }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        switch placement {
        case .page:
            ShelfSection(shelf: self)
        case .expanded, .leadingEar, .trailingEar, .pill, .activityLeading, .activityTrailing, .activityDetail, .headline:
            EmptyView()
        }
    }
}

private struct ShelfSection: View {
    let shelf: ShelfStore
    @State private var isTargeted = false

    /// A file is hovering over a shelf that has no room left.
    private var rejectsDrop: Bool { isTargeted && shelf.isFull }

    private var borderColor: Color {
        if rejectsDrop { return .red }
        return .white.opacity(isTargeted ? 0.9 : 0.25)
    }

    /// Up to six items per row; rows are centered, so a single file sits in the middle.
    private var rows: [[ShelfStore.Item]] {
        stride(from: 0, to: shelf.items.count, by: 6).map {
            Array(shelf.items[$0..<min($0 + 6, shelf.items.count)])
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: shelf.items.isEmpty ? [5, 4] : []))
                .foregroundStyle(borderColor)
                .background(isTargeted && !rejectsDrop ? .white.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 12))

            if shelf.items.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.title)
                    Text("Drop files here to keep them handy")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(rows, id: \.first?.id) { row in
                        HStack(spacing: 10) {
                            ForEach(row) { item in
                                FileTile(item: item, shelf: shelf)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
                .opacity(rejectsDrop ? 0.3 : 1)
            }

            if rejectsDrop {
                Text("Shelf full")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.snappy, value: isTargeted)
        .animation(.snappy, value: shelf.items)
        .onDrop(of: [.fileURL, .data], isTargeted: $isTargeted) { providers in
            guard !shelf.isFull else { return false }
            Task { await shelf.add(providers) }
            return true
        }
    }
}

private struct FileTile: View {
    let item: ShelfStore.Item
    let shelf: ShelfStore

    var body: some View {
        VStack(spacing: 2) {
            FileThumbnail(url: item.url)
                .frame(width: 30, height: 30)
            Text(item.name)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(width: 60)
        .contentShape(Rectangle())
        .onDrag {
            ShelfStore.dragProvider(for: item)
        } preview: {
            FileThumbnail(url: item.url)
                .frame(width: 48, height: 48)
        }
        .contextMenu {
            Button("Open") {
                NSWorkspace.shared.open(item.url)
            }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Divider()
            Button("Remove from Shelf") {
                shelf.remove(item)
            }
            Button("Clear Shelf") {
                shelf.removeAll()
            }
        }
        .transition(.scale.combined(with: .opacity))
    }
}

/// A Quick Look thumbnail (image, PDF, video frame…), falling back to the file's Finder icon.
private struct FileThumbnail: View {
    let url: URL
    @State private var thumbnail: NSImage?

    var body: some View {
        Image(nsImage: thumbnail ?? NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .task(id: url) {
                thumbnail = await Self.makeThumbnail(for: url)
            }
    }

    private static func makeThumbnail(for url: URL) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 56, height: 56),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
    }
}
