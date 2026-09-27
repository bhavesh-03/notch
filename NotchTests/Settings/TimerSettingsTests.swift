import Foundation
import Testing
@testable import Notch

@MainActor
struct TimerSettingsTests {
    let suite = "TimerSettingsTests.\(UUID().uuidString)"
    var defaults: UserDefaults { UserDefaults(suiteName: suite)! }

    @Test func startsWithTodaysTimer() {
        let settings = NotchSettings(defaults: defaults)
        #expect(settings.timerLength == 25 * 60)
        #expect(settings.timerPresets == [5, 10, 25, 45])
        #expect(settings.showsTimerPresets && settings.timerNotifies && settings.timerPlaysSound)
    }

    @Test func timerDefaultsSurviveARelaunch() {
        let settings = NotchSettings(defaults: defaults)
        settings.timerLength = 50 * 60
        settings.setTimerPreset(at: 1, minutes: 15)
        settings.showsTimerPresets = false
        settings.timerPlaysSound = false

        let relaunched = NotchSettings(defaults: defaults)
        #expect(relaunched.timerLength == 50 * 60)
        #expect(relaunched.timerPresets == [5, 15, 25, 45])
        #expect(!relaunched.showsTimerPresets)
        #expect(!relaunched.timerPlaysSound)
    }

    @Test(arguments: [(1.0, 15.0), (99_999.0, 7200.0)])
    func lengthStaysInTheTimersRange(requested: Double, expected: Double) {
        let settings = NotchSettings(defaults: defaults)
        settings.timerLength = requested
        #expect(settings.timerLength == expected)
    }

    @Test func presetsAreWholeMinutesInRange() {
        let settings = NotchSettings(defaults: defaults)
        settings.setTimerPreset(at: 0, minutes: 0)
        settings.setTimerPreset(at: 1, minutes: 500)
        settings.setTimerPreset(at: 2, minutes: 12.6)
        settings.setTimerPreset(at: 9, minutes: 30)   // no such slot: ignored
        #expect(settings.timerPresets == [1, 120, 13, 45])
    }

    @Test func badSavedPresetsFallBackToDefaults() {
        defaults.set([1.0, 2.0], forKey: "settings.timerPresets")
        #expect(NotchSettings(defaults: defaults).timerPresets == [5, 10, 25, 45])
    }

    @Test func resetRestoresTodaysTimer() {
        let settings = NotchSettings(defaults: defaults)
        settings.timerLength = 60
        settings.setTimerPreset(at: 0, minutes: 90)
        settings.timerNotifies = false
        settings.resetTimer()
        #expect(settings.timerLength == 25 * 60)
        #expect(settings.timerPresets == [5, 10, 25, 45])
        #expect(settings.timerNotifies)
    }

    @Test func aLengthChangeIsReportedOnlyWhenItChanges() {
        let settings = NotchSettings(defaults: defaults)
        var reports: [Double] = []
        settings.onTimerLengthChanged = { reports.append($0) }
        settings.timerLength = 25 * 60   // same
        settings.timerLength = 10 * 60
        #expect(reports == [600])
    }
}

@MainActor
struct TimerLengthSyncTests {
    private func model(_ settings: NotchSettings? = nil) -> NotchViewModel {
        NotchViewModel(geometry: .previewHardware, settings: settings ?? .ephemeral())
    }

    @Test func theTimerStartsAtTheSavedLength() {
        let settings = NotchSettings.ephemeral()
        settings.timerLength = 40 * 60
        #expect(model(settings).timer.duration == 40 * 60)
    }

    @Test func theRulerSavesTheLength() {
        let model = model()
        model.timer.setDuration(seconds: 12 * 60 + 30)
        #expect(model.settings.timerLength == 12 * 60 + 30)
    }

    @Test func settingsMoveTheRuler() {
        let model = model()
        model.settings.timerLength = 3 * 60
        #expect(model.timer.duration == 3 * 60)
    }

    @Test func aChangeWhileRunningWaitsForTheTimerToEnd() {
        let model = model()
        model.timer.start()
        model.settings.timerLength = 5 * 60
        #expect(model.timer.duration == 25 * 60, "the running timer keeps its length")

        model.timer.reset()
        #expect(model.timer.duration == 5 * 60)
    }
}

@MainActor
struct TimerControllerLengthTests {
    @Test func reportsOnlyRealChanges() {
        let timer = TimerController(duration: 600)
        var reports: [TimeInterval] = []
        timer.onDurationChanged = { reports.append($0) }
        timer.setDuration(seconds: 605)   // rounds back to 600
        timer.setDuration(seconds: 900)
        #expect(reports == [900])
    }

    @Test func aPendingLengthAppliesWhenTheTimerFinishes() async {
        let timer = TimerController(duration: 0.1)
        timer.start()
        timer.setDuration(seconds: 120)
        #expect(await eventually { timer.state.phase == .idle })
        #expect(timer.duration == 120)
    }

    @Test func aPausedTimerAlsoKeepsItsLength() {
        let timer = TimerController(duration: 600)
        timer.start()
        timer.pause()
        timer.setDuration(seconds: 60)
        #expect(timer.duration == 600)
        timer.reset()
        #expect(timer.duration == 60)
    }
}

struct TimerWordingTests {
    @Test(arguments: [
        (30.0, "Your timer for 30 seconds is done."),
        (1500.0, "Your timer for 25 minutes is done."),
        (5400.0, "Your timer for 1 hour, 30 minutes is done."),
    ])
    func theNotificationSpellsOutTheLength(duration: TimeInterval, body: String) {
        #expect(NotificationService.timerFinishedBody(duration: duration) == body)
    }

    @Test(arguments: [(300.0, "5m"), (2700.0, "45m"), (3600.0, "1h"), (5400.0, "1h30"), (3900.0, "1h05")])
    @MainActor func chipTitles(seconds: TimeInterval, title: String) {
        #expect(TimerPage.chipTitle(seconds: seconds) == title)
    }
}
