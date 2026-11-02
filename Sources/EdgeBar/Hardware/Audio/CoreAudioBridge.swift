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
            return
        }
        
        self.defaultOutputDeviceID = deviceID
        self.cachedVolume = readHardwareVolume(deviceID: deviceID)
        self.isMutedCache = readHardwareMute(deviceID: deviceID)
    }
    
    private func registerListeners() {
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
        
        // Master
        var masterAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &masterAddress, 0, nil, &size, &volume) == noErr {
            return volume
        }
        
        // Stereo channels 1 & 2
        for ch: UInt32 in 1...2 {
            var chAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: ch
            )
            if AudioObjectGetPropertyData(deviceID, &chAddress, 0, nil, &size, &volume) == noErr {
                return volume
            }
        }
        
        return 0.5
    }
    
    private func readHardwareMute(deviceID: AudioDeviceID) -> Bool {
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
        
        // Always query the live default output device ID to prevent stale device references
        var deviceID = AudioDeviceID(kAudioDeviceUnknown)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceID) == noErr {
            self.defaultOutputDeviceID = deviceID
        } else {
            deviceID = self.defaultOutputDeviceID
        }
        
        guard deviceID != kAudioDeviceUnknown else {
            lock.unlock()
            return
        }
        
        let clamped = max(0.0, min(1.0, volume))
        cachedVolume = clamped
        var vol = clamped
        let size = UInt32(MemoryLayout<Float32>.size)
        
        // Apply direct scalar volume to Master (if available)
        var masterAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectSetPropertyData(deviceID, &masterAddress, 0, nil, size, &vol)
        
        // Apply direct scalar volume to Stereo Channels 1 & 2 (AirPods, headphones, built-in speakers)
        for ch: UInt32 in 1...2 {
            var chAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: ch
            )
            _ = AudioObjectSetPropertyData(deviceID, &chAddress, 0, nil, size, &vol)
        }
        
        let wasMuted = isMutedCache
        if clamped > 0.001 && wasMuted {
            isMutedCache = false
            var zero: UInt32 = 0
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &zero)
        }
        lock.unlock()
        
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
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &val)
        let vol = cachedVolume
        lock.unlock()
        
        onVolumeChanged?(vol, muted)
    }
    
    public func toggleMute() {
        setMuted(!isMuted())
    }
}
