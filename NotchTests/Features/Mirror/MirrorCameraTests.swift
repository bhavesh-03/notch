import AVFoundation
import Testing
@testable import Notch

@MainActor
struct MirrorCameraTests {
    @Test(arguments: [
        (AVAuthorizationStatus.authorized, MirrorCamera.Access.granted),
        (.notDetermined, .notDetermined),
        (.denied, .denied),
        (.restricted, .denied),
    ])
    func authorizationMapsToAccess(status: AVAuthorizationStatus, access: MirrorCamera.Access) {
        #expect(MirrorCamera.access(for: status) == access)
    }

    @Test func theMirrorIsAButtonWithATallPage() {
        let mirror = MirrorCamera()
        #expect(mirror.tab?.style == .button)
        #expect(mirror.wantsTallPage)
        #expect(mirror.earPriority == nil)
    }

    @Test func theCameraIsOffUntilTheMirrorIsShown() {
        #expect(!MirrorCamera().isRunning)
    }
}

@MainActor
struct TabStyleTests {
    @Test func tabsAreLabelledTabsByDefault() {
        #expect(NotchTab(title: "Files", symbol: "tray").style == .tab)
    }

    @Test func openingTheMirrorMakesTheNotchTall() {
        let model = NotchViewModel(geometry: .previewHardware)
        model.expand()
        #expect(!model.isTall)
        model.select(tab: model.mirror)
        #expect(model.isTall)
        model.select(tab: model.shelf)
        #expect(!model.isTall)
    }
}
