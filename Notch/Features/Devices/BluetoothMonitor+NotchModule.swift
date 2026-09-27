import SwiftUI

/// Devices pop up when they connect, like the card an iPhone shows for AirPods: the device springs
/// in and its battery rings fill. Nothing in the ears; the Devices widget lists what's connected.
extension BluetoothMonitor: NotchModule {
    var feature: NotchFeature { .devices }
    var earPriority: Int? { nil }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        if let device = latestConnection {
            switch placement {
            case .activityLeading:
                DeviceGlyph(kind: device.kind)
                    .font(.system(size: 22))
            case .activityTrailing:
                if let level = device.battery.summary {
                    BatteryRing(level: level, lineWidth: 3)
                        .frame(width: 26, height: 26)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
            case .activityDetail:
                HStack(spacing: 10) {
                    Text(device.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    // Buds get L, R and case; anything else already shows its level in the ring above.
                    if device.kind.hasBuds && device.battery.isKnown {
                        BatteryLevels(battery: device.battery, kind: device.kind)
                    } else {
                        Text("Connected")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
            default:
                EmptyView()
            }
        }
    }
}

/// The device's symbol, springing in when it appears.
struct DeviceGlyph: View {
    let kind: BluetoothDeviceInfo.Kind
    @State private var appeared = false

    var body: some View {
        Image(systemName: kind.symbol)
            .symbolRenderingMode(.hierarchical)
            .scaleEffect(appeared ? 1 : 0.4)
            .opacity(appeared ? 1 : 0)
            .symbolEffect(.bounce, value: appeared)
            .onAppear {
                withAnimation(.spring(duration: 0.6, bounce: 0.45).delay(0.15)) { appeared = true }
            }
    }
}

/// A ring that fills to the battery level when it appears; red when low.
struct BatteryRing: View {
    let level: Int
    var lineWidth: CGFloat = 2.5
    var showsText = true
    @State private var filled = false

    private var color: Color { level <= 20 ? .red : .green }

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: filled ? Double(level) / 100 : 0)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsText {
                Text("\(level)")
                    .font(.system(size: 8, weight: .bold))
                    .monospacedDigit()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.3)) { filled = true }
        }
    }
}

/// L, R and case for AirPods and Beats; one level for anything else; nothing if it doesn't report.
struct BatteryLevels: View {
    let battery: BluetoothDeviceInfo.Battery
    let kind: BluetoothDeviceInfo.Kind

    var body: some View {
        HStack(spacing: 8) {
            if kind.hasBuds {
                level("L", battery.left)
                level("R", battery.right)
                level("Case", battery.caseLevel)
            } else if let single = battery.single ?? battery.summary {
                level(nil, single)
            } else {
                Text("Connected")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .animation(.snappy, value: battery)
    }

    @ViewBuilder
    private func level(_ label: String?, _ value: Int?) -> some View {
        if let value {
            HStack(spacing: 3) {
                if let label {
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                BatteryRing(level: value, lineWidth: 2, showsText: false)
                    .frame(width: 11, height: 11)
                Text("\(value)%")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            }
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
        }
    }
}

/// Connected devices and their batteries, on Home.
struct DevicesWidget: View {
    let monitor: BluetoothMonitor
    let size: WidgetSize

    var body: some View {
        DevicesWidgetContent(devices: monitor.devices, size: size)
    }
}

/// The widget's layout from plain values, so it can be previewed.
struct DevicesWidgetContent: View {
    let devices: [BluetoothDeviceInfo]
    let size: WidgetSize

    var body: some View {
        if devices.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Image(systemName: "dot.radiowaves.left.and.right")
                Text("No devices")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if size == .small, let device = devices.last {
            HStack(spacing: 6) {
                Image(systemName: device.kind.symbol)
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                if let level = device.battery.summary {
                    Text("\(level)%")
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(level <= 20 ? .red : .white)
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(devices.suffix(size.rows == 2 ? 3 : 1).reversed()) { device in
                    HStack(spacing: 8) {
                        Image(systemName: device.kind.symbol)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 20)
                        if size.columns == 2 {
                            Text(device.name)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            if let level = device.battery.summary {
                                // One level per row: the lower bud for AirPods.
                                HStack(spacing: 3) {
                                    BatteryRing(level: level, lineWidth: 2, showsText: false)
                                        .frame(width: 11, height: 11)
                                    Text("\(level)%")
                                        .font(.caption2.weight(.semibold))
                                        .monospacedDigit()
                                }
                            }
                        } else {
                            Spacer(minLength: 0)
                            if let level = device.battery.summary {
                                BatteryRing(level: level)
                                    .frame(width: 22, height: 22)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
