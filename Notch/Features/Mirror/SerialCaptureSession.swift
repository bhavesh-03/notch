import AVFoundation

/// Owns an AVCaptureSession and touches it only from one serial queue.
///
/// AVCaptureSession isn't marked Sendable, but it's safe to use from a background queue as long as
/// every configuration and start/stop call is serialized — the pattern Apple's camera samples use,
/// because startRunning() blocks while the camera powers up. This type is the only place that
/// touches the session, and it always does so on `queue`; that's the promise `@unchecked Sendable` makes.
/// (The preview layer only *reads* the session to display it, which AVFoundation supports from the main thread.)
final class SerialCaptureSession: @unchecked Sendable {
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "notch.mirror.session")
    private var isConfigured = false

    /// Configures the built-in camera on first use, then starts; reports whether it's running.
    func start(completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            guard configureIfNeeded() else { return completion(false) }
            session.startRunning()
            completion(session.isRunning)
        }
    }

    func stop() {
        queue.async { [self] in
            session.stopRunning()
        }
    }

    private func configureIfNeeded() -> Bool {
        if isConfigured { return true }
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return false }
        session.beginConfiguration()
        session.sessionPreset = .high
        session.addInput(input)
        session.commitConfiguration()
        isConfigured = true
        return true
    }
}
