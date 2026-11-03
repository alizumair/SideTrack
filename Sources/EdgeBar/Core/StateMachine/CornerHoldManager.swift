import Foundation
import CoreGraphics
import AppKit

public enum CornerType: String, CaseIterable, Equatable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    
    public var isHoldable: Bool {
        switch self {
        case .topLeft, .bottomLeft, .bottomRight:
            return true
        case .topRight:
            // Top-Right is reserved exclusively for double-tap mute
            return false
        }
    }
}

public protocol CornerHoldManagerDelegate: AnyObject {
    func cornerHoldDidStart(corner: CornerType)
    func cornerHoldDidCountdown(corner: CornerType, action: CornerHoldAction, count: Int, total: Int)
    func cornerHoldDidCancel()
    func cornerHoldDidTrigger(action: CornerHoldAction)
}

public extension CornerHoldManagerDelegate {
    func cornerHoldDidCountdown(corner: CornerType, action: CornerHoldAction, count: Int, total: Int) {}
    func cornerHoldDidCancel() {}
}

public final class CornerHoldManager {
    public weak var delegate: CornerHoldManagerDelegate?
    
    private let lock = NSLock()
    
    private var _activeCorner: CornerType?
    private var _activeTouchID: Int32?
    private var _startPosition: CGPoint?
    private var _isHolding: Bool = false
    private var _hasTriggeredForCurrentTouch: Bool = false
    private var holdWorkItem: DispatchWorkItem?
    private var countdownWorkItems: [DispatchWorkItem] = []
    
    public var activeCorner: CornerType? {
        lock.lock()
        defer { lock.unlock() }
        return _activeCorner
    }
    
    public var activeTouchID: Int32? {
        lock.lock()
        defer { lock.unlock() }
        return _activeTouchID
    }
    
    public var startPosition: CGPoint? {
        lock.lock()
        defer { lock.unlock() }
        return _startPosition
    }
    
    public var isHolding: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isHolding
    }
    
    public var hasTriggeredForCurrentTouch: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _hasTriggeredForCurrentTouch
    }
    
    // Test hook to allow injecting custom execution queues or immediate execution
    public var customScheduler: ((Double, @escaping () -> Void) -> DispatchWorkItem)?
    
    public init() {}
    
    /// Classifies whether an (x, y) coordinate is in one of the 4 outer corner zones (default 15% width & height).
    public func classifyCorner(x: Float, y: Float, cornerFraction: Float = 0.15) -> CornerType? {
        let isLeft = x <= cornerFraction
        let isRight = x >= (1.0 - cornerFraction)
        let isBottom = y <= cornerFraction
        let isTop = y >= (1.0 - cornerFraction)
        
        if isTop && isLeft {
            return .topLeft
        }
        if isTop && isRight {
            return .topRight
        }
        if isBottom && isLeft {
            return .bottomLeft
        }
        if isBottom && isRight {
            return .bottomRight
        }
        return nil
    }
    
    /// Processes a trackpad frame for corner hold detection.
    /// Returns `true` if the touch is actively held or consumed as a corner hold gesture.
    public func processFrame(
        contacts: [TrackpadContact],
        settings: SettingsModel
    ) -> Bool {
        lock.lock()
        
        guard settings.cornerHoldsEnabled else {
            if _isHolding {
                internalCancelHold()
            }
            lock.unlock()
            return false
        }
        
        // Multi-finger cancel: immediately cancels hold and yields
        if contacts.count != 1 {
            if _isHolding {
                internalCancelHold()
            }
            lock.unlock()
            return false
        }
        
        let contact = contacts[0]
        
        // Finger lifted / terminating
        if contact.state.isTerminating {
            if _isHolding {
                internalCancelHold()
            }
            lock.unlock()
            return false
        }
        
        let fraction = Float(settings.cornerHoldFraction)
        
        // If already triggered for this specific touch, keep consuming until lifted
        if _hasTriggeredForCurrentTouch && contact.id == _activeTouchID {
            lock.unlock()
            return true
        }
        
        // If currently tracking an active hold
        if _isHolding, let currentTouchID = _activeTouchID, let startPos = _startPosition, let corner = _activeCorner {
            guard contact.id == currentTouchID else {
                internalCancelHold()
                lock.unlock()
                return false
            }
            
            // Stationary check: movement threshold 0.045 (~6mm) to allow natural resting thumb stability
            let dx = contact.x - Float(startPos.x)
            let dy = contact.y - Float(startPos.y)
            let movement = hypot(dx, dy)
            
            // Check if finger moved too much or wandered out of corner zone
            let stillInCorner = classifyCorner(x: contact.x, y: contact.y, cornerFraction: fraction) == corner
            if movement > 0.045 || !stillInCorner {
                internalCancelHold()
                lock.unlock()
                return false
            }
            
            lock.unlock()
            return true
        }
        
        // New touch candidate in a corner zone
        guard let corner = classifyCorner(x: contact.x, y: contact.y, cornerFraction: fraction),
              corner.isHoldable else {
            lock.unlock()
            return false
        }
        
        // Determine action and duration
        let action: CornerHoldAction
        switch corner {
        case .topLeft:
            action = settings.topLeftHoldAction
        case .bottomLeft:
            action = settings.bottomLeftHoldAction
        case .bottomRight:
            action = settings.bottomRightHoldAction
        case .topRight:
            lock.unlock()
            return false
        }
        
        guard action != .disabled else {
            lock.unlock()
            return false
        }
        
        let duration: Double = (action == .screenRecording) ? settings.screenRecordingHoldDuration : settings.screenshotHoldDuration
        
        // Begin tracking hold
        _activeTouchID = contact.id
        _activeCorner = corner
        _startPosition = CGPoint(x: CGFloat(contact.x), y: CGFloat(contact.y))
        _isHolding = true
        _hasTriggeredForCurrentTouch = false
        
        let touchID = contact.id
        let scheduler = self.customScheduler
        
        let block: () -> Void = { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            guard self._isHolding,
                  self._activeTouchID == touchID,
                  !self._hasTriggeredForCurrentTouch else {
                self.lock.unlock()
                return
            }
            
            self._hasTriggeredForCurrentTouch = true
            self._isHolding = false
            self.lock.unlock()
            
            self.delegate?.cornerHoldDidTrigger(action: action)
        }
        
        if let custom = scheduler {
            self.holdWorkItem = custom(duration, block)
        } else {
            let item = DispatchWorkItem(block: block)
            self.holdWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
            
            // Schedule countdown ticks (1... 2... 3...)
            if settings.showHoldCountdownTimer {
                let totalSeconds = max(1, Int(round(duration)))
                self.delegate?.cornerHoldDidCountdown(corner: corner, action: action, count: 1, total: totalSeconds)
                
                if totalSeconds > 1 {
                    for sec in 2...totalSeconds {
                        let delay = Double(sec - 1)
                        if delay < duration {
                            let tickItem = DispatchWorkItem { [weak self] in
                                guard let self = self, self.isHolding, self._activeTouchID == touchID else { return }
                                self.delegate?.cornerHoldDidCountdown(corner: corner, action: action, count: sec, total: totalSeconds)
                            }
                            self.countdownWorkItems.append(tickItem)
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: tickItem)
                        }
                    }
                }
            }
        }
        
        lock.unlock()
        
        // Subtle start tick haptic feedback
        delegate?.cornerHoldDidStart(corner: corner)
        
        return true
    }
    
    public func cancelHold() {
        lock.lock()
        defer { lock.unlock() }
        internalCancelHold()
    }
    
    private func internalCancelHold() {
        holdWorkItem?.cancel()
        holdWorkItem = nil
        countdownWorkItems.forEach { $0.cancel() }
        countdownWorkItems.removeAll()
        _activeTouchID = nil
        _activeCorner = nil
        _startPosition = nil
        _isHolding = false
        _hasTriggeredForCurrentTouch = false
        delegate?.cornerHoldDidCancel()
    }
}
