import Foundation
import CoreFoundation

public protocol MultitouchFrameDelegate: AnyObject {
    func multitouchBridge(_ bridge: MultitouchBridge, didUpdateContacts contacts: [TrackpadContact], timestamp: Double, frame: Int32)
}

public final class MultitouchBridge {
    public static let shared = MultitouchBridge()
    
    public weak var delegate: MultitouchFrameDelegate?
    
    private typealias MTContactCallbackFunction = @convention(c) (OpaquePointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias MTDeviceCreateListType = @convention(c) () -> Unmanaged<CFArray>?
    private typealias MTDeviceCreateDefaultType = @convention(c) () -> OpaquePointer?
    private typealias MTRegisterContactFrameCallbackType = @convention(c) (OpaquePointer, MTContactCallbackFunction) -> Void
    private typealias MTUnregisterContactFrameCallbackType = @convention(c) (OpaquePointer, MTContactCallbackFunction) -> Void
    private typealias MTDeviceStartType = @convention(c) (OpaquePointer, Int32) -> Void
    private typealias MTDeviceStopType = @convention(c) (OpaquePointer, Int32) -> Void
    private typealias MTDeviceScheduleOnRunLoopType = @convention(c) (OpaquePointer, CFRunLoop, CFString) -> Void
    
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var createListFn: MTDeviceCreateListType?
    private var createDefaultFn: MTDeviceCreateDefaultType?
    private var registerCallbackFn: MTRegisterContactFrameCallbackType?
    private var unregisterCallbackFn: MTUnregisterContactFrameCallbackType?
    private var startDeviceFn: MTDeviceStartType?
    private var stopDeviceFn: MTDeviceStopType?
    private var scheduleRunLoopFn: MTDeviceScheduleOnRunLoopType?
    
    private var activeDevices: [OpaquePointer] = []
    private var isRunning: Bool = false
    
    private init() {
        loadFramework()
    }
    
    deinit {
        stop()
        if let handle = frameworkHandle {
            dlclose(handle)
        }
    }
    
    private func loadFramework() {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else {
            NSLog("[EdgeBar] Failed to load MultitouchSupport.framework via dlopen")
            return
        }
        self.frameworkHandle = handle
        
        if let sym = dlsym(handle, "MTDeviceCreateList") {
            createListFn = unsafeBitCast(sym, to: MTDeviceCreateListType.self)
        }
        if let sym = dlsym(handle, "MTDeviceCreateDefault") {
            createDefaultFn = unsafeBitCast(sym, to: MTDeviceCreateDefaultType.self)
        }
        if let sym = dlsym(handle, "MTRegisterContactFrameCallback") {
            registerCallbackFn = unsafeBitCast(sym, to: MTRegisterContactFrameCallbackType.self)
        }
        if let sym = dlsym(handle, "MTUnregisterContactFrameCallback") {
            unregisterCallbackFn = unsafeBitCast(sym, to: MTUnregisterContactFrameCallbackType.self)
        }
        if let sym = dlsym(handle, "MTDeviceStart") {
            startDeviceFn = unsafeBitCast(sym, to: MTDeviceStartType.self)
        }
        if let sym = dlsym(handle, "MTDeviceStop") {
            stopDeviceFn = unsafeBitCast(sym, to: MTDeviceStopType.self)
        }
        if let sym = dlsym(handle, "MTDeviceScheduleOnRunLoop") {
            scheduleRunLoopFn = unsafeBitCast(sym, to: MTDeviceScheduleOnRunLoopType.self)
        }
    }
    
    public func start() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isRunning else { return }
            guard let registerCb = self.registerCallbackFn,
                  let startDev = self.startDeviceFn else {
                NSLog("[EdgeBar] Multitouch function pointers not loaded")
                return
            }
            
            var devices: [OpaquePointer] = []
            if let createList = self.createListFn, let cfList = createList()?.takeRetainedValue() {
                let count = CFArrayGetCount(cfList)
                for i in 0..<count {
                    if let devPtr = CFArrayGetValueAtIndex(cfList, i) {
                        devices.append(OpaquePointer(devPtr))
                    }
                }
            }
            
            if devices.isEmpty, let createDefault = self.createDefaultFn, let dev = createDefault() {
                devices.append(dev)
            }
            
            for dev in devices {
                registerCb(dev, MultitouchBridge.frameCallback)
                if let schedule = self.scheduleRunLoopFn {
                    schedule(dev, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
                }
                startDev(dev, 0)
            }
            
            self.activeDevices = devices
            self.isRunning = true
            NSLog("[EdgeBar] Multitouch monitoring active on %d device(s)", devices.count)
        }
    }
    
    public func stop() {
        guard isRunning else { return }
        guard let stopDev = stopDeviceFn,
              let unregisterCb = unregisterCallbackFn else { return }
        
        for dev in activeDevices {
            stopDev(dev, 0)
            unregisterCb(dev, MultitouchBridge.frameCallback)
        }
        activeDevices.removeAll()
        isRunning = false
        NSLog("[EdgeBar] Multitouch monitoring stopped")
    }
    
    fileprivate func processContacts(_ contacts: [TrackpadContact], timestamp: Double, frame: Int32) {
        delegate?.multitouchBridge(self, didUpdateContacts: contacts, timestamp: timestamp, frame: frame)
    }
    
    private static let frameCallback: MTContactCallbackFunction = { device, touchesPtr, numTouches, timestamp, frame in
        guard let touchesPtr = touchesPtr, numTouches > 0 else {
            MultitouchBridge.shared.processContacts([], timestamp: timestamp, frame: frame)
            return 0
        }
        
        let rawTouches = touchesPtr.assumingMemoryBound(to: MTTouchRaw.self)
        var contacts: [TrackpadContact] = []
        contacts.reserveCapacity(Int(numTouches))
        for i in 0..<Int(numTouches) {
            contacts.append(TrackpadContact(raw: rawTouches[i]))
        }
        if let first = contacts.first {
            NSLog("[EdgeBar] Contact id=%d count=%d x=%.3f y=%.3f state=%d", first.id, numTouches, first.x, first.y, first.state.rawValue)
        }
        MultitouchBridge.shared.processContacts(contacts, timestamp: timestamp, frame: frame)
        return 0
    }
}
