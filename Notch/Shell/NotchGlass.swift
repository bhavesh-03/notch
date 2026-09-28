import SwiftUI

/// Liquid Glass where macOS has it (26 and later), and the flat translucent look from before it on
/// older systems. Every use of glass goes through here, so availability is handled in one place.
///
/// Emphasized controls (Done, Join, a chosen chip) use a solid fill instead: glass takes its color
/// from what's behind it, and behind the notch is black, so a tint barely shows and text on it fades.
extension View {
    /// A neutral control: dark glass with a soft rim over the notch; `interactive` responds to presses.
    @ViewBuilder
    func glassControl<S: Shape>(in shape: S, interactive: Bool = true) -> some View {
        if #available(macOS 26, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            background(.white.opacity(0.15), in: shape)
        }
    }

    /// A surface: widget cards, the selection pills.
    @ViewBuilder
    func glassSurface<S: Shape>(in shape: S, fallbackOpacity: Double = 0.07) -> some View {
        if #available(macOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.white.opacity(fallbackOpacity), in: shape)
        }
    }

    /// Tinted glass (the accent swatches, the smoked notch on screens without one), or the tint
    /// itself as a plain fill.
    @ViewBuilder
    func glassTinted<S: Shape>(_ tint: Color, in shape: S, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(interactive ? .regular.tint(tint).interactive() : .regular.tint(tint), in: shape)
        } else {
            background(tint, in: shape)
        }
    }

    /// A glass button style for Settings, or the standard bordered one.
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(macOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }
}

/// Groups glass shapes so they blend as they pass each other; just the content before macOS 26.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
