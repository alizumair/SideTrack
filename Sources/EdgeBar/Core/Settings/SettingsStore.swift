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
                let decoded = try decoder.decode(SettingsModel.self, from: data)
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
