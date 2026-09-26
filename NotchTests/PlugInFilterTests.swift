import Foundation
import Testing
@testable import Notch

@MainActor
struct PlugInFilterTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 0)
    let unplugged = BatteryStatus(level: 50, isCharging: false, isPluggedIn: false)
    let plugged = BatteryStatus(level: 50, isCharging: false, isPluggedIn: true)
    let charging = BatteryStatus(level: 50, isCharging: true, isPluggedIn: true)

    @Test func firstPlugInAfterLaunchIsAnnounced() {
        var filter = PlugInFilter()
        let result1 = filter.shouldAnnounce(plugged, after: unplugged, at: t0)
        #expect(result1)
    }

    @Test func noPreviousReadingIsNeverAnnounced() {
        var filter = PlugInFilter()
        let result2 = filter.shouldAnnounce(plugged, after: nil, at: t0)
        #expect(!result2)
    }

    @Test func quickReconnectIsIgnored() {
        var filter = PlugInFilter()
        _ = filter.shouldAnnounce(plugged, after: unplugged, at: t0)
        let result3 = filter.shouldAnnounce(unplugged, after: plugged, at: t0 + 10)
        #expect(!result3)
        let result4 = filter.shouldAnnounce(plugged, after: unplugged, at: t0 + 10.8)
        #expect(!result4)
    }

    @Test func reconnectAfterTheMinimumIsAnnounced() {
        var filter = PlugInFilter()
        _ = filter.shouldAnnounce(unplugged, after: plugged, at: t0)
        let result5 = filter.shouldAnnounce(plugged, after: unplugged, at: t0 + 2)
        #expect(result5)
    }

    @Test func chargingStartingLaterIsNotAnnounced() {
        var filter = PlugInFilter()
        _ = filter.shouldAnnounce(plugged, after: unplugged, at: t0)
        let result6 = filter.shouldAnnounce(charging, after: plugged, at: t0 + 3)
        #expect(!result6)
    }

    @Test func aFlappingCableAnnouncesOnlyOnceItSettles() {
        var filter = PlugInFilter()
        var announced: [Bool] = []
        // (previous, current, seconds): plug in, the cable flaps twice, then it's replugged after a real gap
        let events: [(BatteryStatus, BatteryStatus, TimeInterval)] = [
            (unplugged, plugged, 0),
            (plugged, unplugged, 5), (unplugged, plugged, 5.3),
            (plugged, unplugged, 5.9), (unplugged, plugged, 6.4),
            (plugged, unplugged, 6.9), (unplugged, plugged, 9.5),
        ]
        for (previous, current, time) in events {
            announced.append(filter.shouldAnnounce(current, after: previous, at: t0 + time))
        }
        #expect(announced == [true, false, false, false, false, false, true])
    }
}
