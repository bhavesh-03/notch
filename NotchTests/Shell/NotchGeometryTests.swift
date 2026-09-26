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
        let size = NotchGeometry.expandedSize
        #expect(geometry.panelRect.midX == geometry.notchRect.midX)
        #expect(geometry.panelRect.maxY == airScreen.maxY)
        #expect(geometry.panelRect.size == size)
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
}
