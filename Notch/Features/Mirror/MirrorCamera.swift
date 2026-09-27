import AVFoundation

/// The built-in camera as a mirror: nothing is recorded or saved, frames only go to the preview.
/// The capture session runs only between `start()` and `stop()`, which the mirror's view calls
/// when it appears and disappears, so the camera is never left on.
@Observable
final class MirrorCamera {
    enum Access {
        case notDetermined
        case granted
        case denied
    }

    private(set) var access: Access
    private(set) var isRunning = false
    /// Set if access is granted but there's no usable camera (e.g. a Mac mini, or the lid is closed).
    private(set) var isUnavailable = false

    @ObservationIgnored private let capture = SerialCaptureSession()

    var session: AVCaptureSession { capture.session }

    init() {
        access = Self.access(for: AVCaptureDevice.authorizationStatus(for: .video))
    }

    static func access(for status: AVAuthorizationStatus) -> Access {
        switch status {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func start() async {
        if access == .notDetermined {
            access = await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
        }
        guard access == .granted, !isRunning else { return }
        isRunning = true
        let started = await withCheckedContinuation { continuation in
            capture.start { continuation.resume(returning: $0) }
        }
        isUnavailable = !started
        if !started { isRunning = false }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        capture.stop()
    }
}
