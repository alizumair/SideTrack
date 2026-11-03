import Foundation

public enum EdgeAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case brightness = "Display Brightness"
    case volume = "System Volume"
    case keyboardBrightness = "Keyboard Backlight"
    case micGain = "Microphone Gain"
    case tabSwitch = "Switch Tabs"
    case videoSeek = "Forward / Rewind Video"
    case mediaTrack = "Media Track Skip"
    case scroll = "Page Scroll"
    case timelineScrub = "Timeline Frame Scrub"
    case disabled = "Disabled"
    
    public var id: String { rawValue }
}

public enum CornerAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case toggleMute = "Toggle Mute"
    case playPause = "Play / Pause"
    case maxBrightness = "Max Brightness"
    case screenshot = "Take Screenshot"
    case screenRecording = "Screen Recording"
    case runCustomScript = "Run Custom Script"
    case disabled = "Disabled"
    
    public var id: String { rawValue }
}

public enum HUDStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case minimalPill = "Minimalist Edge Pill"
    case liquidGlass = "Native Liquid Glass"
    
    public var id: String { rawValue }
}

public enum ScriptTriggerType: String, Codable, CaseIterable, Identifiable, Sendable {
    case shortcut = "macOS Shortcut"
    case appleScript = "AppleScript"
    case shell = "Shell Command (zsh)"
    
    public var id: String { rawValue }
}

public struct CustomScriptTrigger: Codable, Equatable, Sendable {
    public var type: ScriptTriggerType = .shortcut
    public var payload: String = ""
    
    public init(type: ScriptTriggerType = .shortcut, payload: String = "") {
        self.type = type
        self.payload = payload
    }
}

public enum BottomScrubMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case tabSwitch = "Switch Browser Tabs"
    case videoSeek = "Forward / Rewind Video"
    case timelineScrub = "Timeline Frame Scrub"
    case mediaTrack = "Media Track Skip"
    case pageScroll = "Page Scroll"
    
    public var id: String { rawValue }
}

public struct AppProfile: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var bundleIdentifier: String
    public var isEnabled: Bool = true
    
    public var leftEdgeAction: EdgeAction?
    public var rightEdgeAction: EdgeAction?
    public var bottomEdgeAction: EdgeAction?
    public var topRightCornerAction: CornerAction?
    public var bottomDoubleTapAction: CornerAction?
    public var bottomScrubMode: BottomScrubMode = .mediaTrack
    
    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        isEnabled: Bool = true,
        leftEdgeAction: EdgeAction? = nil,
        rightEdgeAction: EdgeAction? = nil,
        bottomEdgeAction: EdgeAction? = nil,
        topRightCornerAction: CornerAction? = nil,
        bottomDoubleTapAction: CornerAction? = nil,
        bottomScrubMode: BottomScrubMode = .mediaTrack
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isEnabled = isEnabled
        self.leftEdgeAction = leftEdgeAction
        self.rightEdgeAction = rightEdgeAction
        self.bottomEdgeAction = bottomEdgeAction
        self.topRightCornerAction = topRightCornerAction
        self.bottomDoubleTapAction = bottomDoubleTapAction
        self.bottomScrubMode = bottomScrubMode
    }
}

public struct SettingsModel: Codable, Equatable, Sendable {
    public static let currentVersion = 4
    public static let storageKey = "io.github.edgebar.settings.v1"
    
    public var version: Int = SettingsModel.currentVersion
    public var isEnabled: Bool = true
    
    // Granular Edge Dimensions (individual for each of the 4 borders)
    public var leftEdgeWidthFraction: Double = 0.10     // 10% outer left strip
    public var rightEdgeWidthFraction: Double = 0.10    // 10% outer right strip
    public var bottomEdgeHeightFraction: Double = 0.10  // 10% outer bottom strip
    public var topEdgeHeightFraction: Double = 0.10     // 10% outer top strip
    public var cornerZoneFraction: Double = 0.10        // 10% corner box
    
    // Backward-compatibility bridges for existing accessors
    public var edgeWidthFraction: Double {
        get { leftEdgeWidthFraction }
        set {
            leftEdgeWidthFraction = newValue
            rightEdgeWidthFraction = newValue
        }
    }
    public var edgeHeightFraction: Double {
        get { bottomEdgeHeightFraction }
        set {
            bottomEdgeHeightFraction = newValue
            topEdgeHeightFraction = newValue
        }
    }
    
    // Default Global Actions
    public var leftEdgeAction: EdgeAction = .brightness
    public var rightEdgeAction: EdgeAction = .volume
    public var bottomEdgeAction: EdgeAction = .mediaTrack
    public var topRightCornerAction: CornerAction = .toggleMute
    public var bottomDoubleTapAction: CornerAction = .playPause
    
    // Feel, Haptics & Audio
    public var sensitivity: Double = 1.0
    public var invertVerticalAxis: Bool = false
    public var cursorFreezingEnabled: Bool = true
    public var hapticsEnabled: Bool = true
    public var audioFeedbackEnabled: Bool = true       // Subtle mechanical audio click
    public var hapticSteps: Int = 64                   // 64 Steps (Ultra-Smooth)
    public var precisionMultiplier: Double = 0.25      // Quarter-step with ⇧⌥
    
    // Visual Feedback & HUD Style
    public var hudStyle: HUDStyle = .minimalPill       // Minimalist compact edge pill by default
    public var showMenuBarIcon: Bool = true
    public var showHUDOverlay: Bool = true
    public var useSystemOSD: Bool = true
    public var doubleTapMaxInterval: Double = 0.35
    public var maxTapMovementThreshold: Double = 0.015 // Tight tap boundary (~1.5mm)
    
    // Corner Hold Macros
    public var cornerHoldsEnabled: Bool = true
    public var cornerHoldFraction: Double = 0.15       // 15% outer corner zones
    public var screenshotHoldDuration: Double = 1.5    // Left corners (Top-Left / Bottom-Left)
    public var screenRecordingHoldDuration: Double = 3.0 // Bottom-Right corner
    
    // Scripting & Custom Triggers
    public var customScriptTrigger: CustomScriptTrigger = CustomScriptTrigger(type: .shortcut, payload: "")
    
    // App-Specific Context Profiles & Game Mode
    public var gameModeEnabled: Bool = true             // Disable gestures in full-screen games / apps
    public var profiles: [AppProfile] = [
        AppProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            name: "Streaming & Video",
            bundleIdentifier: "netflix, disney, prime video, primevideo, youtube, hulu, twitch, max, apple tv, com.apple.TV, com.apple.QuickTimePlayerX, com.colliderli.iina, org.videolan.vlc, com.amazon.aiv.AIVApp, com.firecore.infuse, tv.plex.desktop, com.stremio.stremio",
            bottomEdgeAction: .videoSeek,
            bottomScrubMode: .videoSeek
        ),
        AppProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
            name: "Web Browsers",
            bundleIdentifier: "com.apple.Safari, com.google.Chrome, company.thebrowser.Browser, com.brave.Browser, org.mozilla.firefox, com.microsoft.edgemac, com.kagi.kagimacOS, com.operasoftware.Opera, com.vivaldi.Vivaldi",
            bottomEdgeAction: .tabSwitch,
            bottomScrubMode: .tabSwitch
        ),
        AppProfile(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID(),
            name: "Video Editors",
            bundleIdentifier: "com.apple.FinalCut, com.adobe.PremierePro, com.blackmagic-design.DaVinciResolve",
            bottomEdgeAction: .timelineScrub,
            bottomScrubMode: .timelineScrub
        )
    ]
    
    // General
    public var launchAtLogin: Bool = false
    
    public init() {}
    
    public static var `default`: SettingsModel {
        SettingsModel()
    }
}
