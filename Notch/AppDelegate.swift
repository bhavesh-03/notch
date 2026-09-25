//
//  AppDelegate.swift
//  Notch
//
//  Created by Vineet Parmar on 25/09/26.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var panel: NotchPanel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        let notchedScreen = NSScreen.screens.first { $0.safeAreaInsets.top > 0}
        guard let screen = notchedScreen ?? NSScreen.main else { return }
        
        let panelSize = CGSize(width: 400, height: 150)
        
        let origin = CGPoint(
            x: screen.frame.midX - panelSize.width / 2,
            y: screen.frame.maxY - panelSize.height
        )
        
        let panel = NotchPanel(contentRect: CGRect(origin: origin, size: panelSize))
        panel.contentView = NSHostingView(rootView: ContentView())
        panel.orderFrontRegardless()
        
        self.panel = panel
        
    }
}
