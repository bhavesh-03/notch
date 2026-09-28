import CoreGraphics
import Testing
@testable import Notch

@MainActor
struct NotchGeometryTests {
    /// A 13" MacBook Air screen at the global origin, as measured on the real device.
    let airScreen = CGRect(x: 0, y: 0, width: 1470, height: 956)

    private func hardware(screen: CGRect) -> NotchGeometry {
        NotchGeometry(screenFrame: screen, leftAreaWidth: 645.5, rightAreaWidth: 645.5,
                      notchHeight: 32, kind: .hardware)
    }

    @Test func hardwareNotchMatchesMeasuredRect() {
        let geometry = hardware(screen: airScreen)
        #expect(geometry.notchRect == CGRect(x: 645.5, y: 924, width: 179, height: 32))
    }

    @Test func hardwareCollapsedRectAddsEarsOnBothSides() {
        let geometry = hardware(screen: airScreen)
        let ear = NotchGeometry.earWidth
        #expect(geometry.collapsedRect == CGRect(x: 645.5 - ear, y: 924, width: 179 + 2 * ear, height: 32))
    }

    @Test func panelIsCenteredOnNotchAndFlushWithTop() {
        let geometry = hardware(screen: airScreen)
        #expect(geometry.panelRect.midX == geometry.notchRect.midX)
        #expect(geometry.panelRect.maxY == airScreen.maxY)
        #expect(geometry.panelRect.size == geometry.panelSize)
    }

    @Test func screenAwayFromGlobalOriginIsHandled() {
        // e.g. the built-in display sitting left of (and below) an external main display
        let offsetScreen = CGRect(x: -1470, y: 1080, width: 1470, height: 956)
        let geometry = hardware(screen: offsetScreen)
        #expect(geometry.notchRect == CGRect(x: -824.5, y: 2004, width: 179, height: 32))
        #expect(geometry.panelRect.maxY == offsetScreen.maxY)
    }

    @Test func virtualNotchHasNoEars() {
        let external = CGRect(x: 1470, y: 0, width: 1920, height: 1080)
        let size = NotchGeometry.virtualNotchSize
        let side = (external.width - size.width) / 2
        let geometry = NotchGeometry(screenFrame: external, leftAreaWidth: side, rightAreaWidth: side,
                                     notchHeight: size.height, kind: .virtual)
        #expect(geometry.notchRect == CGRect(x: 2340, y: 1056, width: 180, height: 24))
        #expect(geometry.collapsedRect == geometry.notchRect)
    }

    @Test func expandedPanelIsWideEnoughForCollapsedNotch() {
        let geometry = hardware(screen: airScreen)
        #expect(geometry.panelRect.contains(geometry.collapsedRect))
    }

    @Test func activityWrapsTheNotchWithEarsAndADetailRow() {
        let geometry = hardware(screen: airScreen)
        let size = geometry.activitySize
        #expect(size.width == 179 + 2 * NotchGeometry.activityEarWidth)
        #expect(size.height == 32 + NotchGeometry.activityDetailHeight)
        #expect(size.width <= geometry.panelRect.width && size.height <= geometry.panelRect.height)
    }

    @Test func fileDragsOpenTheNotchFromTheWholeExpandedArea() {
        let geometry = hardware(screen: airScreen)
        let belowTheNotch = CGPoint(x: geometry.notchRect.midX + 150, y: geometry.notchRect.minY - 80)

        #expect(!geometry.hoverTarget(isExpanded: false, isDraggingFile: false).contains(belowTheNotch))
        #expect(geometry.hoverTarget(isExpanded: false, isDraggingFile: true).contains(belowTheNotch))
        #expect(geometry.hoverTarget(isExpanded: true, isDraggingFile: false).contains(belowTheNotch))
    }

    @Test func hoverTargetIncludesTheTopScreenEdge() {
        let geometry = hardware(screen: airScreen)
        let topEdge = CGPoint(x: geometry.notchRect.midX, y: airScreen.maxY)
        #expect(geometry.hoverTarget(isExpanded: false, isDraggingFile: false).contains(topEdge))
    }

    @Test func theHeadlineAddsHeightButNotWidth() {
        let geometry = hardware(screen: airScreen)
        let plain = geometry.expandedSize(withHeadline: false)
        let withPlayer = geometry.expandedSize(withHeadline: true)
        #expect(withPlayer.width == plain.width)
        #expect(withPlayer.height == plain.height + NotchGeometry.headlineHeight)
    }

    @Test func thePanelFitsTheTallestStateSoItNeverResizes() {
        let geometry = hardware(screen: airScreen)
        #expect(geometry.panelRect.contains(geometry.expandedRect(withHeadline: true)))
        #expect(geometry.panelRect.contains(geometry.expandedRect(withHeadline: false)))
    }

    @Test func hoveringBelowTheVisibleShapeDoesNotKeepItOpen() {
        let geometry = hardware(screen: airScreen)
        let inTheEmptyStrip = CGPoint(x: geometry.notchRect.midX, y: airScreen.maxY - NotchGeometry.expandedHeight - 20)

        #expect(geometry.panelRect.contains(inTheEmptyStrip), "the transparent part of the panel")
        #expect(!geometry.hoverTarget(isExpanded: true, hasHeadline: false, isDraggingFile: false).contains(inTheEmptyStrip))
        #expect(geometry.hoverTarget(isExpanded: true, hasHeadline: true, isDraggingFile: false).contains(inTheEmptyStrip))
    }

    @Test func theChosenWidthSizesTheShapeAndThePanel() {
        var geometry = hardware(screen: airScreen)
        geometry.expandedWidth = 620
        #expect(geometry.expandedRect(withHeadline: false).width == 620)
        #expect(geometry.panelRect.width == 620)
        #expect(geometry.expandedRect(withHeadline: true).midX == geometry.notchRect.midX, "still centered on the notch")
    }

    @Test func withoutEarsTheCollapsedNotchIsJustTheNotch() {
        var geometry = hardware(screen: airScreen)
        geometry.showsEars = false
        #expect(geometry.collapsedRect == geometry.notchRect)
    }
}

struct MenuBarClearanceTests {
    // The MacBook Air's notch in screen coordinates (as NotchGeometryTests' airScreen).
    let notch = CGRect(x: 645.5, y: 924, width: 179, height: 32)
    let ear: CGFloat = 40

    private func title(from minX: CGFloat, to maxX: CGFloat) -> CGRect {
        CGRect(x: minX, y: 0, width: maxX - minX, height: 24)
    }

    @Test func aFewMenusLeaveRoomForTheEars() {
        let menus = [title(from: 10, to: 40), title(from: 40, to: 90), title(from: 90, to: 140)]
        #expect(MenuBarClearance.earsFit(menuTitles: menus, notch: notch, earWidth: ear))
    }

    @Test func aMenuRunningUpToTheCameraBlocksTheLeftEar() {
        // Like Xcode's "Integrate", ending just short of the camera.
        let menus = [title(from: 560, to: 640)]
        #expect(!MenuBarClearance.earsFit(menuTitles: menus, notch: notch, earWidth: ear))
    }

    @Test func menusContinuedPastTheCameraBlockTheRightEar() {
        // Like Xcode's "Window" and "Help", placed right of the camera.
        let menus = [title(from: 830, to: 900)]
        #expect(!MenuBarClearance.earsFit(menuTitles: menus, notch: notch, earWidth: ear))
    }

    @Test func menusWellClearOfTheEarsAreFine() {
        let menus = [title(from: 400, to: 590), title(from: 880, to: 940)]
        #expect(MenuBarClearance.earsFit(menuTitles: menus, notch: notch, earWidth: ear))
    }
}

struct MenuBarPresenceTests {
    // The MacBook Air's screen: 956 pt tall, a 33 pt menu bar (as logged from the real thing).
    let top: CGFloat = 956
    let height: CGFloat = 33

    @Test func hiddenUntilThePointerTouchesTheTop() {
        var presence = MenuBarPresence()
        let showing1 = presence.update(pointerY: 597, screenTop: top, menuBarHeight: height, menuOpen: false)
        #expect(!showing1)
        let showing2 = presence.update(pointerY: 940, screenTop: top, menuBarHeight: height, menuOpen: false)
        #expect(!showing2, "near the top isn't enough")
        let showing3 = presence.update(pointerY: 955, screenTop: top, menuBarHeight: height, menuOpen: false)
        #expect(showing3)
    }

    @Test func staysWhileThePointerIsInTheMenuBarThenHides() {
        var presence = MenuBarPresence()
        _ = presence.update(pointerY: 956, screenTop: top, menuBarHeight: height, menuOpen: false)
        let showing4 = presence.update(pointerY: 930, screenTop: top, menuBarHeight: height, menuOpen: false)
        #expect(showing4, "moving along the menu bar")
        let showing5 = presence.update(pointerY: 846, screenTop: top, menuBarHeight: height, menuOpen: false)
        #expect(!showing5, "moved down, as logged")
    }

    @Test func anOpenMenuKeepsItRevealed() {
        var presence = MenuBarPresence()
        _ = presence.update(pointerY: 956, screenTop: top, menuBarHeight: height, menuOpen: false)
        let showing6 = presence.update(pointerY: 700, screenTop: top, menuBarHeight: height, menuOpen: true)
        #expect(showing6)
        let showing7 = presence.update(pointerY: 700, screenTop: top, menuBarHeight: height, menuOpen: false)
        #expect(!showing7, "menu closed")
    }

    @Test func switchingAppsStartsHidden() {
        var presence = MenuBarPresence()
        _ = presence.update(pointerY: 956, screenTop: top, menuBarHeight: height, menuOpen: false)
        presence.reset()
        #expect(!presence.isRevealed)
    }
}
