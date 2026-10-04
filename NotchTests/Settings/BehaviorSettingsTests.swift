import Foundation
import Testing
@testable import Notch

@MainActor
struct BehaviorSettingsTests {
    let suite = "BehaviorSettingsTests.\(UUID().uuidString)"
    var defaults: UserDefaults { UserDefaults(suiteName: suite)! }

    @Test func startsWithTodaysBehavior() {
        let settings = NotchSettings(defaults: defaults)
        #expect(settings.hoverDelay == 0)
        #expect(settings.animationSpeed == .standard)
        #expect(NotchFeature.withPopUps.allSatisfy(settings.showsPopUp(for:)))
    }

    @Test func behaviorSurvivesARelaunch() {
        let settings = NotchSettings(defaults: defaults)
        settings.hoverDelay = 0.6
        settings.animationSpeed = .quick
        settings.setShowsPopUp(for: .nowPlaying, false)

        let relaunched = NotchSettings(defaults: defaults)
        #expect(relaunched.hoverDelay == 0.6)
        #expect(relaunched.animationSpeed == .quick)
        #expect(!relaunched.showsPopUp(for: .nowPlaying))
        #expect(relaunched.showsPopUp(for: .battery))
    }

    @Test func resetRestoresTodaysBehavior() {
        let settings = NotchSettings(defaults: defaults)
        settings.hoverDelay = 0.3
        settings.animationSpeed = .relaxed
        settings.setShowsPopUp(for: .timer, false)
        settings.swipeNavigationEnabled = false
        settings.hapticFeedbackEnabled = true
        settings.resetBehavior()
        #expect(settings.hoverDelay == 0 && settings.animationSpeed == .standard)
        #expect(settings.swipeNavigationEnabled && !settings.hapticFeedbackEnabled, "swiping on, haptics off, as on a new install")
        #expect(settings.showsPopUp(for: .timer))
        #expect(NotchSettings(defaults: defaults).showsPopUp(for: .timer), "the reset is saved too")
    }

    @Test func onlyFeaturesWithAPopUpAreListed() {
        #expect(NotchFeature.withPopUps == [.battery, .timer, .calendar, .nowPlaying, .devices])
    }

    @Test(arguments: [(-1.0, 0.0), (5.0, 1.0), (0.45, 0.45)])
    func hoverDelayStaysInRange(requested: Double, expected: Double) {
        let settings = NotchSettings(defaults: defaults)
        settings.hoverDelay = requested
        #expect(settings.hoverDelay == expected)
    }

    @Test func speedsAreOrdered() {
        let speeds = AnimationSpeed.allCases.map(\.multiplier)
        #expect(speeds == speeds.sorted())
        #expect(AnimationSpeed.standard.multiplier == 1, "standard is the tuned feel, untouched")
    }
}

@MainActor
struct HoverDelayTests {
    private func model(delay: Double) -> NotchViewModel {
        let settings = NotchSettings.ephemeral()
        settings.hoverDelay = delay
        return NotchViewModel(geometry: .previewHardware, settings: settings)
    }

    @Test func instantOpensRightAway() {
        let model = model(delay: 0)
        model.pointerEntered()
        #expect(model.isExpanded)
    }

    @Test func aDelayOpensAfterThePointerRests() async {
        let model = model(delay: 0.3)
        model.pointerEntered()
        #expect(!model.isExpanded, "not yet")
        #expect(await eventually { model.isExpanded })
    }

    @Test func passingByDoesNotOpen() async throws {
        let model = model(delay: 0.15)
        model.pointerEntered()
        model.pointerLeft()
        try await Task.sleep(for: .seconds(0.15 + 0.3))
        #expect(!model.isExpanded)
    }

    @Test func movingWithinTheNotchDoesNotRestartTheDelay() async {
        let model = model(delay: 0.3)
        let start = ContinuousClock.now
        model.pointerEntered()
        // Mouse-move events keep arriving while the pointer rests; each one calls pointerEntered.
        for _ in 0..<5 {
            try? await Task.sleep(for: .milliseconds(50))
            model.pointerEntered()
        }
        #expect(await eventually { model.isExpanded })
        #expect(ContinuousClock.now - start < .seconds(1.5), "opened on the first countdown, not pushed back each move")
    }

    @Test func aFileDragOpensRightAwayDespiteADelay() {
        let model = model(delay: 0.6)
        model.pointerEntered(isDraggingFile: true)
        #expect(model.isExpanded)
    }

    @Test func returningCancelsAPendingCollapse() async throws {
        let model = model(delay: 0.3)
        model.expand()
        model.pointerLeft()
        model.pointerEntered()
        try await Task.sleep(for: .milliseconds(500))
        #expect(model.isExpanded)
    }
}

@MainActor
struct PopUpSettingsTests {
    @Test func aMutedPopUpDoesNotAppear() {
        let settings = NotchSettings.ephemeral()
        let model = NotchViewModel(geometry: .previewHardware, settings: settings)
        settings.setShowsPopUp(for: .battery, false)

        model.showActivity(from: model.battery)
        #expect(model.presentation == .collapsed)

        model.showActivity(from: model.timer)
        #expect(model.presentation == .activity(model.timer), "other pop-ups are unaffected")
    }

    @Test func mutingAPopUpKeepsTheFeatureInTheEars() {
        let settings = NotchSettings.ephemeral()
        let model = NotchViewModel(geometry: .previewHardware, settings: settings)
        settings.setShowsPopUp(for: .battery, false)
        #expect(model.modules.contains { $0.feature == .battery })
    }
}
