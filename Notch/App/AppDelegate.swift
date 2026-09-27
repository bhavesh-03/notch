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
    private let settings: NotchSettings
    private let mediaKeys = MediaKeyTap()
    private var accessibilityWait: Task<Void, Never>?
    private lazy var settingsWindow = SettingsWindowController(settings: settings)
    private var monitors: [Any] = []
    private var screenChangeTask: Task<Void, Never>?
    private var menuTrackingTasks: [Task<Void, Never>] = []
    private var dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
    private let notifications = NotificationService()

    override init() {
        // Before the settings load, so they load what the sandboxed version saved.
        SandboxMigration.runIfNeeded()
        settings = NotchSettings()
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        guard let geometry = currentGeometry() else { return }
        
        let viewModel = NotchViewModel(geometry: geometry, settings: settings)
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
        timer.onStart = { [notifications, settings] in
            guard settings.timerNotifies else { return }
            Task { await notifications.requestAuthorizationIfNeeded() }
        }
        timer.onFinish = { [notifications, settings, weak timer, weak viewModel] in
            guard let timer else { return }
            if settings.timerNotifies {
                notifications.postTimerFinished(duration: timer.state.duration, playsSound: settings.timerPlaysSound)
            }
            viewModel?.showActivity(from: timer)
        }

        viewModel.battery.onPluggedIn = { [weak viewModel] in
            guard let viewModel else { return }
            viewModel.showActivity(from: viewModel.battery)
        }

        viewModel.onOpenSettings = { [weak self] in
            self?.settingsWindow.show()
        }
        viewModel.levels.onShow = { [weak viewModel] in
            viewModel?.showLevels()
        }
        mediaKeys.onKey = { [weak viewModel] key, fine in
            viewModel?.levels.handle(key, fine: fine) ?? false
        }

        settings.onGeometryChanged = { [weak self] in
            self?.updateGeometry()
        }
        settings.onFeaturesChanged = { [weak self] in
            self?.applyFeatureSettings()
        }
        applyFeatureSettings()
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
                self?.updateGeometry()
            }
        }
        
    }
    
    /// Starts or stops the parts of hidden features that do work in the background.
    private func applyFeatureSettings() {
        guard let viewModel else { return }
        if settings.isVisible(.nowPlaying) {
            viewModel.nowPlaying.start()   // no-op when already running
        } else {
            viewModel.nowPlaying.stop()    // ends the helper process
        }
        if settings.isVisible(.levels) {
            startMediaKeys()
        } else {
            accessibilityWait?.cancel()
            mediaKeys.stop()               // the keys go back to macOS
        }
    }

    /// Takes over the volume and brightness keys, asking for Accessibility permission first if needed
    /// and starting as soon as it's granted (no relaunch).
    private func startMediaKeys() {
        guard !mediaKeys.isRunning else { return }
        if MediaKeyTap.isTrusted {
            mediaKeys.start()
            return
        }
        MediaKeyTap.requestTrust()
        accessibilityWait?.cancel()
        accessibilityWait = Task { [weak self] in
            while !Task.isCancelled, !MediaKeyTap.isTrusted {
                try? await Task.sleep(for: .seconds(2))
            }
            guard !Task.isCancelled else { return }
            self?.mediaKeys.start()
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
        // With no module taking files (the Files feature hidden), a file drag is just a drag.
        guard viewModel?.modules.contains(where: \.acceptsFileDrops) == true else { return false }
        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != dragPasteboardChangeCount, let types = pasteboard.types else { return false }
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        return types.contains(.fileURL) || types.contains(where: promiseTypes.contains)
    }

    private func handleMouseMoved(isDraggingFile: Bool = false) {
        guard let viewModel else { return }
        
        let mouse = NSEvent.mouseLocation
        let tallShape = viewModel.geometry.hoverTarget(isExpanded: true, hasHeadline: true, isDraggingFile: false)
        let hoverIsTall = viewModel.hoverIsTall(pointerInTallShape: tallShape.contains(mouse))
        let activeRect = viewModel.geometry.hoverTarget(isExpanded: viewModel.isExpanded, hasHeadline: hoverIsTall, isDraggingFile: isDraggingFile)
        
        if activeRect.contains(mouse) {
            viewModel.pointerEntered(isDraggingFile: isDraggingFile)
            if isDraggingFile {
                viewModel.showDropTarget()
            }
        } else {
            viewModel.pointerLeft()
        }
        
    }
    
    /// The notch on the current screen, shaped by the user's Look settings.
    private func currentGeometry() -> NotchGeometry? {
        let notchedScreen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
        guard let screen = notchedScreen ?? NSScreen.main else { return nil }
        var geometry = NotchGeometry(screen: screen)
        geometry.expandedWidth = settings.width.points
        geometry.showsEars = settings.showsEars
        return geometry
    }
    
    /// Rebuilds the geometry after the screen or a Look setting changed, and moves the panel to match.
    private func updateGeometry() {
        guard let panel, let viewModel, let geometry = currentGeometry() else { return }
        viewModel.geometry = geometry
        panel.setFrame(geometry.panelRect, display: true)
    }
    
}
