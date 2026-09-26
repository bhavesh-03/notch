import Foundation
import Testing
@testable import Notch

@MainActor
struct CalendarEventTests {
    let now = Date(timeIntervalSinceReferenceDate: 10_000)

    private func event(_ title: String, startsIn start: TimeInterval, lasts duration: TimeInterval = 1800, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(id: title, title: title, start: now + start, end: now + start + duration, isAllDay: allDay)
    }

    @Test func picksTheEarliestUpcomingEvent() {
        let events = [event("Later", startsIn: 7200), event("Soon", startsIn: 600)]
        #expect(CalendarEvent.next(in: events, at: now)?.title == "Soon")
    }

    @Test func anEventInProgressWinsOverUpcomingOnes() {
        let events = [event("Soon", startsIn: 600), event("Ongoing", startsIn: -300, lasts: 1800)]
        let next = CalendarEvent.next(in: events, at: now)
        #expect(next?.title == "Ongoing")
        #expect(next?.isInProgress(at: now) == true)
    }

    @Test func finishedEventsAreSkipped() {
        let events = [event("Done", startsIn: -3600, lasts: 1800), event("Next", startsIn: 900)]
        #expect(CalendarEvent.next(in: events, at: now)?.title == "Next")
    }

    @Test func anEventEndingExactlyNowIsFinished() {
        let events = [event("JustEnded", startsIn: -1800, lasts: 1800)]
        #expect(CalendarEvent.next(in: events, at: now) == nil)
    }

    @Test func allDayEventsAreSkipped() {
        let events = [event("Holiday", startsIn: -3600, lasts: 86_400, allDay: true), event("Standup", startsIn: 1200)]
        #expect(CalendarEvent.next(in: events, at: now)?.title == "Standup")
    }

    @Test func noEventsMeansNothingToShow() {
        #expect(CalendarEvent.next(in: [], at: now) == nil)
    }
}
