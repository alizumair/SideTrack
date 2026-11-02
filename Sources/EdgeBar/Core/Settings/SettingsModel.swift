import Foundation

public enum EdgeAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case brightness = "Brightness"
    case volume = "Volume"
    case mediaTrack = "Media Track Skip"
    case disabled = "Disabled"
    
    public var id: String { rawValue }
}

public enum CornerAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case toggleMute = "Toggle Mute"
    case playPause = "Play / Pause"
    case maxBrightness = "Max Brightness"
    case disabled = "Disabled"
    
    public var id: String { rawValue }
}

public struct SettingsModel: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let storageKey = "io.github.edgebar.settings.v1"
    
    public var version: Int = SettingsModel.currentVersion
    public var isEnabled: Bool = true
    
    // Edges
    public var edgeWidthFraction: Double = 0.14        // 14% outer horizontal edge (~22mm)
    public var edgeHeightFraction: Double = 0.18       // 18% outer bottom edge
    public var cornerZoneFraction: Double = 0.12       // 12% corner box (compact for tap targets)
    public var leftEdgeAction: EdgeAction = .brightness
    public var rightEdgeAction: EdgeAction = .volume
    public var bottomEdgeAction: EdgeAction = .mediaTrack
    public var topRightCornerAction: CornerAction = .toggleMute
    public var bottomDoubleTapAction: CornerAction = .playPause
    
    // Feel & Precision
    public var sensitivity: Double = 1.0
    public var invertVerticalAxis: Bool = false
    public var cursorFreezingEnabled: Bool = true
    public var hapticsEnabled: Bool = true
    public var hapticSteps: Int = 16
    public var precisionMultiplier: Double = 0.25      // Quarter-step with ⇧⌥
    
    // Extras & System Bridges
    public var showMenuBarIcon: Bool = true
    public var showHUDOverlay: Bool = false            // Use native macOS system popups by default
    public var useSystemOSD: Bool = true
    public var doubleTapMaxInterval: Double = 0.35
    public var maxTapMovementThreshold: Double = 0.015 // Tight tap boundary (~1.5mm)
    
    // General
    public var launchAtLogin: Bool = false
    
    public init() {}
    
    public static var `default`: SettingsModel {
        SettingsModel()
    }
}
