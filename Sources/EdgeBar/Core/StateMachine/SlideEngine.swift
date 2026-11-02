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
    private var hasFiredMediaSkipForCurrentSlide: Bool = false
    private var isSlidingActive: Bool = false
    
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
        
        // Purge any ignored touch IDs that are no longer active on the trackpad
        let activeIDs = Set(contacts.map { $0.id })
        ignoredTouchIDs = ignoredTouchIDs.intersection(activeIDs)
        
        // 1. Multi-finger Gate:
        // When 2 or more fingers are on the pad, yield immediately and completely to macOS
        // for native scrolling, pinch-to-zoom, and mission control.
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
        
        // If this touch ID was flagged as ignored for this contact session, skip it
        if ignoredTouchIDs.contains(contact.id) {
            return
        }
        
        // Process touch lifecycle
        switch phase {
        case .idle:
            let zone = classifier.classify(x: contact.x, y: contact.y)
            if zone == .middle {
                // Reject middle touches: normal pointer movement, ignore throughout its session
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
                // If the user performed a quick flick swipe along the bottom strip before releasing:
                if zone == .bottom && absDx >= 0.020 && absDx > absDy {
                    delegate?.slideEngineDidSkipMediaTrack(forward: dx > 0)
                } else {
                    // Finger lifted while still in candidate: check if it's a tap
                    let tapThreshold: Float = 0.020
                    if movement < tapThreshold && duration < settings.doubleTapMaxInterval {
                        handleTap(zone: zone, x: contact.x, y: contact.y, timestamp: timestamp)
                    }
                }
                phase = .idle
                return
            }
            
            if zone == .left || zone == .right || zone == .topRightCorner {
                let inwardDx: Float = (zone == .left) ? dx : -dx
                
                // 1. Strict rejection of inward horizontal strokes:
                // Moving horizontally towards the center of the trackpad
                if inwardDx >= 0.006 && inwardDx >= (absDy * 0.7) {
                    ignoredTouchIDs.insert(touchID)
                    phase = .idle
                    return
                }
                
                // 2. Strict rejection of general horizontal movement on vertical strips
                if absDx >= 0.008 && absDx >= absDy {
                    ignoredTouchIDs.insert(touchID)
                    phase = .idle
                    return
                }
                
                // 3. Effortless vertical slide activation:
                // Responsive ~0.8mm vertical travel (absDy >= 0.010),
                // clearly vertical (absDy > absDx),
                // and not moving inward into the center (inwardDx < 0.006)
                if absDy >= 0.010 && absDy > absDx && inwardDx < 0.006 {
                    phase = .sliding(touchID: touchID, zone: zone, currentX: contact.x, currentY: contact.y)
                    startSlide()
                    processSlideDelta(zone: zone, deltaX: dx, deltaY: dy)
                }
            } else if zone == .bottom {
                // Gating for bottom edge:
                // Only reject if moving predominantly upwards from the bottom strip into trackpad center:
                if dy > 0.040 && dy > (absDx * 1.8) {
                    ignoredTouchIDs.insert(touchID)
                    phase = .idle
                    return
                }
                
                // Engage horizontal media skip when swiping horizontally across the bottom strip
                if absDx >= 0.020 && absDx >= absDy {
                    if !hasFiredMediaSkipForCurrentSlide {
                        delegate?.slideEngineDidSkipMediaTrack(forward: dx > 0)
                        hasFiredMediaSkipForCurrentSlide = true
                    }
                    phase = .sliding(touchID: touchID, zone: zone, currentX: contact.x, currentY: contact.y)
                    startSlide()
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
                
                // Check if user turned horizontally towards the trackpad body during an active slide
                if zone == .left || zone == .right || zone == .topRightCorner {
                    let inwardDx: Float = (zone == .left) ? dx : -dx
                    // Strict on horizontal mistakes: abort slide immediately when dragging inward into the trackpad
                    if inwardDx >= 0.004 && inwardDx >= abs(dy) {
                        endSlide(cancelled: true)
                        ignoredTouchIDs.insert(touchID)
                        phase = .idle
                        return
                    }
                    
                    // Exit slide if the finger crosses beyond the edge zone into the trackpad body
                    if zone == .left && contact.x > Float(settings.edgeWidthFraction) * 1.05 {
                        endSlide(cancelled: true)
                        ignoredTouchIDs.insert(touchID)
                        phase = .idle
                        return
                    }
                    if (zone == .right || zone == .topRightCorner) && contact.x < (1.0 - Float(settings.edgeWidthFraction) * 1.05) {
                        endSlide(cancelled: true)
                        ignoredTouchIDs.insert(touchID)
                        phase = .idle
                        return
                    }
                }
                if zone == .bottom && contact.y > Float(settings.edgeHeightFraction) * 1.25 {
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
    
    private func startSlide() {
        isSlidingActive = true
        delegate?.slideEngineSlideStateChanged(isSliding: true)
    }
    
    private func endSlide(cancelled: Bool) {
        isSlidingActive = false
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
        // Strict on horizontal mistakes: If movement on this frame is not strictly vertical, ignore vertical delta!
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
            
        case .bottom, .middle:
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
