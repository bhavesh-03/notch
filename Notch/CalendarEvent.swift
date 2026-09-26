import Foundation

/// A calendar event reduced to what the notch needs, independent of EventKit.
struct CalendarEvent: Equatable, Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool

    /// How long before the start the event claims the notch's ears.
    static let headsUp: TimeInterval = 10 * 60
    /// How long after the start it keeps them (showing "Now").
    static let nowWindow: TimeInterval = 5 * 60

    func isInProgress(at now: Date) -> Bool {
        start <= now && now < end
    }

    /// From 10 minutes before the start until 5 minutes into the event (or its end, if sooner).
    func isImminent(at now: Date) -> Bool {
        now >= start.addingTimeInterval(-Self.headsUp)
            && now < min(start.addingTimeInterval(Self.nowWindow), end)
    }

    /// Whole minutes until the start, rounded up so it never reads "0 min" early.
    func minutesUntilStart(at now: Date) -> Int {
        max(0, Int((start.timeIntervalSince(now) / 60).rounded(.up)))
    }

    /// The next moment after `now` at which what the notch shows for this event changes.
    func nextBoundary(after now: Date) -> Date? {
        [start.addingTimeInterval(-Self.headsUp), start, start.addingTimeInterval(Self.nowWindow), end]
            .filter { $0 > now }
            .min()
    }

    /// True when the same event has gone from "not started" to "in progress" between two readings.
    static func didStart(_ current: CalendarEvent?, previous: CalendarEvent?, since then: Date, at now: Date) -> Bool {
        guard let current, let previous, current.id == previous.id else { return false }
        return !previous.isInProgress(at: then) && current.isInProgress(at: now)
    }

    /// The event to show: in progress or upcoming, earliest start first. All-day events are skipped.
    static func next(in events: [CalendarEvent], at now: Date) -> CalendarEvent? {
        events
            .filter { !$0.isAllDay && $0.end > now }
            .min { $0.start < $1.start }
    }
}
