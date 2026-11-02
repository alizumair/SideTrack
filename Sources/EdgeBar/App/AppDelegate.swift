import Foundation
import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var activityToken: NSObjectProtocol?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Guarantee menu bar accessory mode (no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Prevent App Nap from suspending background trackpad listener
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "Real-time Trackpad Gesture Tracking"
        )
        
        // Initialize Status Bar controller
        statusBarController = StatusBarController(appState: AppState.shared)
        
        // Check initial permissions
        AccessibilityManager.shared.checkStatus()
        
        // Start trackpad engine
        AppState.shared.startEngine()
        
        // Check permissions and present onboarding if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if !AccessibilityManager.shared.isFullyAuthorized {
                self?.statusBarController?.openPermissions()
            }
        }
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.stopEngine()
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
        }
    }
}
