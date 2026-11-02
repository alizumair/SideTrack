import Foundation
import AppKit
import Combine

public final class AppState: ObservableObject, MultitouchFrameDelegate, SlideEngineDelegate {
    public static let shared = AppState()
    
    @Published public var currentVolume: Float = 0.5
    @Published public var isMuted: Bool = false
    @Published public var currentBrightness: Float = 0.5
    @Published public var isSliding: Bool = false
    
    public let settingsStore: SettingsStore
    public let slideEngine: SlideEngine
    private var cancellables = Set<AnyCancellable>()
    
    // Accumulators for discrete volume step tracking (~2.8mm per tick)
    private var accumulatedVolumeTravel: Float = 0.0
    private let travelPerVolumeStep: Float = 0.035
    
    public init(settingsStore: SettingsStore = .shared) {
        self.settingsStore = settingsStore
        self.slideEngine = SlideEngine(settings: settingsStore.settings)
        
        setupDelegates()
        bindSettings()
        syncSystemValues()
    }
    
    private func setupDelegates() {
        slideEngine.delegate = self
        MultitouchBridge.shared.delegate = self
        
        CoreAudioBridge.shared.onVolumeChanged = { [weak self] vol, muted in
            DispatchQueue.main.async {
                self?.currentVolume = vol
                self?.isMuted = muted
            }
        }
        
        DisplayBrightnessBridge.shared.onBrightnessChanged = { [weak self] brightness in
            DispatchQueue.main.async {
                self?.currentBrightness = brightness
            }
        }
    }
    
    private func bindSettings() {
        settingsStore.$settings
            .sink { [weak self] newSettings in
                guard let self = self else { return }
                self.slideEngine.settings = newSettings
            }
            .store(in: &cancellables)
    }
    
    public func syncSystemValues() {
        currentVolume = CoreAudioBridge.shared.getVolume()
        isMuted = CoreAudioBridge.shared.isMuted()
        currentBrightness = DisplayBrightnessBridge.shared.getBrightness()
    }
    
    public func startEngine() {
        MultitouchBridge.shared.start()
    }
    
    public func stopEngine() {
        MultitouchBridge.shared.stop()
        CursorFreezer.shared.unfreeze()
    }
    
    // MARK: - MultitouchFrameDelegate
    public func multitouchBridge(_ bridge: MultitouchBridge, didUpdateContacts contacts: [TrackpadContact], timestamp: Double, frame: Int32) {
        slideEngine.processFrame(contacts: contacts, timestamp: timestamp)
    }
    
    // MARK: - SlideEngineDelegate
    public func slideEngineDidAdjustBrightness(delta: Float, isPrecise: Bool) {
        // Direct, smooth 120Hz display brightness adjustment
        let current = DisplayBrightnessBridge.shared.getBrightness()
        let multiplier: Float = isPrecise ? 0.3 : 0.8
        let updated = max(0.0, min(1.0, current + delta * multiplier))
        DisplayBrightnessBridge.shared.setBrightness(updated)
        
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.trackStep(level: updated, totalSteps: settingsStore.settings.hapticSteps)
        }
    }
    
    public func slideEngineDidAdjustVolume(delta: Float, isPrecise: Bool) {
        // Reset opposite accumulator when direction reverses
        if delta > 0 && accumulatedVolumeTravel < 0 {
            accumulatedVolumeTravel = 0
        } else if delta < 0 && accumulatedVolumeTravel > 0 {
            accumulatedVolumeTravel = 0
        }
        
        accumulatedVolumeTravel += delta
        let step = isPrecise ? (travelPerVolumeStep * 2.0) : travelPerVolumeStep
        
        if accumulatedVolumeTravel >= step {
            while accumulatedVolumeTravel >= step {
                accumulatedVolumeTravel -= step
                MediaKeyDispatcher.shared.volumeUp()
                if settingsStore.settings.hapticsEnabled {
                    HapticFeedbackBridge.shared.tick()
                }
            }
        } else if accumulatedVolumeTravel <= -step {
            while accumulatedVolumeTravel <= -step {
                accumulatedVolumeTravel += step
                MediaKeyDispatcher.shared.volumeDown()
                if settingsStore.settings.hapticsEnabled {
                    HapticFeedbackBridge.shared.tick()
                }
            }
        }
    }
    
    public func slideEngineDidSkipMediaTrack(forward: Bool) {
        if forward {
            MediaKeyDispatcher.shared.nextTrack()
        } else {
            MediaKeyDispatcher.shared.previousTrack()
        }
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.tick()
        }
    }
    
    public func slideEngineDidPlayPause() {
        MediaKeyDispatcher.shared.playPause()
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.alignment()
        }
    }
    
    public func slideEngineDidToggleMute() {
        CoreAudioBridge.shared.toggleMute()
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.alignment()
        }
    }
    
    public func slideEngineSlideStateChanged(isSliding: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isSliding = isSliding
        }
        
        if isSliding {
            accumulatedVolumeTravel = 0.0
            if settingsStore.settings.cursorFreezingEnabled {
                CursorFreezer.shared.freeze()
            }
        } else {
            accumulatedVolumeTravel = 0.0
            CursorFreezer.shared.unfreeze()
            HapticFeedbackBridge.shared.reset()
        }
    }
    
    public func slideEngineHapticTick() {
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.tick()
        }
    }
}
