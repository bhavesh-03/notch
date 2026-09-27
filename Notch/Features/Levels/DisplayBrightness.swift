import CoreGraphics
import Foundation

/// The built-in display's brightness, through the private DisplayServices framework (looked up at
/// runtime, so a macOS without it just means the brightness keys are left to macOS).
enum DisplayBrightness {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let framework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let getFn = dlsym(framework, "DisplayServicesGetBrightness").map { unsafeBitCast($0, to: GetFn.self) }
    private static let setFn = dlsym(framework, "DisplayServicesSetBrightness").map { unsafeBitCast($0, to: SetFn.self) }

    /// The built-in screen, if it's on (not closed in clamshell mode).
    static var builtInDisplay: CGDirectDisplayID? {
        var count: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetOnlineDisplayList(16, &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 && CGDisplayIsAsleep($0) == 0 }
    }

    static var brightness: Double? {
        guard let display = builtInDisplay, let getFn else { return nil }
        var value: Float = 0
        guard getFn(display, &value) == 0 else { return nil }
        return Double(value)
    }

    /// Whether the notch can handle the brightness keys: a built-in screen and the private functions.
    static var isAdjustable: Bool { brightness != nil && setFn != nil }

    static func setBrightness(_ level: Double) {
        guard let display = builtInDisplay, let setFn else { return }
        _ = setFn(display, Float(min(max(level, 0), 1)))
    }
}
