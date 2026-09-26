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
        try await Task.sleep(for: .milliseconds(300))
        #expect(finished == 1)
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
}
