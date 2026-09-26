import SwiftUI

struct ContentView: View {

    let viewModel: NotchViewModel

    private var geometry: NotchGeometry { viewModel.geometry }

    private var size: CGSize {
        viewModel.isExpanded ? NotchGeometry.expandedSize : geometry.collapsedRect.size
    }

    private var notchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            bottomLeadingRadius: viewModel.isExpanded ? 24 : 10,
            bottomTrailingRadius: viewModel.isExpanded ? 24 : 10
        )
    }

    var body: some View {
        notchShape.fill(.black)
            .frame(width: size.width, height: size.height)
            .overlay {
                if viewModel.isExpanded {
                    expandedContent
                } else {
                    collapsedContent
                }
            }
            .animation(.snappy, value: battery)
            .animation(.snappy, value: timer.state)
            .foregroundStyle(.white)
            .clipShape(notchShape)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var battery: BatteryStatus? { viewModel.battery.status }
    private var timer: TimerController { viewModel.timer }
    private var timerIsActive: Bool { timer.state.phase != .idle }

    @ViewBuilder
    private var collapsedContent: some View {
        switch geometry.kind {
        case .hardware:
            HStack(spacing: 0) {
                Group {
                    if timerIsActive {
                        Image(systemName: timer.isRunning ? "timer" : "pause.fill")
                    } else if let battery {
                        batteryIcon(battery)
                    }
                }
                .frame(width: NotchGeometry.earWidth)

                Spacer()

                Group {
                    if timerIsActive {
                        countdown
                    } else if let battery {
                        batteryPercentage(battery)
                    }
                }
                .font(.caption2)
                .frame(width: NotchGeometry.earWidth)
            }
        case .virtual:
            if timerIsActive {
                countdown.font(.caption)
            } else if let battery {
                batteryIcon(battery)
            }
        }
    }

    private var expandedContent: some View {
        HStack(spacing: 20) {
            batterySection
            Divider()
                .overlay(.white.opacity(0.3))
                .frame(height: 60)
            timerSection
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private var batterySection: some View {
        if let battery {
            VStack(spacing: 6) {
                batteryIcon(battery)
                    .font(.title)
                batteryPercentage(battery)
                    .font(.title3.bold())
                Text(statusText(for: battery))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        } else {
            Text("No battery")
        }
    }

    private var timerSection: some View {
        VStack(spacing: 10) {
            countdown
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
                .disabled(!timerIsActive)
                .opacity(timerIsActive ? 1 : 0.4)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var countdown: some View {
        if case .running(let endDate) = timer.state.phase {
            TimelineView(.periodic(from: endDate.addingTimeInterval(-timer.state.duration), by: 1)) { context in
                countdownText(timer.remaining(at: context.date))
            }
        } else {
            countdownText(timer.remaining(at: .now))
        }
    }

    private func countdownText(_ remaining: TimeInterval) -> some View {
        Text(Duration.seconds(Int(remaining.rounded(.up))).formatted(.time(pattern: .minuteSecond)))
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
            .fixedSize()
    }

    private func batteryIcon(_ battery: BatteryStatus) -> some View {
        Image(systemName: battery.symbolName)
            .contentTransition(.symbolEffect(.replace))
    }

    private func batteryPercentage(_ battery: BatteryStatus) -> some View {
        Text("\(battery.level)%")
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    private func statusText(for battery: BatteryStatus) -> String {
        if battery.isCharging {
            "Charging"
        } else if battery.isPluggedIn {
            "Plugged in"
        } else {
            "On battery"
        }
    }
}

extension NotchGeometry {
    static let previewHardware = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
        leftAreaWidth: 645.5,
        rightAreaWidth: 645.5,
        notchHeight: 32,
        kind: .hardware
    )

    static let previewVirtual = NotchGeometry(
        screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
        leftAreaWidth: 645,
        rightAreaWidth: 645,
        notchHeight: 24,
        kind: .virtual
    )
}

#Preview("Collapsed · hardware") {
    ContentView(viewModel: NotchViewModel(geometry: .previewHardware))
        .frame(width: 400, height: 150)
}

#Preview("Collapsed · virtual") {
    ContentView(viewModel: NotchViewModel(geometry: .previewVirtual))
        .frame(width: 400, height: 150)
}

#Preview("Expanded") {
    let model = NotchViewModel(geometry: .previewHardware)
    model.isExpanded = true
    return ContentView(viewModel: model)
        .frame(width: 400, height: 150)
}
