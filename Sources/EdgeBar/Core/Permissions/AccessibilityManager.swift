import Foundation
import AppKit
import ApplicationServices

public final class AccessibilityManager: ObservableObject {
    public static let shared = AccessibilityManager()
    
    @Published public private(set) var isTrusted: Bool = false
    
    public var isFullyAuthorized: Bool {
        isTrusted
    }
    
    private var pollTimer: Timer?
    
    private init() {
        checkStatus()
    }
    
    public func checkStatus() {
        let trusted = AXIsProcessTrusted()
        DispatchQueue.main.async { [weak self] in
            self?.isTrusted = trusted
        }
    }
    
    public func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startPollingForPermission()
    }
    
    public func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
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
            let trusted = AXIsProcessTrusted()
            DispatchQueue.main.async {
                self.isTrusted = trusted
                if trusted {
                    timer.invalidate()
                    self.pollTimer = nil
                }
            }
        }
    }
    
    deinit {
        pollTimer?.invalidate()
    }
}
