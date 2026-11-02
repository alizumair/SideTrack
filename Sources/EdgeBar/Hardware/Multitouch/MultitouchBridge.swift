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
    private typealias MTRegisterContactFrameCallbackType = @convention(c) (OpaquePointer, MTContactCallbackFunction) -> Void
    private typealias MTUnregisterContactFrameCallbackType = @convention(c) (OpaquePointer, MTContactCallbackFunction) -> Void
    private typealias MTDeviceStartType = @convention(c) (OpaquePointer, Int32) -> Void
    private typealias MTDeviceStopType = @convention(c) (OpaquePointer, Int32) -> Void
    private typealias MTDeviceIsBuiltInType = @convention(c) (OpaquePointer) -> Bool
    
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var createListFn: MTDeviceCreateListType?
    private var registerCallbackFn: MTRegisterContactFrameCallbackType?
    private var unregisterCallbackFn: MTUnregisterContactFrameCallbackType?
    private var startDeviceFn: MTDeviceStartType?
    private var stopDeviceFn: MTDeviceStopType?
    private var isBuiltInFn: MTDeviceIsBuiltInType?
    
    private var activeDevices: [OpaquePointer] = []
    private var isRunning: Bool = false
    private let queue = DispatchQueue(label: "io.github.edgebar.multitouch", qos: .userInteractive)
    
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
        if let sym = dlsym(handle, "MTDeviceIsBuiltIn") {
            isBuiltInFn = unsafeBitCast(sym, to: MTDeviceIsBuiltInType.self)
        }
    }
    
    public func start() {
        queue.async { [weak self] in
            guard let self = self, !self.isRunning else { return }
            guard let createList = self.createListFn,
                  let registerCb = self.registerCallbackFn,
                  let startDev = self.startDeviceFn else {
                NSLog("[EdgeBar] Multitouch function pointers not loaded")
                return
            }
            
            guard let cfList = createList()?.takeRetainedValue() else {
                NSLog("[EdgeBar] MTDeviceCreateList returned nil")
                return
            }
            
            let count = CFArrayGetCount(cfList)
            var devices: [OpaquePointer] = []
            for i in 0..<count {
                if let devPtr = CFArrayGetValueAtIndex(cfList, i) {
                    let dev = OpaquePointer(devPtr)
                    devices.append(dev)
                    registerCb(dev, MultitouchBridge.frameCallback)
                    startDev(dev, 0)
                }
            }
            self.activeDevices = devices
            self.isRunning = true
            NSLog("[EdgeBar] Multitouch monitoring started on %d device(s)", count)
        }
    }
    
    public func stop() {
        queue.sync {
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
        MultitouchBridge.shared.processContacts(contacts, timestamp: timestamp, frame: frame)
        return 0
    }
}
