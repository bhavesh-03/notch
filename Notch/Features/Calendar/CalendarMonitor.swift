import AppKit
import EventKit

@Observable
final class CalendarMonitor {
    enum Access {
        case notDetermined
        case granted
        case denied
    }

    private(set) var access: Access
    private(set) var nextEvent: CalendarEvent?
    /// What's coming up, soonest first, for the bigger widgets: the rest of today and the next few days.
    private(set) var upcoming: [CalendarEvent] = []
    /// When the event was last evaluated; observed, so views re-render at each scheduled wake-up.
    private(set) var evaluatedAt = Date()

    @ObservationIgnored var onEventStarted: ((CalendarEvent) -> Void)?
    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var changeTask: Task<Void, Never>?
    @ObservationIgnored private var wakeTask: Task<Void, Never>?

    init() {
        access = Self.currentAccess()
        if access == .granted {
            startObserving()
        }
    }

    func requestAccess() async {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        access = granted ? .granted : .denied
        if granted {
            startObserving()
        }
    }

    func refresh() {
        guard access == .granted else { return }
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now.addingTimeInterval(-12 * 3600),
            end: now.addingTimeInterval(24 * 3600),
            calendars: nil
        )
        let events = store.events(matching: predicate).map { CalendarEvent($0) }
        upcoming = self.events(from: now, to: now.addingTimeInterval(7 * 24 * 3600))
            .filter { $0.end > now }
            .sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
            .prefix(8)
            .map { $0 }

        let previous = nextEvent
        let previousEvaluation = evaluatedAt
        nextEvent = CalendarEvent.next(in: events, at: now)
        evaluatedAt = now

        if let nextEvent, CalendarEvent.didStart(nextEvent, previous: previous, since: previousEvaluation, at: now) {
            onEventStarted?(nextEvent)
        }
        scheduleWake()
    }

    /// Events overlapping a range, earliest first; for the calendar page's month and day.
    func events(from start: Date, to end: Date) -> [CalendarEvent] {
        guard access == .granted else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .map { CalendarEvent($0) }
            .sorted { $0.start < $1.start }
    }

    /// Opens the event in the Calendar app.
    static func openInCalendar(_ event: CalendarEvent) {
        let identifier = event.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? event.id
        if let url = URL(string: "ical://ekevent/\(identifier)?method=show&options=more") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Sleeps until the next moment the display should change, instead of polling.
    private func scheduleWake() {
        wakeTask?.cancel()
        let wakeAt = nextEvent?.nextBoundary(after: evaluatedAt) ?? evaluatedAt.addingTimeInterval(3600)
        let delay = wakeAt.timeIntervalSince(evaluatedAt) + 0.5

        wakeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    private func startObserving() {
        refresh()
        changeTask?.cancel()
        changeTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                self?.refresh()
            }
        }
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }
}

private extension CalendarEvent {
    init(_ event: EKEvent) {
        self.init(
            id: event.eventIdentifier ?? UUID().uuidString,
            title: event.title ?? "Untitled",
            start: event.startDate,
            end: event.endDate,
            isAllDay: event.isAllDay,
            color: event.calendar?.cgColor.flatMap { EventColor($0) },
            location: event.location,
            callURL: CallLink.find(in: [event.url?.absoluteString, event.location, event.notes])
        )
    }
}

private extension CalendarEvent.EventColor {
    init?(_ color: CGColor) {
        guard let rgb = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let c = rgb.components, c.count >= 3 else { return nil }
        self.init(red: c[0], green: c[1], blue: c[2])
    }
}
