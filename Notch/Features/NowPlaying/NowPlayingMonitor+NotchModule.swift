import SwiftUI

extension NowPlayingMonitor: NotchModule {
    /// Above the battery (0), below an imminent meeting (5) and a running timer (10), only while playing.
    var earPriority: Int? {
        info?.isPlaying == true ? 3 : nil
    }

    /// Ears only for now; the expanded player comes next.
    var hasExpandedSection: Bool { false }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        if let info {
            switch placement {
            case .leadingEar, .pill:
                SourceAppIcon(bundleIdentifier: info.appBundleIdentifier)
                    .frame(width: 16, height: 16)
            case .trailingEar:
                PlayingIndicator(isPlaying: info.isPlaying)
            case .expanded, .activityLeading, .activityTrailing, .activityDetail:
                EmptyView()
            }
        }
    }
}

/// The icon of the app that's playing (e.g. the YouTube Music web app), or a note if it can't be found.
private struct SourceAppIcon: View {
    let bundleIdentifier: String

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
        } else {
            Image(systemName: "music.note")
        }
    }
}

/// Animated bars while playing; still while paused.
private struct PlayingIndicator: View {
    let isPlaying: Bool

    var body: some View {
        Image(systemName: "waveform")
            .symbolEffect(.variableColor.iterative, isActive: isPlaying)
            .foregroundStyle(.white.opacity(isPlaying ? 1 : 0.5))
    }
}
