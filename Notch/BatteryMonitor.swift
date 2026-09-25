//
//  BatteryMonitor.swift
//  Notch
//
//  Created by Vineet Parmar on 26/09/26.
//


import Foundation
import IOKit.ps
import notify

@Observable
final class BatteryMonitor {
    private(set) var status: BatteryStatus?
    @ObservationIgnored private var notifyToken: Int32 = NOTIFY_TOKEN_INVALID

    init() {
        refresh()
        notify_register_dispatch(kIOPSNotifyAnyPowerSource, &notifyToken, .main) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        notify_cancel(notifyToken)
    }

    private func refresh() {
        status = Self.readStatus()
    }

    private static func readStatus() -> BatteryStatus? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }

            if let status = BatteryStatus(description: description) {
                return status
            }
        }
        return nil
    }
}
