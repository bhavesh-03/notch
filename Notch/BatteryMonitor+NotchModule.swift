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
                    ChargingBattery(status: status)
                case .activityTrailing:
                    BatteryPercentage(status: status)
                        .font(.title3.bold())
                case .activityDetail:
                    Text(status.isCharging ? "Charging" : "Connected")
                        .font(.caption)
                        .foregroundStyle(.green)
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

/// The battery drawn by hand so its fill can animate continuously (SF Symbols only have 0/25/50/75/100%).
/// Always green: it celebrates power arriving. At plug-in macOS usually reports "not charging yet",
/// so the accurate charging-vs-on-hold state is left to the ear icon (bolt vs plug) afterwards.
struct ChargingBattery: View {
    let status: BatteryStatus

    @State private var isFilled: Bool
    @State private var showsBolt: Bool

    init(status: BatteryStatus, startsFinished: Bool = false) {
        self.status = status
        _isFilled = State(initialValue: startsFinished)
        _showsBolt = State(initialValue: startsFinished)
    }

    var body: some View {
        HStack(spacing: 1.5) {
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
                .overlay(alignment: .leading) {
                    BatteryFill(level: isFilled ? Double(status.level) / 100 : 0)
                        .fill(.green)
                        .padding(3)
                }
                .overlay {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .scaleEffect(showsBolt ? 1 : 0.01)
                        .opacity(showsBolt ? 1 : 0)
                }
                .frame(width: 36, height: 17)

            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.5))
                .frame(width: 2.5, height: 6)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.25)) {
                isFilled = true
            }
            withAnimation(.bouncy(duration: 0.45, extraBounce: 0.25).delay(0.6)) {
                showsBolt = true
            }
        }
    }
}

/// The filled part of the battery; `level` (0...1) is animatable, so SwiftUI draws every in-between frame.
struct BatteryFill: Shape {
    var level: Double

    var animatableData: Double {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(level, 0), 1)
        let fillRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width * clamped, height: rect.height)
        return Path(roundedRect: fillRect, cornerRadius: 2.5)
    }
}
