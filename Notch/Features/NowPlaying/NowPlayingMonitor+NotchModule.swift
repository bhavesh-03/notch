import SwiftUI

extension NowPlayingMonitor: NotchModule {
    /// Above the battery (0), below an imminent meeting (5) and a running timer (10), only while playing.
    var earPriority: Int? {
        info?.isPlaying == true ? 3 : nil
    }

    /// The player lives in the headline row instead of a column.
    var hasExpandedSection: Bool { false }

    /// Shown whenever there's something to control, playing or paused.
    var hasHeadline: Bool { info != nil }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        if let info {
            switch placement {
            case .leadingEar, .pill:
                SourceAppIcon(bundleIdentifier: info.appBundleIdentifier)
                    .frame(width: 16, height: 16)
            case .trailingEar:
                PlayingIndicator(isPlaying: info.isPlaying)
            case .headline:
                PlayerRow(monitor: self, info: info)
            case .activityLeading:
                ArtworkTile(bundleIdentifier: info.appBundleIdentifier)
                    .frame(width: 26, height: 26)
            case .activityTrailing:
                PlayingIndicator(isPlaying: info.isPlaying)
                    .font(.title3)
            case .activityDetail:
                Text([info.title, info.artist].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
            case .expanded:
                EmptyView()
            }
        }
    }
}

/// Artwork-sized app icon, title, artist, live progress, and transport controls.
private struct PlayerRow: View {
    let monitor: NowPlayingMonitor
    let info: NowPlayingInfo

    var body: some View {
        HStack(spacing: 12) {
            ArtworkTile(bundleIdentifier: info.appBundleIdentifier)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(info.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text([info.artist, info.appName].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                if info.duration > 0 {
                    PlaybackProgress(info: info)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                control("backward.fill", .previous)
                control(info.isPlaying ? "pause.fill" : "play.fill", .toggle)
                    .contentTransition(.symbolEffect(.replace))
                control("forward.fill", .next)
            }
            .buttonStyle(.plain)
        }
        .animation(.snappy, value: info.isPlaying)
    }

    private func control(_ symbol: String, _ command: NowPlayingBridgeProcess.Command) -> some View {
        Button {
            monitor.send(command)
        } label: {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.15), in: Circle())
        }
    }
}

/// A thin progress line with elapsed and remaining time, redrawn once a second from the extrapolated position.
private struct PlaybackProgress: View {
    let info: NowPlayingInfo

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = info.elapsed(at: context.date)
            HStack(spacing: 6) {
                Text(Self.format(elapsed))
                GeometryReader { proxy in
                    Capsule()
                        .fill(.white.opacity(0.25))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(.white)
                                .frame(width: proxy.size.width * min(1, elapsed / info.duration))
                        }
                }
                .frame(height: 3)
                Text("-" + Self.format(info.duration - elapsed))
            }
            .font(.system(size: 9).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private static func format(_ seconds: TimeInterval) -> String {
        Duration.seconds(Int(max(0, seconds))).formatted(.time(pattern: .minuteSecond))
    }
}

/// Stands in for album art, which third-party apps can't read for most sources: the playing app's icon
/// on a soft background tinted with the icon's own colors, the way Apple's media controls look without art.
private struct ArtworkTile: View {
    let bundleIdentifier: String

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let tint = Color(nsColor: AppIconTint.color(for: bundleIdentifier))
            RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    SourceAppIcon(bundleIdentifier: bundleIdentifier)
                        .frame(width: side * 0.68, height: side * 0.68)
                        .shadow(color: .black.opacity(0.3), radius: side * 0.05, y: side * 0.03)
                }
        }
    }
}

/// Remembers each app's icon tint so it's computed once, not on every redraw.
private enum AppIconTint {
    static var cache: [String: NSColor] = [:]

    static func color(for bundleIdentifier: String) -> NSColor {
        if let cached = cache[bundleIdentifier] { return cached }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        let color = icon?.averageColor ?? .darkGray
        cache[bundleIdentifier] = color
        return color
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
