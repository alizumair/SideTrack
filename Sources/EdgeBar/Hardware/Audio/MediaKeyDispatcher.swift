import Foundation
import AppKit
import ApplicationServices

public enum MediaKey: Int32 {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
    case playPause = 16
    case nextTrack = 17
    case previousTrack = 18
    case fastForward = 19
    case rewind = 20
    case illuminationUp = 21
    case illuminationDown = 22
}

public final class MediaKeyDispatcher {
    public static let shared = MediaKeyDispatcher()
    
    private typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int32, AnyObject?) -> DarwinBoolean
    private var sendMediaRemoteCommand: MRMediaRemoteSendCommandFunction?
    
    private init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) {
            if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
                sendMediaRemoteCommand = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFunction.self)
            }
        }
    }
    
    public func playPause() {
        if let sendMR = sendMediaRemoteCommand {
            _ = sendMR(2, nil) // kMRTogglePlayPause = 2
        }
        postKey(MediaKey.playPause.rawValue, down: true)
        postKey(MediaKey.playPause.rawValue, down: false)
    }
    
    public func nextTrack() {
        if let sendMR = sendMediaRemoteCommand {
            _ = sendMR(4, nil) // kMRNextTrack = 4
        }
        postKey(MediaKey.nextTrack.rawValue, down: true)
        postKey(MediaKey.nextTrack.rawValue, down: false)
    }
    
    public func previousTrack() {
        if let sendMR = sendMediaRemoteCommand {
            _ = sendMR(5, nil) // kMRPreviousTrack = 5
        }
        postKey(MediaKey.previousTrack.rawValue, down: true)
        postKey(MediaKey.previousTrack.rawValue, down: false)
    }
    
    public func volumeUp() {
        postKey(MediaKey.soundUp.rawValue, down: true)
        postKey(MediaKey.soundUp.rawValue, down: false)
    }
    
    public func volumeDown() {
        postKey(MediaKey.soundDown.rawValue, down: true)
        postKey(MediaKey.soundDown.rawValue, down: false)
    }
    
    public func brightnessUp() {
        postKey(MediaKey.brightnessUp.rawValue, down: true)
        postKey(MediaKey.brightnessUp.rawValue, down: false)
    }
    
    public func brightnessDown() {
        postKey(MediaKey.brightnessDown.rawValue, down: true)
        postKey(MediaKey.brightnessDown.rawValue, down: false)
    }
    
    public func keyboardBrightnessUp() {
        postKey(MediaKey.illuminationUp.rawValue, down: true)
        postKey(MediaKey.illuminationUp.rawValue, down: false)
    }
    
    public func keyboardBrightnessDown() {
        postKey(MediaKey.illuminationDown.rawValue, down: true)
        postKey(MediaKey.illuminationDown.rawValue, down: false)
    }
    
    public func stepTimeline(forward: Bool) {
        // Virtual key 124 is Right Arrow, 123 is Left Arrow
        let key: CGKeyCode = forward ? 124 : 123
        let source = CGEventSource(stateID: .hidSystemState)
        if let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
           let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }
    
    public func seekVideo(forward: Bool) {
        let key: CGKeyCode = forward ? 124 : 123
        let source = CGEventSource(stateID: .hidSystemState)
        let targetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        
        EdgeBarLogger.log("seekVideo: forward=\(forward), targetPID=\(targetPID ?? 0)")
        NSLog("[EdgeBar] seekVideo called: forward=%d, targetPID=%d", forward ? 1 : 0, targetPID ?? 0)
        
        // 1. Send via System Events through osascript (bypasses accessibility permission barriers)
        let keyCodeNum = forward ? 124 : 123
        runOsaScriptAsync("tell application \"System Events\" to key code \(keyCodeNum)")
        
        // 2. Also dispatch via CGEvent to target PID and HID taps
        if let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true) {
            if let pid = targetPID { down.postToPid(pid) }
            down.post(tap: .cgSessionEventTap)
            down.post(tap: .cghidEventTap)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) {
            let upSource = CGEventSource(stateID: .hidSystemState)
            if let up = CGEvent(keyboardEventSource: upSource, virtualKey: key, keyDown: false) {
                if let pid = targetPID { up.postToPid(pid) }
                up.post(tap: .cgSessionEventTap)
                up.post(tap: .cghidEventTap)
            }
        }
    }
    
    public func switchTab(next: Bool) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            EdgeBarLogger.log("switchTab failed: frontmostApplication is nil")
            return
        }
        let pid = app.processIdentifier
        let bundleID = app.bundleIdentifier?.lowercased() ?? ""
        let name = app.localizedName?.lowercased() ?? ""
        
        EdgeBarLogger.log("switchTab requested: next=\(next), app=\(bundleID), name=\(name), pid=\(pid)")
        NSLog("[EdgeBar] switchTab called: next=%d, app=%@, pid=%d", next ? 1 : 0, bundleID, pid)
        
        // Method 1: Google Chrome (Direct application script via /usr/bin/osascript)
        if bundleID.contains("chrome") || name.contains("chrome") {
            let script: String
            if next {
                script = """
                tell application "Google Chrome" to tell front window
                    set cur to active tab index
                    set cnt to count of tabs
                    if cur >= cnt then
                        set active tab index to 1
                    else
                        set active tab index to (cur + 1)
                    end if
                end tell
                """
            } else {
                script = """
                tell application "Google Chrome" to tell front window
                    set cur to active tab index
                    set cnt to count of tabs
                    if cur <= 1 then
                        set active tab index to cnt
                    else
                        set active tab index to (cur - 1)
                    end if
                end tell
                """
            }
            runOsaScriptAsync(script)
            return
        }
        
        // Method 2: Safari (Direct application script via /usr/bin/osascript)
        if bundleID.contains("safari") || name.contains("safari") {
            let script: String
            if next {
                script = """
                tell application "Safari" to tell front window
                    set cur to index of current tab
                    set cnt to count of tabs
                    if cur >= cnt then
                        set current tab to tab 1
                    else
                        set current tab to tab (cur + 1)
                    end if
                end tell
                """
            } else {
                script = """
                tell application "Safari" to tell front window
                    set cur to index of current tab
                    set cnt to count of tabs
                    if cur <= 1 then
                        set current tab to tab cnt
                    else
                        set current tab to tab (cur - 1)
                    end if
                end tell
                """
            }
            runOsaScriptAsync(script)
            return
        }
        
        // Method 3: Brave Browser
        if bundleID.contains("brave") || name.contains("brave") {
            let script: String
            if next {
                script = """
                tell application "Brave Browser" to tell front window
                    set cur to active tab index
                    set cnt to count of tabs
                    if cur >= cnt then
                        set active tab index to 1
                    else
                        set active tab index to (cur + 1)
                    end if
                end tell
                """
            } else {
                script = """
                tell application "Brave Browser" to tell front window
                    set cur to active tab index
                    set cnt to count of tabs
                    if cur <= 1 then
                        set active tab index to cnt
                    else
                        set active tab index to (cur - 1)
                    end if
                end tell
                """
            }
            runOsaScriptAsync(script)
            return
        }
        
        // Method 4: Microsoft Edge
        if bundleID.contains("edgemac") || bundleID.contains("edge") || name.contains("edge") {
            let script: String
            if next {
                script = """
                tell application "Microsoft Edge" to tell front window
                    set cur to active tab index
                    set cnt to count of tabs
                    if cur >= cnt then
                        set active tab index to 1
                    else
                        set active tab index to (cur + 1)
                    end if
                end tell
                """
            } else {
                script = """
                tell application "Microsoft Edge" to tell front window
                    set cur to active tab index
                    set cnt to count of tabs
                    if cur <= 1 then
                        set active tab index to cnt
                    else
                        set active tab index to (cur - 1)
                    end if
                end tell
                """
            }
            runOsaScriptAsync(script)
            return
        }
        
        // Method 5: Universal Fallback for Arc, Firefox, Orion, Opera, Vivaldi & all other apps
        let targetItem = next ? "Select Next Tab" : "Select Previous Tab"
        let fallbackItem = next ? "Show Next Tab" : "Show Previous Tab"
        let thirdItem = next ? "Next Tab" : "Previous Tab"
        let keyModifier = next ? "control down" : "{control down, shift down}"
        
        let universalScript = """
        tell application "System Events"
            set frontApp to first application process whose frontmost is true
            try
                tell frontApp to tell menu bar 1 to tell menu "Tab"
                    click menu item "\(targetItem)"
                end tell
            on error
                try
                    tell frontApp to tell menu bar 1 to tell menu "Window"
                        click menu item "\(fallbackItem)"
                    end tell
                on error
                    try
                        tell frontApp to tell menu bar 1 to tell menu "Window"
                            click menu item "\(thirdItem)"
                        end tell
                    on error
                        key code 48 using \(keyModifier)
                    end try
                end try
            end try
        end tell
        """
        runOsaScriptAsync(universalScript)
    }
    
    private func runOsaScriptAsync(_ script: String) {
        DispatchQueue.global(qos: .userInteractive).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", script]
            do {
                try proc.run()
                proc.waitUntilExit()
                EdgeBarLogger.log("runOsaScriptAsync completed with exit=\(proc.terminationStatus)")
            } catch {
                EdgeBarLogger.log("runOsaScriptAsync execution error: \(error)")
            }
        }
    }
    
    @discardableResult
    private func triggerMenuAction(pid: pid_t, targetTitles: [String]) -> Bool {
        let axApp = AXUIElementCreateApplication(pid)
        var menuBarRef: AnyObject?
        let err1 = AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBarRef)
        guard err1 == .success, let mb = menuBarRef else {
            EdgeBarLogger.log("triggerMenuAction: kAXMenuBarAttribute failed with err=\(err1.rawValue) for pid=\(pid)")
            return false
        }
        
        var menuBarItemsRef: AnyObject?
        let err2 = AXUIElementCopyAttributeValue(mb as! AXUIElement, kAXChildrenAttribute as CFString, &menuBarItemsRef)
        guard err2 == .success, let topMenus = menuBarItemsRef as? [AXUIElement] else {
            EdgeBarLogger.log("triggerMenuAction: topMenus failed with err=\(err2.rawValue) for pid=\(pid)")
            return false
        }
        
        let targetsLower = targetTitles.map { $0.lowercased() }
        
        for topMenu in topMenus {
            var subMenuRef: AnyObject?
            guard AXUIElementCopyAttributeValue(topMenu, kAXChildrenAttribute as CFString, &subMenuRef) == .success,
                  let subMenus = subMenuRef as? [AXUIElement], let menu = subMenus.first else { continue }
            
            var itemsRef: AnyObject?
            guard AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &itemsRef) == .success,
                  let items = itemsRef as? [AXUIElement] else { continue }
            
            for item in items {
                var titleVal: AnyObject?
                if AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleVal) == .success,
                   let title = titleVal as? String {
                    if targetsLower.contains(title.lowercased()) {
                        let err = AXUIElementPerformAction(item, kAXPressAction as CFString)
                        EdgeBarLogger.log("triggerMenuAction: pressed '\(title)', result=\(err.rawValue)")
                        return err == .success
                    }
                }
            }
        }
        EdgeBarLogger.log("triggerMenuAction: none of \(targetTitles) found in menu items for pid=\(pid)")
        return false
    }
    
    public func scrollPage(up: Bool, deltaLines: Int32 = 3) {
        let delta = up ? deltaLines : -deltaLines
        if let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: delta, wheel2: 0, wheel3: 0) {
            scroll.post(tap: .cghidEventTap)
        }
    }
    
    private func postKey(_ keyCode: Int32, down: Bool) {
        let stateFlag: Int = down ? 0xa00 : 0xb00
        let flags = NSEvent.ModifierFlags(rawValue: UInt(stateFlag))
        let data1 = Int((keyCode << 16) | Int32(stateFlag))
        
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        
        if let cgEvent = event?.cgEvent {
            cgEvent.post(tap: .cghidEventTap)
        }
    }
}
