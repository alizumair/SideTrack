import Foundation
import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static private(set) var shared: AppDelegate?
    public private(set) var statusBarController: StatusBarController?
    
    public override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Guarantee menu bar accessory mode (no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize Status Bar controller
        statusBarController = StatusBarController(appState: AppState.shared)
        
        // Start trackpad engine
        AppState.shared.startEngine()
        
        // Open settings if requested via CLI flag
        if CommandLine.arguments.contains("--settings") || CommandLine.arguments.contains("-s") {
            statusBarController?.openSettings()
        }
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.openSettings()
        return true
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.stopEngine()
    }
}
