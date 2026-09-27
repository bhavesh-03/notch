import Foundation
import Testing
@testable import Notch

struct CPUTicksTests {
    @Test func usageIsTheBusyShareOfTheInterval() {
        let before = CPUTicks(busy: 100, idle: 900)
        let after = CPUTicks(busy: 130, idle: 970)   // 30 busy of 100 ticks
        #expect(after.usage(since: before) == 0.3)
    }

    @Test func noTimePassedMeansNoReading() {
        let ticks = CPUTicks(busy: 100, idle: 900)
        #expect(ticks.usage(since: ticks) == nil)
    }

    @Test func countersThatWentBackwardsAreIgnored() {
        #expect(CPUTicks(busy: 10, idle: 10).usage(since: CPUTicks(busy: 100, idle: 900)) == nil)
    }
}

struct TemperatureSensorsTests {
    let readings: [(name: String, celsius: Double)] = [
        ("PMU2 tdev1", -22.4), ("PMU tdie12", 39.9), ("PMU2 tdie5", 36.1), ("PMU tdie8", 44.7),
        ("PMU tcal", 51.8), ("gas gauge battery", 33.7), ("PMU tdie3", 0),
    ]

    @Test func cpuIsTheHottestDie() {
        #expect(TemperatureSensors.cpu(from: readings) == 44.7, "tcal isn't a die sensor")
    }

    @Test func batteryIsTheGasGauge() {
        #expect(TemperatureSensors.battery(from: readings) == 33.7)
    }

    @Test func implausibleReadingsAreIgnored() {
        #expect(TemperatureSensors.cpu(from: [("PMU tdie1", -22), ("PMU tdie2", 0), ("PMU tdie3", 400)]) == nil)
    }
}

@MainActor
struct SystemStatsMonitorTests {
    nonisolated final class FakeReader: SystemStatsReading, @unchecked Sendable {
        var count = 0
        func sample() -> SystemStatsSample {
            count += 1
            var sample = SystemStatsSample.empty
            sample.cpuUsage = Double(count) / 100
            return sample
        }
    }

    @Test func samplesOnlyWhileSomeoneIsLooking() async {
        let reader = FakeReader()
        let monitor = SystemStatsMonitor(reader: reader, interval: .milliseconds(20))
        #expect(!monitor.isSampling)

        monitor.addViewer()
        #expect(await eventually { monitor.latest != nil })

        monitor.removeViewer()
        #expect(!monitor.isSampling)
        let countAfterStop = reader.count
        try? await Task.sleep(for: .milliseconds(100))
        #expect(reader.count <= countAfterStop + 1, "at most one reading already in flight")
    }

    @Test func twoViewersShareOneSampler() {
        let monitor = SystemStatsMonitor(reader: FakeReader(), interval: .seconds(60))
        monitor.addViewer()
        monitor.addViewer()
        monitor.removeViewer()
        #expect(monitor.isSampling, "one viewer is still looking")
        monitor.removeViewer()
        #expect(!monitor.isSampling)
    }

    @Test func historyKeepsTheLatestSamples() {
        let monitor = SystemStatsMonitor(reader: FakeReader())
        for index in 0..<(SystemStatsMonitor.historyLength + 5) {
            var sample = SystemStatsSample.empty
            sample.cpuUsage = Double(index)
            monitor.record(sample)
        }
        #expect(monitor.history.count == SystemStatsMonitor.historyLength)
        #expect(monitor.history.last?.cpuUsage == Double(SystemStatsMonitor.historyLength + 4))
        #expect(monitor.history.first?.cpuUsage == 5)
    }
}

/// Runs the real reader inside the sandboxed test host, so a sandbox or macOS change that cuts off
/// a source shows up here instead of as a silently empty widget.
struct SystemStatsReaderTests {
    @Test func readsTheMacsVitalsInsideTheSandbox() async throws {
        let reader = SystemStatsReader()
        _ = reader.sample()                          // CPU usage needs two readings
        try await Task.sleep(for: .milliseconds(200))
        let sample = reader.sample()

        let cpu = try #require(sample.cpuUsage)
        #expect((0...1).contains(cpu))
        let memory = try #require(sample.memoryUsed)
        #expect(memory > 0 && memory <= sample.memoryTotal)
        #expect(sample.memoryPressure != nil)
        #if arch(arm64)
        let gpu = try #require(sample.gpuUsage)
        #expect((0...1).contains(gpu))
        let temperature = try #require(sample.cpuTemperature)
        #expect(TemperatureSensors.plausible.contains(temperature))
        #endif
    }
}
