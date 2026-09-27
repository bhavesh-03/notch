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
        case .expanded:
            MirrorPage(camera: self)
        case .leadingEar, .trailingEar, .pill, .activityLeading, .activityTrailing, .activityDetail, .headline:
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

/// Hosts AVFoundation's preview layer, mirrored like a real mirror.
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

        override func layout() {
            super.layout()
            // The connection only exists once the session has an input, so mirror it here.
            if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
    }
}
