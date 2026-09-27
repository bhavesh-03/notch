import SwiftUI

/// The next event on Home. (Calendar gets a bigger redesign later; this keeps today's content.)
struct CalendarWidget: View {
    let calendar: CalendarMonitor
    let size: WidgetSize

    var body: some View {
        switch size {
        case .tall, .large:
            CalendarSection(calendar: calendar)
        case .small, .wide:
            if calendar.access == .granted {
                compact
            } else {
                // Asking for access needs the full explanation; the small sizes show just the button.
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

    private var compact: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(size == .wide ? .title3 : .body)
            VStack(alignment: .leading, spacing: 1) {
                if let event = calendar.nextEvent {
                    Text(event.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(size == .wide ? 2 : 1)
                    TimelineView(.everyMinute) { context in
                        Text(event.isInProgress(at: context.date) ? "Now" : event.start.formatted(date: .omitted, time: .shortened))
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text("Nothing coming up")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
