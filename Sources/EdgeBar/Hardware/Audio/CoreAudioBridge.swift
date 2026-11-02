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
    
    // Dedicated background audio worker for low-latency asynchronous hardware writes
    private let audioQueue = DispatchQueue(label: "io.github.edgebar.coreaudio", qos: .userInteractive)
    private var pendingHardwareVolume: Float32? = nil
    private var isApplyingVolume: Bool = false
    
    private init() {
        refreshAudioDevice()
        registerListeners()
    }
    
    public func refreshAudioDevice() {
        lock.lock()
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
            lock.unlock()
            return
        }
        
        self.defaultOutputDeviceID = deviceID
        self.cachedVolume = readHardwareVolume(deviceID: deviceID)
        self.isMutedCache = readHardwareMute(deviceID: deviceID)
        let vol = self.cachedVolume
        let muted = self.isMutedCache
        lock.unlock()
        
        onVolumeChanged?(vol, muted)
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
        
        // 1. Try master element
        var masterAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &masterAddress, 0, nil, &size, &volume) == noErr {
            return volume
        }
        
        // 2. Try stereo channels 1 & 2 (AirPods, headphones, built-in speakers)
        for ch: UInt32 in 1...2 {
            var chAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: ch
            )
            size = UInt32(MemoryLayout<Float32>.size) // Must reset size before each call
            if AudioObjectGetPropertyData(deviceID, &chAddress, 0, nil, &size, &volume) == noErr {
                return volume
            }
        }
        
        return cachedVolume
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
        let clamped = max(0.0, min(1.0, volume))
        
        lock.lock()
        cachedVolume = clamped
        pendingHardwareVolume = clamped
        
        let wasMuted = isMutedCache
        if clamped > 0.001 && wasMuted {
            isMutedCache = false
        }
        
        if !isApplyingVolume {
            isApplyingVolume = true
            lock.unlock()
            audioQueue.async { [weak self] in
                self?.processPendingVolume()
            }
        } else {
            lock.unlock()
        }
        
        onVolumeChanged?(clamped, isMutedCache)
    }
    
    private func processPendingVolume() {
        while true {
            lock.lock()
            guard let target = pendingHardwareVolume else {
                isApplyingVolume = false
                lock.unlock()
                return
            }
            pendingHardwareVolume = nil
            var deviceID = self.defaultOutputDeviceID
            lock.unlock()
            
            // Validate / refresh deviceID if needed
            if deviceID == kAudioDeviceUnknown {
                var dev = AudioDeviceID(kAudioDeviceUnknown)
                var propSize = UInt32(MemoryLayout<AudioDeviceID>.size)
                var propAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                if AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propAddress, 0, nil, &propSize, &dev) == noErr {
                    deviceID = dev
                    lock.lock()
                    self.defaultOutputDeviceID = dev
                    lock.unlock()
                }
            }
            
            guard deviceID != kAudioDeviceUnknown else { continue }
            
            var vol = target
            let size = UInt32(MemoryLayout<Float32>.size)
            
            // Set Master (if available)
            var masterAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            _ = AudioObjectSetPropertyData(deviceID, &masterAddress, 0, nil, size, &vol)
            
            // Set Channels 1 & 2 (AirPods Pro, headphones, stereo speakers)
            for ch: UInt32 in 1...2 {
                var chAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyVolumeScalar,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: ch
                )
                _ = AudioObjectSetPropertyData(deviceID, &chAddress, 0, nil, size, &vol)
            }
            
            // Ensure unmute if volume > 0
            if target > 0.001 {
                var zero: UInt32 = 0
                var muteAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyMute,
                    mScope: kAudioDevicePropertyScopeOutput,
                    mElement: kAudioObjectPropertyElementMain
                )
                _ = AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, UInt32(MemoryLayout<UInt32>.size), &zero)
            }
        }
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
    
    // MARK: - Microphone Input Gain
    public func getInputGain() -> Float32 {
        lock.lock()
        defer { lock.unlock() }
        var deviceID = AudioDeviceID(kAudioDeviceUnknown)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
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
        guard status == noErr, deviceID != kAudioDeviceUnknown else { return 0.5 }
        
        var volume: Float32 = 0.5
        var size = UInt32(MemoryLayout<Float32>.size)
        var volAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &size, &volume) == noErr {
            return max(0.0, min(1.0, volume))
        }
        
        volAddress.mElement = 1
        size = UInt32(MemoryLayout<Float32>.size)
        if AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &size, &volume) == noErr {
            return max(0.0, min(1.0, volume))
        }
        
        return 0.5
    }
    
    public func setInputGain(_ value: Float32) {
        let clamped = max(0.0, min(1.0, value))
        audioQueue.async {
            var deviceID = AudioDeviceID(kAudioDeviceUnknown)
            var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
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
            guard status == noErr, deviceID != kAudioDeviceUnknown else { return }
            
            var vol = clamped
            var volAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            let setStatus = AudioObjectSetPropertyData(deviceID, &volAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &vol)
            if setStatus != noErr {
                for ch: UInt32 in 1...2 {
                    var chAddress = AudioObjectPropertyAddress(
                        mSelector: kAudioDevicePropertyVolumeScalar,
                        mScope: kAudioDevicePropertyScopeInput,
                        mElement: ch
                    )
                    var chVol = clamped
                    _ = AudioObjectSetPropertyData(deviceID, &chAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &chVol)
                }
            }
        }
    }
}
