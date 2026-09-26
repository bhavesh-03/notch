import SwiftUI

extension CalendarMonitor: NotchModule {
    var earPriority: Int? { nil }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        switch placement {
        case .expanded:
            CalendarSection(calendar: self)
        case .leadingEar, .trailingEar, .pill, .activityLeading, .activityTrailing, .activityDetail:
            EmptyView()
        }
    }
}

private struct CalendarSection: View {
    let calendar: CalendarMonitor

    var body: some View {
        VStack(spacing: 6) {
            switch calendar.access {
            case .notDetermined:
                Image(systemName: "calendar")
                    .font(.title)
                Button("Show next event") {
                    Task { await calendar.requestAccess() }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.15), in: Capsule())

            case .denied:
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.title)
                Text("Calendar access is off")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Button("Open Settings") {
                    NSWorkspace.shared.open(Self.privacySettingsURL)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.blue)

            case .granted:
                if let event = calendar.nextEvent {
                    EventSummary(event: event)
                } else {
                    Image(systemName: "calendar")
                        .font(.title)
                    Text("Nothing coming up")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(width: 110)
    }

    private static let privacySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
    )!
}

private struct EventSummary: View {
    let event: CalendarEvent

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.title2)
            Text(event.title)
                .font(.callout.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            TimelineView(.everyMinute) { context in
                Text(event.isInProgress(at: context.date) ? "Now" : event.start.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}
