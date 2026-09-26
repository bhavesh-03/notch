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

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var changeTask: Task<Void, Never>?

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
        nextEvent = CalendarEvent.next(in: events, at: now)
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
