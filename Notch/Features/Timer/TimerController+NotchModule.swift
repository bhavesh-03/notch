//
//  TimerController+NotchModule.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//


import SwiftUI

extension TimerController: NotchModule {
    var feature: NotchFeature { .timer }

    var earPriority: Int? {
        state.phase == .idle ? nil : 10
    }

    /// No tab-bar button: the page opens when you tap the timer on Home.
    var tab: NotchTab? { NotchTab(title: "Timer", symbol: "timer", style: .page) }

    /// Tall only while choosing a length (the ruler needs the room); a running countdown fits the normal height.
    var wantsTallPage: Bool { state.phase == .idle }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        Group {
            switch placement {
            case .leadingEar:
                Image(systemName: isRunning ? "timer" : "pause.fill")
            case .trailingEar:
                Countdown(timer: self)
                    .font(.caption2)
            case .pill:
                Countdown(timer: self)
                    .font(.caption)
            case .expanded:
                TimerSection(timer: self)
            case .page:
                TimerPage(timer: self)
            case .headline:
                EmptyView()
            case .activityLeading:
                Image(systemName: "timer")
                    .font(.title2)
            case .activityTrailing:
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            case .activityDetail:
                Text("Time's up")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .animation(.snappy, value: state)
    }
}

private struct TimerSection: View {
    let timer: TimerController
    @Environment(\.openNotchPage) private var openPage

    private var isActive: Bool { timer.state.phase != .idle }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                openPage(timer)
            } label: {
                Countdown(timer: timer)
                    .font(.system(size: 34, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Set the timer")
            HStack(spacing: 12) {
                Button {
                    timer.toggle()
                } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.15), in: Circle())
                }
                Button {
                    timer.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.15), in: Circle())
                }
                .disabled(!isActive)
                .opacity(isActive ? 1 : 0.4)
            }
            .buttonStyle(.plain)
        }
    }
}

struct Countdown: View {
    let timer: TimerController

    var body: some View {
        if case .running(let endDate) = timer.state.phase {
            TimelineView(.periodic(from: endDate.addingTimeInterval(-timer.state.duration), by: 1)) { context in
                text(for: timer.remaining(at: context.date))
            }
        } else {
            text(for: timer.remaining(at: .now))
        }
    }

    private func text(for remaining: TimeInterval) -> some View {
        Text(TimerFormat.string(seconds: Int(remaining.rounded(.up))))
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
            .fixedSize()
    }
}