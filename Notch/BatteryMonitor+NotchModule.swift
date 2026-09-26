//
//  BatteryMonitor+NotchModule.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//


import SwiftUI

extension BatteryMonitor: NotchModule {
    var earPriority: Int? {
        status == nil ? nil : 0
    }

    @ViewBuilder
    func content(for placement: NotchPlacement) -> some View {
        if let status {
            Group {
                switch placement {
                case .leadingEar, .pill:
                    BatteryIcon(status: status)
                case .trailingEar:
                    BatteryPercentage(status: status)
                        .font(.caption2)
                case .expanded:
                    BatterySection(status: status)
                case .activityLeading:
                    BatteryIcon(status: status)
                        .font(.title2)
                case .activityTrailing:
                    BatteryPercentage(status: status)
                        .font(.title3.bold())
                case .activityDetail:
                    Text(status.isCharging ? "Charging" : "Power connected")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .animation(.snappy, value: status)
        } else if placement == .expanded {
            Text("No battery")
        }
    }
}

private struct BatteryIcon: View {
    let status: BatteryStatus

    var body: some View {
        Image(systemName: status.symbolName)
            .contentTransition(.symbolEffect(.replace))
    }
}

private struct BatteryPercentage: View {
    let status: BatteryStatus

    var body: some View {
        Text("\(status.level)%")
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

private struct BatterySection: View {
    let status: BatteryStatus

    var body: some View {
        VStack(spacing: 6) {
            BatteryIcon(status: status)
                .font(.title)
            BatteryPercentage(status: status)
                .font(.title3.bold())
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var statusText: String {
        if status.isCharging {
            "Charging"
        } else if status.isPluggedIn {
            "Plugged in"
        } else {
            "On battery"
        }
    }
}

