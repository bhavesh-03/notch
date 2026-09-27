import Darwin
import Foundation
import IOKit

/// Something that can take a reading; the monitor uses the real one, tests a fake.
nonisolated protocol SystemStatsReading: AnyObject, Sendable {
    func sample() -> SystemStatsSample
}

/// Reads the Mac's vitals from the kernel and IOKit. All of these work inside the App Sandbox
/// (checked from the sandboxed test host); fan speeds would need the SMC, which the sandbox blocks.
///
/// `nonisolated` (the project defaults to the main actor): a reading takes a few milliseconds, so the
/// monitor takes it off the main thread. `@unchecked Sendable` because the one piece of state, the previous CPU ticks, is
/// only touched from the monitor's one sampling task at a time.
nonisolated final class SystemStatsReader: SystemStatsReading, @unchecked Sendable {
    private var previousTicks: CPUTicks?
    private let temperatures = HIDTemperatureSensors()

    init() {}

    func sample() -> SystemStatsSample {
        var sample = SystemStatsSample.empty
        if let ticks = Self.cpuTicks() {
            sample.cpuUsage = previousTicks.flatMap { ticks.usage(since: $0) }
            previousTicks = ticks
        }
        sample.gpuUsage = Self.gpuUsage()
        sample.memoryUsed = Self.memoryUsed()
        sample.memoryPressure = Self.memoryPressure()
        let readings = temperatures.readings()
        sample.cpuTemperature = TemperatureSensors.cpu(from: readings)
        sample.batteryTemperature = TemperatureSensors.battery(from: readings)
        sample.thermalState = ProcessInfo.processInfo.thermalState
        return sample
    }

    // MARK: - CPU

    /// Sums every core's user, system and nice ticks (busy) and idle ticks.
    private static func cpuTicks() -> CPUTicks? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return nil }
        defer {
            // The kernel allocated the array in our address space; hand it back.
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        var ticks = CPUTicks(busy: 0, idle: 0)
        for core in 0..<Int(cpuCount) {
            let base = core * Int(CPU_STATE_MAX)
            func value(_ state: Int32) -> UInt64 { UInt64(UInt32(bitPattern: info[base + Int(state)])) }
            ticks.busy += value(CPU_STATE_USER) + value(CPU_STATE_SYSTEM) + value(CPU_STATE_NICE)
            ticks.idle += value(CPU_STATE_IDLE)
        }
        return ticks
    }

    // MARK: - GPU

    /// The GPU driver's own utilization figure, from its IORegistry statistics.
    private static func gpuUsage() -> Double? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        var usage: Double?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let stats = IORegistryEntryCreateCFProperty(service, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any],
               let percent = stats["Device Utilization %"] as? NSNumber {
                usage = max(usage ?? 0, percent.doubleValue / 100)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return usage
    }

    // MARK: - Memory

    /// App memory + wired + compressed, like Activity Monitor's "Memory Used".
    private static func memoryUsed() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(vm_kernel_page_size)
        let appPages = UInt64(stats.internal_page_count) - UInt64(stats.purgeable_count)
        return (appPages + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * pageSize
    }

    private static func memoryPressure() -> MemoryPressure? {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else { return nil }
        return MemoryPressure(rawValue: Int(level))
    }
}

/// The Mac's temperature sensors, read through the (private) IOHIDEventSystemClient: on Apple
/// Silicon, the only way to reach them that the sandbox allows. Looked up at runtime with dlsym, so a
/// future macOS without these functions just yields no temperatures instead of failing to launch.
nonisolated private final class HIDTemperatureSensors: @unchecked Sendable {
    private typealias CreateFn = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias SetMatchingFn = @convention(c) (AnyObject, CFDictionary) -> Int32
    private typealias CopyServicesFn = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
    private typealias CopyEventFn = @convention(c) (AnyObject, Int64, Int32, Int64) -> Unmanaged<AnyObject>?
    private typealias FloatValueFn = @convention(c) (AnyObject, Int32) -> Double
    private typealias CopyPropertyFn = @convention(c) (AnyObject, CFString) -> Unmanaged<AnyObject>?

    private static let temperatureEvent: Int64 = 15   // kIOHIDEventTypeTemperature

    private let copyEvent: CopyEventFn?
    private let floatValue: FloatValueFn?
    /// The sensors and their names, found once; the set doesn't change while the Mac runs.
    private let sensors: [(service: AnyObject, name: String)]
    private let client: AnyObject?

    init() {
        let iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW)
        func load<T>(_ name: String, as type: T.Type) -> T? {
            dlsym(iokit, name).map { unsafeBitCast($0, to: type) }
        }
        copyEvent = load("IOHIDServiceClientCopyEvent", as: CopyEventFn.self)
        floatValue = load("IOHIDEventGetFloatValue", as: FloatValueFn.self)
        guard let create = load("IOHIDEventSystemClientCreate", as: CreateFn.self),
              let setMatching = load("IOHIDEventSystemClientSetMatching", as: SetMatchingFn.self),
              let copyServices = load("IOHIDEventSystemClientCopyServices", as: CopyServicesFn.self),
              let copyProperty = load("IOHIDServiceClientCopyProperty", as: CopyPropertyFn.self),
              let client = create(kCFAllocatorDefault)?.takeRetainedValue()
        else {
            sensors = []
            self.client = nil
            return
        }
        // Vendor-defined usage page 0xff00, usage 5: temperature sensors.
        _ = setMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)
        let services = (copyServices(client)?.takeRetainedValue() as? [AnyObject]) ?? []
        sensors = services.map { service in
            (service, copyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String ?? "")
        }
        self.client = client
    }

    func readings() -> [(name: String, celsius: Double)] {
        guard let copyEvent, let floatValue else { return [] }
        return sensors.compactMap { sensor in
            guard let event = copyEvent(sensor.service, Self.temperatureEvent, 0, 0)?.takeRetainedValue() else { return nil }
            return (sensor.name, floatValue(event, Int32(Self.temperatureEvent << 16)))
        }
    }
}
