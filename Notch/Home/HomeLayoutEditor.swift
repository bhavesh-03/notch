import SwiftUI

/// Arranges Home's widgets: drag one to move it, drag its corner to resize, tap − to remove.
///
/// Shows each widget at its saved size with the empty cells outlined, so what you arrange is what's
/// saved; Home itself then fills any gaps. Used in the notch (with the live widgets as tiles) and in
/// Settings (with labelled tiles).
struct HomeLayoutEditor<Tile: View>: View {
    @Bindable var settings: NotchSettings
    let columns: Int
    var spacing: CGFloat = 8
    var cornerRadius: CGFloat = 14
    @ViewBuilder let tile: (HomeWidget) -> Tile

    @State private var dragging: Drag?
    @State private var resizing: Resize?
    @State private var wobble = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Drag {
        let kind: HomeWidgetKind
        /// Where the card's top-left was when the drag began, and how far it's moved since.
        let origin: CGPoint
        var translation: CGSize
    }

    private struct Resize {
        let kind: HomeWidgetKind
        let startSize: CGSize
        var translation: CGSize
    }

    private var visible: Set<HomeWidgetKind> {
        Set(HomeWidgetKind.allCases.filter { settings.isVisible($0.feature) })
    }

    private var shownLayout: HomeLayout {
        HomeLayout(widgets: settings.homeLayout.widgets.filter { visible.contains($0.kind) })
    }

    var body: some View {
        let arrangement = shownLayout.arranged(columns: columns)
        GeometryReader { proxy in
            let cell = CGSize(
                width: (proxy.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns),
                height: (proxy.size.height - spacing * CGFloat(HomeLayout.rows - 1)) / CGFloat(HomeLayout.rows)
            )
            // One container, so cards blend as they pass each other while dragging. Its spacing is below
            // the gap between cards, so they never merge at rest.
            GlassGroup(spacing: spacing / 2) {
                ZStack(alignment: .topLeading) {
                    emptyCells(cell: cell, placed: arrangement.placed)
                    ForEach(arrangement.placed, id: \.widget.id) { placement in
                        card(for: placement, cell: cell)
                    }
                }
            }
            .coordinateSpace(.named(Self.space))
        }
        .animation(.spring(duration: 0.4, bounce: 0.2), value: settings.homeLayout)
        .onAppear { wobble = true }
    }

    private static var space: String { "HomeLayoutEditor" }

    // MARK: - Pieces

    /// Faint outlines of the cells no widget covers, so the gaps are visible while arranging.
    private func emptyCells(cell: CGSize, placed: [HomeLayout.Placement]) -> some View {
        let empty = (0..<(columns * HomeLayout.rows)).filter { index in
            !placed.contains { $0.covers(column: index / HomeLayout.rows, row: index % HomeLayout.rows) }
        }
        return ForEach(empty, id: \.self) { index in
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: cell.width, height: cell.height)
                .offset(x: CGFloat(index / HomeLayout.rows) * (cell.width + spacing),
                        y: CGFloat(index % HomeLayout.rows) * (cell.height + spacing))
        }
    }

    private func frame(of placement: HomeLayout.Placement, cell: CGSize) -> CGRect {
        CGRect(
            x: CGFloat(placement.column) * (cell.width + spacing),
            y: CGFloat(placement.row) * (cell.height + spacing),
            width: cell.width * CGFloat(placement.columnSpan) + spacing * CGFloat(placement.columnSpan - 1),
            height: cell.height * CGFloat(placement.rowSpan) + spacing * CGFloat(placement.rowSpan - 1)
        )
    }

    private func card(for placement: HomeLayout.Placement, cell: CGSize) -> some View {
        let kind = placement.widget.kind
        let slot = frame(of: placement, cell: cell)
        let isDragged = dragging?.kind == kind
        let isResized = resizing?.kind == kind
        // A dragged card follows the pointer; a resized one follows the handle until it snaps.
        let size = isResized ? resizedSize(cell: cell) : slot.size
        let position = isDragged ? dragPosition() : slot.origin
        let index = settings.homeLayout.widgets.firstIndex { $0.kind == kind } ?? 0

        return tile(placement.widget)
            .frame(width: size.width, height: size.height)
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .glassSurface(in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(isDragged ? 0.5 : 0.22), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) { removeBadge(kind) }
            .overlay(alignment: .bottomTrailing) { resizeHandle(kind, slot: slot.size, cell: cell) }
            .scaleEffect(isDragged ? 1.04 : 1)
            .shadow(color: .black.opacity(isDragged ? 0.5 : 0), radius: 10, y: 4)
            .rotationEffect(.degrees(reduceMotion || isDragged || isResized ? 0 : (wobble ? 1 : -1) * (index.isMultiple(of: 2) ? 0.9 : -0.9)))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.14).repeatForever(autoreverses: true), value: wobble)
            .offset(x: position.x, y: position.y)
            .zIndex(isDragged || isResized ? 1 : 0)
            .gesture(moveGesture(kind, slot: slot, cell: cell))
    }

    private func removeBadge(_ kind: HomeWidgetKind) -> some View {
        Button {
            settings.homeLayout.remove(kind)
        } label: {
            Image(systemName: "minus")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .glassControl(in: Circle())
        }
        .buttonStyle(.plain)
        .offset(x: -4, y: -4)
        .help("Remove \(kind.title)")
    }

    private func resizeHandle(_ kind: HomeWidgetKind, slot: CGSize, cell: CGSize) -> some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .glassControl(in: Circle())
            .offset(x: 3, y: 3)
            .contentShape(Circle().inset(by: -6))
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        if resizing?.kind != kind {
                            resizing = Resize(kind: kind, startSize: slot, translation: .zero)
                        }
                        resizing?.translation = value.translation
                        // Snap the saved size as the handle crosses half a cell.
                        let size = resizedSize(cell: cell)
                        let columns = Int(((size.width + spacing) / (cell.width + spacing)).rounded())
                        let rows = Int(((size.height + spacing) / (cell.height + spacing)).rounded())
                        settings.homeLayout.resize(kind, to: WidgetSize(columns: columns, rows: rows))
                    }
                    .onEnded { _ in resizing = nil }
            )
            .help("Drag to resize")
    }

    /// The card's size while its handle is dragged: its starting size plus the drag, within one cell
    /// and two cells each way.
    private func resizedSize(cell: CGSize) -> CGSize {
        guard let resizing else { return .zero }
        let maxWidth = cell.width * 2 + spacing
        let maxHeight = cell.height * 2 + spacing
        return CGSize(
            width: min(max(resizing.startSize.width + resizing.translation.width, cell.width), maxWidth),
            height: min(max(resizing.startSize.height + resizing.translation.height, cell.height), maxHeight)
        )
    }

    private func dragPosition() -> CGPoint {
        guard let dragging else { return .zero }
        return CGPoint(x: dragging.origin.x + dragging.translation.width, y: dragging.origin.y + dragging.translation.height)
    }

    private func moveGesture(_ kind: HomeWidgetKind, slot: CGRect, cell: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if dragging?.kind != kind {
                    dragging = Drag(kind: kind, origin: slot.origin, translation: .zero)
                }
                dragging?.translation = value.translation
                // The cell under the pointer decides where the widget goes; the rest repack around it.
                let column = Int(value.location.x / (cell.width + spacing))
                let row = Int(value.location.y / (cell.height + spacing))
                guard (0..<columns).contains(column), (0..<HomeLayout.rows).contains(row) else { return }
                settings.homeLayout.move(kind, toColumn: column, row: row, columns: columns, visible: visible)
            }
            .onEnded { _ in
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) { dragging = nil }
            }
    }
}

/// Add Widget: the kinds not on Home yet. Kinds whose feature is off are listed but disabled.
struct AddWidgetMenu: View {
    let settings: NotchSettings

    private var missing: [HomeWidgetKind] {
        HomeWidgetKind.allCases.filter { !settings.homeLayout.contains($0) }
    }

    var body: some View {
        Menu {
            ForEach(missing) { kind in
                Button {
                    settings.homeLayout.add(kind)
                } label: {
                    Label {
                        Text(kind.title)
                    } icon: {
                        NotchIcon(name: kind.symbol)
                    }
                }
                .disabled(!settings.isVisible(kind.feature))
            }
            if missing.isEmpty {
                Text("Every widget is on Home")
            }
        } label: {
            Label("Add Widget", systemImage: "plus")
        }
    }
}

/// How many widgets don't fit at this width, if any.
struct OverflowNote: View {
    let settings: NotchSettings
    let columns: Int

    var body: some View {
        let shown = HomeLayout(widgets: settings.homeLayout.widgets.filter { settings.isVisible($0.kind.feature) })
        let hidden = shown.arranged(columns: columns).overflow
        if !hidden.isEmpty {
            Text("\(hidden.map(\.kind.title).formatted()) \(hidden.count == 1 ? "doesn't" : "don't") fit at this width")
        }
    }
}
