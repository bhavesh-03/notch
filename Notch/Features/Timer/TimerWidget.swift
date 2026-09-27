import SwiftUI

/// The timer on Home. Tapping the time opens the timer page to set it.
struct TimerWidget: View {
    let timer: TimerController
    let size: WidgetSize
    @Environment(\.openNotchPage) private var openPage

    private var isActive: Bool { timer.state.phase != .idle }

    var body: some View {
        switch size {
        case .small:
            HStack(spacing: 6) {
                time(size: 17)
                Spacer(minLength: 0)
                playPause(side: 24)
            }
        case .wide:
            HStack(spacing: 8) {
                time(size: 26)
                Spacer(minLength: 0)
                playPause(side: 30)
                reset(side: 30)
            }
            .padding(.horizontal, 4)
        case .tall:
            VStack(spacing: 8) {
                time(size: 22)
                HStack(spacing: 8) {
                    playPause(side: 28)
                    reset(side: 28)
                }
            }
        case .large:
            TimerSection(timer: timer)
        }
    }

    private func time(size: CGFloat) -> some View {
        Button {
            openPage(timer)
        } label: {
            Countdown(timer: timer)
                .font(.system(size: size, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .buttonStyle(.plain)
        .help("Set the timer")
    }

    private func playPause(side: CGFloat) -> some View {
        round(timer.isRunning ? "pause.fill" : "play.fill", side: side) { timer.toggle() }
            .contentTransition(.symbolEffect(.replace))
    }

    private func reset(side: CGFloat) -> some View {
        round("arrow.counterclockwise", side: side) { timer.reset() }
            .disabled(!isActive)
            .opacity(isActive ? 1 : 0.4)
    }

    private func round(_ symbol: String, side: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: side * 0.4, weight: .semibold))
                .frame(width: side, height: side)
                .glassControl(in: Circle())
        }
        .buttonStyle(.plain)
    }
}
