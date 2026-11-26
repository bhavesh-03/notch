import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

extension ShelfStore: NotchModule {
    var feature: NotchFeature { .files }

    var earPriority: Int? { nil }


    var tab: NotchTab? { NotchTab(title: "Files", symbol: "tray.full.fill") }

    var acceptsFileDrops: Bool { true }

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
                fileGrid
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
        .onDrop(of: [.fileURL, .data], isTargeted: $isTargeted) { providers in
            guard !shelf.isFull else { return false }
            Task {
                let added = await shelf.add(providers)
                if added == 0 {
                    feedback = Feedback(text: "No new items", symbol: "tray")
                } else if shelf.isFull && added < providers.count {
                    feedback = Feedback(text: "Shelf full · \(added) added", symbol: "tray.full.fill")
                } else {
                    feedback = Feedback(text: added == 1 ? "1 item added" : "\(added) items added", symbol: "checkmark.circle.fill")
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
            } else if !shelf.items.isEmpty {
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
        .frame(height: 19)
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

    private var fileGrid: some View {
        // Six flexible columns fit even at the narrowest notch width.
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 2) {
            ForEach(shelf.items) { item in
                FileTile(
                    item: item,
                    isSelected: selection.contains(item.id),
                    toggleSelection: { toggleSelection(item.id) },
                    dragItems: { selection.contains(item.id) ? selectedItems : [item] },
                    copy: { copy([item]) },
                    remove: { shelf.remove(item) }
                )
                .transition(reduceMotion ? .opacity : .offset(y: -8).combined(with: .opacity))
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
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

private struct FileTile: View {
    let item: ShelfStore.Item
    let isSelected: Bool
    let toggleSelection: () -> Void
    let dragItems: () -> [ShelfStore.Item]
    let copy: () -> Void
    let remove: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 1) {
            FileThumbnail(url: item.url)
                .frame(width: 21, height: 21)
            Text(item.name)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(isSelected ? .white.opacity(0.16) : .clear, in: .rect(cornerRadius: 7))
        .overlay { ShelfDragSource(items: dragItems, onClick: toggleSelection) }
        .contentShape(.rect(cornerRadius: 7))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { toggleSelection() }
        .accessibilityAction(named: Text("Remove from Shelf"), remove)
        .overlay(alignment: .topTrailing) {
            if isHovered {
                Button(action: remove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .frame(width: 14, height: 14)
                        .glassControl(in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(item.name)")
            }
        }
        .onHover { isHovered = $0 }
        .help(item.name)
        .contextMenu {
            Button(isSelected ? "Deselect" : "Select", action: toggleSelection)
            Button("Copy", action: copy)
            Divider()
            Button("Open") { NSWorkspace.shared.open(item.url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Divider()
            Button("Remove from Shelf", action: remove)
        }
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
