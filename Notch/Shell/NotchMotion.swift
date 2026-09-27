import SwiftUI

/// Every notch animation value in one place, so the feel can be tuned without hunting through views.
/// `speed` is the user's Animation speed setting; Reduce Motion replaces the motion entirely.
///
/// The choreography: the old content leaves quickly, the shape springs to its new size,
/// and the new content blurs in once the shape has mostly settled.
enum NotchMotion {
    static func activityOpen(reduceMotion: Bool, speed: Double = 1) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.75, bounce: 0.45).speed(speed)
    }

    static func activityClose(reduceMotion: Bool, speed: Double = 1) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.65, bounce: 0.32).speed(speed)
    }

    /// The expanded notch changing height (switching tabs, the player row appearing or leaving).
    /// Slow enough that a shrink never snaps, with a bounce you can see as it settles.
    static func pageResize(reduceMotion: Bool, speed: Double = 1) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 1.2, bounce: 0.4).speed(speed)
    }

    /// The ears changing owner (e.g. music paused, battery takes over). No shape change, so no spring needed.
    static func earHandover(reduceMotion: Bool, speed: Double = 1) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.85).speed(speed)
    }

    /// A calm, overlapping cross-dissolve for the ears. Unlike activities, nothing needs to get out of
    /// the way of a moving shape, so the old content softens away while the new one comes into focus.
    static func earContent(reduceMotion: Bool, speed: Double = 1) -> AnyTransition {
        guard !reduceMotion else {
            return .opacity.animation(.easeInOut(duration: 0.25))
        }
        let arriving = AnyTransition(.blurReplace).animation(.smooth(duration: 0.6).delay(0.25).speed(speed))
        let leaving = AnyTransition.opacity
            .combined(with: .scale(scale: 0.8))
            .combined(with: AnyTransition(.blurReplace))
            .animation(.smooth(duration: 0.5).speed(speed))
        return .asymmetric(insertion: arriving, removal: leaving)
    }

    /// Content arriving: waits for the shape, then blurs and scales into focus.
    static func contentIn(reduceMotion: Bool, speed: Double = 1) -> AnyTransition {
        reduceMotion
            ? .opacity.animation(.easeIn(duration: 0.15).delay(0.1))
            : AnyTransition(.blurReplace).animation(.smooth(duration: 0.45).delay(0.1).speed(speed))
    }

    /// Content leaving: gets out of the way fast so it never overlaps the next layout.
    static func contentOut(speed: Double = 1) -> AnyTransition {
        .opacity.animation(.easeOut(duration: 0.18).speed(speed))
    }

    static func content(reduceMotion: Bool, speed: Double = 1) -> AnyTransition {
        .asymmetric(insertion: contentIn(reduceMotion: reduceMotion, speed: speed), removal: contentOut(speed: speed))
    }

    /// The notch opening on hover and closing when the pointer leaves.
    static func expandCollapse(speed: Double = 1) -> Animation {
        .snappy.speed(speed)
    }
}
