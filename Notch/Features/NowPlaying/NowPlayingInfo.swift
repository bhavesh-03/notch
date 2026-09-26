import Foundation

/// What's playing, as reported by the bridge. A plain value: decodable from one bridge line, fully testable.
struct NowPlayingInfo: Equatable, Decodable {
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

    /// Decodes one line from the bridge: an info when something is playing, nil when nothing is.
    static func decode(line: Data) throws -> NowPlayingInfo? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard try decoder.decode(Activity.self, from: line).active else { return nil }
        return try decoder.decode(NowPlayingInfo.self, from: line)
    }

    private struct Activity: Decodable {
        let active: Bool
    }
}
