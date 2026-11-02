import Foundation
import CoreAudio
import AudioToolbox

public final class CoreAudioBridge {
    public static let shared = CoreAudioBridge()
    
    public typealias VolumeChangeCallback = (Float32, Bool) -> Void
    public var onVolumeChanged: VolumeChangeCallback?
    
    private var defaultOutputDeviceID: AudioDeviceID = kAudioDeviceUnknown
    
    private init() {
        defaultOutputDeviceID = fetchDefaultOutputDeviceID()
        registerDeviceChangeListener()
    }
    
    private func fetchDefaultOutputDeviceID() -> AudioDeviceID {
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
        
        if status != noErr {
            NSLog("[EdgeBar] CoreAudio: Could not get default output device (status: %d)", status)
        }
        return deviceID
    }
    
    private func registerDeviceChangeListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main
        ) { [weak self] _, _ in
            guard let self = self else { return }
            self.defaultOutputDeviceID = self.fetchDefaultOutputDeviceID()
        }
    }
    
    public func getVolume() -> Float32 {
        let deviceID = fetchDefaultOutputDeviceID()
        guard deviceID != kAudioDeviceUnknown else { return 0.5 }
        
        var volume: Float32 = 0.0
        var size = UInt32(MemoryLayout<Float32>.size)
        
        // Try master element first
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectHasProperty(deviceID, &address) {
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
            if status == noErr { return volume }
        }
        
        // Fallback to channel 1 (left channel)
        address.mElement = 1
        if AudioObjectHasProperty(deviceID, &address) {
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
            if status == noErr { return volume }
        }
        
        return 0.5
    }
    
    public func setVolume(_ volume: Float32) {
        let deviceID = fetchDefaultOutputDeviceID()
        guard deviceID != kAudioDeviceUnknown else { return }
        
        let clamped = max(0.0, min(1.0, volume))
        var vol = clamped
        let size = UInt32(MemoryLayout<Float32>.size)
        
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var success = false
        if AudioObjectHasProperty(deviceID, &address) {
            let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
            if status == noErr { success = true }
        }
        
        // Also set channel 1 and channel 2 if master failed or for multi-channel sync
        for channel: UInt32 in 1...2 {
            address.mElement = channel
            if AudioObjectHasProperty(deviceID, &address) {
                let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &vol)
                if status == noErr { success = true }
            }
        }
        
        if success {
            // If setting volume > 0 and device is muted, unmute it
            if clamped > 0.001 && isMuted() {
                setMuted(false)
            }
            onVolumeChanged?(clamped, isMuted())
        }
    }
    
    public func isMuted() -> Bool {
        let deviceID = fetchDefaultOutputDeviceID()
        guard deviceID != kAudioDeviceUnknown else { return false }
        
        var isMuted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectHasProperty(deviceID, &address) {
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isMuted)
            if status == noErr { return isMuted != 0 }
        }
        
        // Try channel 1
        address.mElement = 1
        if AudioObjectHasProperty(deviceID, &address) {
            let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &isMuted)
            if status == noErr { return isMuted != 0 }
        }
        
        return false
    }
    
    public func setMuted(_ muted: Bool) {
        let deviceID = fetchDefaultOutputDeviceID()
        guard deviceID != kAudioDeviceUnknown else { return }
        
        var isMuted: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        if AudioObjectHasProperty(deviceID, &address) {
            _ = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &isMuted)
        }
        
        for channel: UInt32 in 1...2 {
            address.mElement = channel
            if AudioObjectHasProperty(deviceID, &address) {
                _ = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &isMuted)
            }
        }
        
        onVolumeChanged?(getVolume(), muted)
    }
    
    public func toggleMute() {
        setMuted(!isMuted())
    }
}
