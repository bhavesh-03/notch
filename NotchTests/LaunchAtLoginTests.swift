import ServiceManagement
import Testing
@testable import Notch

@MainActor
struct LaunchAtLoginTests {
    struct Failure: Error {}

    final class FakeService: LoginItemService {
        var status: SMAppService.Status = .notRegistered
        var statusAfterRegister: SMAppService.Status = .enabled
        var failure: Error?

        func register() throws {
            if let failure { throw failure }
            status = statusAfterRegister
        }

        func unregister() throws {
            if let failure { throw failure }
            status = .notRegistered
        }
    }

    @Test func startsFromTheSystemStatus() {
        let service = FakeService()
        service.status = .enabled
        #expect(LaunchAtLogin(service: service).isEnabled)
    }

    @Test func enablingAndDisablingUpdateTheStatus() {
        let service = FakeService()
        let launch = LaunchAtLogin(service: service)
        launch.setEnabled(true)
        #expect(launch.isEnabled)
        launch.setEnabled(false)
        #expect(!launch.isEnabled)
        #expect(launch.lastError == nil)
    }

    @Test func registrationThatNeedsApprovalIsReported() {
        let service = FakeService()
        service.statusAfterRegister = .requiresApproval
        let launch = LaunchAtLogin(service: service)
        launch.setEnabled(true)
        #expect(!launch.isEnabled)
        #expect(launch.needsApproval)
    }

    @Test func aFailureKeepsTheRealStatusAndRecordsTheError() {
        let service = FakeService()
        service.failure = Failure()
        let launch = LaunchAtLogin(service: service)
        launch.setEnabled(true)
        #expect(!launch.isEnabled)
        #expect(launch.lastError != nil)
    }

    @Test func refreshPicksUpChangesMadeInSystemSettings() {
        let service = FakeService()
        let launch = LaunchAtLogin(service: service)
        service.status = .enabled
        #expect(!launch.isEnabled)
        launch.refresh()
        #expect(launch.isEnabled)
    }
}
