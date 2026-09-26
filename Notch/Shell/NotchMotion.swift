import SwiftUI

/// Every activity animation value in one place, so the feel can be tuned without hunting through views.
///
/// The choreography: the old content leaves quickly, the shape springs to its new size,
/// and the new content blurs in once the shape has mostly settled.
enum NotchMotion {
    static func activityOpen(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.55, bounce: 0.38)
    }

    static func activityClose(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.25)
    }

    /// The ears changing owner (e.g. music paused, battery takes over). No shape change, so no spring needed.
    static func earHandover(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.85)
    }

    /// A calm, overlapping cross-dissolve for the ears. Unlike activities, nothing needs to get out of
    /// the way of a moving shape, so the old content softens away while the new one comes into focus.
    static func earContent(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else {
            return .opacity.animation(.easeInOut(duration: 0.25))
        }
        let arriving = AnyTransition(.blurReplace).animation(.smooth(duration: 0.6).delay(0.25))
        let leaving = AnyTransition.opacity
            .combined(with: .scale(scale: 0.8))
            .combined(with: AnyTransition(.blurReplace))
            .animation(.smooth(duration: 0.5))
        return .asymmetric(insertion: arriving, removal: leaving)
    }

    /// Content arriving: waits for the shape, then blurs and scales into focus.
    static func contentIn(reduceMotion: Bool) -> AnyTransition {
        reduceMotion
            ? .opacity.animation(.easeIn(duration: 0.15).delay(0.1))
            : AnyTransition(.blurReplace).animation(.smooth(duration: 0.3).delay(0.05))
    }

    /// Content leaving: gets out of the way fast so it never overlaps the next layout.
    static let contentOut: AnyTransition = .opacity.animation(.easeOut(duration: 0.1))

    static func content(reduceMotion: Bool) -> AnyTransition {
        .asymmetric(insertion: contentIn(reduceMotion: reduceMotion), removal: contentOut)
    }
}
