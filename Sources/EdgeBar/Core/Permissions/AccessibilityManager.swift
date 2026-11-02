import Foundation
import AppKit
import ApplicationServices

public final class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()
    
    private typealias IOHIDCheckAccessType = @convention(c) (UInt32) -> Int32
    private typealias IOHIDRequestAccessType = @convention(c) (UInt32) -> Bool
    
    @Published public private(set) var isTrusted: Bool = false
    @Published public private(set) var isAccessibilityGranted: Bool = false
    @Published public private(set) var isInputMonitoringGranted: Bool = false
    
    public var isFullyAuthorized: Bool {
        isAccessibilityGranted && isInputMonitoringGranted
    }
    
    private var pollTimer: Timer?
    
    private init() {
        checkStatus()
    }
    
    public func checkStatus() {
        let axTrusted = AXIsProcessTrusted()
        var inputTrusted = false
        if let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW),
           let sym = dlsym(handle, "IOHIDCheckAccess") {
            let checkFn = unsafeBitCast(sym, to: IOHIDCheckAccessType.self)
            inputTrusted = (checkFn(0) == 0) // kIOHIDRequestTypeListenEvent = 0
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAccessibilityGranted = axTrusted
            self.isInputMonitoringGranted = inputTrusted
            self.isTrusted = axTrusted && inputTrusted
        }
    }
    
    public func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startPollingForPermission()
    }
    
    public func promptForInputMonitoring() {
        if let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW),
           let sym = dlsym(handle, "IOHIDRequestAccess") {
            let reqFn = unsafeBitCast(sym, to: IOHIDRequestAccessType.self)
            _ = reqFn(0)
        }
        openInputMonitoringSettings()
    }
    
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPollingForPermission()
    }
    
    public func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
        startPollingForPermission()
    }
    
    public func startPollingForPermission() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.checkStatus()
            if self.isFullyAuthorized {
                timer.invalidate()
                self.pollTimer = nil
            }
        }
    }
    
    deinit {
        pollTimer?.invalidate()
    }
}
