import Foundation

/// A connected Bluetooth device, reduced to what the notch shows. Independent of IOBluetooth.
struct BluetoothDeviceInfo: Equatable, Identifiable {
    /// The device's Bluetooth address.
    let id: String
    let name: String
    let kind: Kind
    var battery: Battery

    enum Kind: Equatable {
        case airPods, airPodsPro, airPodsMax, beats
        case headphones, speaker, keyboard, mouse, gameController, other

        /// Works out what a device is from its name and Bluetooth class, as far as the notch cares.
        /// Class numbers are from the Bluetooth Assigned Numbers: major 4 is audio/video (minor 5
        /// loudspeaker, the rest headsets and headphones), major 5 is peripherals (0x10 keyboard,
        /// 0x20 pointing device, low bits 1–2 joystick/gamepad).
        static func classify(name: String, majorClass: Int, minorClass: Int) -> Kind {
            let lower = name.lowercased()
            if lower.contains("airpods max") { return .airPodsMax }
            if lower.contains("airpods pro") { return .airPodsPro }
            if lower.contains("airpods") { return .airPods }
            if lower.contains("beats") || lower.contains("powerbeats") { return .beats }
            switch majorClass {
            case 4:
                return minorClass == 5 || minorClass == 10 ? .speaker : .headphones
            case 5:
                if minorClass & 0x0F == 1 || minorClass & 0x0F == 2 { return .gameController }
                if minorClass & 0x30 == 0x20 { return .mouse }
                if minorClass & 0x10 != 0 { return .keyboard }
                return .other
            default:
                return .other
            }
        }

        var symbol: String {
            switch self {
            case .airPods: "airpods"
            case .airPodsPro: "airpods.pro"
            case .airPodsMax: "airpods.max"
            case .beats: "beats.headphones"
            case .headphones: "headphones"
            case .speaker: "hifispeaker.fill"
            case .keyboard: "keyboard"
            case .mouse: "computermouse"
            case .gameController: "gamecontroller"
            case .other: "dot.radiowaves.left.and.right"
            }
        }

        /// AirPods and Beats report each bud and the case separately.
        var hasBuds: Bool {
            [.airPods, .airPodsPro, .beats].contains(self)
        }
    }

    /// Battery levels in percent; nil where the device doesn't report one.
    struct Battery: Equatable {
        var single: Int?
        var left: Int?
        var right: Int?
        var caseLevel: Int?

        static let unknown = Battery()

        /// Devices report 0 for "not known", so 0 becomes nil.
        init(single: Int? = nil, left: Int? = nil, right: Int? = nil, caseLevel: Int? = nil) {
            func known(_ value: Int?) -> Int? { value.flatMap { (1...100).contains($0) ? $0 : nil } }
            self.single = known(single)
            self.left = known(left)
            self.right = known(right)
            self.caseLevel = known(caseLevel)
        }

        var isKnown: Bool { single != nil || left != nil || right != nil || caseLevel != nil }

        /// One number for small places: the lower bud (the one that'll run out first), else the level.
        var summary: Int? {
            [left, right].compactMap { $0 }.min() ?? single ?? caseLevel
        }
    }
}
