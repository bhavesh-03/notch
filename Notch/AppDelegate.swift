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
    private let viewModel = NotchViewModel()
    private var monitors: [Any] = []
    private var notchRect: CGRect = .zero
    
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        let notchedScreen = NSScreen.screens.first { $0.safeAreaInsets.top > 0}
        guard let screen = notchedScreen ?? NSScreen.main else { return }
        
        let panelSize = CGSize(width: 400, height: 150)
        
        let origin = CGPoint(
            x: screen.frame.midX - panelSize.width / 2,
            y: screen.frame.maxY - panelSize.height
        )
        
        let panel = NotchPanel(contentRect: CGRect(origin: origin, size: panelSize))
        panel.contentView = NSHostingView(rootView: ContentView(viewModel: viewModel))
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        
        viewModel.onExpandedChange = { [weak panel] expanded in
            panel?.ignoresMouseEvents = !expanded
        }
        
        let notchSize = CGSize(width: 179, height: 32)
        notchRect = CGRect(
            x: screen.frame.midX - notchSize.width / 2,
            y: screen.frame.maxY - notchSize.height,
            width: notchSize.width,
            height: notchSize.height
        )
        
        self.panel = panel
        
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] _ in
            self?.handleMouseMoved()
        }) {
            monitors.append(global)
        }
        
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] event in
            self?.handleMouseMoved()
            return event
        }) {
            monitors.append(local)
        }
        
    }
    
    private func handleMouseMoved() {
        guard let panel else { return }
        
        let mouse = NSEvent.mouseLocation
        let activeRect = viewModel.isExpanded ? panel.frame : notchRect
        
        if activeRect.contains(mouse) {
            viewModel.expand()
        } else {
            viewModel.scheduleCollapse()
        }
        
    }
}
