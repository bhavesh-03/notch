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
        #expect(model.tabModules.count == 1)
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
        try await Task.sleep(for: .milliseconds(500))
        #expect(!model.isExpanded)
        #expect(model.selectedTab == nil)
    }
}
