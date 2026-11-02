import Foundation
import CoreGraphics

public final class DisplayBrightnessBridge {
    public static let shared = DisplayBrightnessBridge()
    
    private typealias DisplayServicesGetBrightnessType = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias DisplayServicesSetBrightnessType = @convention(c) (CGDirectDisplayID, Float) -> Int32
    
    private var getBrightnessFn: DisplayServicesGetBrightnessType?
    private var setBrightnessFn: DisplayServicesSetBrightnessType?
    private var frameworkHandle: UnsafeMutableRawPointer?
    
    public var onBrightnessChanged: ((Float) -> Void)?
    
    private init() {
        loadFramework()
    }
    
    deinit {
        if let handle = frameworkHandle {
            dlclose(handle)
        }
    }
    
    private func loadFramework() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_NOW) else {
            NSLog("[EdgeBar] Could not dlopen DisplayServices.framework; fallback will be used.")
            return
        }
        self.frameworkHandle = handle
        
        if let symGet = dlsym(handle, "DisplayServicesGetBrightness") {
            self.getBrightnessFn = unsafeBitCast(symGet, to: DisplayServicesGetBrightnessType.self)
        }
        if let symSet = dlsym(handle, "DisplayServicesSetBrightness") {
            self.setBrightnessFn = unsafeBitCast(symSet, to: DisplayServicesSetBrightnessType.self)
        }
    }
    
    public func getBrightness() -> Float {
        if let getBrightness = getBrightnessFn {
            var value: Float = 0.5
            let res = getBrightness(CGMainDisplayID(), &value)
            if res == 0 {
                return max(0.0, min(1.0, value))
            }
        }
        return 0.5
    }
    
    public func setBrightness(_ value: Float) {
        let clamped = max(0.0, min(1.0, value))
        if let setBrightness = setBrightnessFn {
            let res = setBrightness(CGMainDisplayID(), clamped)
            if res == 0 {
                onBrightnessChanged?(clamped)
                return
            }
        }
        
        // Fallback: estimate step difference and dispatch brightness keys
        let current = getBrightness()
        if clamped > current {
            MediaKeyDispatcher.shared.brightnessUp()
        } else if clamped < current {
            MediaKeyDispatcher.shared.brightnessDown()
        }
        onBrightnessChanged?(clamped)
    }
    
    public func adjustBrightness(by delta: Float) {
        let current = getBrightness()
        setBrightness(current + delta)
    }
}
