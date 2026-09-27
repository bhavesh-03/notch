import AVFoundation
import SwiftUI

extension MirrorCamera: NotchModule {
    var earPriority: Int? { nil }

    var hasExpandedSection: Bool { false }

    var tab: NotchTab? { NotchTab(title: "Mirror", symbol: "web.camera", style: .button) }

    var wantsTallPage: Bool { true }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        switch placement {
        case .page:
            MirrorPage(camera: self)
        case .expanded, .leadingEar, .trailingEar, .pill, .activityLeading, .activityTrailing, .activityDetail, .headline:
            EmptyView()
        }
    }
}

private struct MirrorPage: View {
    let camera: MirrorCamera

    var body: some View {
        Group {
            if camera.access == .denied {
                VStack(spacing: 6) {
                    Image(systemName: "video.slash")
                        .font(.title)
                    Text("Camera access is off")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                    Button("Open Settings") {
                        NSWorkspace.shared.open(Self.privacySettingsURL)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.blue)
                }
            } else if camera.isUnavailable {
                VStack(spacing: 6) {
                    Image(systemName: "web.camera")
                        .font(.title)
                    Text("No camera available")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else {
                CameraPreview(session: camera.session)
                    // A horizontal flip, like a real mirror: your right hand appears on the right.
                    // Done on the view rather than the capture connection, which only exists once the
                    // session is configured (asynchronously), so setting it there could be missed.
                    .scaleEffect(x: -1, y: 1)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        // The camera runs exactly while this page is on screen.
        .task { await camera.start() }
        .onDisappear { camera.stop() }
    }

    private static let privacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
    )!
}

/// Hosts AVFoundation's preview layer. The mirroring is done by the SwiftUI view that uses it.
private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ view: PreviewView, context: Context) {}

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            previewLayer.videoGravity = .resizeAspectFill
            layer = previewLayer
            wantsLayer = true
        }

        required init?(coder: NSCoder) { nil }

    }
}
