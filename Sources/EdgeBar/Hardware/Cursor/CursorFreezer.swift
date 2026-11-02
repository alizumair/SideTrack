import Foundation
import CoreGraphics

public final class CursorFreezer {
    public static let shared = CursorFreezer()
    
    private var isFrozen: Bool = false
    private let lock = NSLock()
    
    private init() {}
    
    deinit {
        unfreeze()
    }
    
    public func freeze() {
        lock.lock()
        defer { lock.unlock() }
        
        guard !isFrozen else { return }
        CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
        isFrozen = true
    }
    
    public func unfreeze() {
        lock.lock()
        defer { lock.unlock() }
        
        guard isFrozen else { return }
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
        isFrozen = false
    }
}
