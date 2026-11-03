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

public enum CornerHoldAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case screenshot = "Take Screenshot"
    case screenRecording = "Screen Recording"
    case toggleMute = "Toggle Mute"
    case playPause = "Play / Pause"
    case lockScreen = "Lock Screen"
    case customScript = "Run Custom Script"
    case disabled = "Disabled"
    
    public var id: String { rawValue }
}

public enum ScreenshotMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case systemGiven = "Full Screen"
    case interactive = "Crop Screen (Area Selection)"
    case systemApp = "macOS Screenshot Tool (Cmd+Shift+5)"
    case clipboard = "Silent to Clipboard"
    
    public var id: String { rawValue }
}

public enum ScreenRecordingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case fullScreenWithStopButton = "Full Screen (with Stop Button)"
    case cropScreenWithStopButton = "Crop Screen (with Stop Button)"
    case systemToolbar = "macOS Recording Tool (Cmd+Shift+5)"
    
    public var id: String { rawValue }
}

public enum HUDStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case minimalPill = "Minimalist Edge Pill"
    case liquidGlass = "Native Liquid Glass"
    
    public var id: String { rawValue }
}

public enum SliderActivationStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case instant = "Instant (Fast Response)"
    case holdToEngage = "Hold to Engage (Micro-Dwell)"
    
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
    public static let currentVersion = 11
    public static let storageKey = "io.github.edgebar.settings.v1"
    
    public var version: Int = SettingsModel.currentVersion
    public var isEnabled: Bool = true
    
    // Granular Edge Dimensions (individual for each of the 4 borders)
    public var leftEdgeWidthFraction: Double = 0.10     // 10% outer left strip
    public var rightEdgeWidthFraction: Double = 0.10    // 10% outer right strip
    public var bottomEdgeHeightFraction: Double = 0.16  // 16% outer bottom strip (comfortable thumb landing zone)
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
    public var tabSwitchSensitivity: Double = 0.5      // Calmer tab switching (0.2...2.0)
    public var sliderActivationStyle: SliderActivationStyle = .instant
    public var sliderHoldDwellDuration: Double = 0.20  // Micro-dwell hold time (0.10s ... 0.80s)
    public var invertVerticalAxis: Bool = false
    public var cursorFreezingEnabled: Bool = true
    public var hapticsEnabled: Bool = true
    public var audioFeedbackEnabled: Bool = false      // Disabled by default (silent sliding)
    public var hapticSteps: Int = 64                   // 64 Steps (Ultra-Smooth)
    public var precisionMultiplier: Double = 0.25      // Quarter-step with ⇧⌥
    
    // Visual Feedback & HUD Style
    public var hudStyle: HUDStyle = .minimalPill       // Minimalist compact edge pill by default
    public var showMenuBarIcon: Bool = true
    public var showHUDOverlay: Bool = true
    public var useSystemOSD: Bool = true
    public var doubleTapMaxInterval: Double = 0.35
    public var maxTapMovementThreshold: Double = 0.015 // Tight tap boundary (~1.5mm)
    
    // Corner Hold Macros & Gestures
    public var cornerHoldsEnabled: Bool = true
    public var cornerHoldFraction: Double = 0.15          // 15% outer corner zones
    public var showHoldCountdownTimer: Bool = true         // 1 2 3 visual countdown HUD
    public var bottomLeftHoldAction: CornerHoldAction = .screenshot
    public var bottomRightHoldAction: CornerHoldAction = .screenRecording
    public var topLeftHoldAction: CornerHoldAction = .screenshot
    public var screenshotMode: ScreenshotMode = .interactive
    public var recordingMode: ScreenRecordingMode = .cropScreenWithStopButton
    public var screenshotHoldDuration: Double = 1.5       // Left corners (Top-Left / Bottom-Left)
    public var screenRecordingHoldDuration: Double = 3.0   // Bottom-Right corner
    
    // Save Destination for Screenshots & Screen Recordings
    public var customMediaSaveDirectory: String = ""       // Empty string means system default (e.g. ~/Documents or ~/Desktop)
    
    // Scripting & Custom Triggers
    public var customScriptTrigger: CustomScriptTrigger = CustomScriptTrigger(type: .shortcut, payload: "")
    
    // App-Specific Context Profiles & Game Mode
    public var gameModeEnabled: Bool = false            // Full-screen bypass (disabled by default so video & browsing work uninterrupted)
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
    
    private enum CodingKeys: String, CodingKey {
        case version, isEnabled
        case leftEdgeWidthFraction, rightEdgeWidthFraction, bottomEdgeHeightFraction, topEdgeHeightFraction, cornerZoneFraction
        case edgeWidthFraction, edgeHeightFraction
        case leftEdgeAction, rightEdgeAction, bottomEdgeAction, topRightCornerAction, bottomDoubleTapAction
        case sensitivity, tabSwitchSensitivity, sliderActivationStyle, sliderHoldDwellDuration, invertVerticalAxis, cursorFreezingEnabled, hapticsEnabled, audioFeedbackEnabled, hapticSteps, precisionMultiplier
        case hudStyle, showMenuBarIcon, showHUDOverlay, useSystemOSD, doubleTapMaxInterval, maxTapMovementThreshold
        case cornerHoldsEnabled, cornerHoldFraction, showHoldCountdownTimer
        case bottomLeftHoldAction, bottomRightHoldAction, topLeftHoldAction, screenshotMode, recordingMode
        case screenshotHoldDuration, screenRecordingHoldDuration, customMediaSaveDirectory
        case customScriptTrigger, gameModeEnabled, profiles, launchAtLogin
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        
        let legacyW = try container.decodeIfPresent(Double.self, forKey: .edgeWidthFraction) ?? 0.10
        let legacyH = try container.decodeIfPresent(Double.self, forKey: .edgeHeightFraction) ?? 0.12
        
        self.leftEdgeWidthFraction = try container.decodeIfPresent(Double.self, forKey: .leftEdgeWidthFraction) ?? legacyW
        self.rightEdgeWidthFraction = try container.decodeIfPresent(Double.self, forKey: .rightEdgeWidthFraction) ?? legacyW
        self.bottomEdgeHeightFraction = try container.decodeIfPresent(Double.self, forKey: .bottomEdgeHeightFraction) ?? max(legacyH, 0.12)
        self.topEdgeHeightFraction = try container.decodeIfPresent(Double.self, forKey: .topEdgeHeightFraction) ?? legacyH
        self.cornerZoneFraction = try container.decodeIfPresent(Double.self, forKey: .cornerZoneFraction) ?? 0.10
        
        self.leftEdgeAction = try container.decodeIfPresent(EdgeAction.self, forKey: .leftEdgeAction) ?? .brightness
        self.rightEdgeAction = try container.decodeIfPresent(EdgeAction.self, forKey: .rightEdgeAction) ?? .volume
        self.bottomEdgeAction = try container.decodeIfPresent(EdgeAction.self, forKey: .bottomEdgeAction) ?? .mediaTrack
        self.topRightCornerAction = try container.decodeIfPresent(CornerAction.self, forKey: .topRightCornerAction) ?? .toggleMute
        self.bottomDoubleTapAction = try container.decodeIfPresent(CornerAction.self, forKey: .bottomDoubleTapAction) ?? .playPause
        
        self.sensitivity = try container.decodeIfPresent(Double.self, forKey: .sensitivity) ?? 1.0
        self.tabSwitchSensitivity = try container.decodeIfPresent(Double.self, forKey: .tabSwitchSensitivity) ?? 0.5
        self.sliderActivationStyle = try container.decodeIfPresent(SliderActivationStyle.self, forKey: .sliderActivationStyle) ?? .instant
        self.sliderHoldDwellDuration = try container.decodeIfPresent(Double.self, forKey: .sliderHoldDwellDuration) ?? 0.20
        self.invertVerticalAxis = try container.decodeIfPresent(Bool.self, forKey: .invertVerticalAxis) ?? false
        self.cursorFreezingEnabled = try container.decodeIfPresent(Bool.self, forKey: .cursorFreezingEnabled) ?? true
        self.hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        self.audioFeedbackEnabled = try container.decodeIfPresent(Bool.self, forKey: .audioFeedbackEnabled) ?? false
        self.hapticSteps = try container.decodeIfPresent(Int.self, forKey: .hapticSteps) ?? 64
        self.precisionMultiplier = try container.decodeIfPresent(Double.self, forKey: .precisionMultiplier) ?? 0.25
        
        self.hudStyle = try container.decodeIfPresent(HUDStyle.self, forKey: .hudStyle) ?? .minimalPill
        self.showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        self.showHUDOverlay = try container.decodeIfPresent(Bool.self, forKey: .showHUDOverlay) ?? true
        self.useSystemOSD = try container.decodeIfPresent(Bool.self, forKey: .useSystemOSD) ?? true
        self.doubleTapMaxInterval = try container.decodeIfPresent(Double.self, forKey: .doubleTapMaxInterval) ?? 0.35
        self.maxTapMovementThreshold = try container.decodeIfPresent(Double.self, forKey: .maxTapMovementThreshold) ?? 0.015
        
        self.cornerHoldsEnabled = try container.decodeIfPresent(Bool.self, forKey: .cornerHoldsEnabled) ?? true
        self.cornerHoldFraction = try container.decodeIfPresent(Double.self, forKey: .cornerHoldFraction) ?? 0.15
        self.showHoldCountdownTimer = try container.decodeIfPresent(Bool.self, forKey: .showHoldCountdownTimer) ?? true
        self.bottomLeftHoldAction = try container.decodeIfPresent(CornerHoldAction.self, forKey: .bottomLeftHoldAction) ?? .screenshot
        self.bottomRightHoldAction = try container.decodeIfPresent(CornerHoldAction.self, forKey: .bottomRightHoldAction) ?? .screenRecording
        self.topLeftHoldAction = try container.decodeIfPresent(CornerHoldAction.self, forKey: .topLeftHoldAction) ?? .screenshot
        self.screenshotMode = try container.decodeIfPresent(ScreenshotMode.self, forKey: .screenshotMode) ?? .interactive
        self.recordingMode = try container.decodeIfPresent(ScreenRecordingMode.self, forKey: .recordingMode) ?? .cropScreenWithStopButton
        self.screenshotHoldDuration = try container.decodeIfPresent(Double.self, forKey: .screenshotHoldDuration) ?? 1.5
        self.screenRecordingHoldDuration = try container.decodeIfPresent(Double.self, forKey: .screenRecordingHoldDuration) ?? 3.0
        self.customMediaSaveDirectory = try container.decodeIfPresent(String.self, forKey: .customMediaSaveDirectory) ?? ""
        
        self.customScriptTrigger = try container.decodeIfPresent(CustomScriptTrigger.self, forKey: .customScriptTrigger) ?? CustomScriptTrigger(type: .shortcut, payload: "")
        self.gameModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .gameModeEnabled) ?? true
        self.profiles = try container.decodeIfPresent([AppProfile].self, forKey: .profiles) ?? SettingsModel.default.profiles
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(leftEdgeWidthFraction, forKey: .leftEdgeWidthFraction)
        try container.encode(rightEdgeWidthFraction, forKey: .rightEdgeWidthFraction)
        try container.encode(bottomEdgeHeightFraction, forKey: .bottomEdgeHeightFraction)
        try container.encode(topEdgeHeightFraction, forKey: .topEdgeHeightFraction)
        try container.encode(cornerZoneFraction, forKey: .cornerZoneFraction)
        try container.encode(leftEdgeAction, forKey: .leftEdgeAction)
        try container.encode(rightEdgeAction, forKey: .rightEdgeAction)
        try container.encode(bottomEdgeAction, forKey: .bottomEdgeAction)
        try container.encode(topRightCornerAction, forKey: .topRightCornerAction)
        try container.encode(bottomDoubleTapAction, forKey: .bottomDoubleTapAction)
        try container.encode(sensitivity, forKey: .sensitivity)
        try container.encode(tabSwitchSensitivity, forKey: .tabSwitchSensitivity)
        try container.encode(sliderActivationStyle, forKey: .sliderActivationStyle)
        try container.encode(sliderHoldDwellDuration, forKey: .sliderHoldDwellDuration)
        try container.encode(invertVerticalAxis, forKey: .invertVerticalAxis)
        try container.encode(cursorFreezingEnabled, forKey: .cursorFreezingEnabled)
        try container.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try container.encode(audioFeedbackEnabled, forKey: .audioFeedbackEnabled)
        try container.encode(hapticSteps, forKey: .hapticSteps)
        try container.encode(precisionMultiplier, forKey: .precisionMultiplier)
        try container.encode(hudStyle, forKey: .hudStyle)
        try container.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try container.encode(showHUDOverlay, forKey: .showHUDOverlay)
        try container.encode(useSystemOSD, forKey: .useSystemOSD)
        try container.encode(doubleTapMaxInterval, forKey: .doubleTapMaxInterval)
        try container.encode(maxTapMovementThreshold, forKey: .maxTapMovementThreshold)
        try container.encode(cornerHoldsEnabled, forKey: .cornerHoldsEnabled)
        try container.encode(cornerHoldFraction, forKey: .cornerHoldFraction)
        try container.encode(showHoldCountdownTimer, forKey: .showHoldCountdownTimer)
        try container.encode(bottomLeftHoldAction, forKey: .bottomLeftHoldAction)
        try container.encode(bottomRightHoldAction, forKey: .bottomRightHoldAction)
        try container.encode(topLeftHoldAction, forKey: .topLeftHoldAction)
        try container.encode(screenshotMode, forKey: .screenshotMode)
        try container.encode(recordingMode, forKey: .recordingMode)
        try container.encode(screenshotHoldDuration, forKey: .screenshotHoldDuration)
        try container.encode(screenRecordingHoldDuration, forKey: .screenRecordingHoldDuration)
        try container.encode(customMediaSaveDirectory, forKey: .customMediaSaveDirectory)
        try container.encode(customScriptTrigger, forKey: .customScriptTrigger)
        try container.encode(gameModeEnabled, forKey: .gameModeEnabled)
        try container.encode(profiles, forKey: .profiles)
        try container.encode(launchAtLogin, forKey: .launchAtLogin)
    }
    
    public static var `default`: SettingsModel {
        SettingsModel()
    }
}
