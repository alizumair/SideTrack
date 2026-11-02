import Foundation
import AppKit

public protocol SlideEngineDelegate: AnyObject {
    func slideEngineDidAdjustBrightness(delta: Float, isPrecise: Bool)
    func slideEngineDidAdjustVolume(delta: Float, isPrecise: Bool)
    func slideEngineDidSkipMediaTrack(forward: Bool)
    func slideEngineDidPlayPause()
    func slideEngineDidToggleMute()
    func slideEngineSlideStateChanged(isSliding: Bool)
    func slideEngineHapticTick()
}

public final class SlideEngine {
    public weak var delegate: SlideEngineDelegate?
    
    public var settings: SettingsModel {
        didSet {
            updateClassifier()
        }
    }
    
    public private(set) var phase: GesturePhase = .idle
    private var classifier: EdgeClassifier
    private var ignoredTouchIDs: Set<Int32> = []
    private var lastTap: RecordedTap?
    private var accumulatedBottomSwipeDelta: Float = 0.0
    private var hasFiredMediaSkipForCurrentSlide: Bool = false
    private var isSlidingActive: Bool = false
    
    // Vertical travel threshold required before engaging an edge slide (~3.5mm)
    private let verticalActivationDistance: Float = 0.022
    
    // Test hook for simulating modifier flags without depending on UI events
    public var modifierFlagsProvider: (() -> NSEvent.ModifierFlags)?
    
    public init(settings: SettingsModel = .default) {
        self.settings = settings
        self.classifier = EdgeClassifier(
            edgeWidth: Float(settings.edgeWidthFraction),
            edgeHeight: Float(settings.edgeHeightFraction),
            cornerSize: Float(settings.cornerZoneFraction)
        )
    }
    
    private func updateClassifier() {
        self.classifier = EdgeClassifier(
            edgeWidth: Float(settings.edgeWidthFraction),
            edgeHeight: Float(settings.edgeHeightFraction),
            cornerSize: Float(settings.cornerZoneFraction)
        )
    }
    
    public func processFrame(contacts: [TrackpadContact], timestamp: Double) {
        guard settings.isEnabled else {
            if isSlidingActive {
                endSlide(cancelled: true)
            }
            return
        }
        
        // 1. Intelligent Multi-finger Gate:
        // When 2 or more fingers are on the pad, pass through immediately to macOS for native scrolling.
        if contacts.count > 1 {
            if isSlidingActive || phase != .idle {
                endSlide(cancelled: true)
                phase = .cancelled
            }
            return
        }
        
        // 2. Pad is empty
        if contacts.isEmpty {
            if isSlidingActive {
                endSlide(cancelled: false)
            }
            phase = .idle
            ignoredTouchIDs.removeAll()
            accumulatedBottomSwipeDelta = 0.0
            hasFiredMediaSkipForCurrentSlide = false
            return
        }
        
        // 3. Exactly one finger on the pad
        let contact = contacts[0]
        
        // If we previously entered cancelled state due to multi-finger, wait until touch lifts
        if phase == .cancelled {
            if contact.state.isTerminating {
                phase = .idle
            }
            return
        }
        
        // If this touch ID was flagged as middle/ignored, ignore it entirely
        if ignoredTouchIDs.contains(contact.id) {
            if contact.state.isTerminating {
                ignoredTouchIDs.remove(contact.id)
            }
            return
        }
        
        // Process touch lifecycle
        switch phase {
        case .idle:
            let zone = classifier.classify(x: contact.x, y: contact.y)
            if zone == .middle {
                // Reject middle touch: strictly ignore it throughout its lifespan
                ignoredTouchIDs.insert(contact.id)
                return
            }
            accumulatedBottomSwipeDelta = 0.0
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
            let tapThreshold = Float(settings.maxTapMovementThreshold)
            
            if contact.state.isTerminating {
                // Finger lifted while still a candidate
                if movement < tapThreshold && duration < settings.doubleTapMaxInterval {
                    handleTap(zone: zone, x: contact.x, y: contact.y, timestamp: timestamp)
                }
                phase = .idle
                return
            }
            
            // Check directional motion intent
            if zone == .left || zone == .right || zone == .topRightCorner {
                // HORIZONTAL DRAG REJECTION:
                // If the user drags horizontally from the edge towards the center (absDx >= absDy),
                // cancel edge handling immediately so this touch has ZERO effect on volume or brightness.
                if absDx > 0.012 && absDx >= absDy {
                    ignoredTouchIDs.insert(touchID)
                    phase = .idle
                    return
                }
                
                // VERTICAL ENGAGEMENT:
                // Must slide vertically by at least verticalActivationDistance (~3.5mm)
                // with predominantly vertical travel before engaging slider.
                if absDy >= verticalActivationDistance && absDy >= absDx * 1.4 {
                    phase = .sliding(touchID: touchID, zone: zone, currentX: contact.x, currentY: contact.y)
                    startSlide()
                    processSlideDelta(zone: zone, deltaX: dx, deltaY: dy)
                }
            } else if zone == .bottom {
                // For bottom edge: must be predominantly horizontal
                if absDy > 0.012 && absDy >= absDx {
                    ignoredTouchIDs.insert(touchID)
                    phase = .idle
                    return
                }
                
                // Horizontal track skip check
                if absDx >= 0.040 && absDx >= absDy * 1.4 {
                    phase = .sliding(touchID: touchID, zone: zone, currentX: contact.x, currentY: contact.y)
                    startSlide()
                    processSlideDelta(zone: zone, deltaX: dx, deltaY: dy)
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
                // If a side-edge slide wanders horizontally off the edge strip into the trackpad body,
                // cancel the slide immediately so it stops affecting the slider.
                if (zone == .left && contact.x > Float(settings.edgeWidthFraction) * 1.4) ||
                   ((zone == .right || zone == .topRightCorner) && contact.x < (1.0 - Float(settings.edgeWidthFraction) * 1.4)) {
                    endSlide(cancelled: true)
                    ignoredTouchIDs.insert(touchID)
                    phase = .idle
                    return
                }
                
                let dx = contact.x - currentX
                let dy = contact.y - currentY
                phase = .sliding(touchID: touchID, zone: zone, currentX: contact.x, currentY: contact.y)
                processSlideDelta(zone: zone, deltaX: dx, deltaY: dy)
            }
            
        case .cancelled:
            break
        }
    }
    
    private func startSlide() {
        isSlidingActive = true
        accumulatedBottomSwipeDelta = 0.0
        hasFiredMediaSkipForCurrentSlide = false
        delegate?.slideEngineSlideStateChanged(isSliding: true)
    }
    
    private func endSlide(cancelled: Bool) {
        isSlidingActive = false
        accumulatedBottomSwipeDelta = 0.0
        hasFiredMediaSkipForCurrentSlide = false
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
        let isPrecise = isPrecisionHeld()
        let multiplier: Float = isPrecise ? Float(settings.precisionMultiplier) : 1.0
        let sensitivity = Float(settings.sensitivity)
        
        var effectiveDeltaY = deltaY * sensitivity * multiplier
        if settings.invertVerticalAxis {
            effectiveDeltaY = -effectiveDeltaY
        }
        
        switch zone {
        case .left:
            // Left Edge: Strictly Display Brightness (vertical)
            if settings.leftEdgeAction == .brightness {
                delegate?.slideEngineDidAdjustBrightness(delta: effectiveDeltaY, isPrecise: isPrecise)
            } else if settings.leftEdgeAction == .volume {
                delegate?.slideEngineDidAdjustVolume(delta: effectiveDeltaY, isPrecise: isPrecise)
            }
            
        case .right, .topRightCorner:
            // Right Edge & Corner sliding: Strictly System Volume (vertical)
            if settings.rightEdgeAction == .volume {
                delegate?.slideEngineDidAdjustVolume(delta: effectiveDeltaY, isPrecise: isPrecise)
            } else if settings.rightEdgeAction == .brightness {
                delegate?.slideEngineDidAdjustBrightness(delta: effectiveDeltaY, isPrecise: isPrecise)
            }
            
        case .bottom:
            // Bottom Edge: Strictly horizontal media track skip
            accumulatedBottomSwipeDelta += deltaX * sensitivity
            let swipeThreshold: Float = 0.040 // 4% horizontal swipe distance
            if !hasFiredMediaSkipForCurrentSlide {
                if accumulatedBottomSwipeDelta > swipeThreshold {
                    delegate?.slideEngineDidSkipMediaTrack(forward: true)
                    hasFiredMediaSkipForCurrentSlide = true
                } else if accumulatedBottomSwipeDelta < -swipeThreshold {
                    delegate?.slideEngineDidSkipMediaTrack(forward: false)
                    hasFiredMediaSkipForCurrentSlide = true
                }
            }
            
        case .middle:
            break
        }
    }
    
    private func handleTap(zone: EdgeZone, x: Float, y: Float, timestamp: Double) {
        let tap = RecordedTap(zone: zone, timestamp: timestamp, x: x, y: y)
        
        if let last = lastTap,
           last.zone == zone,
           (timestamp - last.timestamp) <= settings.doubleTapMaxInterval {
            // Double-tap confirmed in zone!
            lastTap = nil
            triggerDoubleTapAction(zone: zone)
        } else {
            lastTap = tap
        }
    }
    
    private func triggerDoubleTapAction(zone: EdgeZone) {
        switch zone {
        case .topRightCorner:
            if settings.topRightCornerAction == .toggleMute {
                delegate?.slideEngineDidToggleMute()
            }
        case .bottom:
            if settings.bottomDoubleTapAction == .playPause {
                delegate?.slideEngineDidPlayPause()
            }
        default:
            break
        }
    }
}
