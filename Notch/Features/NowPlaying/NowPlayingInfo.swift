import Foundation

/// What's playing, as reported by the bridge. A plain value: decodable from one bridge line, fully testable.
struct NowPlayingInfo: Equatable, Decodable, Identifiable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let playbackRate: Double
    /// When `elapsedTime` was measured; the position moves on from here while playing.
    let timestamp: Date
    let isPlaying: Bool
    let appName: String
    let appBundleIdentifier: String

    /// One player per app, so the app is the identity.
    var id: String { appBundleIdentifier }

    /// Whether a web browser is playing. macOS reports the browser, not the site, and doesn't share
    /// the site's artwork, so the browser's icon would say nothing about the music.
    var isFromBrowser: Bool { Self.browsers.contains(appBundleIdentifier) }

    static let browsers: Set<String> = [
        "company.thebrowser.Browser",        // Arc
        "com.google.Chrome",
        "com.apple.Safari",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "org.mozilla.firefox",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "com.kagi.kagimacOS",                // Orion
    ]

    /// The playback position right now, extrapolated from the last report.
    func elapsed(at now: Date) -> TimeInterval {
        let moved = isPlaying ? playbackRate * now.timeIntervalSince(timestamp) : 0
        let position = max(0, elapsedTime + moved)
        return duration > 0 ? min(position, duration) : position
    }

    /// True when this is a different track from `previous` and it's playing. Never on the first
    /// report (e.g. at launch), and never for pause/resume of the same track.
    func isNewTrack(after previous: NowPlayingInfo?) -> Bool {
        guard let previous, isPlaying else { return false }
        return title != previous.title || artist != previous.artist
    }

    /// Whether the app with `bundleIdentifier` is the one playing. Used to step aside while you're
    /// looking at the player itself. macOS reports the app, not the window or tab.
    func isFrom(app bundleIdentifier: String?) -> Bool {
        bundleIdentifier == appBundleIdentifier
    }
}

/// Everything playing (or paused with something loaded) on the Mac, from one bridge line.
struct NowPlayingSnapshot: Equatable, Decodable {
    /// Every app with a track loaded, in a stable order.
    let players: [NowPlayingInfo]
    /// The app macOS picked as "now playing": media keys and system commands go to it.
    let electedID: String?

    init(players: [NowPlayingInfo], electedID: String?) {
        self.players = players
        self.electedID = electedID
    }

    static let empty = NowPlayingSnapshot(players: [], electedID: nil)

    static func decode(line: Data) throws -> NowPlayingSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(NowPlayingSnapshot.self, from: line)
    }

    private enum CodingKeys: String, CodingKey {
        case players
        case electedID = "elected"
    }
}
