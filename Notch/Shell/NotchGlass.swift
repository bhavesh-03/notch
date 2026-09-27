import SwiftUI

/// Liquid Glass for the notch's neutral controls. Over the notch's black it reads as dark glass with a
/// soft rim; `interactive` makes it respond to presses like system controls.
///
/// Emphasized controls (Done, Join, a chosen chip) use a solid fill instead: glass takes its color
/// from what's behind it, and behind the notch is black, so a tint barely shows and text on it fades.
extension View {
    func glassControl<S: Shape>(in shape: S, interactive: Bool = true) -> some View {
        glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
    }
}
