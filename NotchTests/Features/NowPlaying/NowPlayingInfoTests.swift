import Foundation
import Testing
@testable import Notch

@MainActor
struct NowPlayingInfoTests {
    let line = #"{"elected":"com.apple.Safari.WebApp.X","players":[{"album":"Album","appBundleIdentifier":"com.apple.Safari.WebApp.X","appName":"YT Music","artist":"Artist","duration":200,"elapsedTime":30,"isPlaying":true,"playbackRate":1,"timestamp":1000,"title":"Song"},{"album":"","appBundleIdentifier":"com.spotify.client","appName":"Spotify","artist":"Other","duration":180,"elapsedTime":5,"isPlaying":false,"playbackRate":0,"timestamp":1000,"title":"Other Song"}]}"#

    private func info(isPlaying: Bool = true, rate: Double = 1, elapsed: Double = 30, duration: Double = 200) -> NowPlayingInfo {
        NowPlayingInfo(title: "Song", artist: "Artist", album: "", duration: duration, elapsedTime: elapsed,
                       playbackRate: rate, timestamp: Date(timeIntervalSince1970: 1000), isPlaying: isPlaying,
                       appName: "YT Music", appBundleIdentifier: "x")
    }

    @Test func decodesABridgeLine() throws {
        let snapshot = try NowPlayingSnapshot.decode(line: Data(line.utf8))
        #expect(snapshot.electedID == "com.apple.Safari.WebApp.X")
        #expect(snapshot.players.map(\.appName) == ["YT Music", "Spotify"])
        let first = try #require(snapshot.players.first)
        #expect(first.title == "Song")
        #expect(first.isPlaying)
        #expect(first.timestamp == Date(timeIntervalSince1970: 1000))
        #expect(first.id == "com.apple.Safari.WebApp.X")
    }

    @Test func nothingLoadedIsAnEmptySnapshot() throws {
        let snapshot = try NowPlayingSnapshot.decode(line: Data(#"{"players":[]}"#.utf8))
        #expect(snapshot == .empty)
    }

    @Test func garbageIsAnError() {
        #expect(throws: (any Error).self) { try NowPlayingSnapshot.decode(line: Data("not json".utf8)) }
        #expect(throws: (any Error).self) { try NowPlayingSnapshot.decode(line: Data(#"{"error":"MediaRemote unavailable"}"#.utf8)) }
    }

    @Test(arguments: [(NowPlayingBridgeProcess.Command.toggle, "playpause"), (.next, "next track"), (.previous, "previous track")])
    func scriptsForScriptableApps(command: NowPlayingBridgeProcess.Command, verb: String) {
        #expect(NowPlayingScripting.source(for: command, in: "com.apple.Music") == "tell application id \"com.apple.Music\" to \(verb)")
        #expect(NowPlayingScripting.source(for: command, in: "com.google.Chrome") == nil)
    }

    @Test(arguments: [("company.thebrowser.Browser", true), ("com.google.Chrome", true), ("com.apple.Safari", true),
                      ("com.apple.Safari.WebApp.X", false), ("com.spotify.client", false), ("com.apple.Music", false)])
    func browsersAreRecognized(bundleIdentifier: String, isBrowser: Bool) {
        let player = NowPlayingInfo(title: "Song", artist: "", album: "", duration: 0, elapsedTime: 0, playbackRate: 0,
                                    timestamp: .now, isPlaying: false, appName: "", appBundleIdentifier: bundleIdentifier)
        #expect(player.isFromBrowser == isBrowser)
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
