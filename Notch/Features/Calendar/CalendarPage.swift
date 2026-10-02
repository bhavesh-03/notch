import SwiftUI

/// The calendar page, opened from the Calendar widget: the month's days in a strip, and the selected
/// day's events below.
struct CalendarPage: View {
    let calendar: CalendarMonitor

    @State private var month = CalendarMonth(containing: .now)
    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var events: [CalendarEvent] = []

    var body: some View {
        Group {
            if calendar.access == .granted {
                CalendarPageContent(month: $month, selected: $selected, events: events)
            } else {
                CalendarSection(calendar: calendar)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Reload when the month changes, or when Calendar's data does (the monitor's refresh time moves).
        .task(id: [month.start, calendar.evaluatedAt]) {
            events = calendar.events(from: month.interval.start, to: month.interval.end)
        }
    }
}

/// The page's layout from plain values, so it can be previewed with sample events.
struct CalendarPageContent: View {
    @Binding var month: CalendarMonth
    @Binding var selected: Date
    let events: [CalendarEvent]

    var body: some View {
        VStack(spacing: 8) {
            MonthHeader(month: $month, selected: $selected)
            MonthStrip(month: month, selected: $selected, busyDays: CalendarEvent.busyDays(in: events))
            Divider().overlay(.white.opacity(0.15))
            DayEvents(day: selected, events: CalendarEvent.events(on: selected, in: events))
        }
    }
}

/// "September 2026" with Today and ‹ ›. Changing month selects its first day (or today).
private struct MonthHeader: View {
    @Binding var month: CalendarMonth
    @Binding var selected: Date

    var body: some View {
        HStack(spacing: 6) {
            Text(month.start.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 15, weight: .semibold))
                .contentTransition(.numericText())
            Spacer()
            if !Calendar.current.isDate(selected, inSameDayAs: .now) {
                Button("Today") { show(CalendarMonth(containing: .now)) }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .glassControl(in: Capsule())
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            arrow("chevron.left", months: -1)
            arrow("chevron.right", months: 1)
        }
        .buttonStyle(.plain)
        .animation(.snappy, value: selected)
    }

    private func show(_ newMonth: CalendarMonth) {
        withAnimation(.snappy) {
            month = newMonth
            selected = newMonth.defaultDay()
        }
    }

    private func arrow(_ symbol: String, months: Int) -> some View {
        Button {
            show(month.adding(months: months))
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 22, height: 22)
                .glassControl(in: Circle())
        }
    }
}

/// Every day of the month in a row that scrolls, like a week strip that runs the whole month.
private struct MonthStrip: View {
    let month: CalendarMonth
    @Binding var selected: Date
    let busyDays: Set<Date>
    @Environment(\.notchAccent) private var accent

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(month.days(), id: \.self) { day in
                        let isSelected = day == selected
                        let isToday = Calendar.current.isDateInToday(day)
                        VStack(spacing: 3) {
                            Text(day.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(isSelected ? .black.opacity(0.6) : .white.opacity(0.4))
                            Text(day.formatted(.dateTime.day()))
                                .font(.system(size: 15, weight: isSelected || isToday ? .bold : .medium))
                                .monospacedDigit()
                                .foregroundStyle(isSelected ? .black : isToday ? accent : .white)
                            Circle()
                                .fill(busyDays.contains(day) ? (isSelected ? .black.opacity(0.6) : accent) : .clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(width: 34, height: 46)
                        .background(isSelected ? (isToday ? accent : .white) : .white.opacity(0.06), in: .rect(cornerRadius: 10, style: .continuous))
                        .id(day)
                        .onTapGesture { withAnimation(.snappy) { selected = day } }
                    }
                }
            }
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
            .onChange(of: selected) { withAnimation(.snappy) { proxy.scrollTo(selected, anchor: .center) } }
        }
        .frame(height: 46)
    }
}

/// "Today · Sunday 27 September" and that day's events.
private struct DayEvents: View {
    let day: Date
    let events: [CalendarEvent]

    private var title: String {
        let date = day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        if Calendar.current.isDateInToday(day) { return "Today · \(date)" }
        if Calendar.current.isDateInTomorrow(day) { return "Tomorrow · \(date)" }
        return date
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            if events.isEmpty {
                Text("No events")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(events) { EventRow(event: $0) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// One event: its calendar's color, time, title and length or place, and Join for calls.
/// Clicking it opens the event in Calendar.
struct EventRow: View {
    let event: CalendarEvent
    var compact = false
    /// Adds the weekday for events not today, for lists that span several days.
    var showsDay = false
    @Environment(\.notchAccent) private var accent

    private var color: Color {
        event.color.map { Color(red: $0.red, green: $0.green, blue: $0.blue) } ?? accent
    }

    private var time: String {
        let time = event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened)
        guard showsDay, !Calendar.current.isDateInToday(event.start) else { return time }
        let day = Calendar.current.isDateInTomorrow(event.start) ? "Tmrw" : event.start.formatted(.dateTime.weekday(.abbreviated))
        return event.isAllDay ? day : "\(day) \(time)"
    }

    private var detail: String? {
        if let location = event.location, !location.isEmpty, event.callURL == nil { return location }
        guard !event.isAllDay else { return nil }
        let minutes = Int(event.duration / 60)
        return minutes < 60 ? "\(minutes) min" : minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) min"
    }

    var body: some View {
        HStack(spacing: 8) {
            Capsule().fill(color).frame(width: 3)
            Text(time)
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .fixedSize()
                .frame(minWidth: compact ? 0 : 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if !compact, let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if let url = event.callURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    // Compact rows keep the room for the title: just the camera.
                    Label("Join", systemImage: "video.fill")
                        .labelStyle(CompactJoinLabelStyle(compact: compact))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, compact ? 5 : 8)
                        .padding(.vertical, 3)
                        .background(color, in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Join the call")
            }
        }
        .padding(.vertical, compact ? 3 : 4)
        .padding(.horizontal, 6)
        .frame(height: compact ? 24 : 34)
        .background(color.opacity(0.1), in: .rect(cornerRadius: 7, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { CalendarMonitor.openInCalendar(event) }
        .help("Open in Calendar")
    }
}

/// The Join label: icon and word, or just the icon in compact rows.
private struct CompactJoinLabelStyle: LabelStyle {
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        if compact {
            configuration.icon
        } else {
            HStack(spacing: 4) {
                configuration.icon
                configuration.title
            }
        }
    }
}
