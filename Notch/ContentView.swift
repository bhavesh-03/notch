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
            .foregroundStyle(.white)
            .clipShape(notchShape)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var battery: BatteryStatus? { viewModel.battery.status }

    @ViewBuilder
    private var collapsedContent: some View {
        switch geometry.kind {
        case .hardware:
            HStack(spacing: 0) {
                Group {
                    if let battery {
                        batteryIcon(battery)
                    }
                }
                .frame(width: NotchGeometry.earWidth)

                Spacer()

                Group {
                    if let battery {
                        batteryPercentage(battery)
                            .font(.caption2)
                    }
                }
                .frame(width: NotchGeometry.earWidth)
            }
        case .virtual:
            if let battery {
                batteryIcon(battery)
            }
        }
    }

    private var expandedContent: some View {
        HStack(spacing: 12) {
            if let battery {
                batteryIcon(battery)
                    .font(.title)
                VStack(alignment: .leading, spacing: 2) {
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
        .transition(.opacity)
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
