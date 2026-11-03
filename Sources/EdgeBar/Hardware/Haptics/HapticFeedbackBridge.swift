import Foundation
import AppKit
import AudioToolbox

public typealias HapticEngine = HapticFeedbackBridge

public final class HapticFeedbackBridge {
    public static let shared = HapticFeedbackBridge()
    
    private let performer = NSHapticFeedbackManager.defaultPerformer
    private var lastStep: Int?
    public var audioFeedbackEnabled: Bool = false
    private let clickSound = NSSound(named: "Tink")
    
    private init() {}
    
    public func tick() {
        performer.perform(.levelChange, performanceTime: .now)
        if audioFeedbackEnabled {
            playAudioClick()
        }
    }
    
    public func alignment() {
        performer.perform(.alignment, performanceTime: .now)
        if audioFeedbackEnabled {
            playAudioClick()
        }
    }
    
    public func playAudioClick() {
        guard let sound = clickSound else { return }
        sound.stop()
        sound.play()
    }
    
    public func reset() {
        lastStep = nil
    }
    
    /// Checks if the level (0.0 ... 1.0) crossed a discrete step threshold.
    /// If crossed, triggers a synchronized tactile haptic tick.
    /// Note: Slider movement is strictly silent haptic (no audio tick sound).
    public func trackStep(level: Float, totalSteps: Int = 16) {
        let clamped = max(0.0, min(1.0, level))
        let currentStep = Int(round(clamped * Float(totalSteps)))
        
        if let previous = lastStep {
            if previous != currentStep {
                performer.perform(.levelChange, performanceTime: .now)
                lastStep = currentStep
            }
        } else {
            lastStep = currentStep
        }
    }
}
