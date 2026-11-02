import Foundation
import CoreAudio
import AudioToolbox

public final class CoreAudioBridge {
    public static let shared = CoreAudioBridge()
    
    public typealias VolumeChangeCallback = (Float32, Bool) -> Void
    public var onVolumeChanged: VolumeChangeCallback?
    
    private var defaultOutputDeviceID: AudioDeviceID = kAudioDeviceUnknown
    private var cachedVolume: Float32 = 0.5
    private var isMutedCache: Bool = false
    private var hasMasterVolume: Bool = false
    private var settableChannels: [UInt32] = []
    private var hasMuteProperty: Bool = false
    private let lock = NSLock()
    
    private init() {
        refreshAudioDevice()
        registerListeners()
    }
    
    public func refreshAudioDevice() {
        lock.lock()
        defer { lock.unlock() }
        
        var deviceID = AudioDeviceID(kAudioDeviceUnknown)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        guard status == noErr, deviceID != kAudioDeviceUnknown else {
            NSLog("[EdgeBar] CoreAudio: Could not fetch default output device")
            return
        }
        
        self.defaultOutputDeviceID = deviceID
        self.settableChannels.removeAll()
        
        // Inspect master volume
        var masterAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        self.hasMasterVolume = AudioObjectHasProperty(deviceID, &masterAddress)
        
        // Inspect stereo channels 1 & 2
        for ch: UInt32 in 1...2 {
            var chAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: ch
            )
            if AudioObjectHasProperty(deviceID, &chAddress) {
                var settable: DarwinBoolean = false
                let sStatus = AudioObjectIsPropertySettable(deviceID, &chAddress, &settable)
                if sStatus == noErr && settable.boolValue {
                    settableChannels.append(ch)
                }
            }
        }
        
        // Inspect mute
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        self.hasMuteProperty = AudioObjectHasProperty(deviceID, &muteAddress)
        
        // Query initial volume
        self.cachedVolume = readHardwareVolume(deviceID: deviceID)
        self.isMutedCache = readHardwareMute(deviceID: deviceID)
    }
    
    private func registerListeners() {
        // Listen for default device changes
        var devAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            self?.refreshAudioDevice()
        }
    }
    
    private func readHardwareVolume(deviceID: AudioDeviceID) -> Float32 {
        var volume: Float32 = 0.5
        var size = UInt32(MemoryLayout<Float32>.size)
        
        if hasMasterVolume {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume) == noErr {
                return volume
            }
        }
        
        for ch in settableChannels {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: ch
            )
            if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume) == noErr {
                return volume
            }
        }
        
        return 0.5
    }
    
    private func readHardwareMute(deviceID: AudioDeviceID) -> Bool {
        guard hasMuteProperty else { return false }
        var isMuted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isMuted) == noErr {
            return isMuted != 0
        }
        return false
    }
    
    public func getVolume() -> Float32 {
        lock.lock()
        defer { lock.unlock() }
        return cachedVolume
    }
    
    public func setVolume(_ volume: Float32) {
        lock.lock()
        let deviceID = defaultOutputDeviceID
        guard deviceID != kAudioDeviceUnknown else {
            lock.unlock()
            return
        }
        
        let clamped = max(0.0, min(1.0, volume))
        let previous = cachedVolume
        cachedVolume = clamped
        var vol = clamped
        let size = UInt32(MemoryLayout<Float32>.size)
        
        var didApply = false
        
        if hasMasterVolume {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol) == noErr {
                didApply = true
            }
        }
        
        for ch in settableChannels {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: ch
            )
            if AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol) == noErr {
                didApply = true
            }
        }
        
        let wasMuted = isMutedCache
        if clamped > 0.001 && wasMuted {
            isMutedCache = false
            if hasMuteProperty {
                var zero: UInt32 = 0
                var muteAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain
                )
                _ = AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &zero)
            }
        }
        lock.unlock()
        
        // If the hardware device doesn't support direct scalar volume (e.g. HDMI or external DAC), fallback to media keys
        if !didApply {
            if clamped > previous {
                MediaKeyDispatcher.shared.volumeUp()
            } else if clamped < previous {
                MediaKeyDispatcher.shared.volumeDown()
            }
        }
        
        onVolumeChanged?(clamped, isMutedCache)
    }
    
    public func isMuted() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isMutedCache
    }
    
    public func setMuted(_ muted: Bool) {
        lock.lock()
        let deviceID = defaultOutputDeviceID
        guard deviceID != kAudioDeviceUnknown else {
            lock.unlock()
            return
        }
        
        isMutedCache = muted
        var val: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        
        if hasMuteProperty {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &val)
        }
        let vol = cachedVolume
        lock.unlock()
        
        onVolumeChanged?(vol, muted)
    }
    
    public func toggleMute() {
        setMuted(!isMuted())
    }
}
