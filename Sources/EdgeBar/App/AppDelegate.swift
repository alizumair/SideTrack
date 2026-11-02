import Foundation
import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Guarantee menu bar accessory mode (no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize Status Bar controller
        statusBarController = StatusBarController(appState: AppState.shared)
        
        // Start trackpad engine
        AppState.shared.startEngine()
        
        // Check permissions and present onboarding if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if !AccessibilityManager.shared.isTrusted {
                self?.statusBarController?.openPermissions()
            }
        }
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.stopEngine()
    }
}
