import AppKit
import SwiftUI

enum ShelfFileTransfer {
    static func copy(_ items: [ShelfStore.Item], to pasteboard: NSPasteboard = .general) -> Bool {
        guard !items.isEmpty else { return false }
        pasteboard.clearContents()
        return pasteboard.writeObjects(items.map { $0.url as NSURL })
    }

    static func dragItems(_ items: [ShelfStore.Item], at point: CGPoint) -> [NSDraggingItem] {
        items.enumerated().map { index, item in
            let drag = NSDraggingItem(pasteboardWriter: item.url as NSURL)
            let offset = CGFloat(min(index, 2)) * 4
            let frame = CGRect(x: point.x - 20 + offset, y: point.y - 20 - offset, width: 40, height: 40)
            let icon = NSWorkspace.shared.icon(forFile: item.url.path)
            drag.setDraggingFrame(frame, contents: icon)
            return drag
        }
    }
}

/// Native file drags hand Finder and other apps the original URLs and explicitly offer copy.
struct ShelfDragSource: NSViewRepresentable {
    let items: () -> [ShelfStore.Item]
    let onClick: () -> Void

    func makeNSView(context: Context) -> DragView { DragView() }

    func updateNSView(_ view: DragView, context: Context) {
        view.items = items
        view.onClick = onClick
    }

    final class DragView: NSView, NSDraggingSource {
        var items: () -> [ShelfStore.Item] = { [] }
        var onClick: () -> Void = {}
        private var mouseDownLocation: CGPoint?

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            mouseDownLocation = event.locationInWindow
        }

        override func mouseUp(with event: NSEvent) {
            guard mouseDownLocation != nil else { return }
            mouseDownLocation = nil
            if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick() }
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start = mouseDownLocation else { return }
            let point = event.locationInWindow
            guard hypot(point.x - start.x, point.y - start.y) >= 4 else { return }
            mouseDownLocation = nil

            let draggingItems = ShelfFileTransfer.dragItems(items(), at: convert(point, from: nil))
            guard !draggingItems.isEmpty else { return }
            let session = beginDraggingSession(with: draggingItems, event: event, source: self)
            session.draggingFormation = .stack
            session.animatesToStartingPositionsOnCancelOrFail = false
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            .copy
        }
    }
}
