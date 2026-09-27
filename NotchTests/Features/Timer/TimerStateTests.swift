import Foundation
import Testing
@testable import Notch

@MainActor
struct TimerStateTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)
    let duration: TimeInterval = 25 * 60

    @Test func idleShowsFullDuration() {
        let timer = TimerState(duration: duration)
        #expect(timer.phase == .idle)
        #expect(timer.remaining(at: start) == duration)
    }

    @Test func runningCountsDown() {
        var timer = TimerState(duration: duration)
        timer.start(at: start)
        #expect(timer.phase == .running(endDate: start + duration))
        #expect(timer.remaining(at: start + 60) == duration - 60)
    }

    @Test func pausingFreezesRemainingTime() {
        var timer = TimerState(duration: duration)
        timer.start(at: start)
        timer.pause(at: start + 60)
        #expect(timer.phase == .paused(remaining: duration - 60))
        #expect(timer.remaining(at: start + 3600) == duration - 60)
    }

    @Test func resumingContinuesFromPausedTime() {
        var timer = TimerState(duration: duration)
        timer.start(at: start)
        timer.pause(at: start + 60)
        timer.start(at: start + 3600)
        #expect(timer.remaining(at: start + 3600 + 100) == duration - 160)
    }

    @Test func remainingNeverGoesNegative() {
        var timer = TimerState(duration: duration)
        timer.start(at: start)
        #expect(timer.remaining(at: start + duration + 500) == 0)
    }

    @Test func finishesExactlyAtEndDate() {
        var timer = TimerState(duration: duration)
        timer.start(at: start)
        #expect(!timer.isFinished(at: start + duration - 1))
        #expect(timer.isFinished(at: start + duration))
    }

    @Test func idleAndPausedAreNeverFinished() {
        var timer = TimerState(duration: duration)
        #expect(!timer.isFinished(at: start + 10_000))
        timer.start(at: start)
        timer.pause(at: start + 10)
        #expect(!timer.isFinished(at: start + 10_000))
    }

    @Test func startingWhileRunningDoesNotRestart() {
        var timer = TimerState(duration: duration)
        timer.start(at: start)
        timer.start(at: start + 300)
        #expect(timer.phase == .running(endDate: start + duration))
    }

    @Test func pausingWhenNotRunningDoesNothing() {
        var timer = TimerState(duration: duration)
        timer.pause(at: start)
        #expect(timer.phase == .idle)

        timer.start(at: start)
        timer.pause(at: start + 60)
        timer.pause(at: start + 120)
        #expect(timer.phase == .paused(remaining: duration - 60))
    }

    @Test(arguments: [false, true])
    func resetReturnsToIdle(pausedFirst: Bool) {
        var timer = TimerState(duration: duration)
        timer.start(at: start)
        if pausedFirst { timer.pause(at: start + 60) }
        timer.reset()
        #expect(timer.phase == .idle)
        #expect(timer.remaining(at: start + 120) == duration)
    }

    @Test func durationCanBeChangedWhileIdle() {
        var timer = TimerState(duration: duration)
        timer.setDuration(seconds: 16 * 60 + 30)
        #expect(timer.duration == 16 * 60 + 30)
        #expect(timer.remaining(at: start) == 16 * 60 + 30)
    }

    @Test(arguments: [(0.0, 15.0), (-60.0, 15.0), (7, 15), (22, 15), (23, 30), (7200, 7200), (9000, 7200), (990, 990)])
    func durationIsSteppedAndClamped(requested: TimeInterval, expected: TimeInterval) {
        var timer = TimerState(duration: duration)
        timer.setDuration(seconds: requested)
        #expect(timer.duration == expected)
    }

    @Test func aRunningOrPausedTimerKeepsItsLength() {
        var timer = TimerState(duration: duration)
        timer.start(at: start)
        timer.setDuration(seconds: 300)
        #expect(timer.duration == duration)
        timer.pause(at: start + 60)
        timer.setDuration(seconds: 300)
        #expect(timer.duration == duration)
        timer.reset()
        timer.setDuration(seconds: 300)
        #expect(timer.duration == 300)
    }
}

@MainActor
struct TimerFormatTests {
    @Test(arguments: [(0, "0:00"), (15, "0:15"), (990, "16:30"), (3599, "59:59"), (3600, "1:00:00"), (5430, "1:30:30"), (7200, "2:00:00")])
    func formatsMinutesUnderAnHourAndHoursAbove(seconds: Int, text: String) {
        #expect(TimerFormat.string(seconds: seconds) == text)
    }
}
