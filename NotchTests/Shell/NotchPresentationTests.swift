import Foundation
import SwiftUI
import Testing
@testable import Notch

@MainActor
struct NotchPresentationTests {
    private func model() -> NotchViewModel {
        NotchViewModel(geometry: .previewHardware)
    }

    @Test func startsCollapsed() {
        #expect(model().presentation == .collapsed)
    }

    @Test func activityShowsThenCollapsesOnItsOwn() async throws {
        let model = model()
        model.showActivity(from: model.timer, for: .milliseconds(50))
        #expect(model.presentation == .activity(model.timer))
        #expect(!model.isExpanded)
        #expect(await eventually { model.presentation == .collapsed })
    }

    @Test func hoverDuringActivityExpandsAndStaysExpanded() async throws {
        let model = model()
        model.showActivity(from: model.battery, for: .milliseconds(50))
        model.expand()
        #expect(model.presentation == .expanded)
        try await Task.sleep(for: .milliseconds(300))
        #expect(model.presentation == .expanded)
    }

    @Test func activityIsIgnoredWhileExpanded() {
        let model = model()
        model.expand()
        model.showActivity(from: model.battery)
        #expect(model.presentation == .expanded)
    }

    @Test func newActivityReplacesCurrentOneAndRestartsItsTimer() async throws {
        let model = model()
        // The battery activity alone would end at 0.6 s; the timer's replaces it at 0.2 s and lasts until 2.2 s.
        model.showActivity(from: model.battery, for: .milliseconds(600))
        try await Task.sleep(for: .milliseconds(200))
        model.showActivity(from: model.timer, for: .seconds(2))
        try await Task.sleep(for: .milliseconds(800))
        #expect(model.presentation == .activity(model.timer), "still showing at 1.0 s: the battery's timer was cancelled")
    }

    @Test func onExpandedChangeOnlyReportsExpansion() {
        let model = model()
        var reports: [Bool] = []
        model.onExpandedChange = { reports.append($0) }
        model.showActivity(from: model.battery)
        model.expand()
        #expect(reports == [false, true])
    }

    @Test func activitiesFromDifferentModulesAreNotEqual() {
        let model = model()
        #expect(NotchViewModel.Presentation.activity(model.battery) != .activity(model.timer))
        #expect(NotchViewModel.Presentation.activity(model.timer) == .activity(model.timer))
        #expect(NotchViewModel.Presentation.collapsed != .expanded)
    }
}

@MainActor
struct ReduceMotionTests {
    @Test func activityAnimationRespectsReduceMotion() {
        let normal = NotchViewModel(geometry: .previewHardware, reduceMotion: { false })
        let reduced = NotchViewModel(geometry: .previewHardware, reduceMotion: { true })
        #expect(normal.activityAnimation == NotchMotion.activityOpen(reduceMotion: false))
        #expect(reduced.activityAnimation == .easeInOut(duration: 0.2))
        #expect(normal.activityCloseAnimation == NotchMotion.activityClose(reduceMotion: false))
        #expect(reduced.activityCloseAnimation == .easeInOut(duration: 0.2))
        #expect(normal.activityAnimation != reduced.activityAnimation)
    }
}

@MainActor
struct HoldOpenTests {
    @Test func heldOpenNotchIgnoresCollapseRequests() async throws {
        let model = NotchViewModel(geometry: .previewHardware)
        model.expand()
        model.holdOpen()
        model.scheduleCollapse()
        try await Task.sleep(for: .milliseconds(500))
        #expect(model.isExpanded)
    }

    @Test func holdingOpenCancelsACollapseAlreadyInFlight() async throws {
        let model = NotchViewModel(geometry: .previewHardware)
        model.expand()
        model.scheduleCollapse()
        model.holdOpen()
        try await Task.sleep(for: .milliseconds(500))
        #expect(model.isExpanded)
    }

    @Test func afterReleaseTheNotchCanCollapseAgain() async throws {
        let model = NotchViewModel(geometry: .previewHardware)
        model.expand()
        model.holdOpen()
        model.releaseHold()
        model.scheduleCollapse()
        #expect(await eventually { !model.isExpanded })
    }
}
