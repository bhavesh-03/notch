import SwiftUI
import Testing
@testable import Notch

@MainActor
struct NotchModuleTests {
    final class FakeModule: NotchModule {
        let name: String
        var earPriority: Int?
        var feature: NotchFeature { .battery }

        init(_ name: String, priority: Int?) {
            self.name = name
            self.earPriority = priority
        }

        func content(for placement: NotchPlacement) -> some View {
            EmptyView()
        }
    }

    private func owner(_ modules: [any NotchModule]) -> String? {
        (modules.earOwner as? FakeModule)?.name
    }

    @Test func highestPriorityWins() {
        let modules: [any NotchModule] = [FakeModule("low", priority: 0), FakeModule("high", priority: 10)]
        #expect(owner(modules) == "high")
    }

    @Test func orderInTheArrayDoesNotAffectPriority() {
        let modules: [any NotchModule] = [FakeModule("high", priority: 10), FakeModule("low", priority: 0)]
        #expect(owner(modules) == "high")
    }

    @Test func modulesWithNilPriorityAreIgnored() {
        let modules: [any NotchModule] = [FakeModule("absent", priority: nil), FakeModule("present", priority: 0)]
        #expect(owner(modules) == "present")
    }

    @Test func nobodyClaimingMeansEmptyEars() {
        let modules: [any NotchModule] = [FakeModule("a", priority: nil), FakeModule("b", priority: nil)]
        #expect(modules.earOwner == nil)
        #expect(([] as [any NotchModule]).earOwner == nil)
    }

    @Test func timerClaimsEarsOnlyWhileActive() {
        let timer = TimerController(duration: 100)
        #expect(timer.earPriority == nil)
        timer.start()
        let running = timer.earPriority
        timer.pause()
        let paused = timer.earPriority
        timer.reset()
        #expect(running != nil && running == paused)
        #expect(timer.earPriority == nil)
    }

    @Test func activeTimerOutranksBattery() throws {
        let battery = BatteryMonitor()
        try #require(battery.status != nil, "needs a Mac with a battery")
        let timer = TimerController(duration: 100)
        let modules: [any NotchModule] = [battery, timer]

        #expect(modules.earOwner === battery)
        timer.start()
        #expect(modules.earOwner === timer)
        timer.reset()
    }
}

@MainActor
struct HeadlineTests {
    @Test func noModuleClaimsTheHeadlineByDefault() {
        let modules: [any NotchModule] = [NotchModuleTests.FakeModule("a", priority: 1), NotchModuleTests.FakeModule("b", priority: nil)]
        #expect(modules.headliner == nil)
    }

    @Test func nowPlayingHasNoHeadlineWhenNothingIsPlaying() {
        #expect(!NowPlayingMonitor().hasHeadline)
        #expect(NotchViewModel(geometry: .previewHardware).hasHeadline == false)
    }
}
