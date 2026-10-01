import Foundation
import Testing
@testable import Notch

@MainActor
struct NotchTabTests {
    private func model() -> NotchViewModel {
        NotchViewModel(geometry: .previewHardware)
    }

    @Test func modulesHaveNoTabAndIgnoreFileDropsByDefault() {
        let fake = NotchModuleTests.FakeModule("a", priority: nil)
        #expect(fake.tab == nil)
        #expect(!fake.acceptsFileDrops)
    }

    @Test func theShelfIsTheFilesTabAndTakesDrops() {
        let model = model()
        #expect(model.shelf.tab == NotchTab(title: "Files", symbol: "tray.full.fill"))
        #expect(model.shelf.acceptsFileDrops)
        #expect(model.tabModules.filter { $0.tab?.style == .tab }.map { $0.tab?.title } == ["Files", "Notes"])
        #expect(model.tabModules.filter { $0.tab?.style == .button }.map { $0.tab?.title } == ["Calculator", "Mirror"])
        #expect(model.tabModules.filter { $0.tab?.style == .page }.map { $0.tab?.title } == ["Timer", "Calendar"])
    }

    @Test func theNotchOpensOnHome() {
        let model = model()
        model.expand()
        #expect(model.selectedTab == nil)
        #expect(model.selectedTabModule == nil)
    }

    @Test func draggingAFileOpensTheTabThatTakesDrops() {
        let model = model()
        model.expand()
        model.showDropTarget()
        #expect(model.selectedTabModule === model.shelf)
        #expect(!model.showsHeadline, "the player row belongs to Home only")
    }

    @Test func tabsCanBeSwitchedByHand() {
        let model = model()
        model.select(tab: model.shelf)
        #expect(model.selectedTabModule === model.shelf)
        model.select(tab: nil)
        #expect(model.selectedTab == nil)
    }

    @Test func collapsingReturnsToHome() async throws {
        let model = model()
        model.expand()
        model.select(tab: model.shelf)
        model.scheduleCollapse()
        #expect(await eventually { !model.isExpanded })
        #expect(model.selectedTab == nil)
    }

    @Test func theTimerIsOnHomeAndHasATallPage() {
        let model = model()
        #expect(model.homeWidgets.contains { $0.kind == .timer }, "still on Home, as a widget")
        model.select(tab: model.timer)
        #expect(model.isTall)
        model.timer.start()
        #expect(!model.isTall, "the running countdown shrinks the notch")
        model.timer.reset()
    }

    @Test func shrinkingUnderThePointerIsNotLeaving() {
        let model = model()
        model.expand()
        model.select(tab: model.timer)
        #expect(model.hoverIsTall(pointerInTallShape: true))
        model.timer.start()
        #expect(!model.isTall)
        #expect(model.hoverIsTall(pointerInTallShape: true), "pointer still where the tall notch was: stay open")
        #expect(model.hoverIsTall(pointerInTallShape: true), "no matter how long it stays there")
        #expect(!model.hoverIsTall(pointerInTallShape: false), "moved out: normal hover")
        #expect(!model.hoverIsTall(pointerInTallShape: true), "and moving back doesn't revive it")
        model.timer.reset()
    }

    @Test func aNotchThatWasNeverTallHasNoGrace() {
        let model = model()
        model.expand()
        #expect(!model.hoverIsTall(pointerInTallShape: true))
    }
}

struct TabBarLayoutTests {
    // Roughly Home, Files and Notes in the tab font.
    let widths: [CGFloat] = [33, 28, 36]

    @Test func everyLabelWhenThereIsRoom() {
        #expect(TabBarLayout.labels(titleWidths: widths, selected: 0, available: 300) == .all)
    }

    @Test func onlyTheSelectedLabelWhenTight() {
        // Standard width leaves about 150 pt left of the camera: three labels don't fit, one does.
        #expect(TabBarLayout.labels(titleWidths: widths, selected: 2, available: 150) == .selectedOnly)
    }

    @Test func iconsOnlyWhenVeryTight() {
        #expect(TabBarLayout.labels(titleWidths: widths, selected: 0, available: 100) == .none)
    }

    @Test func aPageWithNoTabShowsIconsWhenTight() {
        // The timer and calendar pages have no tab button, so nothing is selected in the bar.
        #expect(TabBarLayout.labels(titleWidths: widths, selected: nil, available: 150) == .selectedOnly)
        #expect(TabBarLayout.labels(titleWidths: widths, selected: nil, available: 90) == .none)
    }

    @Test func realTitlesAreMeasured() {
        #expect(TabBarLayout.measure("Notes") > TabBarLayout.measure("Home") * 0.5)
        #expect(TabBarLayout.measure("") == 0)
    }
}
