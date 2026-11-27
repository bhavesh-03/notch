import SwiftUI

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
    @State private var copiedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Clipboard")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(clipboard.history.count) / \(ClipboardMonitor.capacity)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button {
                    clipboard.clear()
                    copiedID = nil
                } label: {
                    Label("Clear History", systemImage: "trash")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .glassControl(in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(clipboard.history.isEmpty)
            }
            if clipboard.history.isEmpty {
                ContentUnavailableView("Clipboard is empty", systemImage: "clipboard",
                                       description: Text("Copy text, an image, or a file to get started."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(clipboard.history) { entry in
                            HStack(spacing: 8) {
                                ClipboardEntryLabel(entry: entry, concise: false)
                                Button {
                                    if clipboard.copy(entry) { copiedID = entry.id }
                                } label: {
                                    Label(copiedID == entry.id ? "Copied" : "Copy",
                                          systemImage: copiedID == entry.id ? "checkmark" : "doc.on.doc")
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .glassControl(in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.07), in: .rect(cornerRadius: 9))
                        }
                    }
                }
            }
        }
        .task(id: copiedID) {
            guard copiedID != nil else { return }
            try? await Task.sleep(for: .seconds(1.3))
            if !Task.isCancelled { copiedID = nil }
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
