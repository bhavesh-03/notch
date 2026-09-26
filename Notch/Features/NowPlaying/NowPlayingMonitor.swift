import Foundation

/// Publishes what's playing anywhere on the Mac (browsers, web apps, Music, Spotify…) and sends media commands.
@Observable
final class NowPlayingMonitor {
    private(set) var info: NowPlayingInfo?

    @ObservationIgnored var onTrackChanged: ((NowPlayingInfo) -> Void)?

    @ObservationIgnored private let bridge = NowPlayingBridgeProcess()
    @ObservationIgnored private var restartTask: Task<Void, Never>?
    @ObservationIgnored private var isStarted = false

    /// Started explicitly by the app (not in init) so tests and previews don't spawn processes.
    func start(libraryURL: URL? = NowPlayingBridgeProcess.defaultLibraryURL) {
        guard !isStarted, let libraryURL else { return }
        isStarted = true

        bridge.onUpdate = { [weak self] info in
            guard let self else { return }
            let previous = self.info
            self.info = info
            if let info, info.isNewTrack(after: previous) {
                self.onTrackChanged?(info)
            }
        }
        bridge.onExit = { [weak self] in
            self?.scheduleRestart(libraryURL: libraryURL)
        }
        try? bridge.start(libraryURL: libraryURL)
    }

    func stop() {
        isStarted = false
        restartTask?.cancel()
        bridge.onExit = nil
        bridge.stop()
        info = nil
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
