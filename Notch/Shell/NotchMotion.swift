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
