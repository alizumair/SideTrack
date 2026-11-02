import Foundation
import AppKit

public typealias HapticEngine = HapticFeedbackBridge

public final class HapticFeedbackBridge {
    public static let shared = HapticFeedbackBridge()
    
    private let performer = NSHapticFeedbackManager.defaultPerformer
    private var lastStep: Int?
    
    private init() {}
    
    public func tick() {
        performer.perform(.levelChange, performanceTime: .now)
    }
    
    public func alignment() {
        performer.perform(.alignment, performanceTime: .now)
    }
    
    public func reset() {
        lastStep = nil
    }
    
    /// Checks if the level (0.0 ... 1.0) crossed a discrete step threshold.
    /// If crossed, triggers a synchronized tactile tick.
    public func trackStep(level: Float, totalSteps: Int = 16) {
        let clamped = max(0.0, min(1.0, level))
        let currentStep = Int(round(clamped * Float(totalSteps)))
        
        if let previous = lastStep {
            if previous != currentStep {
                tick()
                lastStep = currentStep
            }
        } else {
            lastStep = currentStep
        }
    }
}
