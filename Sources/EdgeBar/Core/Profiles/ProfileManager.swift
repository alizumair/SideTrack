import Foundation
import AppKit

public final class ProfileManager: ObservableObject {
    public static let shared = ProfileManager()
    
    @Published public private(set) var activeProfile: AppProfile?
    @Published public private(set) var isGameModeActive: Bool = false
    @Published public private(set) var frontmostAppName: String = ""
    @Published public private(set) var frontmostBundleID: String = ""
    @Published public private(set) var frontmostWindowTitle: String = ""
    
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
        let windowTitle = getFrontmostWindowTitle(for: app.processIdentifier)
        
        self.frontmostBundleID = bundleID
        self.frontmostAppName = appName
        self.frontmostWindowTitle = windowTitle
        
        let currentLower = bundleID.lowercased()
        let nameLower = appName.lowercased()
        let titleLower = windowTitle.lowercased()
        
        let streamingKeywords = [
            "netflix", "youtube", "disney", "prime video", "primevideo",
            "hulu", "twitch", "max", "hbomax", "apple tv", "appletv",
            "quicktime", "iina", "vlc", "infuse", "plex", "stremio"
        ]
        
        let browserBundleIDs = [
            "com.apple.safari", "com.google.chrome", "org.mozilla.firefox",
            "company.thebrowser.browser", "com.brave.browser", "com.microsoft.edgemac",
            "com.kagi.kagimacos", "com.operasoftware.opera", "com.vivaldi.vivaldi"
        ]
        let browserNames = [
            "safari", "google chrome", "chrome", "firefox", "brave",
            "brave browser", "microsoft edge", "arc", "orion", "opera", "vivaldi"
        ]
        let isBrowser = browserBundleIDs.contains(where: { currentLower == $0 || currentLower.hasPrefix($0) })
            || browserNames.contains(where: { nameLower == $0 })
        
        let isStreaming = streamingKeywords.contains(where: {
            currentLower.contains($0) || nameLower.contains($0) || titleLower.contains($0)
        })
        
        var matched: AppProfile? = nil
        
        // 1. Dedicated Streaming & Video (YouTube, Netflix, Prime Video, QuickTime, VLC, IINA, etc.)
        if isStreaming {
            matched = settings.profiles.first(where: { $0.isEnabled && ($0.bottomScrubMode == .videoSeek || $0.name.lowercased().contains("streaming") || $0.name.lowercased().contains("video")) })
            if matched == nil {
                matched = AppProfile(
                    name: "Streaming & Video",
                    bundleIdentifier: bundleID,
                    bottomEdgeAction: .videoSeek,
                    bottomScrubMode: .videoSeek
                )
            }
        } else if isBrowser {
            // 2. Web Browsers Profile (switch tabs when browsing regular web pages)
            matched = settings.profiles.first(where: { $0.isEnabled && ($0.bottomScrubMode == .tabSwitch || $0.name.lowercased().contains("browser")) })
            if matched == nil {
                matched = AppProfile(
                    name: "Web Browsers",
                    bundleIdentifier: bundleID,
                    bottomEdgeAction: .tabSwitch,
                    bottomScrubMode: .tabSwitch
                )
            }
        } else {
            // 3. Match custom user-defined profiles by bundle identifier or title
            for profile in settings.profiles where profile.isEnabled {
                let identifiers = profile.bundleIdentifier
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                
                let matches = identifiers.contains { id in
                    guard !id.isEmpty else { return false }
                    return currentLower.contains(id) || nameLower.contains(id) || titleLower.contains(id)
                }
                
                if matches {
                    matched = profile
                    break
                }
            }
        }
        
        NSLog("[EdgeBar] evaluateFrontmostApp: app=%@, isBrowser=%d, profile=%@, scrubMode=%@",
              bundleID, isBrowser ? 1 : 0, matched?.name ?? "none", matched?.bottomScrubMode.rawValue ?? "none")
        
        // Check Full-Screen / Game Mode bypass:
        // Never bypass when watching video, switching tabs in browser, or editing timelines!
        var isFullScreen = false
        let isProtected = isStreaming || isBrowser || (matched?.bottomScrubMode == .timelineScrub)
        if settings.gameModeEnabled && !isProtected {
            isFullScreen = isAppFullScreen(app: app)
        }
        self.isGameModeActive = isFullScreen
        
        self.activeProfile = matched
        onProfileChanged?(matched, isFullScreen)
    }
    
    private func getActiveBrowserMediaContext(bundleID: String) -> String {
        let bLower = bundleID.lowercased()
        if bLower.contains("chrome") {
            let script = "tell application \"Google Chrome\" to get URL of active tab of front window"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                if let url = appleScript.executeAndReturnError(&error).stringValue {
                    return url
                }
            }
        } else if bLower.contains("safari") {
            let script = "tell application \"Safari\" to get URL of current tab of front window"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                if let url = appleScript.executeAndReturnError(&error).stringValue {
                    return url
                }
            }
        }
        return ""
    }
    
    private func getFrontmostWindowTitle(for pid: pid_t) -> String {
        // 1. Accessibility API (fast, works in macOS Sequoia without screen capture prompt)
        let axApp = AXUIElementCreateApplication(pid)
        var focusedWindow: AnyObject?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let win = focusedWindow {
            var titleVal: AnyObject?
            if AXUIElementCopyAttributeValue(win as! AXUIElement, kAXTitleAttribute as CFString, &titleVal) == .success,
               let titleStr = titleVal as? String, !titleStr.isEmpty {
                return titleStr
            }
        }
        
        // 2. Fallback via CGWindowListCopyWindowInfo
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return ""
        }
        for win in windowInfoList {
            guard let ownerPID = win[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid else { continue }
            if let layer = win[kCGWindowLayer as String] as? Int, layer != 0 { continue }
            if let title = win[kCGWindowName as String] as? String, !title.isEmpty {
                return title
            }
        }
        return ""
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
