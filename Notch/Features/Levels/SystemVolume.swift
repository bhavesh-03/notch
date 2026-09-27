import AudioToolbox
import CoreAudio

/// The volume of the current output (speakers, AirPods…), through CoreAudio.
enum SystemVolume {
    private static func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeOutput) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static var outputDevice: AudioObjectID? {
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var where_ = address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &where_, 0, nil, &size, &device) == noErr,
              device != 0 else { return nil }
        return device
    }

    /// Whether the output's volume can be set here. Some outputs (HDMI to a TV) only take the TV's remote.
    static var isAdjustable: Bool {
        guard let device = outputDevice else { return false }
        var where_ = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        var settable = DarwinBoolean(false)
        return AudioObjectIsPropertySettable(device, &where_, &settable) == noErr && settable.boolValue
    }

    static var volume: Double? {
        guard let device = outputDevice else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var where_ = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        guard AudioObjectGetPropertyData(device, &where_, 0, nil, &size, &value) == noErr else { return nil }
        return Double(value)
    }

    static func setVolume(_ level: Double) {
        guard let device = outputDevice else { return }
        var value = Float32(min(max(level, 0), 1))
        var where_ = address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        AudioObjectSetPropertyData(device, &where_, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        // Turning it up unmutes, as the volume keys do.
        if level > 0, isMuted { setMuted(false) }
    }

    static var isMuted: Bool {
        guard let device = outputDevice else { return false }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var where_ = address(kAudioDevicePropertyMute)
        guard AudioObjectGetPropertyData(device, &where_, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    static func setMuted(_ muted: Bool) {
        guard let device = outputDevice else { return }
        var value = UInt32(muted ? 1 : 0)
        var where_ = address(kAudioDevicePropertyMute)
        AudioObjectSetPropertyData(device, &where_, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
    }
}
