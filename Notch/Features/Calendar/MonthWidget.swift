import SwiftUI

/// A calendar glance that works even when event access has not been granted.
struct MonthWidget: View {
    let calendar: CalendarMonitor
    let size: WidgetSize
    @Environment(\.calendar) private var dateCalendar
    @Environment(\.notchAccent) private var accent
    @Environment(\.openNotchPage) private var openPage

    var body: some View {
        Button { openPage(calendar) } label: {
            TimelineView(.everyMinute) { context in
                if size == .large {
                    monthGrid(today: context.date)
                } else {
                    dateGlance(today: context.date)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Today’s date")
        .accessibilityValue(Date.now.formatted(date: .complete, time: .omitted))
        .accessibilityHint("Opens the calendar")
        .help("Open Calendar")
    }

    private func dateGlance(today: Date) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(today.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)
            Text(today.formatted(.dateTime.month(.abbreviated).day()))
                .font(.callout.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func monthGrid(today: Date) -> some View {
        let month = CalendarMonth(containing: today, calendar: dateCalendar)
        let weeks = month.weeks(calendar: dateCalendar)
        let weekdays = CalendarMonth.weekdaySymbols(calendar: dateCalendar)
        return GeometryReader { proxy in
            let rowHeight = max(1, (proxy.size.height - 13) / CGFloat(weeks.count + 1))
            VStack(alignment: .leading, spacing: 0) {
                Text(today.formatted(.dateTime.month(.wide)))
                    .font(.caption2.weight(.semibold))
                    .frame(height: 13)
                HStack(spacing: 0) {
                    ForEach(weekdays.indices, id: \.self) { index in
                        Text(weekdays[index])
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(height: rowHeight)
                ForEach(weeks.indices, id: \.self) { index in
                    HStack(spacing: 0) {
                        ForEach(weeks[index], id: \.self) { day in
                            let isToday = dateCalendar.isDate(day, inSameDayAs: today)
                            Text("\(dateCalendar.component(.day, from: day))")
                                .font(.system(size: 9, weight: isToday ? .bold : .medium).monospacedDigit())
                                .foregroundStyle(isToday ? .black : .white.opacity(month.contains(day, calendar: dateCalendar) ? 0.92 : 0.28))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(width: max(16, rowHeight), height: rowHeight)
                                .background(isToday ? accent : .clear, in: Circle())
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: rowHeight)
                }
            }
            .accessibilityHidden(true)
        }
    }
}
