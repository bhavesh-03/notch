import AppKit

/// Publishes what's playing anywhere on the Mac (browsers, web apps, Music, Spotify…) and sends media commands.
@Observable
final class NowPlayingMonitor {
    private(set) var info: NowPlayingInfo?
    /// The app you're using right now; while it's the one playing, the notch doesn't repeat it.
    private(set) var frontmostAppBundleIdentifier: String?

    /// True while the playing app is the frontmost one.
    var isSourceInFront: Bool {
        info?.isFrom(app: frontmostAppBundleIdentifier) == true
    }

    @ObservationIgnored var onTrackChanged: ((NowPlayingInfo) -> Void)?

    @ObservationIgnored private let bridge = NowPlayingBridgeProcess()
    @ObservationIgnored private var restartTask: Task<Void, Never>?
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    /// Started explicitly by the app (not in init) so tests and previews don't spawn processes.
    func start(libraryURL: URL? = NowPlayingBridgeProcess.defaultLibraryURL) {
        guard !isStarted, let libraryURL else { return }
        isStarted = true

        bridge.onUpdate = { [weak self] info in
            self?.receive(info)
        }
        watchFrontmostApp()
        bridge.onExit = { [weak self] in
            self?.scheduleRestart(libraryURL: libraryURL)
        }
        try? bridge.start(libraryURL: libraryURL)
    }

    func stop() {
        isStarted = false
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        restartTask?.cancel()
        bridge.onExit = nil
        bridge.stop()
        info = nil
    }

    /// A report from the bridge. Announces a new track, unless you're already looking at its app.
    func receive(_ info: NowPlayingInfo?) {
        let previous = self.info
        self.info = info
        if let info, info.isNewTrack(after: previous), !isSourceInFront {
            onTrackChanged?(info)
        }
    }

    func frontmostAppChanged(to bundleIdentifier: String?) {
        frontmostAppBundleIdentifier = bundleIdentifier
    }

    /// Follows app switches through NSWorkspace's notification: event-driven, no polling.
    private func watchFrontmostApp() {
        frontmostAppChanged(to: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleIdentifier = app?.bundleIdentifier
            MainActor.assumeIsolated {
                self?.frontmostAppChanged(to: bundleIdentifier)
            }
        }
    }

    func send(_ command: NowPlayingBridgeProcess.Command) {
        bridge.send(command)
    }

    /// If the bridge dies (e.g. a macOS update breaks it), try again after a pause instead of spinning.
    private func scheduleRestart(libraryURL: URL) {
        guard isStarted else { return }
        info = nil
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self, self.isStarted else { return }
            try? self.bridge.start(libraryURL: libraryURL)
        }
    }
}
