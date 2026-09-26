import Foundation
import Testing
@testable import Notch

@MainActor
struct NowPlayingInfoTests {
    let line = #"{"active":true,"album":"Album","appBundleIdentifier":"com.apple.Safari.WebApp.X","appName":"YT Music","artist":"Artist","duration":200,"elapsedTime":30,"isPlaying":true,"playbackRate":1,"timestamp":1000,"title":"Song"}"#

    private func info(isPlaying: Bool = true, rate: Double = 1, elapsed: Double = 30, duration: Double = 200) -> NowPlayingInfo {
        NowPlayingInfo(title: "Song", artist: "Artist", album: "", duration: duration, elapsedTime: elapsed,
                       playbackRate: rate, timestamp: Date(timeIntervalSince1970: 1000), isPlaying: isPlaying,
                       appName: "YT Music", appBundleIdentifier: "x")
    }

    @Test func decodesABridgeLine() throws {
        let decoded = try #require(try NowPlayingInfo.decode(line: Data(line.utf8)))
        #expect(decoded.title == "Song")
        #expect(decoded.appName == "YT Music")
        #expect(decoded.isPlaying)
        #expect(decoded.timestamp == Date(timeIntervalSince1970: 1000))
    }

    @Test func inactiveMeansNothingPlaying() throws {
        #expect(try NowPlayingInfo.decode(line: Data(#"{"active":false}"#.utf8)) == nil)
    }

    @Test func garbageIsAnError() {
        #expect(throws: (any Error).self) { try NowPlayingInfo.decode(line: Data("not json".utf8)) }
    }

    @Test func positionAdvancesWhilePlaying() {
        #expect(info().elapsed(at: Date(timeIntervalSince1970: 1010)) == 40)
    }

    @Test func positionIsFrozenWhilePaused() {
        #expect(info(isPlaying: false).elapsed(at: Date(timeIntervalSince1970: 1100)) == 30)
    }

    @Test func positionRespectsPlaybackRate() {
        #expect(info(rate: 2).elapsed(at: Date(timeIntervalSince1970: 1010)) == 50)
    }

    @Test func positionStopsAtTheEnd() {
        #expect(info(elapsed: 190).elapsed(at: Date(timeIntervalSince1970: 1100)) == 200)
    }

    @Test func liveStreamsWithoutADurationKeepCounting() {
        #expect(info(elapsed: 500, duration: 0).elapsed(at: Date(timeIntervalSince1970: 1010)) == 510)
    }
}

@MainActor
struct TrackChangeTests {
    private func track(_ title: String, by artist: String = "Artist", playing: Bool = true) -> NowPlayingInfo {
        NowPlayingInfo(title: title, artist: artist, album: "", duration: 200, elapsedTime: 0, playbackRate: playing ? 1 : 0,
                       timestamp: .now, isPlaying: playing, appName: "YT Music", appBundleIdentifier: "x")
    }

    @Test func aDifferentSongIsANewTrack() {
        #expect(track("B").isNewTrack(after: track("A")))
        #expect(track("A", by: "Other").isNewTrack(after: track("A")))
    }

    @Test func pauseAndResumeAreNotNewTracks() {
        #expect(!track("A", playing: false).isNewTrack(after: track("A")))
        #expect(!track("A").isNewTrack(after: track("A", playing: false)))
    }

    @Test func theFirstReportIsNotANewTrack() {
        #expect(!track("A").isNewTrack(after: nil), "e.g. at launch, or after the bridge restarts")
    }

    @Test func aTrackThatChangedWhilePausedIsNotAnnounced() {
        #expect(!track("B", playing: false).isNewTrack(after: track("A")))
    }
}

/// Runs the real bridge inside the sandboxed app, end to end.
@MainActor
struct NowPlayingBridgeProcessTests {
    @Test func bridgeStartsReportsAndStops() async throws {
        let library = try #require(NowPlayingBridgeProcess.defaultLibraryURL)
        let bridge = NowPlayingBridgeProcess()
        var reports = 0
        bridge.onUpdate = { _ in reports += 1 }
        try bridge.start(libraryURL: library)

        for _ in 0..<50 where reports == 0 {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(reports >= 1, "the bridge should report the current state (playing or not) within 5 s")
        #expect(bridge.isRunning)

        bridge.stop()
        #expect(!bridge.isRunning)
    }
}
