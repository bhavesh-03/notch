import Foundation

/// A month for the calendar page's strip: its days and the range to load events for.
struct CalendarMonth: Equatable {
    /// Midnight on the first of the month.
    let start: Date

    init(containing date: Date, calendar: Calendar = .current) {
        start = calendar.dateInterval(of: .month, for: date)!.start
    }

    /// Every day of the month, as midnights.
    func days(calendar: Calendar = .current) -> [Date] {
        let count = calendar.range(of: .day, in: .month, for: start)!.count
        return (0..<count).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }

    var interval: DateInterval {
        Calendar.current.dateInterval(of: .month, for: start)!
    }

    func adding(months: Int, calendar: Calendar = .current) -> CalendarMonth {
        CalendarMonth(containing: calendar.date(byAdding: .month, value: months, to: start)!, calendar: calendar)
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(date, equalTo: start, toGranularity: .month)
    }

    /// The day to select on arriving at this month: today in the current month, else the 1st.
    func defaultDay(today: Date = .now, calendar: Calendar = .current) -> Date {
        contains(today, calendar: calendar) ? calendar.startOfDay(for: today) : start
    }
}

extension CalendarEvent {
    /// The events on a day (midnight), all-day ones first, then by start time.
    static func events(on day: Date, in events: [CalendarEvent], calendar: Calendar = .current) -> [CalendarEvent] {
        let end = calendar.date(byAdding: .day, value: 1, to: day)!
        return events
            .filter { $0.start < end && $0.end > day }
            .sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
    }

    /// Every day (midnight) that has at least one event; a multi-day event marks each day it covers.
    static func busyDays(in events: [CalendarEvent], calendar: Calendar = .current) -> Set<Date> {
        var days = Set<Date>()
        for event in events {
            var day = calendar.startOfDay(for: event.start)
            while day < event.end {
                days.insert(day)
                day = calendar.date(byAdding: .day, value: 1, to: day)!
            }
        }
        return days
    }
}
