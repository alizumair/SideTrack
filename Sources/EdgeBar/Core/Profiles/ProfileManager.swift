import Foundation
import AppKit

public final class ProfileManager: ObservableObject {
    public static let shared = ProfileManager()
    
    @Published public private(set) var activeProfile: AppProfile?
    @Published public private(set) var isGameModeActive: Bool = false
    @Published public private(set) var frontmostAppName: String = ""
    @Published public private(set) var frontmostBundleID: String = ""
    
    public var onProfileChanged: ((AppProfile?, Bool) -> Void)?
    
    private var observer: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    
    private init() {
        setupWorkspaceNotifications()
        evaluateFrontmostApp()
    }
    
    deinit {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        if let sObs = spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sObs)
        }
    }
    
    private func setupWorkspaceNotifications() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateFrontmostApp()
        }
        
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.evaluateFrontmostApp()
        }
    }
    
    public func evaluateFrontmostApp(settings: SettingsModel = SettingsStore.shared.settings) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let bundleID = app.bundleIdentifier ?? ""
        let appName = app.localizedName ?? ""
        
        self.frontmostBundleID = bundleID
        self.frontmostAppName = appName
        
        // 1. Check Full-Screen / Game Mode bypass
        var isFullScreen = false
        if settings.gameModeEnabled {
            isFullScreen = isAppFullScreen(app: app)
        }
        self.isGameModeActive = isFullScreen
        
        // 2. Find matching profile
        var matched: AppProfile? = nil
        for profile in settings.profiles where profile.isEnabled {
            let identifiers = profile.bundleIdentifier
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            
            let currentLower = bundleID.lowercased()
            let nameLower = appName.lowercased()
            
            if identifiers.contains(where: { currentLower.contains($0) || nameLower.contains($0) }) {
                matched = profile
                break
            }
        }
        
        self.activeProfile = matched
        onProfileChanged?(matched, isFullScreen)
    }
    
    private func isAppFullScreen(app: NSRunningApplication) -> Bool {
        // Method 1: Check window list on current screen
        guard let screen = NSScreen.main else { return false }
        let screenRect = screen.frame
        
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        
        for win in windowInfoList {
            guard let pid = win[kCGWindowOwnerPID as String] as? pid_t, pid == app.processIdentifier else { continue }
            guard let boundsDict = win[kCGWindowBounds as String] as? [String: Any],
                  let winRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            
            // Check if window matches or exceeds full screen size (covering menu bar / dock)
            if winRect.width >= screenRect.width - 2 && winRect.height >= screenRect.height - 2 {
                return true
            }
        }
        
        return false
    }
}
