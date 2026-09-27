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
    @ObservationIgnored private var expandTask: Task<Void, Never>?
    private var activityTask: Task<Void, Never>?
    @ObservationIgnored private var isHeldOpen = false
    var geometry: NotchGeometry
    let battery = BatteryMonitor()
    let timer: TimerController
    let calendar = CalendarMonitor()
    let shelf = ShelfStore()
    let nowPlaying = NowPlayingMonitor()
    let mirror = MirrorCamera()
    let launchAtLogin = LaunchAtLogin()
    let settings: NotchSettings

    /// Asks the app to show the settings window (the view can't reach the app delegate itself).
    @ObservationIgnored var onOpenSettings: (() -> Void)?
    var hasHeadline: Bool { modules.headliner != nil }

    /// The module whose tab is open, or nil for Home.
    private(set) var selectedTab: ObjectIdentifier?

    var tabModules: [any NotchModule] { modules.filter { $0.tab != nil } }

    var selectedTabModule: (any NotchModule)? {
        tabModules.first { ObjectIdentifier($0) == selectedTab }
    }

    /// The headline (media player) belongs to Home only.
    var showsHeadline: Bool { selectedTab == nil && hasHeadline }

    /// The expanded notch is tall for the player row on Home, or for a page that asks for it.
    var isTall: Bool { showsHeadline || selectedTabModule?.wantsTallPage == true }

    @ObservationIgnored private var keepsTallHover = false

    /// Whether hover should use the tall shape. When the notch shrinks away from a pointer that
    /// hasn't moved (e.g. pressing Start Timer near the bottom), that isn't the user leaving: the
    /// tall shape keeps counting for as long as the pointer stays inside it. Once it moves out,
    /// normal hover resumes. (Based on where the pointer is, not on a timeout.)
    func hoverIsTall(pointerInTallShape: Bool) -> Bool {
        if isTall {
            keepsTallHover = true
            return true
        }
        if keepsTallHover, pointerInTallShape { return true }
        keepsTallHover = false
        return false
    }

    func select(tab module: (any NotchModule)?) {
        selectedTab = module.map { ObjectIdentifier($0) }
    }

    /// A file is being dragged onto the notch: open whichever tab takes file drops.
    func showDropTarget() {
        guard let target = tabModules.first(where: { $0.acceptsFileDrops }) else { return }
        select(tab: target)
    }
    /// Every module, whether or not the user shows it.
    var allModules: [any NotchModule] { [battery, timer, calendar, shelf, nowPlaying, mirror] }

    /// The modules the user shows, in the order they chose. Everything in the notch reads this, so
    /// a hidden feature disappears from the ears, Home, the tabs and activities alike.
    var modules: [any NotchModule] {
        let all = allModules
        return settings.visibleFeatures.compactMap { feature in all.first { $0.feature == feature } }
    }

    @ObservationIgnored private let reduceMotion: () -> Bool

    init(
        geometry: NotchGeometry,
        settings: NotchSettings = .ephemeral(),
        reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    ) {
        self.geometry = geometry
        self.settings = settings
        self.reduceMotion = reduceMotion
        timer = TimerController(duration: settings.timerLength)
        syncTimerLength()
    }

    /// The ruler and Settings edit the same length. Each side only reports a real change, so an
    /// update goes around once and stops (ruler → settings → timer: already that length, no report).
    private func syncTimerLength() {
        timer.onDurationChanged = { [settings] seconds in
            settings.timerLength = seconds
        }
        settings.onTimerLengthChanged = { [timer] seconds in
            timer.setDuration(seconds: seconds)
        }
    }

    /// Springs normally; a short, bounce-free ease when the user has asked for less motion.
    var activityAnimation: Animation {
        NotchMotion.activityOpen(reduceMotion: reduceMotion(), speed: settings.animationSpeed.multiplier)
    }

    var activityCloseAnimation: Animation {
        NotchMotion.activityClose(reduceMotion: reduceMotion(), speed: settings.animationSpeed.multiplier)
    }

    /// The pointer is over the notch. Opens it after the user's hover delay; a file drag opens it
    /// right away, since the user is already on their way to drop.
    func pointerEntered(isDraggingFile: Bool = false) {
        collapseTask?.cancel()
        collapseTask = nil

        let delay = settings.hoverDelay
        guard !isExpanded, !isDraggingFile, delay > 0 else {
            cancelPendingExpand()
            expand()
            return
        }
        guard expandTask == nil else { return }   // already counting down
        expandTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            expandTask = nil
            expand()
        }
    }

    /// The pointer left the notch: a pending open is called off, and an open notch closes soon.
    func pointerLeft() {
        cancelPendingExpand()
        scheduleCollapse()
    }

    private func cancelPendingExpand() {
        expandTask?.cancel()
        expandTask = nil
    }

    func expand() {
        collapseTask?.cancel()
        collapseTask = nil
        activityTask?.cancel()
        activityTask = nil

        guard !isExpanded else { return }
        withAnimation(NotchMotion.expandCollapse(speed: settings.animationSpeed.multiplier)) {
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

            withAnimation(NotchMotion.expandCollapse(speed: settings.animationSpeed.multiplier)) {
                presentation = .collapsed
                selectedTab = nil
                keepsTallHover = false
            }
            collapseTask = nil
        }
    }

    func showActivity(from module: any NotchModule, for duration: Duration = .seconds(2.5)) {
        guard !isExpanded, settings.isVisible(module.feature), settings.showsPopUp(for: module.feature) else { return }

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
                    selectedTab = nil
                }
            }
            activityTask = nil
        }
    }
}
