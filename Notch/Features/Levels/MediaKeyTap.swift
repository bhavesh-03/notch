import AppKit
import ApplicationServices

/// Catches the volume and brightness keys before macOS does, so the notch can show its own indicator
/// instead of macOS's. Needs Accessibility permission; without it (or for a key the notch can't act
/// on, like brightness on an external display) keys pass through to macOS untouched.
final class MediaKeyTap {
    /// Handles a key press; returns whether it took care of it (true swallows the event).
    var onKey: ((MediaKey, _ fine: Bool) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { tap != nil }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows macOS's "allow in Accessibility" prompt, once.
    static func requestTrust() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    /// Starts listening; false if macOS refused (no Accessibility permission yet).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = CGEventMask(1 << 14)   // NX_SYSDEFINED: the media keys
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<MediaKeyTap>.fromOpaque(context).takeUnretainedValue()
                return MainActor.assumeIsolated { owner.handle(type: type, event: event) }
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS switches a tap off if it's ever slow to answer; switch it straight back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard let ns = NSEvent(cgEvent: event), ns.type == .systemDefined,
              let (key, isDown) = MediaKey.decode(subtype: Int(ns.subtype.rawValue), data1: ns.data1)
        else { return Unmanaged.passUnretained(event) }

        let fine = ns.modifierFlags.contains([.shift, .option])
        // Presses do the work; the matching release is swallowed too if the press was, so macOS
        // never sees half a key.
        let handled = isDown ? (onKey?(key, fine) ?? false) : canHandle(key)
        return handled ? nil : Unmanaged.passUnretained(event)
    }

    private func canHandle(_ key: MediaKey) -> Bool {
        key.isVolume ? SystemVolume.isAdjustable : DisplayBrightness.isAdjustable
    }
}
