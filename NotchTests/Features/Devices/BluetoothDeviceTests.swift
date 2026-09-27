import AppKit
import Foundation
import Testing
@testable import Notch

@MainActor
struct BluetoothDeviceTests {
    typealias Kind = BluetoothDeviceInfo.Kind

    // The devices paired to this Mac when the feature was built (from a probe), plus a few more.
    @Test(arguments: [
        ("UK AirPods Pro - Find My", 4, 6, Kind.airPodsPro),
        ("Vineet's AirPods", 4, 6, .airPods),
        ("AirPods Max", 4, 6, .airPodsMax),
        ("Powerbeats Pro", 4, 1, .beats),
        ("WH-1000XM4", 4, 1, .headphones),
        ("MiSuperBassWirelessHeadphones", 4, 1, .headphones),
        ("JBL Flip 6", 4, 5, .speaker),
        ("Keyboard K480", 5, 16, .keyboard),
        ("MX Master 3", 5, 32, .mouse),
        ("DualSense Wireless Controller", 5, 2, .gameController),
        ("Vineet's iPhone", 0, 0, .other),
    ])
    func classifies(name: String, major: Int, minor: Int, kind: Kind) {
        #expect(Kind.classify(name: name, majorClass: major, minorClass: minor) == kind)
    }

    @Test func everyKindHasASymbol() {
        let kinds: [Kind] = [.airPods, .airPodsPro, .airPodsMax, .beats, .headphones, .speaker, .keyboard, .mouse, .gameController, .other]
        for kind in kinds {
            #expect(NSImage(systemSymbolName: kind.symbol, accessibilityDescription: nil) != nil, "\(kind.symbol)")
        }
    }

    @Test func zeroMeansUnknown() {
        let battery = BluetoothDeviceInfo.Battery(single: 0, left: 0, right: 0, caseLevel: 0)
        #expect(!battery.isKnown)
        #expect(battery.summary == nil)
    }

    @Test func theSummaryIsTheLowerBud() {
        #expect(BluetoothDeviceInfo.Battery(left: 80, right: 45, caseLevel: 100).summary == 45)
        #expect(BluetoothDeviceInfo.Battery(single: 70).summary == 70)
        #expect(BluetoothDeviceInfo.Battery(caseLevel: 60).summary == 60, "just the case, while the buds are in it")
    }
}

@MainActor
struct BluetoothMonitorTests {
    private func airPods(battery: BluetoothDeviceInfo.Battery? = nil) -> BluetoothDeviceInfo {
        BluetoothDeviceInfo(id: "aa-bb", name: "AirPods Pro", kind: .airPodsPro, battery: battery ?? .unknown)
    }

    @Test func aNewConnectionIsAnnounced() {
        let monitor = BluetoothMonitor()
        var announced: [String] = []
        monitor.onConnected = { announced.append($0.name) }
        monitor.record(airPods(), announce: true)
        #expect(announced == ["AirPods Pro"])
        #expect(monitor.latestConnection?.id == "aa-bb")
        #expect(monitor.devices.count == 1)
    }

    @Test func alreadyConnectedDevicesAreListedQuietly() {
        let monitor = BluetoothMonitor()
        var announced = 0
        monitor.onConnected = { _ in announced += 1 }
        monitor.record(airPods(), announce: false)
        #expect(announced == 0)
        #expect(monitor.devices.count == 1)
    }

    @Test func batteriesArrivingLaterUpdateThePopUpToo() {
        let monitor = BluetoothMonitor()
        monitor.record(airPods(), announce: true)
        monitor.updateBattery(id: "aa-bb", to: .init(left: 90, right: 88, caseLevel: 60))
        #expect(monitor.devices.first?.battery.left == 90)
        #expect(monitor.latestConnection?.battery.caseLevel == 60)
    }

    @Test func reconnectingDoesNotListTwice() {
        let monitor = BluetoothMonitor()
        monitor.record(airPods(), announce: true)
        monitor.record(airPods(battery: .init(left: 50, right: 50)), announce: true)
        #expect(monitor.devices.count == 1)
        #expect(monitor.devices.first?.battery.left == 50)
    }

    @Test func disconnectingRemoves() {
        let monitor = BluetoothMonitor()
        monitor.record(airPods(), announce: false)
        monitor.removeDevice(id: "aa-bb")
        #expect(monitor.devices.isEmpty)
    }
}
