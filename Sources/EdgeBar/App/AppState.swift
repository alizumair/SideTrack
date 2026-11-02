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
        let current = DisplayBrightnessBridge.shared.getBrightness()
        let multiplier: Float = isPrecise ? 0.35 : 0.8
        let updated = max(0.0, min(1.0, current + delta * multiplier))
        DisplayBrightnessBridge.shared.setBrightness(updated)
        
        // Show native macOS Brightness Sun HUD
        OSDBridge.shared.showBrightness(level: updated)
        
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.trackStep(level: updated, totalSteps: settingsStore.settings.hapticSteps)
        }
    }
    
    public func slideEngineDidAdjustVolume(delta: Float, isPrecise: Bool) {
        let current = CoreAudioBridge.shared.getVolume()
        // Responsive gain: 1.25x matches finger travel velocity to brightness speed
        let multiplier: Float = isPrecise ? 0.35 : 1.25
        let updated = max(0.0, min(1.0, current + delta * multiplier))
        CoreAudioBridge.shared.setVolume(updated)
        
        // Show native macOS Volume Speaker HUD
        OSDBridge.shared.showVolume(level: updated, muted: CoreAudioBridge.shared.isMuted())
        
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.trackStep(level: updated, totalSteps: settingsStore.settings.hapticSteps)
        }
    }
    
    public func slideEngineDidSkipMediaTrack(forward: Bool) {
        if forward {
            MediaKeyDispatcher.shared.nextTrack()
            EdgeBarHUDOverlay.shared.show(.media(message: "Next Track", icon: "forward.fill"))
        } else {
            MediaKeyDispatcher.shared.previousTrack()
            EdgeBarHUDOverlay.shared.show(.media(message: "Previous Track", icon: "backward.fill"))
        }
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.tick()
        }
    }
    
    public func slideEngineDidPlayPause() {
        MediaKeyDispatcher.shared.playPause()
        EdgeBarHUDOverlay.shared.show(.media(message: "Play / Pause", icon: "playpause.fill"))
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.alignment()
        }
    }
    
    public func slideEngineDidToggleMute() {
        CoreAudioBridge.shared.toggleMute()
        let isMuted = CoreAudioBridge.shared.isMuted()
        let current = CoreAudioBridge.shared.getVolume()
        OSDBridge.shared.showVolume(level: current, muted: isMuted)
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.alignment()
        }
    }
    
    public func slideEngineSlideStateChanged(isSliding: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isSliding = isSliding
        }
        
        if isSliding {
            if settingsStore.settings.cursorFreezingEnabled {
                CursorFreezer.shared.freeze()
            }
        } else {
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
