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
    
    init(screenFrame: CGRect, leftAreaWidth: CGFloat, rightAreaWidth: CGFloat, notchHeight: CGFloat) {
        self.screenFrame = screenFrame
        self.notchRect = CGRect(
            x: screenFrame.minX + leftAreaWidth,
            y: screenFrame.maxY - notchHeight,
            width: screenFrame.width - leftAreaWidth - rightAreaWidth,
            height: notchHeight
        )
    }
    
    init?(screen: NSScreen) {
        guard let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
              screen.safeAreaInsets.top > 0 else { return nil }
        self.init(screenFrame: screen.frame,
                  leftAreaWidth: left.width,
                  rightAreaWidth: right.width,
                  notchHeight: screen.safeAreaInsets.top)
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
