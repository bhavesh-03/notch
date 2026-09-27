import Foundation

/// A volume or brightness key, decoded from the system-defined event the keyboard sends.
///
/// macOS delivers these keys as "system defined" events (subtype 8, auxiliary control buttons) whose
/// `data1` packs the key in the high 16 bits and its state in the next byte: 0x0A down, 0x0B up,
/// plus a repeat flag in the lowest bit.
enum MediaKey: Equatable {
    case volumeUp, volumeDown, mute
    case brightnessUp, brightnessDown

    // NX_KEYTYPE_* values from IOKit's ev_keymap.h.
    private static let codes: [Int: MediaKey] = [0: .volumeUp, 1: .volumeDown, 7: .mute, 2: .brightnessUp, 3: .brightnessDown]

    /// The key and whether this is its press (not its release), or nil for other events.
    static func decode(subtype: Int, data1: Int) -> (key: MediaKey, isDown: Bool)? {
        guard subtype == 8, let key = codes[(data1 & 0xFFFF_0000) >> 16] else { return nil }
        let state = (data1 & 0xFF00) >> 8
        return (key, state == 0x0A)
    }

    var isVolume: Bool { self == .volumeUp || self == .volumeDown || self == .mute }
}

/// How a key press moves a level, the way macOS does it: 16 steps, or quarter steps with ⇧⌥.
enum LevelStep {
    static let normal = 1.0 / 16
    static let fine = 1.0 / 64

    /// The next level, snapped to the step so repeated presses land on the same marks.
    static func next(from level: Double, up: Bool, fine isFine: Bool) -> Double {
        let step = isFine ? fine : normal
        let steps = (level / step).rounded()
        let moved = (steps + (up ? 1 : -1)) * step
        return min(max(moved, 0), 1)
    }
}
