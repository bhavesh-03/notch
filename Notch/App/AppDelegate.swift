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
    private var menuTrackingTasks: [Task<Void, Never>] = []
    private var dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
    private let notifications = NotificationService()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        guard let geometry = Self.currentGeometry() else { return }
        
        let viewModel = NotchViewModel(geometry: geometry)
        self.viewModel = viewModel
        let panel = NotchPanel(contentRect: geometry.panelRect)
        panel.contentView = NSHostingView(rootView: NotchView(viewModel: viewModel))
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        
        viewModel.onExpandedChange = { [weak panel, weak viewModel] expanded in
            panel?.ignoresMouseEvents = !expanded
            if expanded {
                viewModel?.launchAtLogin.refresh()
            }
        }
        
        self.panel = panel
        
        let timer = viewModel.timer
        timer.onStart = { [notifications] in
            Task { await notifications.requestAuthorizationIfNeeded() }
        }
        timer.onFinish = { [notifications, weak timer, weak viewModel] in
            guard let timer else { return }
            notifications.postTimerFinished(duration: timer.state.duration)
            viewModel?.showActivity(from: timer)
        }

        viewModel.battery.onPluggedIn = { [weak viewModel] in
            guard let viewModel else { return }
            viewModel.showActivity(from: viewModel.battery)
        }

        viewModel.nowPlaying.start()
        viewModel.nowPlaying.onTrackChanged = { [weak viewModel] _ in
            guard let viewModel else { return }
            viewModel.showActivity(from: viewModel.nowPlaying)
        }

        viewModel.calendar.onEventStarted = { [weak viewModel] _ in
            guard let viewModel else { return }
            viewModel.showActivity(from: viewModel.calendar)
        }
        
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown], handler: { [weak self] event in
            self?.handleMouseEvent(event)
        }) {
            monitors.append(global)
        }
        
        if let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseDown], handler: { [weak self] event in
            self?.handleMouseEvent(event)
            return event
        }) {
            monitors.append(local)
        }
        
        // While one of our menus is open the pointer is over the menu, not the notch;
        // hold the notch open until the menu closes, then re-check where the pointer is.
        menuTrackingTasks = [
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: NSMenu.didBeginTrackingNotification) {
                    self?.viewModel?.holdOpen()
                }
            },
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: NSMenu.didEndTrackingNotification) {
                    self?.viewModel?.releaseHold()
                    self?.handleMouseMoved()
                }
            },
        ]

        screenChangeTask = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(
                named: NSApplication.didChangeScreenParametersNotification
            ) {
                self?.screensDidChange()
            }
        }
        
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
        case .leftMouseDragged:
            handleMouseMoved(isDraggingFile: isDraggingFile())
        default:
            handleMouseMoved()
        }
    }

    /// True while the current drag carries files: the drag pasteboard was written since the mouse
    /// went down and holds file URLs or file promises (e.g. a screenshot thumbnail).
    /// Window drags and text selection don't qualify.
    private func isDraggingFile() -> Bool {
        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != dragPasteboardChangeCount, let types = pasteboard.types else { return false }
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        return types.contains(.fileURL) || types.contains(where: promiseTypes.contains)
    }

    private func handleMouseMoved(isDraggingFile: Bool = false) {
        guard let viewModel else { return }
        
        let mouse = NSEvent.mouseLocation
        let activeRect = viewModel.geometry.hoverTarget(isExpanded: viewModel.isExpanded, hasHeadline: viewModel.isTall, isDraggingFile: isDraggingFile)
        
        if activeRect.contains(mouse) {
            viewModel.expand()
            if isDraggingFile {
                viewModel.showDropTarget()
            }
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
