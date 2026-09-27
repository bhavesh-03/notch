import Foundation
import Testing
@testable import Notch

@MainActor
struct HomeLayoutEditingTests {
    private func layout(_ widgets: (HomeWidgetKind, WidgetSize)...) -> HomeLayout {
        HomeLayout(widgets: widgets.map { HomeWidget(kind: $0.0, size: $0.1) })
    }

    private let all = Set(HomeWidgetKind.allCases)

    @Test func sizesFromCellCounts() {
        #expect(WidgetSize(columns: 1, rows: 1) == .small)
        #expect(WidgetSize(columns: 2, rows: 1) == .wide)
        #expect(WidgetSize(columns: 1, rows: 2) == .tall)
        #expect(WidgetSize(columns: 3, rows: 5) == .large, "clamped to what exists")
    }

    @Test func addingPutsTheWidgetLastAndOnlyOnce() {
        var home = layout((.cpu, .small))
        home.add(.gpu)
        home.add(.gpu)
        #expect(home == layout((.cpu, .small), (.gpu, .small)))
    }

    @Test func removingAndResizing() {
        var home = layout((.cpu, .small), (.gpu, .small))
        home.resize(.gpu, to: .large)
        home.remove(.cpu)
        #expect(home == layout((.gpu, .large)))
    }

    @Test func draggingForwardOverAWidgetPlacesItAfter() {
        // cpu (0,0), gpu (0,1), memory (1,0): drag cpu over memory.
        var home = layout((.cpu, .small), (.gpu, .small), (.memory, .small))
        let moved = home.move(.cpu, toColumn: 1, row: 0, columns: 4, visible: all)
        #expect(moved)
        #expect(home.widgets.map(\.kind) == [.gpu, .memory, .cpu])
    }

    @Test func draggingBackOverAWidgetPlacesItBefore() {
        var home = layout((.cpu, .small), (.gpu, .small), (.memory, .small))
        let moved = home.move(.memory, toColumn: 0, row: 0, columns: 4, visible: all)
        #expect(moved)
        #expect(home.widgets.map(\.kind) == [.memory, .cpu, .gpu])
    }

    @Test func draggingOverItselfChangesNothing() {
        var home = layout((.cpu, .small), (.gpu, .small))
        let moved = home.move(.cpu, toColumn: 0, row: 0, columns: 4, visible: all)
        #expect(!moved)
    }

    @Test func draggingToAnEmptyCellUsesReadingOrder() {
        // timer fills columns 0-1; cpu at (2,0). Dropping the timer on the empty (3,0) puts it after cpu.
        var home = layout((.timer, .large), (.cpu, .small))
        let moved = home.move(.timer, toColumn: 3, row: 0, columns: 4, visible: all)
        #expect(moved)
        #expect(home.widgets.map(\.kind) == [.cpu, .timer])
    }

    @Test func hiddenWidgetsKeepTheirPlace() {
        // gpu's feature is off, so it isn't shown; moving cpu past memory leaves gpu where it was.
        var home = layout((.cpu, .small), (.gpu, .small), (.memory, .small))
        let visible: Set<HomeWidgetKind> = [.cpu, .memory]
        let moved = home.move(.cpu, toColumn: 0, row: 1, columns: 4, visible: visible)
        #expect(moved)
        #expect(home.widgets.map(\.kind) == [.gpu, .memory, .cpu])
    }
}

@MainActor
struct HomeEditingStateTests {
    @Test func editingKeepsTheNotchOpen() async throws {
        let model = NotchViewModel(geometry: .previewHardware, settings: .ephemeral())
        model.expand()
        model.beginEditingHome()
        model.scheduleCollapse()
        try await Task.sleep(for: .milliseconds(500))
        #expect(model.isExpanded)

        model.endEditingHome()
        model.scheduleCollapse()
        #expect(await eventually { !model.isExpanded })
    }

    @Test func editingHappensOnHome() {
        let model = NotchViewModel(geometry: .previewHardware, settings: .ephemeral())
        model.expand()
        model.select(tab: model.shelf)
        model.beginEditingHome()
        #expect(model.selectedTab == nil)
    }
}
