import Foundation
import CoreGraphics
import ObjectiveC

public enum OSDType: Int64 {
    case volume = 1
    case brightness = 2
    case mute = 3
}

public final class OSDBridge {
    public static let shared = OSDBridge()
    
    private typealias OSDShowChicletsFunc = @convention(c) (
        AnyObject,
        Selector,
        Int64,      // image / graphic type
        UInt32,     // displayID
        UInt32,     // priority
        UInt32,     // msecUntilFade
        UInt32,     // filledChiclets
        UInt32,     // totalChiclets
        Bool        // locked
    ) -> Void
    
    private var osdManager: AnyObject?
    private var showChicletsFn: OSDShowChicletsFunc?
    private var chicletsSelector: Selector?
    private var isAvailable: Bool = false
    
    private init() {
        setup()
    }
    
    private func setup() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/OSD.framework/OSD", RTLD_NOW) else {
            NSLog("[EdgeBar] OSD.framework not found")
            return
        }
        _ = handle
        
        guard let osdClass = NSClassFromString("OSDManager") as AnyObject as? NSObjectProtocol else {
            return
        }
        
        let sharedSel = NSSelectorFromString("sharedManager")
        guard osdClass.responds(to: sharedSel),
              let manager = (osdClass as AnyObject).perform(sharedSel)?.takeUnretainedValue() else {
            return
        }
        
        self.osdManager = manager
        let sel = NSSelectorFromString("showImage:onDisplayID:priority:msecUntilFade:filledChiclets:totalChiclets:locked:")
        self.chicletsSelector = sel
        
        if let method = class_getInstanceMethod(object_getClass(manager), sel) {
            let imp = method_getImplementation(method)
            self.showChicletsFn = unsafeBitCast(imp, to: OSDShowChicletsFunc.self)
            self.isAvailable = true
        }
    }
    
    public func showVolume(level: Float, muted: Bool) {
        guard isAvailable, let manager = osdManager, let fn = showChicletsFn, let sel = chicletsSelector else {
            return
        }
        let totalChiclets: UInt32 = 16
        let filledChiclets = muted ? 0 : UInt32(round(max(0.0, min(1.0, level)) * Float(totalChiclets)))
        let type: Int64 = muted ? OSDType.mute.rawValue : OSDType.volume.rawValue
        
        fn(manager, sel, type, CGMainDisplayID(), 1, 1000, filledChiclets, totalChiclets, false)
    }
    
    public func showBrightness(level: Float) {
        guard isAvailable, let manager = osdManager, let fn = showChicletsFn, let sel = chicletsSelector else {
            return
        }
        let totalChiclets: UInt32 = 16
        let filledChiclets = UInt32(round(max(0.0, min(1.0, level)) * Float(totalChiclets)))
        
        fn(manager, sel, OSDType.brightness.rawValue, CGMainDisplayID(), 1, 1000, filledChiclets, totalChiclets, false)
    }
}
