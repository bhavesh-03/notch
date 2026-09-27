import Testing
@testable import Notch

@MainActor
struct AppVersionTests {
    @Test func showsVersionAndBuild() {
        #expect(AppVersion.display(version: "1.1.0", build: "72") == "Notch 1.1.0 (72)")
    }

    @Test func omitsAMissingBuild() {
        #expect(AppVersion.display(version: "1.1.0", build: nil) == "Notch 1.1.0")
        #expect(AppVersion.display(version: "1.1.0", build: "") == "Notch 1.1.0")
    }

    @Test func aMissingVersionIsVisibleRatherThanBlank() {
        #expect(AppVersion.display(version: nil, build: "5") == "Notch ? (5)")
    }

    @Test func theRunningAppHasAVersion() {
        #expect(AppVersion.current.hasPrefix("Notch 1."))
    }
}
