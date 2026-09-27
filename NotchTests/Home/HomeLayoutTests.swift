import Foundation
import Testing
@testable import Notch

@MainActor
struct HomeLayoutTests {
    private func layout(_ widgets: (HomeWidgetKind, WidgetSize)...) -> HomeLayout {
        HomeLayout(widgets: widgets.map { HomeWidget(kind: $0.0, size: $0.1) })
    }

    private func spots(_ layout: HomeLayout, columns: Int) -> [HomeWidgetKind: [Int]] {
        Dictionary(uniqueKeysWithValues: layout.arranged(columns: columns).placed.map { ($0.widget.kind, [$0.column, $0.row]) })
    }

    @Test(arguments: [(480.0, 4), (540.0, 5), (620.0, 6)])
    func columnsFollowTheNotchWidth(width: CGFloat, columns: Int) {
        #expect(HomeLayout.columns(forWidth: width) == columns)
    }

    @Test func widgetsFillEachColumnTopToBottomThenMoveRight() {
        let result = spots(layout((.cpu, .small), (.gpu, .small), (.memory, .small)), columns: 4)
        #expect(result == [.cpu: [0, 0], .gpu: [0, 1], .memory: [1, 0]])
    }

    @Test func sizesTakeTheirCells() {
        let result = spots(layout((.timer, .large), (.calendar, .wide), (.battery, .small), (.cpu, .small), (.gpu, .tall)), columns: 5)
        #expect(result == [.timer: [0, 0], .calendar: [2, 0], .battery: [2, 1], .cpu: [3, 1], .gpu: [4, 0]])
    }

    @Test func aWidgetSkipsToTheFirstGapItFits() {
        // The small one lands under the wide one; the tall one needs a whole column.
        let result = spots(layout((.calendar, .wide), (.cpu, .small), (.gpu, .tall)), columns: 4)
        #expect(result == [.calendar: [0, 0], .cpu: [0, 1], .gpu: [2, 0]])
    }

    @Test func whatDoesNotFitOverflowsButStaysInTheLayout() {
        let wide = layout((.timer, .large), (.calendar, .large), (.cpu, .large))
        let (placed, overflow) = wide.arranged(columns: 4)
        #expect(placed.map(\.widget.kind) == [.timer, .calendar])
        #expect(overflow.map(\.kind) == [.cpu])
        #expect(wide.arranged(columns: 6).overflow.isEmpty, "a wider notch shows it again")
    }

    @Test func theDefaultFillsTheStandardGrid() {
        let (placed, overflow) = HomeLayout.default.arranged(columns: 5)
        let cells = placed.map { $0.widget.size.columns * $0.widget.size.rows }.reduce(0, +)
        #expect(cells == 10)
        #expect(overflow.map(\.kind) == [.temperature])
    }

    @Test func nothingOverlaps() {
        let (placed, _) = HomeLayout.default.arranged(columns: 6)
        var cells = Set<[Int]>()
        for placement in placed {
            for c in placement.column..<(placement.column + placement.widget.size.columns) {
                for r in placement.row..<(placement.row + placement.widget.size.rows) {
                    #expect(cells.insert([c, r]).inserted, "\(placement.widget.kind) overlaps at \([c, r])")
                }
            }
        }
    }

    @Test func savedLayoutsSurviveUnknownKindsAndRepeats() throws {
        let json = #"{"widgets":[{"kind":"cpu","size":"wide"},{"kind":"weather","size":"small"},{"kind":"cpu","size":"small"},{"kind":"timer","size":"huge"},{"kind":"gpu","size":"tall"}]}"#
        let decoded = try JSONDecoder().decode(HomeLayout.self, from: Data(json.utf8))
        #expect(decoded == layout((.cpu, .wide), (.gpu, .tall)))
    }

    @Test func aLayoutRoundTrips() throws {
        let data = try JSONEncoder().encode(HomeLayout.default)
        #expect(try JSONDecoder().decode(HomeLayout.self, from: data) == .default)
    }
}

@MainActor
struct HomeLayoutFillTests {
    private func layout(_ widgets: (HomeWidgetKind, WidgetSize)...) -> HomeLayout {
        HomeLayout(widgets: widgets.map { HomeWidget(kind: $0.0, size: $0.1) })
    }

    /// Every cell of the grid it reports is covered exactly once.
    private func expectNoGaps(_ result: (placed: [HomeLayout.Placement], columns: Int), sourceLocation: SourceLocation = #_sourceLocation) {
        for c in 0..<result.columns {
            for r in 0..<HomeLayout.rows {
                let covering = result.placed.filter { $0.covers(column: c, row: r) }
                #expect(covering.count == 1, "cell \([c, r]) covered \(covering.count) times", sourceLocation: sourceLocation)
            }
        }
    }

    @Test(arguments: [4, 5, 6])
    func theDefaultLeavesNoGaps(columns: Int) {
        expectNoGaps(HomeLayout.default.filled(columns: columns))
    }

    @Test func unusedColumnsAreDropped() {
        let result = layout((.cpu, .small), (.gpu, .small), (.memory, .small)).filled(columns: 5)
        #expect(result.columns == 2, "three small widgets use two columns, so those two take the full width")
        expectNoGaps(result)
    }

    @Test func aSmallWidgetGrowsDownBeforeSideways() {
        let result = layout((.timer, .large), (.cpu, .small)).filled(columns: 4)
        let cpu = result.placed.first { $0.widget.kind == .cpu }
        #expect(cpu?.rowSpan == 2)
        #expect(cpu?.displaySize == .tall)
        #expect(cpu?.widget.size == .small, "the saved size doesn't change")
        expectNoGaps(result)
    }

    @Test func aGapBesideAWideWidgetIsFilled() {
        // Wide calendar on top, one small below it: the small grows sideways under the calendar.
        let result = layout((.calendar, .wide), (.cpu, .small)).filled(columns: 4)
        expectNoGaps(result)
        #expect(result.placed.first { $0.widget.kind == .cpu }?.displaySize == .wide)
    }

    @Test(arguments: [
        [(HomeWidgetKind.timer, WidgetSize.wide), (.battery, .tall), (.cpu, .small), (.gpu, .wide), (.memory, .small)],
        [(.cpu, .small), (.gpu, .large), (.memory, .small), (.temperature, .tall)],
        [(.calendar, .large)],
    ].map { $0.map { HomeWidget(kind: $0.0, size: $0.1) } })
    func assortedLayoutsLeaveNoGaps(widgets: [HomeWidget]) {
        for columns in 4...6 {
            expectNoGaps(HomeLayout(widgets: widgets).filled(columns: columns))
        }
    }

    @Test func anEmptyLayoutStaysEmpty() {
        #expect(HomeLayout(widgets: []).filled(columns: 5).placed.isEmpty)
    }
}

@MainActor
struct HomeWidgetsTests {
    @Test func theLayoutIsSaved() {
        let suite = "HomeWidgetsTests.\(UUID().uuidString)"
        let settings = NotchSettings(defaults: UserDefaults(suiteName: suite)!)
        #expect(settings.homeLayout == .default)
        settings.homeLayout = HomeLayout(widgets: [HomeWidget(kind: .cpu, size: .large)])
        #expect(NotchSettings(defaults: UserDefaults(suiteName: suite)!).homeLayout.widgets == [HomeWidget(kind: .cpu, size: .large)])
    }

    @Test func hidingAFeatureHidesItsWidgets() {
        let settings = NotchSettings.ephemeral()
        let model = NotchViewModel(geometry: .previewHardware, settings: settings)
        settings.setVisible(.systemStats, false)
        #expect(!model.homeWidgets.contains { $0.kind.feature == .systemStats })
        #expect(model.homeWidgets.contains { $0.kind == .timer })
        settings.setVisible(.timer, false)
        #expect(!model.homeWidgets.contains { $0.kind == .timer })
    }

    @Test func everyWidgetBelongsToAFeature() {
        for kind in HomeWidgetKind.allCases {
            #expect(NotchFeature.allCases.contains(kind.feature))
        }
    }
}
