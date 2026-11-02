import Foundation
import IOKit
import AppKit

public final class KeyboardBacklightBridge {
    public static let shared = KeyboardBacklightBridge()
    
    private var currentLevel: Float = 0.5
    private let lock = NSLock()
    
    public var onBacklightChanged: ((Float) -> Void)?
    
    private init() {
        self.currentLevel = readCurrentBacklight()
    }
    
    /// Reads keyboard brightness from IOKit services (AppleKeyboardBacklight or AppleLMUController)
    public func getBrightness() -> Float {
        lock.lock()
        defer { lock.unlock() }
        let hw = readCurrentBacklight()
        if hw >= 0 {
            currentLevel = hw
        }
        return currentLevel
    }
    
    /// Sets keyboard brightness (0.0 to 1.0) via direct IOKit or illumination events
    public func setBrightness(_ value: Float) {
        let clamped = max(0.0, min(1.0, value))
        lock.lock()
        let previous = currentLevel
        currentLevel = clamped
        lock.unlock()
        
        let delta = clamped - previous
        if abs(delta) > 0.005 {
            writeHardwareBacklight(clamped, delta: delta)
        }
        
        onBacklightChanged?(clamped)
    }
    
    private func readCurrentBacklight() -> Float {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleKeyboardBacklight")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS, iterator != 0 else {
            return -1.0
        }
        defer { IOObjectRelease(iterator) }
        
        let service = IOIteratorNext(iterator)
        guard service != 0 else { return -1.0 }
        defer { IOObjectRelease(service) }
        
        if let prop = IORegistryEntryCreateCFProperty(service, "KeyboardBacklight" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
            return prop.floatValue / 100.0
        }
        if let prop = IORegistryEntryCreateCFProperty(service, "Brightness" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
            return prop.floatValue / 100.0
        }
        return -1.0
    }
    
    private func writeHardwareBacklight(_ level: Float, delta: Float) {
        // Method 1: Try IOKit direct property write
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleKeyboardBacklight")
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS, iterator != 0 {
            let service = IOIteratorNext(iterator)
            if service != 0 {
                let num = NSNumber(value: Int(round(level * 100.0)))
                _ = IORegistryEntrySetCFProperty(service, "KeyboardBacklight" as CFString, num)
                IOObjectRelease(service)
            }
            IOObjectRelease(iterator)
        }
        
        // Method 2: System-defined illumination event stepping
        if delta > 0 {
            MediaKeyDispatcher.shared.keyboardBrightnessUp()
        } else if delta < 0 {
            MediaKeyDispatcher.shared.keyboardBrightnessDown()
        }
    }
}
