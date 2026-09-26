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

@MainActor
struct CalendarTimingTests {
    let start = Date(timeIntervalSinceReferenceDate: 100_000)
    var event: CalendarEvent {
        CalendarEvent(id: "standup", title: "Standup", start: start, end: start + 1800, isAllDay: false)
    }

    @Test(arguments: [
        (-3600.0, false), (-601.0, false), (-600.0, true), (-60.0, true),
        (0.0, true), (299.0, true), (300.0, false), (1799.0, false),
    ])
    func imminentFromTenMinutesBeforeToFiveAfter(offset: TimeInterval, imminent: Bool) {
        #expect(event.isImminent(at: start + offset) == imminent)
    }

    @Test func shortEventStopsBeingImminentWhenItEnds() {
        let short = CalendarEvent(id: "s", title: "Quick sync", start: start, end: start + 120, isAllDay: false)
        #expect(short.isImminent(at: start + 60))
        #expect(!short.isImminent(at: start + 120))
    }

    @Test(arguments: [(-600.0, 10), (-599.0, 10), (-540.0, 9), (-1.0, 1), (0.0, 0), (60.0, 0)])
    func minutesUntilStartRoundsUp(offset: TimeInterval, minutes: Int) {
        #expect(event.minutesUntilStart(at: start + offset) == minutes)
    }

    @Test func boundariesAreVisitedInOrder() {
        var now = start - 3600
        var visited: [TimeInterval] = []
        while let next = event.nextBoundary(after: now) {
            visited.append(next.timeIntervalSince(start))
            now = next
        }
        #expect(visited == [-600, 0, 300, 1800])
    }

    @Test func startIsDetectedOnceForTheSameEvent() {
        let before = start - 30
        let after = start + 30
        #expect(CalendarEvent.didStart(event, previous: event, since: before, at: after))
        #expect(!CalendarEvent.didStart(event, previous: event, since: after, at: after + 60), "already in progress")
        #expect(!CalendarEvent.didStart(event, previous: nil, since: before, at: after), "no previous reading, e.g. launch mid-meeting")
    }

    @Test func aDifferentEventStartingIsNotReportedAsThisOneStarting() {
        let other = CalendarEvent(id: "other", title: "Other", start: start - 3600, end: start - 60, isAllDay: false)
        #expect(!CalendarEvent.didStart(event, previous: other, since: start - 30, at: start + 30))
    }
}
