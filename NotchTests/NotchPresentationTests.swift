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
        try await Task.sleep(for: .milliseconds(300))
        #expect(model.presentation == .collapsed)
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
        model.showActivity(from: model.battery, for: .milliseconds(100))
        try await Task.sleep(for: .milliseconds(60))
        model.showActivity(from: model.timer, for: .milliseconds(200))
        try await Task.sleep(for: .milliseconds(100))
        #expect(model.presentation == .activity(model.timer))
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
