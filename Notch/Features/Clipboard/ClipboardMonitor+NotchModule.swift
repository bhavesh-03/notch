import SwiftUI

extension ClipboardMonitor: NotchModule {
    var feature: NotchFeature { .clipboard }
    var earPriority: Int? { nil }

    var tab: NotchTab? {
        NotchTab(title: "Clipboard", symbol: "clipboard", style: .button)
    }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        switch placement {
        case .page:
            if let entry {
                ClipboardPreview(entry: entry, compact: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 7) {
                    Image(systemName: "clipboard")
                        .font(.title3)
                    Text("Copy text, an image, or files to see a preview here.")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .activityDetail:
            if let entry {
                ClipboardPreview(entry: entry, compact: true)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 7)
            }
        default:
            EmptyView()
        }
    }
}

struct ClipboardPreview: View {
    let entry: ClipboardMonitor.Entry
    let compact: Bool

    private var iconSize: CGFloat { compact ? 32 : 58 }

    var body: some View {
        HStack(spacing: 10) {
            thumbnail
                .frame(width: iconSize, height: iconSize)
                .background(.white.opacity(0.10), in: .rect(cornerRadius: 8))
                .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(compact ? 1 : 3)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassSurface(in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch entry.content {
        case .image(let image):
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("Copied image")
        case .files(let urls):
            if urls.count == 1, let file = urls.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: file.path))
                    .resizable()
                    .scaledToFit()
                    .padding(3)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "doc.on.doc")
                    .accessibilityHidden(true)
            }
        case .text:
            Image(systemName: "text.alignleft")
                .accessibilityHidden(true)
        }
    }

    private var title: String {
        switch entry.content {
        case .image: "Image copied"
        case .files(let files): files.count == 1 ? "File copied" : "\(files.count) files copied"
        case .text: "Text copied"
        }
    }

    private var detail: String? {
        switch entry.content {
        case .image: nil
        case .files(let files): files.map(\.lastPathComponent).joined(separator: ", ")
        case .text(let text): text
        }
    }
}
