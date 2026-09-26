import IOKit.ps
import SwiftUI
import Testing
@testable import Notch

@MainActor
struct BatteryStatusTests {
    private func description(
        type: String = kIOPSInternalBatteryType,
        current: Int? = 79,
        max: Int? = 100,
        charging: Bool? = false,
        state: String = kIOPSBatteryPowerValue
    ) -> [String: Any] {
        var d: [String: Any] = [kIOPSTypeKey: type, kIOPSPowerSourceStateKey: state]
        d[kIOPSCurrentCapacityKey] = current
        d[kIOPSMaxCapacityKey] = max
        d[kIOPSIsChargingKey] = charging
        return d
    }

    @Test func parsesOnBattery() throws {
        let status = try #require(BatteryStatus(description: description()))
        #expect(status == BatteryStatus(level: 79, isCharging: false, isPluggedIn: false))
    }

    @Test func parsesCharging() throws {
        let status = try #require(BatteryStatus(description: description(charging: true, state: kIOPSACPowerValue)))
        #expect(status.isCharging)
        #expect(status.isPluggedIn)
    }

    @Test func pluggedInButNotChargingIsDistinct() throws {
        let status = try #require(BatteryStatus(description: description(charging: false, state: kIOPSACPowerValue)))
        #expect(!status.isCharging)
        #expect(status.isPluggedIn)
    }

    @Test func capacityInMilliampHoursIsConvertedToPercent() throws {
        let status = try #require(BatteryStatus(description: description(current: 4380, max: 5200)))
        #expect(status.level == 84)
    }

    @Test func missingChargingKeyMeansNotCharging() throws {
        let status = try #require(BatteryStatus(description: description(charging: nil)))
        #expect(!status.isCharging)
    }

    @Test func nonInternalBatteryIsRejected() {
        #expect(BatteryStatus(description: description(type: "UPS")) == nil)
    }

    @Test func zeroMaxCapacityIsRejectedInsteadOfDividingByZero() {
        #expect(BatteryStatus(description: description(max: 0)) == nil)
    }

    @Test func missingCapacityIsRejected() {
        #expect(BatteryStatus(description: description(current: nil)) == nil)
        #expect(BatteryStatus(description: description(max: nil)) == nil)
    }

    @Test(arguments: [
        (0, "battery.0percent"), (12, "battery.0percent"),
        (13, "battery.25percent"), (37, "battery.25percent"),
        (38, "battery.50percent"), (62, "battery.50percent"),
        (63, "battery.75percent"), (87, "battery.75percent"),
        (88, "battery.100percent"), (100, "battery.100percent"),
    ])
    func symbolMatchesLevelOnBattery(level: Int, symbol: String) {
        let status = BatteryStatus(level: level, isCharging: false, isPluggedIn: false)
        #expect(status.symbolName == symbol)
    }

    @Test func chargingShowsBoltRegardlessOfLevel() {
        let status = BatteryStatus(level: 10, isCharging: true, isPluggedIn: true)
        #expect(status.symbolName == "battery.100percent.bolt")
    }

    @Test func pluggedInNotChargingShowsPlug() {
        let status = BatteryStatus(level: 80, isCharging: false, isPluggedIn: true)
        #expect(status.symbolName == "powerplug.fill")
    }

    @Test func plugInIsDetectedOnlyOnTheTransition() {
        let onBattery = BatteryStatus(level: 50, isCharging: false, isPluggedIn: false)
        let pluggedHold = BatteryStatus(level: 50, isCharging: false, isPluggedIn: true)
        let charging = BatteryStatus(level: 50, isCharging: true, isPluggedIn: true)

        #expect(pluggedHold.isPlugIn(after: onBattery))
        #expect(charging.isPlugIn(after: onBattery))
        #expect(!charging.isPlugIn(after: pluggedHold), "charging starting later is not a new plug-in")
        #expect(!onBattery.isPlugIn(after: charging), "unplugging is not a plug-in")
        #expect(!pluggedHold.isPlugIn(after: nil), "no previous reading (e.g. at launch) is not a plug-in")
    }
}

@MainActor
struct BatteryFillTests {
    let rect = CGRect(x: 0, y: 0, width: 30, height: 11)

    @Test(arguments: [(0.0, 0.0), (0.5, 15.0), (0.78, 23.4), (1.0, 30.0)])
    func fillWidthTracksLevel(level: Double, width: Double) {
        let bounds = BatteryFill(level: level).path(in: rect).boundingRect
        #expect(abs(bounds.width - width) < 0.001)
    }

    @Test func levelIsClampedToTheBattery() {
        #expect(BatteryFill(level: 1.4).path(in: rect).boundingRect.width == 30)
        #expect(BatteryFill(level: -0.2).path(in: rect).boundingRect.width == 0)
    }

    @Test func animatableDataIsTheLevel() {
        var fill = BatteryFill(level: 0.2)
        #expect(fill.animatableData == 0.2)
        fill.animatableData = 0.9
        #expect(fill.level == 0.9)
    }
}
