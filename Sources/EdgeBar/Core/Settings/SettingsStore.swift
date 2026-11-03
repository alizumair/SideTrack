import Foundation
import Combine

public final class SettingsStore: ObservableObject {
    public static let shared = SettingsStore()
    
    @Published public var settings: SettingsModel {
        didSet {
            save()
        }
    }
    
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let data = userDefaults.data(forKey: SettingsModel.storageKey) {
            do {
                var decoded = try decoder.decode(SettingsModel.self, from: data)
                if decoded.version < 2 {
                    decoded.edgeWidthFraction = 0.10
                    decoded.edgeHeightFraction = 0.10
                    decoded.cornerZoneFraction = 0.10
                    decoded.hapticSteps = 64
                }
                if decoded.version < 3 {
                    if decoded.leftEdgeWidthFraction <= 0 { decoded.leftEdgeWidthFraction = 0.10 }
                    if decoded.rightEdgeWidthFraction <= 0 { decoded.rightEdgeWidthFraction = 0.10 }
                    if decoded.bottomEdgeHeightFraction <= 0 { decoded.bottomEdgeHeightFraction = 0.10 }
                    if decoded.topEdgeHeightFraction <= 0 { decoded.topEdgeHeightFraction = 0.10 }
                    if decoded.profiles.isEmpty {
                        decoded.profiles = SettingsModel.default.profiles
                    }
                    decoded.version = 3
                }
                if decoded.version < 4 {
                    // 1. Ensure Streaming & Video profile exists
                    if !decoded.profiles.contains(where: { $0.name.lowercased().contains("streaming") || $0.name.lowercased().contains("video") }) {
                        if let streamingProfile = SettingsModel.default.profiles.first(where: { $0.name.lowercased().contains("streaming") }) {
                            decoded.profiles.insert(streamingProfile, at: 0)
                        }
                    }
                    // 2. Upgrade Web Browsers profile to .tabSwitch
                    for i in 0..<decoded.profiles.count {
                        if decoded.profiles[i].name.lowercased().contains("browser") {
                            decoded.profiles[i].bottomScrubMode = .tabSwitch
                            decoded.profiles[i].bottomEdgeAction = .tabSwitch
                            decoded.profiles[i].bundleIdentifier = "com.apple.Safari, com.google.Chrome, company.thebrowser.Browser, com.brave.Browser, org.mozilla.firefox, com.microsoft.edgemac, com.kagi.kagimacOS, com.operasoftware.Opera, com.vivaldi.Vivaldi"
                        }
                    }
                    decoded.version = 4
                }
                self.settings = decoded
            } catch {
                NSLog("[EdgeBar] Failed to decode settings, falling back to defaults: %@", error.localizedDescription)
                self.settings = SettingsModel.default
            }
        } else {
            self.settings = SettingsModel.default
        }
    }
    
    public func save() {
        do {
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: SettingsModel.storageKey)
        } catch {
            NSLog("[EdgeBar] Failed to encode settings: %@", error.localizedDescription)
        }
    }
    
    public func resetToDefaults() {
        self.settings = SettingsModel.default
    }
}
