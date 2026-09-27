import Foundation
import IOBluetooth

/// Follows Bluetooth devices connecting and disconnecting, with their batteries. Event-driven:
/// IOBluetooth reports each connection, and each device reports its own disconnection.
@Observable
final class BluetoothMonitor: NSObject {
    /// Connected devices, in the order they connected.
    private(set) var devices: [BluetoothDeviceInfo] = []
    /// The device the last connection pop-up is about.
    private(set) var latestConnection: BluetoothDeviceInfo?

    /// A device connected (not ones already connected when monitoring started).
    @ObservationIgnored var onConnected: ((BluetoothDeviceInfo) -> Void)?

    @ObservationIgnored private var connectNotification: IOBluetoothUserNotification?
    @ObservationIgnored private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    @ObservationIgnored private var batteryTask: Task<Void, Never>?
    /// Connections reported right after registering are the ones that already existed.
    @ObservationIgnored private var quietUntil = Date.distantPast
    @ObservationIgnored private var isStarted = false

    func start() {
        guard !isStarted else { return }
        isStarted = true
        quietUntil = Date().addingTimeInterval(2)
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(deviceConnected(_:device:)))
        batteryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                self?.refreshBatteries()
            }
        }
    }

    func stop() {
        isStarted = false
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications = [:]
        batteryTask?.cancel()
        devices = []
    }

    // MARK: - Events

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        disconnectNotifications[address]?.unregister()
        disconnectNotifications[address] = device.register(forDisconnectNotification: self, selector: #selector(deviceDisconnected(_:device:)))
        record(Self.info(for: device), announce: Date() >= quietUntil)

        // Batteries arrive a moment after the connection; read again so the pop-up and widget fill in.
        Task { [weak self] in
            for delay in [1.0, 3.0] {
                try? await Task.sleep(for: .seconds(delay))
                self?.refreshBattery(of: device)
            }
        }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        guard let address = device.addressString else { return }
        disconnectNotifications[address] = nil
        removeDevice(id: address)
    }

    /// Adds or updates a connected device; `announce` shows the connection pop-up.
    func record(_ info: BluetoothDeviceInfo, announce: Bool) {
        if let index = devices.firstIndex(where: { $0.id == info.id }) {
            devices[index] = info
        } else {
            devices.append(info)
        }
        if announce {
            latestConnection = info
            onConnected?(info)
        }
    }

    func removeDevice(id: String) {
        devices.removeAll { $0.id == id }
    }

    func updateBattery(id: String, to battery: BluetoothDeviceInfo.Battery) {
        guard let index = devices.firstIndex(where: { $0.id == id }), devices[index].battery != battery else { return }
        devices[index].battery = battery
        if latestConnection?.id == id { latestConnection?.battery = battery }
    }

    private func refreshBatteries() {
        for device in (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? [] where device.isConnected() {
            refreshBattery(of: device)
        }
    }

    private func refreshBattery(of device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        updateBattery(id: address, to: Self.battery(of: device))
    }

    // MARK: - Reading a device

    private static func info(for device: IOBluetoothDevice) -> BluetoothDeviceInfo {
        let name = device.name ?? "Bluetooth device"
        return BluetoothDeviceInfo(
            id: device.addressString ?? name,
            name: name,
            kind: .classify(name: name, majorClass: Int(device.deviceClassMajor), minorClass: Int(device.deviceClassMinor)),
            battery: battery(of: device)
        )
    }

    /// The battery levels AirPods, Beats and many headphones report. These properties aren't in the
    /// public headers, so each is read only if the device object answers to it.
    private static func battery(of device: IOBluetoothDevice) -> BluetoothDeviceInfo.Battery {
        func percent(_ key: String) -> Int? {
            guard device.responds(to: NSSelectorFromString(key)) else { return nil }
            return (device.value(forKey: key) as? NSNumber)?.intValue
        }
        return BluetoothDeviceInfo.Battery(
            single: percent("batteryPercentSingle"),
            left: percent("batteryPercentLeft"),
            right: percent("batteryPercentRight"),
            caseLevel: percent("batteryPercentCase")
        )
    }
}
