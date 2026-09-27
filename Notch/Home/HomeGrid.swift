import SwiftUI

/// Home's widgets, packed into a grid whose column count follows the notch's width.
struct HomeGrid: View {
    let viewModel: NotchViewModel

    static let spacing: CGFloat = 8

    var body: some View {
        let layout = HomeLayout(widgets: viewModel.homeWidgets)
        let (placed, columns) = layout.filled(columns: HomeLayout.columns(forWidth: viewModel.geometry.expandedWidth))

        GeometryReader { proxy in
            let cell = CGSize(
                width: (proxy.size.width - Self.spacing * CGFloat(columns - 1)) / CGFloat(columns),
                height: (proxy.size.height - Self.spacing * CGFloat(HomeLayout.rows - 1)) / CGFloat(HomeLayout.rows)
            )
            ZStack(alignment: .topLeading) {
                ForEach(placed, id: \.widget.id) { placement in
                    WidgetCard {
                        HomeWidgetView(kind: placement.widget.kind, size: placement.displaySize, viewModel: viewModel)
                    }
                    .frame(
                        width: cell.width * CGFloat(placement.columnSpan) + Self.spacing * CGFloat(placement.columnSpan - 1),
                        height: cell.height * CGFloat(placement.rowSpan) + Self.spacing * CGFloat(placement.rowSpan - 1)
                    )
                    .offset(
                        x: CGFloat(placement.column) * (cell.width + Self.spacing),
                        y: CGFloat(placement.row) * (cell.height + Self.spacing)
                    )
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.25), value: placed)
        .animation(.spring(duration: 0.5, bounce: 0.25), value: columns)
    }
}

/// The rounded tile every widget sits on.
struct WidgetCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white.opacity(0.07), in: .rect(cornerRadius: 14, style: .continuous))
            // A widget never grows past its cell, whatever its content asks for.
            .clipShape(.rect(cornerRadius: 14, style: .continuous))
    }
}

/// The right view for a widget at the size it's drawn at.
struct HomeWidgetView: View {
    let kind: HomeWidgetKind
    let size: WidgetSize
    let viewModel: NotchViewModel

    var body: some View {
        switch kind {
        case .battery: BatteryWidget(monitor: viewModel.battery, size: size)
        case .timer: TimerWidget(timer: viewModel.timer, size: size)
        case .calendar: CalendarWidget(calendar: viewModel.calendar, size: size)
        case .cpu, .gpu, .memory, .temperature:
            StatsWidget(kind: kind, size: size, monitor: viewModel.stats)
        }
    }
}
