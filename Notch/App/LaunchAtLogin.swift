import ServiceManagement

/// What LaunchAtLogin needs from the system, so tests can substitute a fake.
protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

@Observable
final class LaunchAtLogin {
    private(set) var status: SMAppService.Status
    private(set) var lastError: String?

    @ObservationIgnored private let service: any LoginItemService

    init(service: any LoginItemService = SMAppService.mainApp) {
        self.service = service
        self.status = service.status
    }

    var isEnabled: Bool { status == .enabled }
    var needsApproval: Bool { status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    /// The user can change this in System Settings at any time, so re-read before showing it.
    func refresh() {
        status = service.status
    }
}
