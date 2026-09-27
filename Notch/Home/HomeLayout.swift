import Foundation

/// How much of the Home grid a widget covers, like iOS widget sizes.
enum WidgetSize: String, CaseIterable, Codable, Identifiable {
    case small, wide, tall, large

    var id: String { rawValue }

    var columns: Int { self == .wide || self == .large ? 2 : 1 }
    var rows: Int { self == .tall || self == .large ? 2 : 1 }

    var title: String {
        switch self {
        case .small: "Small"
        case .wide: "Wide"
        case .tall: "Tall"
        case .large: "Large"
        }
    }
}

/// Something that can sit on Home. One of each at most.
enum HomeWidgetKind: String, CaseIterable, Codable, Identifiable {
    case battery, timer, calendar, cpu, gpu, memory, temperature

    var id: String { rawValue }

    /// The feature it belongs to; hiding that feature hides the widget too.
    var feature: NotchFeature {
        switch self {
        case .battery: .battery
        case .timer: .timer
        case .calendar: .calendar
        case .cpu, .gpu, .memory, .temperature: .systemStats
        }
    }

    var title: String {
        switch self {
        case .battery: "Battery"
        case .timer: "Timer"
        case .calendar: "Calendar"
        case .cpu: "CPU"
        case .gpu: "GPU"
        case .memory: "Memory"
        case .temperature: "Temperature"
        }
    }

    /// For narrow widgets, where "Temperature" would be cut off.
    var shortTitle: String { self == .temperature ? "Temp" : title }

    var symbol: String {
        switch self {
        case .battery: "battery.75percent"
        case .timer: "timer"
        case .calendar: "calendar"
        case .cpu: "cpu"
        case .gpu: "square.stack.3d.up"
        case .memory: "memorychip"
        case .temperature: "thermometer.medium"
        }
    }
}

struct HomeWidget: Codable, Equatable, Identifiable {
    var kind: HomeWidgetKind
    var size: WidgetSize

    var id: HomeWidgetKind { kind }
}

/// Home's widgets as an ordered list with sizes. Positions aren't stored: they're worked out by
/// packing the list into however many columns the notch has, so one layout suits every width.
struct HomeLayout: Codable, Equatable {
    var widgets: [HomeWidget]

    static let rows = 2

    /// Fills five columns exactly: the timer's full view, the calendar, and small vitals around them.
    static let `default` = HomeLayout(widgets: [
        HomeWidget(kind: .timer, size: .large),
        HomeWidget(kind: .calendar, size: .wide),
        HomeWidget(kind: .battery, size: .small),
        HomeWidget(kind: .cpu, size: .small),
        HomeWidget(kind: .gpu, size: .small),
        HomeWidget(kind: .memory, size: .small),
        HomeWidget(kind: .temperature, size: .small),
    ])

    /// Columns for a notch of this width, keeping cells about 100 pt wide: 4, 5 or 6 for the
    /// Compact, Standard and Wide settings.
    static func columns(forWidth width: CGFloat) -> Int {
        width >= 600 ? 6 : width >= 520 ? 5 : 4
    }

    struct Placement: Equatable {
        let widget: HomeWidget
        var column: Int
        var row: Int
        /// The cells it covers. Its size's own span, unless `filled` grew it into a gap.
        var columnSpan: Int
        var rowSpan: Int

        init(widget: HomeWidget, column: Int, row: Int) {
            self.widget = widget
            self.column = column
            self.row = row
            columnSpan = widget.size.columns
            rowSpan = widget.size.rows
        }

        /// The size to draw it at, after any growing: two rows and two or more columns is Large, etc.
        var displaySize: WidgetSize {
            switch (columnSpan > 1, rowSpan > 1) {
            case (true, true): .large
            case (false, true): .tall
            case (true, false): .wide
            case (false, false): .small
            }
        }

        func covers(column c: Int, row r: Int) -> Bool {
            (column..<(column + columnSpan)).contains(c) && (row..<(row + rowSpan)).contains(r)
        }
    }

    /// Places each widget, in order, at the first spot it fits, going down each column before
    /// moving right (so Home fills from the left, the way you read it). Widgets with no room left
    /// are returned as `overflow`: kept in the layout, just not shown at this width.
    func arranged(columns: Int) -> (placed: [Placement], overflow: [HomeWidget]) {
        var taken = Set<[Int]>()
        var placed: [Placement] = []
        var overflow: [HomeWidget] = []

        func fits(_ size: WidgetSize, column: Int, row: Int) -> Bool {
            guard column + size.columns <= columns, row + size.rows <= Self.rows else { return false }
            for c in column..<(column + size.columns) {
                for r in row..<(row + size.rows) where taken.contains([c, r]) { return false }
            }
            return true
        }

        for widget in widgets {
            let spot = (0..<columns).lazy
                .flatMap { column in (0..<Self.rows).lazy.map { row in (column, row) } }
                .first { fits(widget.size, column: $0.0, row: $0.1) }
            guard let (column, row) = spot else {
                overflow.append(widget)
                continue
            }
            for c in column..<(column + widget.size.columns) {
                for r in row..<(row + widget.size.rows) { taken.insert([c, r]) }
            }
            placed.append(Placement(widget: widget, column: column, row: row))
        }
        return (placed, overflow)
    }

    /// What Home shows: the packed widgets with no empty space. Columns nobody uses are dropped (the
    /// rest widen to the full width), then widgets grow into gaps next to them, preferring to grow
    /// down or up (a Small becomes Tall) before sideways. Only the drawing changes; the saved sizes
    /// don't, so a widget shrinks back when the space is needed.
    func filled(columns: Int) -> (placed: [Placement], columns: Int) {
        var placed = arranged(columns: columns).placed
        guard !placed.isEmpty else { return ([], columns) }
        let usedColumns = placed.map { $0.column + $0.columnSpan }.max() ?? columns

        func isFree(column c: Int, row r: Int) -> Bool {
            (0..<usedColumns).contains(c) && (0..<Self.rows).contains(r) && !placed.contains { $0.covers(column: c, row: r) }
        }
        func free(columns cs: Range<Int>, rows rs: Range<Int>) -> Bool {
            cs.allSatisfy { c in rs.allSatisfy { r in isFree(column: c, row: r) } }
        }

        var grew = true
        while grew {
            grew = false
            // Vertically first: a column of widgets reads better than one stretched sideways.
            for index in placed.indices {
                let p = placed[index]
                let columnsCovered = p.column..<(p.column + p.columnSpan)
                if free(columns: columnsCovered, rows: (p.row + p.rowSpan)..<(p.row + p.rowSpan + 1)) {
                    placed[index].rowSpan += 1
                    grew = true
                } else if p.row > 0, free(columns: columnsCovered, rows: (p.row - 1)..<p.row) {
                    placed[index].row -= 1
                    placed[index].rowSpan += 1
                    grew = true
                }
            }
            if grew { continue }
            for index in placed.indices {
                let p = placed[index]
                let rowsCovered = p.row..<(p.row + p.rowSpan)
                if free(columns: (p.column + p.columnSpan)..<(p.column + p.columnSpan + 1), rows: rowsCovered) {
                    placed[index].columnSpan += 1
                    grew = true
                    break
                } else if p.column > 0, free(columns: (p.column - 1)..<p.column, rows: rowsCovered) {
                    placed[index].column -= 1
                    placed[index].columnSpan += 1
                    grew = true
                    break
                }
            }
        }
        return (placed, usedColumns)
    }

    // MARK: - Saving

    /// Decodes what it can: widgets of a kind this version doesn't know are skipped, as are repeats.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decoded = try container.decode([Lossy<HomeWidget>].self, forKey: .widgets).compactMap(\.value)
        var seen = Set<HomeWidgetKind>()
        widgets = decoded.filter { seen.insert($0.kind).inserted }
    }

    init(widgets: [HomeWidget]) {
        self.widgets = widgets
    }

    private struct Lossy<Value: Decodable>: Decodable {
        let value: Value?
        init(from decoder: Decoder) throws {
            value = try? decoder.singleValueContainer().decode(Value.self)
        }
    }
}
