//
//  NotchGeometry.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//

import AppKit

struct NotchGeometry {
    
    static let expandedSize = CGSize(width: 540, height: 150)
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
    func hoverTarget(isExpanded: Bool, isDraggingFile: Bool) -> CGRect {
        (isExpanded || isDraggingFile ? panelRect : collapsedRect)
            .insetBy(dx: 0, dy: -1)
    }

    var panelRect: CGRect {
        CGRect(
            x: notchRect.midX - Self.expandedSize.width / 2,
            y: screenFrame.maxY - Self.expandedSize.height,
            width: Self.expandedSize.width,
            height: Self.expandedSize.height
        )
    }
    
}
