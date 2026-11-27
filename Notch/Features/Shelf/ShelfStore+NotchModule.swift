import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

extension ShelfStore: NotchModule {
    var feature: NotchFeature { .files }

    var earPriority: Int? { nil }


    var tab: NotchTab? { NotchTab(title: "Files", symbol: "tray.full.fill") }

    var acceptsFileDrops: Bool { true }
    var wantsTallPage: Bool { true }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        switch placement {
        case .page:
            ShelfSection(shelf: self)
        case .leadingEar, .trailingEar, .pill, .activityLeading, .activityTrailing, .activityDetail, .headline:
            EmptyView()
        }
    }
}

private struct ShelfSection: View {
    let shelf: ShelfStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isTargeted = false
    @State private var selection: Set<ShelfStore.Item.ID> = []
    @State private var feedback: Feedback?
    @State private var renameItem: ShelfStore.Item?
    @State private var proposedName = ""

    private struct Feedback: Identifiable {
        let id = UUID()
        let text: String
        let symbol: String
    }

    private var rejectsDrop: Bool { isTargeted && shelf.isFull }
    private var selectedItems: [ShelfStore.Item] { shelf.items.filter { selection.contains($0.id) } }
    private var copyItems: [ShelfStore.Item] { selectedItems.isEmpty ? shelf.items : selectedItems }
    private var motion: Animation { reduceMotion ? .easeInOut(duration: 0.12) : .smooth(duration: 0.22) }

    var body: some View {
        VStack(spacing: 3) {
            header
            if shelf.items.isEmpty {
                emptyShelf
            } else {
                fileList
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted && !rejectsDrop ? .white.opacity(0.10) : .clear, in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(rejectsDrop ? .red.opacity(0.8) : .white.opacity(isTargeted ? 0.65 : 0.2),
                              style: StrokeStyle(lineWidth: 1, dash: shelf.items.isEmpty ? [5, 4] : []))
                .allowsHitTesting(false)
        }
        .clipShape(.rect(cornerRadius: 12))
        .contentShape(.rect(cornerRadius: 12))
        .contextMenu {
            Button("Select All") { selection = Set(shelf.items.map(\.id)) }
                .disabled(shelf.items.isEmpty)
            Button("Copy Files") { copy(copyItems) }
                .disabled(shelf.items.isEmpty)
            Button("Clear Shelf", role: .destructive) { shelf.removeAll() }
                .disabled(shelf.items.isEmpty)
        }
        .animation(motion, value: isTargeted)
        .animation(motion, value: shelf.items)
        .animation(motion, value: feedback?.id)
        .onChange(of: shelf.items) {
            selection.formIntersection(shelf.items.map(\.id))
        }
        .task(id: feedback?.id) {
            guard feedback != nil else { return }
            try? await Task.sleep(for: .seconds(1.6))
            if !Task.isCancelled { feedback = nil }
        }
        .alert("Rename File", isPresented: Binding(get: { renameItem != nil }, set: { if !$0 { renameItem = nil } }),
               presenting: renameItem) { item in
            TextField("Filename", text: $proposedName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if !shelf.renameOwnedCopy(item, to: proposedName) {
                    feedback = Feedback(text: "Couldn’t rename file", symbol: "exclamationmark.circle")
                }
            }
        }
        .onDrop(of: [UTType.fileURL.identifier, UTType.data.identifier] + NSFilePromiseReceiver.readableDraggedTypes,
                isTargeted: $isTargeted) { providers in
            guard !shelf.isFull else { return false }
            let pasteboard = NSPasteboard(name: .drag)
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
            let promises = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self]) as? [NSFilePromiseReceiver] ?? []
            let previousCount = shelf.items.count
            shelf.add(urls)
            let added = shelf.items.count - previousCount
            if added > 0 { showAdded(added) }
            if !promises.isEmpty {
                shelf.receivePromises(promises) { showAdded(shelf.items.count - previousCount) }
            }
            if !urls.isEmpty || !promises.isEmpty { return true }
            Task {
                let added = await shelf.add(providers)
                if added == 0 {
                    feedback = Feedback(text: "No new items", symbol: "tray")
                } else if shelf.isFull && added < providers.count {
                    feedback = Feedback(text: "Shelf full · \(added) added", symbol: "tray.full.fill")
                } else {
                    showAdded(added)
                }
            }
            return true
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            if rejectsDrop {
                Label("Shelf full", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.red)
            } else if isTargeted && !shelf.items.isEmpty {
                Label("Release to add", systemImage: "folder.fill.badge.plus")
                    .transition(reduceMotion ? .opacity : .offset(y: -3).combined(with: .opacity))
            } else if let feedback {
                Label(feedback.text, systemImage: feedback.symbol)
                    .id(feedback.id)
                    .transition(.opacity)
            } else {
                Text("Files").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(selectedItems.isEmpty
                     ? "\(shelf.items.count) / \(ShelfStore.capacity)"
                     : "\(selectedItems.count) selected")
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            if !shelf.items.isEmpty {
                shelfButton(selectedItems.isEmpty ? "Copy All" : "Copy \(selectedItems.count)", symbol: "doc.on.doc") {
                    copy(copyItems)
                }
                shelfButton("Clear", symbol: "trash") { shelf.removeAll() }
            }
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.white.opacity(0.74))
        .frame(height: 25)
    }

    private var emptyShelf: some View {
        VStack(spacing: 5) {
            Image(systemName: isTargeted ? "folder.fill.badge.plus" : "tray.and.arrow.down")
                .font(.system(size: 22, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
                .offset(y: isTargeted && !reduceMotion ? 3 : 0)
            Text(isTargeted ? "Release to add" : "Drop files or folders here")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 12)
    }

    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(shelf.items) { item in
                    FileRow(
                        item: item,
                        isSelected: selection.contains(item.id),
                        toggleSelection: { toggleSelection(item.id) },
                        dragItems: { selection.contains(item.id) ? selectedItems : [item] },
                        copy: { copy([item]) },
                        rename: {
                            proposedName = item.name
                            renameItem = item
                        },
                        remove: { shelf.remove(item) }
                    )
                    .transition(reduceMotion ? .opacity : .offset(y: -6).combined(with: .opacity))
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func showAdded(_ count: Int) {
        guard count > 0 else { return }
        feedback = Feedback(text: count == 1 ? "1 item added" : "\(count) items added", symbol: "checkmark.circle.fill")
    }

    private func shelfButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .glassControl(in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func toggleSelection(_ id: ShelfStore.Item.ID) {
        if selection.remove(id) == nil { selection.insert(id) }
    }

    private func copy(_ items: [ShelfStore.Item]) {
        if ShelfFileTransfer.copy(items) {
            feedback = Feedback(text: items.count == 1 ? "1 item copied" : "\(items.count) items copied", symbol: "checkmark.circle.fill")
        } else {
            feedback = Feedback(text: "Couldn’t copy files", symbol: "exclamationmark.circle")
        }
    }
}

private struct FileRow: View {
    let item: ShelfStore.Item
    let isSelected: Bool
    let toggleSelection: () -> Void
    let dragItems: () -> [ShelfStore.Item]
    let copy: () -> Void
    let rename: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.35))
                FileThumbnail(url: item.url)
                    .frame(width: 27, height: 27)
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.leading, 8)
            .frame(height: 36)
            .overlay { ShelfDragSource(items: dragItems, onClick: toggleSelection) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(item.name)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { toggleSelection() }
            .help(item.name)
            Button(action: copy) {
                Label("Copy", systemImage: "doc.on.doc")
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .glassControl(in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy \(item.name)")
            .help("Copy File")
            Menu {
                Button("Copy File", action: copy)
                if item.isOwnedCopy { Button("Rename…", action: rename) }
                Button("Open") { NSWorkspace.shared.open(item.url) }
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                Divider()
                Button("Remove from Shelf", role: .destructive, action: remove)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Actions for \(item.name)")
            .padding(.trailing, 4)
        }
        .font(.system(size: 11, weight: .medium))
        .background(.white.opacity(isSelected ? 0.16 : 0.07), in: .rect(cornerRadius: 8))
    }
}

/// A Quick Look thumbnail (image, PDF, video frame…), falling back to the file's Finder icon.
struct FileThumbnail: View {
    let url: URL
    var previewSize: CGFloat = 56
    @State private var thumbnail: NSImage?

    var body: some View {
        Image(nsImage: thumbnail ?? NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .task(id: url) {
                thumbnail = await makeThumbnail()
            }
    }

    private func makeThumbnail() async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: previewSize, height: previewSize),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        return try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
    }
}
