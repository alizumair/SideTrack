import Foundation
import AppKit

public final class MediaDestinationManager {
    public static func effectiveMediaDirectory(settings: SettingsModel = SettingsStore.shared.settings) -> URL {
        if !settings.customMediaSaveDirectory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let expanded = NSString(string: settings.customMediaSaveDirectory).expandingTildeInPath
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: expanded)
            }
        }
        
        // System default: check macOS com.apple.screencapture location
        if let locationString = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") {
            let expanded = NSString(string: locationString).expandingTildeInPath
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: expanded)
            }
        }
        
        // Fallback: Documents, Desktop, or Home
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        return docs ?? desktop ?? FileManager.default.homeDirectoryForCurrentUser
    }
    
    public static func folderDisplayName(for url: URL) -> String {
        return FileManager.default.displayName(atPath: url.path)
    }
    
    public static func generateScreenshotURL(settings: SettingsModel = SettingsStore.shared.settings) -> URL {
        let dir = effectiveMediaDirectory(settings: settings)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' h.mm.ss a"
        let timestamp = formatter.string(from: Date())
        let filename = "Screenshot \(timestamp).png"
        return dir.appendingPathComponent(filename)
    }
    
    public static func generateRecordingURL(settings: SettingsModel = SettingsStore.shared.settings) -> URL {
        let dir = effectiveMediaDirectory(settings: settings)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' h.mm.ss a"
        let timestamp = formatter.string(from: Date())
        let filename = "Screen Recording \(timestamp).mov"
        return dir.appendingPathComponent(filename)
    }
}
