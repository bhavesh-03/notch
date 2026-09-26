//
//  TimerController+NotchModule.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//


import SwiftUI

extension TimerController: NotchModule {
    var earPriority: Int? {
        state.phase == .idle ? nil : 10
    }

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
            }
        }
        .animation(.snappy, value: state)
    }
}

private struct TimerSection: View {
    let timer: TimerController

    private var isActive: Bool { timer.state.phase != .idle }

    var body: some View {
        VStack(spacing: 10) {
            Countdown(timer: timer)
                .font(.system(size: 34, weight: .semibold))
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

private struct Countdown: View {
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
        Text(Duration.seconds(Int(remaining.rounded(.up))).formatted(.time(pattern: .minuteSecond)))
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
            .fixedSize()
    }
}