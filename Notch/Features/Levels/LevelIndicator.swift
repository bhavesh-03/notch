import SwiftUI

/// The notch's volume and brightness indicator. The key tap reports presses here; this applies them
/// and holds what the indicator shows, while the notch presents it like a pop-up.
@Observable
final class LevelIndicator {
    enum Kind: Equatable {
        case volume, brightness
    }

    private(set) var kind: Kind = .volume
    private(set) var level: Double = 0
    private(set) var isMuted = false

    /// Asks the notch to show the indicator (it springs out, or stays out while keys keep coming).
    @ObservationIgnored var onShow: (() -> Void)?

    /// Handles a key; returns whether it was handled here (so macOS shouldn't).
    func handle(_ key: MediaKey, fine: Bool) -> Bool {
        switch key {
        case .volumeUp, .volumeDown:
            guard SystemVolume.isAdjustable, let current = SystemVolume.volume else { return false }
            // Pressing volume up while muted unmutes at the same level, like macOS.
            let next = SystemVolume.isMuted && key == .volumeUp ? current : LevelStep.next(from: current, up: key == .volumeUp, fine: fine)
            SystemVolume.setVolume(next)
            show(.volume, level: next, muted: next == 0)
        case .mute:
            guard SystemVolume.isAdjustable else { return false }
            let muted = !SystemVolume.isMuted
            SystemVolume.setMuted(muted)
            show(.volume, level: SystemVolume.volume ?? level, muted: muted)
        case .brightnessUp, .brightnessDown:
            guard DisplayBrightness.isAdjustable, let current = DisplayBrightness.brightness else { return false }
            let next = LevelStep.next(from: current, up: key == .brightnessUp, fine: fine)
            DisplayBrightness.setBrightness(next)
            show(.brightness, level: next, muted: false)
        }
        return true
    }

    func show(_ kind: Kind, level: Double, muted: Bool) {
        self.kind = kind
        self.level = level
        isMuted = muted
        onShow?()
    }

    var symbol: String {
        switch kind {
        case .brightness:
            level < 0.34 ? "sun.min.fill" : "sun.max.fill"
        case .volume:
            isMuted || level == 0 ? "speaker.slash.fill"
                : level < 0.34 ? "speaker.wave.1.fill"
                : level < 0.67 ? "speaker.wave.2.fill"
                : "speaker.wave.3.fill"
        }
    }

    var percentText: String {
        isMuted ? "Muted" : "\(Int((level * 100).rounded()))%"
    }
}

extension LevelIndicator: NotchModule {
    var feature: NotchFeature { .levels }
    var earPriority: Int? { nil }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        switch placement {
        case .activityLeading:
            Image(systemName: symbol)
                .font(.title3)
                .contentTransition(.symbolEffect(.replace))
        case .activityTrailing:
            Text(percentText)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        case .activityDetail:
            LevelBar(level: isMuted ? 0 : level)
                .padding(.horizontal, 22)
                .padding(.bottom, 4)
        default:
            EmptyView()
        }
    }
}

/// A thin bar filling to the level, in the accent color.
struct LevelBar: View {
    let level: Double
    @Environment(\.notchAccent) private var accent

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(.white.opacity(0.18))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(accent)
                        // A sliver even at the lowest step, and nothing at all at zero.
                        .frame(width: level > 0 ? max(6, proxy.size.width * level) : 0)
                }
        }
        .frame(height: 6)
        .animation(.spring(duration: 0.25, bounce: 0.1), value: level)
    }
}
