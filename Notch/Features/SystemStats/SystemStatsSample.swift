import Foundation

/// One reading of the Mac's vitals. Every value is optional: each comes from a different source, and
/// any of them can be unavailable (an Intel Mac has no HID temperature sensors, for example).
nonisolated struct SystemStatsSample: Equatable {
    /// 0...1, all cores together.
    var cpuUsage: Double?
    /// 0...1, the GPU's own utilization figure.
    var gpuUsage: Double?
    /// Bytes in use, counted the way Activity Monitor's "Memory Used" does.
    var memoryUsed: UInt64?
    var memoryTotal: UInt64
    var memoryPressure: MemoryPressure?
    /// °C, the hottest CPU die sensor.
    var cpuTemperature: Double?
    /// °C.
    var batteryTemperature: Double?
    var thermalState: ProcessInfo.ThermalState

    static let empty = SystemStatsSample(memoryTotal: ProcessInfo.processInfo.physicalMemory, thermalState: .nominal)

    var memoryFraction: Double? {
        guard let memoryUsed, memoryTotal > 0 else { return nil }
        return Double(memoryUsed) / Double(memoryTotal)
    }
}

/// The kernel's memory pressure level, the same signal Activity Monitor's pressure graph colors by.
nonisolated enum MemoryPressure: Int {
    case normal = 1
    case warning = 2
    case critical = 4
}

/// CPU time counters for all cores, as the kernel reports them: ever-increasing ticks per state.
nonisolated struct CPUTicks: Equatable {
    var busy: UInt64
    var idle: UInt64

    /// The share of time spent busy between `previous` and now, or nil without a usable interval.
    func usage(since previous: CPUTicks) -> Double? {
        guard busy >= previous.busy, idle >= previous.idle else { return nil }   // counters reset
        let busyDelta = Double(busy - previous.busy)
        let total = busyDelta + Double(idle - previous.idle)
        guard total > 0 else { return nil }
        return busyDelta / total
    }
}

/// Makes sense of the temperature sensors' readings.
nonisolated enum TemperatureSensors {
    /// Plausible readings only: some sensors report placeholders like -22 °C or 0.
    static let plausible: ClosedRange<Double> = 5...130

    /// The hottest CPU die ("tdie") sensor.
    static func cpu(from readings: [(name: String, celsius: Double)]) -> Double? {
        readings
            .filter { $0.name.localizedCaseInsensitiveContains("tdie") && plausible.contains($0.celsius) }
            .map(\.celsius)
            .max()
    }

    /// The battery's gas gauge sensor.
    static func battery(from readings: [(name: String, celsius: Double)]) -> Double? {
        readings
            .first { $0.name.localizedCaseInsensitiveContains("battery") && plausible.contains($0.celsius) }?
            .celsius
    }
}
