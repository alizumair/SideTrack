import Foundation
import AppKit

public protocol SlideEngineDelegate: AnyObject {
    func slideEngineDidAdjustBrightness(delta: Float, isPrecise: Bool)
    func slideEngineDidAdjustVolume(delta: Float, isPrecise: Bool)
    func slideEngineDidAdjustKeyboardBacklight(delta: Float, isPrecise: Bool)
    func slideEngineDidAdjustMicGain(delta: Float, isPrecise: Bool)
    func slideEngineDidSkipMediaTrack(forward: Bool)
    func slideEngineDidScrubTimeline(forward: Bool)
    func slideEngineDidScrollPage(up: Bool)
    func slideEngineDidSwitchTab(forward: Bool)
    func slideEngineDidSeekVideo(forward: Bool)
    func slideEngineDidPlayPause()
    func slideEngineDidToggleMute()
    func slideEngineSlideStateChanged(isSliding: Bool)
    func slideEngineHapticTick()
    func slideEngineDidStartCornerHold(corner: CornerType)
    func slideEngineDidTriggerScreenshot()
    func slideEngineDidTriggerScreenRecording()
    func slideEngineDidTriggerCustomScript()
}

public extension SlideEngineDelegate {
    func slideEngineDidAdjustKeyboardBacklight(delta: Float, isPrecise: Bool) {}
    func slideEngineDidAdjustMicGain(delta: Float, isPrecise: Bool) {}
    func slideEngineDidScrubTimeline(forward: Bool) {}
    func slideEngineDidScrollPage(up: Bool) {}
    func slideEngineDidSwitchTab(forward: Bool) {}
    func slideEngineDidSeekVideo(forward: Bool) {}
    func slideEngineDidStartCornerHold(corner: CornerType) {}
    func slideEngineDidTriggerScreenshot() {}
    func slideEngineDidTriggerScreenRecording() {}
    func slideEngineDidTriggerCustomScript() {}
}

public final class SlideEngine: CornerHoldManagerDelegate {
    public weak var delegate: SlideEngineDelegate?
    public let cornerHoldManager = CornerHoldManager()
    
    public var settings: SettingsModel {
        didSet {
            updateClassifier()
        }
    }
    
    // Active Profile & Game Mode Bypass
    public var activeProfile: AppProfile?
    public var isGameModeBypassed: Bool = false
    
    public var effectiveLeftAction: EdgeAction {
        if let override = activeProfile?.leftEdgeAction, override != .disabled { return override }
        return settings.leftEdgeAction
    }
    
    public var effectiveRightAction: EdgeAction {
        if let override = activeProfile?.rightEdgeAction, override != .disabled { return override }
        return settings.rightEdgeAction
    }
    
    public var effectiveBottomAction: EdgeAction {
        if let override = activeProfile?.bottomEdgeAction, override != .disabled { return override }
        return settings.bottomEdgeAction
    }
    
    public var effectiveTopRightCornerAction: CornerAction {
        if let override = activeProfile?.topRightCornerAction, override != .disabled { return override }
        return settings.topRightCornerAction
    }
    
    public var effectiveBottomDoubleTapAction: CornerAction {
        if let override = activeProfile?.bottomDoubleTapAction, override != .disabled { return override }
        return settings.bottomDoubleTapAction
    }
    
    public var effectiveBottomScrubMode: BottomScrubMode {
        return activeProfile?.bottomScrubMode ?? .mediaTrack
    }
    
    public private(set) var phase: GesturePhase = .idle
    private var classifier: EdgeClassifier
    private var ignoredTouchIDs: Set<Int32> = []
    private var lastTap: RecordedTap?
    private var hasFiredMediaSkipForCurrentSlide: Bool = false
    private var accumulatedBottomDx: Float = 0.0
    private var isSlidingActive: Bool = false
    
    // Test hook for simulating modifier flags without depending on UI events
    public var modifierFlagsProvider: (() -> NSEvent.ModifierFlags)?
    
    public init(settings: SettingsModel = .default) {
        self.settings = settings
        self.classifier = EdgeClassifier(
            leftWidth: Float(settings.leftEdgeWidthFraction),
            rightWidth: Float(settings.rightEdgeWidthFraction),
            topHeight: Float(settings.topEdgeHeightFraction),
            bottomHeight: Float(settings.bottomEdgeHeightFraction),
            cornerSize: Float(settings.cornerZoneFraction)
        )
        self.cornerHoldManager.delegate = self
    }
    
    private func updateClassifier() {
        self.classifier = EdgeClassifier(
            leftWidth: Float(settings.leftEdgeWidthFraction),
            rightWidth: Float(settings.rightEdgeWidthFraction),
            topHeight: Float(settings.topEdgeHeightFraction),
            bottomHeight: Float(settings.bottomEdgeHeightFraction),
            cornerSize: Float(settings.cornerZoneFraction)
        )
    }
    
    public func processFrame(contacts: [TrackpadContact], timestamp: Double) {
        // Full-Screen Game Mode or Master Disable Gate
        guard settings.isEnabled, !isGameModeBypassed else {
            if isSlidingActive {
                endSlide(cancelled: true)
            }
            cornerHoldManager.cancelHold()
            return
        }
        
        // Purge any ignored touch IDs that are no longer active on the trackpad
        let activeIDs = Set(contacts.map { $0.id })
        ignoredTouchIDs = ignoredTouchIDs.intersection(activeIDs)
        
        // 1. Multi-finger Gate:
        if contacts.count > 1 {
            cornerHoldManager.cancelHold()
            if isSlidingActive || phase != .idle {
                endSlide(cancelled: true)
                phase = .cancelled
            }
            return
        }
        
        // 2. Pad is empty
        if contacts.isEmpty {
            cornerHoldManager.cancelHold()
            if isSlidingActive {
                endSlide(cancelled: false)
            }
            phase = .idle
            ignoredTouchIDs.removeAll()
            hasFiredMediaSkipForCurrentSlide = false
            return
        }
        
        // 3. Exactly one finger on the pad
        let contact = contacts[0]
        
        if phase == .cancelled {
            if contact.state.isTerminating {
                phase = .idle
            }
            cornerHoldManager.cancelHold()
            return
        }
        
        if ignoredTouchIDs.contains(contact.id) {
            return
        }
        
        // Corner hold detection:
        if isSlidingActive {
            cornerHoldManager.cancelHold()
        } else {
            _ = cornerHoldManager.processFrame(contacts: contacts, settings: settings)
        }
        
        // Process touch lifecycle
        switch phase {
        case .idle:
            let zone = classifier.classify(x: contact.x, y: contact.y)
            if zone == .middle {
                ignoredTouchIDs.insert(contact.id)
                return
            }
            hasFiredMediaSkipForCurrentSlide = false
            phase = .candidate(
                touchID: contact.id,
                zone: zone,
                startX: contact.x,
                startY: contact.y,
                startTime: timestamp
            )
            
        case .candidate(let touchID, let zone, let startX, let startY, let startTime):
            guard contact.id == touchID else {
                phase = .idle
                return
            }
            
            let dx = contact.x - startX
            let dy = contact.y - startY
            let absDx = abs(dx)
            let absDy = abs(dy)
            let movement = hypot(dx, dy)
            let duration = timestamp - startTime
            
            if contact.state.isTerminating {
                if zone == .bottom && absDx >= 0.020 && absDx > absDy {
                    handleBottomSwipe(forward: dx > 0)
                } else {
                    let tapThreshold: Float = 0.020
                    if movement < tapThreshold && duration < settings.doubleTapMaxInterval {
                        handleTap(zone: zone, x: contact.x, y: contact.y, timestamp: timestamp)
                    }
                }
                phase = .idle
                return
            }
            
            if cornerHoldManager.isHolding {
                return
            }
            
            if zone == .left || zone == .right || zone == .topRightCorner {
                let inwardDx: Float = (zone == .left) ? dx : -dx
                
                if inwardDx >= 0.006 && inwardDx >= (absDy * 0.7) {
                    ignoredTouchIDs.insert(touchID)
                    phase = .idle
                    return
                }
                
                if absDx >= 0.008 && absDx >= absDy {
                    ignoredTouchIDs.insert(touchID)
                    phase = .idle
                    return
                }
                
                if absDy >= 0.010 && absDy > absDx && inwardDx < 0.006 {
                    phase = .sliding(touchID: touchID, zone: zone, currentX: contact.x, currentY: contact.y)
                    startSlide()
                    processSlideDelta(zone: zone, deltaX: dx, deltaY: dy)
                }
            } else if zone == .bottom {
                if dy > 0.040 && dy > (absDx * 1.8) {
                    ignoredTouchIDs.insert(touchID)
                    phase = .idle
                    return
                }
                
                if absDx >= 0.020 && absDx >= absDy {
                    ProfileManager.shared.evaluateFrontmostApp(settings: settings)
                    phase = .sliding(touchID: touchID, zone: zone, currentX: contact.x, currentY: contact.y)
                    accumulatedBottomDx = 0.0
                    startSlide()
                    processBottomSlideDelta(deltaX: dx)
                }
            }
            
        case .sliding(let touchID, let zone, let currentX, let currentY):
            guard contact.id == touchID else {
                endSlide(cancelled: true)
                phase = .idle
                return
            }
            
            if contact.state.isTerminating {
                endSlide(cancelled: false)
                phase = .idle
            } else {
                let dx = contact.x - currentX
                let dy = contact.y - currentY
                
                if zone == .left || zone == .right || zone == .topRightCorner {
                    let inwardDx: Float = (zone == .left) ? dx : -dx
                    if inwardDx >= 0.004 && inwardDx >= abs(dy) {
                        endSlide(cancelled: true)
                        ignoredTouchIDs.insert(touchID)
                        phase = .idle
                        return
                    }
                    
                    let leftLimit = Float(settings.leftEdgeWidthFraction) * 1.05
                    let rightLimit = 1.0 - (Float(settings.rightEdgeWidthFraction) * 1.05)
                    
                    if zone == .left && contact.x > leftLimit {
                        endSlide(cancelled: true)
                        ignoredTouchIDs.insert(touchID)
                        phase = .idle
                        return
                    }
                    if (zone == .right || zone == .topRightCorner) && contact.x < rightLimit {
                        endSlide(cancelled: true)
                        ignoredTouchIDs.insert(touchID)
                        phase = .idle
                        return
                    }
                }
                if zone == .bottom && contact.y > Float(settings.bottomEdgeHeightFraction) * 1.25 {
                    endSlide(cancelled: true)
                    ignoredTouchIDs.insert(touchID)
                    phase = .idle
                    return
                }
                
                phase = .sliding(touchID: touchID, zone: zone, currentX: contact.x, currentY: contact.y)
                processSlideDelta(zone: zone, deltaX: dx, deltaY: dy)
            }
            
        case .cancelled:
            break
        }
    }
    
    private func handleBottomSwipe(forward: Bool) {
        switch effectiveBottomScrubMode {
        case .tabSwitch:
            delegate?.slideEngineDidSwitchTab(forward: forward)
        case .videoSeek:
            delegate?.slideEngineDidSeekVideo(forward: forward)
        case .timelineScrub:
            delegate?.slideEngineDidScrubTimeline(forward: forward)
        case .pageScroll:
            delegate?.slideEngineDidScrollPage(up: forward)
        case .mediaTrack:
            delegate?.slideEngineDidSkipMediaTrack(forward: forward)
        }
    }
    
    private func processBottomSlideDelta(deltaX: Float) {
        accumulatedBottomDx += deltaX
        
        switch effectiveBottomScrubMode {
        case .tabSwitch:
            let stepThreshold: Float = 0.035
            while accumulatedBottomDx >= stepThreshold {
                delegate?.slideEngineDidSwitchTab(forward: true)
                accumulatedBottomDx -= stepThreshold
            }
            while accumulatedBottomDx <= -stepThreshold {
                delegate?.slideEngineDidSwitchTab(forward: false)
                accumulatedBottomDx += stepThreshold
            }
            
        case .videoSeek:
            let stepThreshold: Float = 0.035
            while accumulatedBottomDx >= stepThreshold {
                delegate?.slideEngineDidSeekVideo(forward: true)
                accumulatedBottomDx -= stepThreshold
            }
            while accumulatedBottomDx <= -stepThreshold {
                delegate?.slideEngineDidSeekVideo(forward: false)
                accumulatedBottomDx += stepThreshold
            }
            
        case .mediaTrack:
            let threshold: Float = 0.035
            if !hasFiredMediaSkipForCurrentSlide && abs(accumulatedBottomDx) >= threshold {
                delegate?.slideEngineDidSkipMediaTrack(forward: accumulatedBottomDx > 0)
                hasFiredMediaSkipForCurrentSlide = true
            }
            
        case .timelineScrub:
            let stepThreshold: Float = 0.025
            while accumulatedBottomDx >= stepThreshold {
                delegate?.slideEngineDidScrubTimeline(forward: true)
                accumulatedBottomDx -= stepThreshold
            }
            while accumulatedBottomDx <= -stepThreshold {
                delegate?.slideEngineDidScrubTimeline(forward: false)
                accumulatedBottomDx += stepThreshold
            }
            
        case .pageScroll:
            let stepThreshold: Float = 0.025
            while accumulatedBottomDx >= stepThreshold {
                delegate?.slideEngineDidScrollPage(up: false)
                accumulatedBottomDx -= stepThreshold
            }
            while accumulatedBottomDx <= -stepThreshold {
                delegate?.slideEngineDidScrollPage(up: true)
                accumulatedBottomDx += stepThreshold
            }
        }
    }
    
    private func startSlide() {
        cornerHoldManager.cancelHold()
        isSlidingActive = true
        delegate?.slideEngineSlideStateChanged(isSliding: true)
    }
    
    private func endSlide(cancelled: Bool) {
        isSlidingActive = false
        hasFiredMediaSkipForCurrentSlide = false
        accumulatedBottomDx = 0.0
        delegate?.slideEngineSlideStateChanged(isSliding: false)
    }
    
    private func isPrecisionHeld() -> Bool {
        let flags: NSEvent.ModifierFlags
        if let provider = modifierFlagsProvider {
            flags = provider()
        } else {
            flags = NSEvent.modifierFlags
        }
        return flags.contains(.shift) && flags.contains(.option)
    }
    
    private func processSlideDelta(zone: EdgeZone, deltaX: Float, deltaY: Float) {
        let absDx = abs(deltaX)
        let absDy = abs(deltaY)
        if (zone == .left || zone == .right || zone == .topRightCorner) && absDy <= absDx {
            return
        }
        
        let isPrecise = isPrecisionHeld()
        let multiplier: Float = isPrecise ? Float(settings.precisionMultiplier) : 1.0
        let sensitivity = Float(settings.sensitivity)
        
        var effectiveDeltaY = deltaY * sensitivity * multiplier
        if settings.invertVerticalAxis {
            effectiveDeltaY = -effectiveDeltaY
        }
        
        switch zone {
        case .left:
            executeAction(effectiveLeftAction, deltaY: effectiveDeltaY, isPrecise: isPrecise)
            
        case .right, .topRightCorner:
            executeAction(effectiveRightAction, deltaY: effectiveDeltaY, isPrecise: isPrecise)
            
        case .bottom:
            processBottomSlideDelta(deltaX: deltaX)
            
        case .middle:
            break
        }
    }
    
    private func executeAction(_ action: EdgeAction, deltaY: Float, isPrecise: Bool) {
        switch action {
        case .brightness:
            delegate?.slideEngineDidAdjustBrightness(delta: deltaY, isPrecise: isPrecise)
        case .volume:
            delegate?.slideEngineDidAdjustVolume(delta: deltaY, isPrecise: isPrecise)
        case .keyboardBrightness:
            delegate?.slideEngineDidAdjustKeyboardBacklight(delta: deltaY, isPrecise: isPrecise)
        case .micGain:
            delegate?.slideEngineDidAdjustMicGain(delta: deltaY, isPrecise: isPrecise)
        case .tabSwitch:
            delegate?.slideEngineDidSwitchTab(forward: deltaY > 0)
        case .videoSeek:
            delegate?.slideEngineDidSeekVideo(forward: deltaY > 0)
        case .scroll:
            delegate?.slideEngineDidScrollPage(up: deltaY > 0)
        case .timelineScrub:
            delegate?.slideEngineDidScrubTimeline(forward: deltaY > 0)
        case .mediaTrack, .disabled:
            break
        }
    }
    
    private func handleTap(zone: EdgeZone, x: Float, y: Float, timestamp: Double) {
        let tap = RecordedTap(zone: zone, timestamp: timestamp, x: x, y: y)
        
        if let last = lastTap,
           last.zone == zone,
           (timestamp - last.timestamp) <= settings.doubleTapMaxInterval {
            lastTap = nil
            triggerDoubleTapAction(zone: zone)
        } else {
            lastTap = tap
        }
    }
    
    private func triggerDoubleTapAction(zone: EdgeZone) {
        switch zone {
        case .topRightCorner:
            executeCornerAction(effectiveTopRightCornerAction)
        case .bottom:
            executeCornerAction(effectiveBottomDoubleTapAction)
        default:
            break
        }
    }
    
    private func executeCornerAction(_ action: CornerAction) {
        switch action {
        case .toggleMute:
            delegate?.slideEngineDidToggleMute()
        case .playPause:
            delegate?.slideEngineDidPlayPause()
        case .maxBrightness:
            delegate?.slideEngineDidAdjustBrightness(delta: 1.0, isPrecise: false)
        case .screenshot:
            delegate?.slideEngineDidTriggerScreenshot()
        case .screenRecording:
            delegate?.slideEngineDidTriggerScreenRecording()
        case .runCustomScript:
            delegate?.slideEngineDidTriggerCustomScript()
        case .disabled:
            break
        }
    }
    
    // MARK: - CornerHoldManagerDelegate
    public func cornerHoldDidStart(corner: CornerType) {
        delegate?.slideEngineDidStartCornerHold(corner: corner)
    }
    
    public func cornerHoldDidTrigger(action: CornerHoldAction) {
        if let touchID = cornerHoldManager.activeTouchID {
            ignoredTouchIDs.insert(touchID)
        }
        phase = .idle
        switch action {
        case .screenshot:
            delegate?.slideEngineDidTriggerScreenshot()
        case .screenRecording:
            delegate?.slideEngineDidTriggerScreenRecording()
        }
    }
}
