//
//  NotchGeometry.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//

import AppKit

struct NotchGeometry {
    
    static let expandedSize = CGSize(width: 540, height: 150)
    /// Extra height for a full-width headline row (the media player) above the module columns.
    static let headlineHeight: CGFloat = 74

    static func expandedSize(withHeadline: Bool) -> CGSize {
        withHeadline ? CGSize(width: expandedSize.width, height: expandedSize.height + headlineHeight) : expandedSize
    }

    /// The panel is sized for the tallest state, so it never resizes; the shape grows inside it.
    static var panelSize: CGSize { expandedSize(withHeadline: true) }
    static let activityEarWidth: CGFloat = 80
    static let activityDetailHeight: CGFloat = 26
    let screenFrame: CGRect
    let notchRect: CGRect
    enum Kind { case hardware, virtual }
    let kind: Kind
    static let virtualNotchSize = CGSize(width: 180, height: 24)
    static let earWidth: CGFloat = 40
    
    var collapsedRect: CGRect {
        switch kind {
        case .hardware: notchRect.insetBy(dx: -Self.earWidth, dy: 0)
        case .virtual:  notchRect
        }
    }
    
    init(screenFrame: CGRect, leftAreaWidth: CGFloat, rightAreaWidth: CGFloat, notchHeight: CGFloat, kind: Kind) {
        self.screenFrame = screenFrame
        self.notchRect = CGRect(
            x: screenFrame.minX + leftAreaWidth,
            y: screenFrame.maxY - notchHeight,
            width: screenFrame.width - leftAreaWidth - rightAreaWidth,
            height: notchHeight
        )
        self.kind = kind
    }
    
    init(screen: NSScreen) {
        if let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
           screen.safeAreaInsets.top > 0 {
            self.init(screenFrame: screen.frame,
                      leftAreaWidth: left.width,
                      rightAreaWidth: right.width,
                      notchHeight: screen.safeAreaInsets.top,
                      kind: .hardware
            )
        } else {
            let sideWidth = (screen.frame.width - Self.virtualNotchSize.width) / 2
            self.init(screenFrame: screen.frame,
                      leftAreaWidth: sideWidth,
                      rightAreaWidth: sideWidth,
                      notchHeight: Self.virtualNotchSize.height,
                      kind: .virtual
            )
        }
    }
    
    var activitySize: CGSize {
        CGSize(
            width: notchRect.width + 2 * Self.activityEarWidth,
            height: notchRect.height + Self.activityDetailHeight
        )
    }

    /// Where the pointer has to be for the notch to open (or stay open).
    /// A file drag opens it from anywhere over the expanded area, so the user never has to
    /// push against the top edge of the screen, which would trigger Mission Control.
    func hoverTarget(isExpanded: Bool, hasHeadline: Bool = false, isDraggingFile: Bool) -> CGRect {
        let target: CGRect
        if isExpanded {
            target = expandedRect(withHeadline: hasHeadline)
        } else if isDraggingFile {
            target = expandedRect(withHeadline: false)
        } else {
            target = collapsedRect
        }
        return target.insetBy(dx: 0, dy: -1)
    }

    /// Where the expanded shape actually is: the visible part of the panel.
    func expandedRect(withHeadline: Bool) -> CGRect {
        let size = Self.expandedSize(withHeadline: withHeadline)
        return CGRect(x: notchRect.midX - size.width / 2, y: screenFrame.maxY - size.height, width: size.width, height: size.height)
    }

    var panelRect: CGRect {
        CGRect(
            x: notchRect.midX - Self.panelSize.width / 2,
            y: screenFrame.maxY - Self.panelSize.height,
            width: Self.panelSize.width,
            height: Self.panelSize.height
        )
    }
    
}
