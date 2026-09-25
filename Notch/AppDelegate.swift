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
    private var screenChangeTask: Task<Void, Never>?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        guard let geometry = Self.currentGeometry() else { return }
        
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
        
        screenChangeTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: NSApplication.didChangeScreenParametersNotification
            ) {
                self?.screensDidChange()
            }
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
    
    private static func currentGeometry() -> NotchGeometry? {
        let notchedScreen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
        guard let screen = notchedScreen ?? NSScreen.main else { return nil }
        return NotchGeometry(screen: screen)
    }
    
    private func screensDidChange() {
        guard let panel, let viewModel, let geometry = Self.currentGeometry() else { return }
        viewModel.geometry = geometry
        panel.setFrame(geometry.panelRect, display: true)
    }
    
}
