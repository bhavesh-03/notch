import SwiftUI

/// CPU, GPU, memory or temperature on Home: the current value, and a graph of the last minute once
/// there's room for one. The widget counts as a viewer of the monitor while it's on screen, so
/// sampling runs only while stats are visible.
struct StatsWidget: View {
    let kind: HomeWidgetKind
    let size: WidgetSize
    let monitor: SystemStatsMonitor
    @Environment(\.notchAccent) private var accent

    var body: some View {
        content
            .onAppear { monitor.addViewer() }
            .onDisappear { monitor.removeViewer() }
    }

    @ViewBuilder
    private var content: some View {
        switch size {
        case .small:
            VStack(alignment: .leading, spacing: 1) {
                label
                valueText.font(.system(size: 20, weight: .semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(alignment: .bottom) {
                Sparkline(values: history, color: accent).opacity(0.22).frame(height: 16)
            }
        case .wide:
            HStack(spacing: 10) {
                // The detail line only if the cell is tall enough for it.
                ViewThatFits(in: .vertical) {
                    VStack(alignment: .leading, spacing: 1) {
                        label
                        valueText.font(.system(size: 20, weight: .semibold))
                        detailText
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        label
                        valueText.font(.system(size: 20, weight: .semibold))
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                Sparkline(values: history, color: accent)
            }
        case .tall:
            VStack(alignment: .leading, spacing: 2) {
                label
                valueText.font(.system(size: 24, weight: .semibold))
                detailText
                if kind == .temperature, let sample {
                    Text(Self.thermalText(sample.thermalState))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 4)
                Sparkline(values: history, color: accent).frame(maxHeight: 34)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .large:
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    label
                    Spacer()
                    detailText
                }
                valueText.font(.system(size: 30, weight: .semibold))
                Sparkline(values: history, color: accent)
            }
        }
    }

    private var sample: SystemStatsSample? { monitor.latest }

    private var label: some View {
        Label(size.columns == 1 ? kind.shortTitle : kind.title, systemImage: kind.symbol)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.6))
            .lineLimit(1)
    }

    private var valueText: some View {
        Text(value)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(.snappy, value: value)
            .foregroundStyle(valueColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private var detailText: some View {
        if let detail {
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
        }
    }

    // MARK: - What each kind shows

    private var value: String {
        switch kind {
        case .cpu: Self.percent(sample?.cpuUsage)
        case .gpu: Self.percent(sample?.gpuUsage)
        case .memory: Self.percent(sample?.memoryFraction)
        case .temperature: sample?.cpuTemperature.map { "\(Int($0.rounded()))°" } ?? "–"
        default: "–"
        }
    }

    private var detail: String? {
        guard let sample else { return nil }
        switch kind {
        case .memory:
            guard let used = sample.memoryUsed else { return nil }
            return "\(Self.gigabytes(used)) of \(Self.gigabytes(sample.memoryTotal)) GB"
        case .temperature:
            let battery = sample.batteryTemperature.map { "Battery \(Int($0.rounded()))°" }
            // Large has room for both on one line; Tall shows the thermal state on its own line.
            return size == .large
                ? [battery, Self.thermalText(sample.thermalState)].compactMap { $0 }.joined(separator: " · ")
                : battery
        default:
            return nil
        }
    }

    /// Warning colors where the value means trouble; white otherwise.
    private var valueColor: Color {
        switch kind {
        case .memory:
            switch sample?.memoryPressure {
            case .warning: .yellow
            case .critical: .red
            default: .white
            }
        case .temperature:
            switch sample?.thermalState {
            case .serious: .orange
            case .critical: .red
            default: .white
            }
        default:
            .white
        }
    }

    /// The graph's points, 0...1. Temperatures are drawn on a 30–100 °C scale.
    private var history: [Double?] {
        monitor.history.map { sample in
            switch kind {
            case .cpu: sample.cpuUsage
            case .gpu: sample.gpuUsage
            case .memory: sample.memoryFraction
            case .temperature: sample.cpuTemperature.map { ($0 - 30) / 70 }
            default: nil
            }
        }
    }

    static func percent(_ fraction: Double?) -> String {
        fraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
    }

    static func gigabytes(_ bytes: UInt64) -> String {
        String(format: "%.1f", Double(bytes) / 1_073_741_824).replacingOccurrences(of: ".0", with: "")
    }

    static func thermalText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "Cool"
        case .fair: "Warm"
        case .serious: "Hot"
        case .critical: "Very hot"
        @unknown default: "–"
        }
    }
}

/// A small line graph with a soft fill beneath, for values from 0 to 1. Gaps (nil) break the line.
struct Sparkline: View {
    let values: [Double?]
    let color: Color

    var body: some View {
        Canvas { context, size in
            let count = max(values.count, 2)
            let step = size.width / CGFloat(max(SystemStatsMonitor.historyLength, count) - 1)
            // Newest at the right edge, so the graph grows in from the right like Activity Monitor.
            let start = size.width - step * CGFloat(values.count - 1)
            var line = Path()
            var area = Path()
            var open = false
            var lastX: CGFloat = 0
            for (index, value) in values.enumerated() {
                let x = start + step * CGFloat(index)
                guard let value else {
                    if open { area.addLine(to: CGPoint(x: lastX, y: size.height)); area.closeSubpath() }
                    open = false
                    continue
                }
                let y = size.height * (1 - min(max(value, 0), 1))
                if open {
                    line.addLine(to: CGPoint(x: x, y: y))
                    area.addLine(to: CGPoint(x: x, y: y))
                } else {
                    line.move(to: CGPoint(x: x, y: y))
                    area.move(to: CGPoint(x: x, y: size.height))
                    area.addLine(to: CGPoint(x: x, y: y))
                    open = true
                }
                lastX = x
            }
            if open { area.addLine(to: CGPoint(x: lastX, y: size.height)); area.closeSubpath() }
            context.fill(area, with: .linearGradient(
                Gradient(colors: [color.opacity(0.35), color.opacity(0)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}
