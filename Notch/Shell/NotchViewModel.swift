import SwiftUI

@Observable
final class NotchViewModel {

    enum Presentation: Equatable {
        case collapsed
        case expanded
        case activity(any NotchModule)

        static func == (lhs: Presentation, rhs: Presentation) -> Bool {
            switch (lhs, rhs) {
            case (.collapsed, .collapsed), (.expanded, .expanded):
                true
            case let (.activity(a), .activity(b)):
                a === b
            default:
                false
            }
        }
    }

    var presentation: Presentation = .collapsed {
        didSet { onExpandedChange?(isExpanded) }
    }
    var isExpanded: Bool { presentation == .expanded }

    @ObservationIgnored var onExpandedChange: ((Bool) -> Void)?
    private var collapseTask: Task<Void, Never>?
    private var activityTask: Task<Void, Never>?
    @ObservationIgnored private var isHeldOpen = false
    var geometry: NotchGeometry
    let battery = BatteryMonitor()
    let timer = TimerController()
    let calendar = CalendarMonitor()
    let shelf = ShelfStore()
    let launchAtLogin = LaunchAtLogin()
    var modules: [any NotchModule] { [battery, timer, calendar, shelf] }

    @ObservationIgnored private let reduceMotion: () -> Bool

    init(
        geometry: NotchGeometry,
        reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    ) {
        self.geometry = geometry
        self.reduceMotion = reduceMotion
    }

    /// Springs normally; a short, bounce-free ease when the user has asked for less motion.
    var activityAnimation: Animation {
        NotchMotion.activityOpen(reduceMotion: reduceMotion())
    }

    var activityCloseAnimation: Animation {
        NotchMotion.activityClose(reduceMotion: reduceMotion())
    }

    func expand() {
        collapseTask?.cancel()
        collapseTask = nil
        activityTask?.cancel()
        activityTask = nil

        guard !isExpanded else { return }
        withAnimation(.snappy) {
            presentation = .expanded
        }
    }

    /// Keeps the notch expanded regardless of the pointer, e.g. while its menu is open.
    func holdOpen() {
        isHeldOpen = true
        collapseTask?.cancel()
        collapseTask = nil
    }

    func releaseHold() {
        isHeldOpen = false
    }

    func scheduleCollapse() {
        guard isExpanded, !isHeldOpen, collapseTask == nil else { return }

        collapseTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            withAnimation(.snappy) {
                presentation = .collapsed
            }
            collapseTask = nil
        }
    }

    func showActivity(from module: any NotchModule, for duration: Duration = .seconds(2.5)) {
        guard !isExpanded else { return }

        activityTask?.cancel()
        withAnimation(activityAnimation) {
            presentation = .activity(module)
        }

        activityTask = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }

            if case .activity = presentation {
                withAnimation(activityCloseAnimation) {
                    presentation = .collapsed
                }
            }
            activityTask = nil
        }
    }
}
