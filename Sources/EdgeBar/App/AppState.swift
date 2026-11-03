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
        HapticFeedbackBridge.shared.audioFeedbackEnabled = settingsStore.settings.audioFeedbackEnabled
        
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
        
        // Smart Context Switching (App Profiles & Game Mode)
        ProfileManager.shared.onProfileChanged = { [weak self] profile, isGameMode in
            guard let self = self else { return }
            self.slideEngine.activeProfile = profile
            self.slideEngine.isGameModeBypassed = isGameMode
        }
        ProfileManager.shared.evaluateFrontmostApp(settings: settingsStore.settings)
    }
    
    private func bindSettings() {
        settingsStore.$settings
            .sink { [weak self] newSettings in
                guard let self = self else { return }
                self.slideEngine.settings = newSettings
                HapticFeedbackBridge.shared.audioFeedbackEnabled = newSettings.audioFeedbackEnabled
                ProfileManager.shared.evaluateFrontmostApp(settings: newSettings)
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
        
        if settingsStore.settings.useSystemOSD {
            OSDBridge.shared.showBrightness(level: updated)
        } else if settingsStore.settings.showHUDOverlay {
            EdgeBarHUDOverlay.shared.show(.brightness(level: updated))
        }
        
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.trackStep(level: updated, totalSteps: settingsStore.settings.hapticSteps)
        }
    }
    
    public func slideEngineDidAdjustVolume(delta: Float, isPrecise: Bool) {
        let current = CoreAudioBridge.shared.getVolume()
        let multiplier: Float = isPrecise ? 0.35 : 0.8
        let updated = max(0.0, min(1.0, current + delta * multiplier))
        CoreAudioBridge.shared.setVolume(updated)
        
        if settingsStore.settings.useSystemOSD {
            OSDBridge.shared.showVolume(level: updated, muted: CoreAudioBridge.shared.isMuted())
        } else if settingsStore.settings.showHUDOverlay {
            EdgeBarHUDOverlay.shared.show(.volume(level: updated, isMuted: CoreAudioBridge.shared.isMuted()))
        }
        
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.trackStep(level: updated, totalSteps: settingsStore.settings.hapticSteps)
        }
    }
    
    public func slideEngineDidAdjustKeyboardBacklight(delta: Float, isPrecise: Bool) {
        let current = KeyboardBacklightBridge.shared.getBrightness()
        let multiplier: Float = isPrecise ? 0.25 : 0.6
        let updated = max(0.0, min(1.0, current + delta * multiplier))
        KeyboardBacklightBridge.shared.setBrightness(updated)
        
        if settingsStore.settings.showHUDOverlay {
            EdgeBarHUDOverlay.shared.show(.keyboardBacklight(level: updated))
        }
        
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.trackStep(level: updated, totalSteps: settingsStore.settings.hapticSteps)
        }
    }
    
    public func slideEngineDidAdjustMicGain(delta: Float, isPrecise: Bool) {
        let current = CoreAudioBridge.shared.getInputGain()
        let multiplier: Float = isPrecise ? 0.25 : 0.6
        let updated = max(0.0, min(1.0, current + delta * multiplier))
        CoreAudioBridge.shared.setInputGain(updated)
        
        if settingsStore.settings.showHUDOverlay {
            EdgeBarHUDOverlay.shared.show(.micGain(level: updated))
        }
        
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.trackStep(level: updated, totalSteps: settingsStore.settings.hapticSteps)
        }
    }
    
    public func slideEngineDidScrubTimeline(forward: Bool) {
        MediaKeyDispatcher.shared.stepTimeline(forward: forward)
        if settingsStore.settings.showHUDOverlay {
            EdgeBarHUDOverlay.shared.show(.timelineScrub(forward: forward))
        }
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.tick()
        }
    }
    
    public func slideEngineDidScrollPage(up: Bool) {
        MediaKeyDispatcher.shared.scrollPage(up: up)
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.tick()
        }
    }
    
    public func slideEngineDidSwitchTab(forward: Bool) {
        MediaKeyDispatcher.shared.switchTab(next: forward)
        if settingsStore.settings.showHUDOverlay {
            EdgeBarHUDOverlay.shared.show(.tabSwitch(forward: forward))
        }
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.tick()
        }
    }
    
    public func slideEngineDidSeekVideo(forward: Bool) {
        MediaKeyDispatcher.shared.seekVideo(forward: forward)
        if settingsStore.settings.showHUDOverlay {
            EdgeBarHUDOverlay.shared.show(.videoSeek(forward: forward))
        }
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.tick()
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
        if settingsStore.settings.useSystemOSD {
            OSDBridge.shared.showVolume(level: current, muted: isMuted)
        } else if settingsStore.settings.showHUDOverlay {
            EdgeBarHUDOverlay.shared.show(.volume(level: current, isMuted: isMuted))
        }
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.alignment()
        }
    }
    
    public func slideEngineDidTriggerCustomScript() {
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.alignment()
        }
        let trigger = settingsStore.settings.customScriptTrigger
        ScriptDispatcher.shared.execute(trigger: trigger) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let msg):
                    let preview = msg.trimmingCharacters(in: .whitespacesAndNewlines)
                    EdgeBarHUDOverlay.shared.show(.media(message: preview.isEmpty ? "Action Executed" : preview, icon: "bolt.fill"))
                case .failure(let err):
                    EdgeBarHUDOverlay.shared.show(.media(message: "Script Failed: \(err.localizedDescription)", icon: "exclamationmark.triangle.fill"))
                }
            }
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
    
    // MARK: - Corner Hold Macros
    public func slideEngineDidStartCornerHold(corner: CornerType) {
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.tick()
        }
    }
    
    public func slideEngineDidTriggerScreenshot() {
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.alignment()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-x", "-c"]
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async {
                    EdgeBarHUDOverlay.shared.show(.media(message: "Screenshot Copied", icon: "camera.fill"))
                }
            } catch {
                NSLog("[EdgeBar] Failed to trigger screencapture: \(error)")
            }
        }
    }
    
    public func slideEngineDidTriggerScreenRecording() {
        if settingsStore.settings.hapticsEnabled {
            HapticFeedbackBridge.shared.alignment()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            task.arguments = ["-i", "-U", "-Jvideo", "-p"]
            do {
                try task.run()
                DispatchQueue.main.async {
                    EdgeBarHUDOverlay.shared.show(.media(message: "Screen Recording", icon: "record.circle"))
                }
            } catch {
                NSLog("[EdgeBar] Failed to run screencapture with -Jvideo: \(error)")
                let url = URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app")
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
            }
        }
    }
}
