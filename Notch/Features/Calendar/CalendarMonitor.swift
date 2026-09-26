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

        let previous = nextEvent
        let previousEvaluation = evaluatedAt
        nextEvent = CalendarEvent.next(in: events, at: now)
        evaluatedAt = now

        if let nextEvent, CalendarEvent.didStart(nextEvent, previous: previous, since: previousEvaluation, at: now) {
            onEventStarted?(nextEvent)
        }
        scheduleWake()
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
            isAllDay: event.isAllDay
        )
    }
}
