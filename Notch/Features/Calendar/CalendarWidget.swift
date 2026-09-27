import SwiftUI

/// What's coming up, on Home: the next event when small, a list when there's room. Tapping it opens
/// the calendar page (a Join button still joins the call).
struct CalendarWidget: View {
    let calendar: CalendarMonitor
    let size: WidgetSize
    @Environment(\.openNotchPage) private var openPage

    var body: some View {
        if calendar.access == .granted {
            CalendarWidgetContent(upcoming: calendar.upcoming, size: size)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture { openPage(calendar) }
                .help("Open the calendar")
        } else {
            access
        }
    }

    @ViewBuilder
    private var access: some View {
        switch size {
        case .tall, .large:
            CalendarSection(calendar: calendar)
        case .small, .wide:
            VStack(spacing: 4) {
                Image(systemName: "calendar")
                Button("Show events") {
                    Task { await calendar.requestAccess() }
                }
                .buttonStyle(.plain)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

/// The widget's layout from plain values, so it can be previewed with sample events.
struct CalendarWidgetContent: View {
    let upcoming: [CalendarEvent]
    let size: WidgetSize
    @Environment(\.notchAccent) private var accent

    var body: some View {
        if let next = upcoming.first {
            switch size {
            case .small:
                VStack(alignment: .leading, spacing: 1) {
                    StartLabel(event: next)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                    Text(next.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                }
            case .wide:
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        StartLabel(event: next)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                        Text(next.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                        if upcoming.count > 1 {
                            Text("\(upcoming.count - 1) more coming up")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    Spacer(minLength: 0)
                    JoinButton(event: next)
                }
            case .tall:
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(upcoming.prefix(3)) { event in
                        VStack(alignment: .leading, spacing: 0) {
                            StartLabel(event: event)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(accent)
                            Text(event.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                    }
                }
            case .large:
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(upcoming.prefix(3)) { event in
                        EventRow(event: event, compact: true, showsDay: true)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "calendar")
                    .font(size == .small ? .body : .title3)
                Text("Nothing coming up")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

}

/// "Now", "10:00 AM", "Tue 10:00 AM" or "All day", updating each minute.
struct StartLabel: View {
    let event: CalendarEvent

    var body: some View {
        TimelineView(.everyMinute) { context in
            Text(Self.text(for: event, at: context.date))
                .lineLimit(1)
        }
    }

    static func text(for event: CalendarEvent, at now: Date) -> String {
        if event.isInProgress(at: now) { return event.isAllDay ? "Today" : "Now" }
        let calendar = Calendar.current
        let day = calendar.isDate(event.start, inSameDayAs: now) ? nil
            : calendar.isDateInTomorrow(event.start) ? "Tomorrow"
            : event.start.formatted(.dateTime.weekday(.abbreviated))
        let time = event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened)
        return [day, time].compactMap { $0 }.joined(separator: " · ")
    }
}

/// Join, for an event with a call link.
private struct JoinButton: View {
    let event: CalendarEvent
    @Environment(\.notchAccent) private var accent

    var body: some View {
        if let url = event.callURL {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Image(systemName: "video.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 30, height: 30)
                    .background(accent, in: Circle())
            }
            .buttonStyle(.plain)
            .help("Join the call")
        }
    }
}
