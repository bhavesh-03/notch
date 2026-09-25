//
//  NotchGeometry.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//

import AppKit

struct NotchGeometry {
    
    static let expandedSize = CGSize(width: 400, height: 150)
    let screenFrame: CGRect
    let notchRect: CGRect
    enum Kind { case hardware, virtual }
    let kind: Kind
    static let virtualNotchSize = CGSize(width: 180, height: 24)
    
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
    
    var panelRect: CGRect {
        CGRect(
            x: notchRect.midX - Self.expandedSize.width / 2,
            y: screenFrame.maxY - Self.expandedSize.height,
            width: Self.expandedSize.width,
            height: Self.expandedSize.height
        )
    }
    
}
