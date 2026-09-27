import Foundation
import Testing
@testable import Notch

@MainActor
struct NowPlayingMonitorTests {
    private func info(_ title: String = "Song", app: String = "com.music", isPlaying: Bool = true) -> NowPlayingInfo {
        NowPlayingInfo(title: title, artist: "Artist", album: "", duration: 200, elapsedTime: 0,
                       playbackRate: 1, timestamp: .now, isPlaying: isPlaying,
                       appName: "Music", appBundleIdentifier: app)
    }

    @Test func claimsTheEarsWhilePlayingInAnotherApp() {
        let monitor = NowPlayingMonitor()
        monitor.frontmostAppChanged(to: "com.editor")
        monitor.receive(info())
        #expect(monitor.earPriority == 3)
    }

    @Test func stepsAsideWhileThePlayingAppIsInFront() {
        let monitor = NowPlayingMonitor()
        monitor.receive(info(app: "com.music"))
        monitor.frontmostAppChanged(to: "com.music")
        #expect(monitor.isSourceInFront)
        #expect(monitor.earPriority == nil)

        monitor.frontmostAppChanged(to: "com.editor")
        #expect(monitor.earPriority == 3, "switching away brings the ears back")
    }

    @Test func thePlayerRowStaysWhileThePlayingAppIsInFront() {
        let monitor = NowPlayingMonitor()
        monitor.frontmostAppChanged(to: "com.music")
        monitor.receive(info(app: "com.music"))
        #expect(monitor.hasHeadline)
    }

    @Test func announcesANewTrackFromAnotherApp() {
        let monitor = NowPlayingMonitor()
        var announced: [String] = []
        monitor.onTrackChanged = { announced.append($0.title) }
        monitor.frontmostAppChanged(to: "com.editor")

        monitor.receive(info("One"))
        monitor.receive(info("Two"))
        #expect(announced == ["Two"])
    }

    @Test func staysQuietAboutANewTrackInTheAppYoureUsing() {
        let monitor = NowPlayingMonitor()
        var announced: [String] = []
        monitor.onTrackChanged = { announced.append($0.title) }
        monitor.frontmostAppChanged(to: "com.music")

        monitor.receive(info("One"))
        monitor.receive(info("Two"))
        #expect(announced.isEmpty)
    }

    @Test func nothingPlayingIsNeverInFront() {
        let monitor = NowPlayingMonitor()
        monitor.frontmostAppChanged(to: "com.music")
        #expect(!monitor.isSourceInFront)
        #expect(monitor.earPriority == nil)
    }
}
