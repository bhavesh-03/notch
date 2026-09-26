import Foundation

/// A calendar event reduced to what the notch needs, independent of EventKit.
struct CalendarEvent: Equatable, Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool

    func isInProgress(at now: Date) -> Bool {
        start <= now && now < end
    }

    /// The event to show: in progress or upcoming, earliest start first. All-day events are skipped.
    static func next(in events: [CalendarEvent], at now: Date) -> CalendarEvent? {
        events
            .filter { !$0.isAllDay && $0.end > now }
            .min { $0.start < $1.start }
    }
}
