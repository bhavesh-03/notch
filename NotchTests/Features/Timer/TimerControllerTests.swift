import Foundation
import Testing
@testable import Notch

@MainActor
struct TimerControllerTests {
    final class FakeClock {
        var now = Date(timeIntervalSinceReferenceDate: 0)
        func advance(_ seconds: TimeInterval) { now += seconds }
    }

    @Test func startPauseResetDriveTheState() {
        let clock = FakeClock()
        let timer = TimerController(duration: 100, now: { clock.now })

        timer.start()
        #expect(timer.isRunning)
        clock.advance(30)
        timer.pause()
        #expect(timer.state.phase == .paused(remaining: 70))
        timer.reset()
        #expect(timer.state.phase == .idle)
    }

    @Test func toggleAlternatesBetweenRunningAndPaused() {
        let clock = FakeClock()
        let timer = TimerController(duration: 100, now: { clock.now })
        timer.toggle()
        #expect(timer.isRunning)
        timer.toggle()
        #expect(!timer.isRunning)
        #expect(timer.state.phase == .paused(remaining: 100))
    }

    @Test func finishesAndCallsOnFinish() async throws {
        let timer = TimerController(duration: 0.05)
        var finished = 0
        timer.onFinish = { finished += 1 }
        timer.start()
        #expect(await eventually { finished == 1 })
        #expect(timer.state.phase == .idle)
    }

    @Test func pausingCancelsTheFinish() async throws {
        let timer = TimerController(duration: 0.1)
        var finished = 0
        timer.onFinish = { finished += 1 }
        timer.start()
        timer.pause()
        try await Task.sleep(for: .milliseconds(300))
        #expect(finished == 0)
        #expect(!timer.isRunning)
    }

    @Test func resetCancelsTheFinish() async throws {
        let timer = TimerController(duration: 0.1)
        var finished = 0
        timer.onFinish = { finished += 1 }
        timer.start()
        timer.reset()
        try await Task.sleep(for: .milliseconds(300))
        #expect(finished == 0)
    }

    @Test func onStartFiresOnStartAndResumeButNotPauseOrReset() {
        let clock = FakeClock()
        let timer = TimerController(duration: 100, now: { clock.now })
        var starts = 0
        timer.onStart = { starts += 1 }

        timer.start()
        #expect(starts == 1)
        timer.pause()
        #expect(starts == 1)
        timer.start()
        #expect(starts == 2)
        timer.reset()
        #expect(starts == 2)
    }

    @Test func onStartSeesTheRunningState() {
        let timer = TimerController(duration: 100)
        var wasRunning = false
        timer.onStart = { [weak timer] in wasRunning = timer?.isRunning ?? false }
        timer.start()
        #expect(wasRunning)
    }

    @Test func theRulerSetsTheLength() {
        let timer = TimerController(duration: 25 * 60)
        #expect(timer.duration == 25 * 60)
        timer.setDuration(seconds: 16 * 60 + 30)
        #expect(timer.duration == 990)
        timer.start()
        #expect(timer.remaining(at: .now) <= 990)
        timer.reset()
    }

    @Test func theTimerPageOpensFromHomeRatherThanTheTabBar() {
        let timer = TimerController()
        #expect(timer.tab?.style == .page)
    }

    @Test func thePageIsTallOnlyWhileChoosingALength() {
        let timer = TimerController(duration: 100)
        #expect(timer.wantsTallPage, "idle: the ruler needs the room")
        timer.start()
        #expect(!timer.wantsTallPage, "running: just the countdown")
        timer.pause()
        #expect(!timer.wantsTallPage)
        timer.reset()
        #expect(timer.wantsTallPage)
    }

    @Test func zoomingInMakesAMinuteFourTimesWider() {
        #expect(DurationRuler.pointsPerSecond(fine: true) == 4 * DurationRuler.pointsPerSecond(fine: false))
        #expect(DurationRuler.pointsPerSecond(fine: false) * 60 == DurationRuler.tickSpacing)
    }

    @Test func normallyTheRulerSnapsToWholeMinutes() {
        #expect(DurationRuler.snapped(16 * 60 + 25, step: 60) == 16 * 60)
        #expect(DurationRuler.snapped(16 * 60 + 35, step: 60) == 17 * 60)
    }

    @Test func fineChoicesSnapToFifteenSeconds() {
        #expect(DurationRuler.snapped(16 * 60 + 25, step: 15) == 16 * 60 + 30)
        #expect(DurationRuler.snapped(16 * 60 + 5, step: 15) == 16 * 60)
    }

    @Test func aFifteenSecondValueKeepsItsPrecision() {
        // The bug: zooming out re-snapped 16:30 to whole minutes. The step now follows the value.
        let chosen: TimeInterval = 16 * 60 + 30
        #expect(DurationRuler.step(for: chosen) == 15)
        #expect(DurationRuler.snapped(chosen, step: DurationRuler.step(for: chosen)) == chosen)
        #expect(DurationRuler.step(for: 16 * 60) == 60)
    }

    @Test func zeroIsShownButNeverChosen() {
        #expect(DurationRuler.visibleRange.lowerBound == 0)
        #expect(DurationRuler.snapped(0, step: 60) == 60)
        #expect(DurationRuler.snapped(0, step: 15) == 15)
        #expect(DurationRuler.snapped(-100, step: 15) == 15)
    }

    @Test func theRulerGoesUpToTwoHours() {
        #expect(DurationRuler.snapped(9000, step: 60) == 7200)
    }

    @Test func pastTheEndsTheRulerMovesWithResistance() {
        let end = DurationRuler.visibleRange.upperBound
        #expect(DurationRuler.rubberBanded(600) == 600, "inside: unchanged")
        #expect(DurationRuler.rubberBanded(-100) == -30)
        #expect(DurationRuler.rubberBanded(end + 100) == end + 30)
    }
}
