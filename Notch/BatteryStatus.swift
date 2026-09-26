//
//  BatteryStatus.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//


import IOKit.ps

struct BatteryStatus: Equatable {
    let level: Int
    let isCharging: Bool
    let isPluggedIn: Bool

    init(level: Int, isCharging: Bool, isPluggedIn: Bool) {
        self.level = level
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
    }

    init?(description: [String: Any]) {
        guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              let current = description[kIOPSCurrentCapacityKey] as? Int,
              let max = description[kIOPSMaxCapacityKey] as? Int,
              max > 0 else { return nil }

        self.init(
            level: current * 100 / max,
            isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
            isPluggedIn: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        )
    }

    var symbolName: String {
        if isCharging { return "battery.100percent.bolt" }
        if isPluggedIn { return "powerplug.fill" }

        switch level {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default:    return "battery.100percent"
        }
    }

    func isPlugIn(after previous: BatteryStatus?) -> Bool {
        guard let previous else { return false }
        return !previous.isPluggedIn && isPluggedIn
    }
}
