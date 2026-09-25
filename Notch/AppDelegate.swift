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
    private var viewModel: NotchViewModel?
    private var monitors: [Any] = []
    
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        let notchedScreen = NSScreen.screens.first { $0.safeAreaInsets.top > 0}
        guard let screen = notchedScreen ?? NSScreen.main else { return }
        let geometry = NotchGeometry(screen: screen)
        let viewModel = NotchViewModel(geometry: geometry)
        self.viewModel = viewModel
        let panel = NotchPanel(contentRect: geometry.panelRect)
        panel.contentView = NSHostingView(rootView: ContentView(viewModel: viewModel))
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        
        viewModel.onExpandedChange = { [weak panel] expanded in
            panel?.ignoresMouseEvents = !expanded
        }
        
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
        guard let panel, let viewModel else { return }
        
        let mouse = NSEvent.mouseLocation
        let activeRect = (viewModel.isExpanded ? panel.frame : viewModel.geometry.collapsedRect)
            .insetBy(dx: 0, dy: -1)
        
        if activeRect.contains(mouse) {
            viewModel.expand()
        } else {
            viewModel.scheduleCollapse()
        }
        
    }
}
