import SwiftUI

public struct GeneralSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var accessibility = AccessibilityManager.shared
    
    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("General Settings")
                    .font(.headline)
                
                // Master Toggle
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable EdgeBar Hardware Interception", isOn: $settingsStore.settings.isEnabled)
                        .font(.subheadline.bold())
                    
                    Text("Turn off to temporarily suspend edge tracking without quitting the app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Accessibility Permissions
                VStack(alignment: .leading, spacing: 10) {
                    Text("System Permissions")
                        .font(.subheadline.bold())
                    
                    HStack {
                        Image(systemName: accessibility.isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(accessibility.isTrusted ? .green : .orange)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(accessibility.isTrusted ? "Accessibility Granted" : "Accessibility Required")
                                .font(.body.weight(.medium))
                            Text(accessibility.isTrusted ? "EdgeBar has hardware-level access to process trackpad frames." : "Grant permission in System Settings -> Privacy & Security -> Accessibility.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !accessibility.isTrusted {
                            Button("Grant Access") {
                                accessibility.promptForAccessibility()
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                Divider()
                
                // Defaults & Storage
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configuration Storage")
                        .font(.subheadline.bold())
                    
                    Text("Configurations are serialized under key: \(SettingsModel.storageKey)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Reset All Settings to Factory Defaults") {
                        settingsStore.resetToDefaults()
                    }
                }
                
                Divider()
                
                // About
                HStack(spacing: 16) {
                    if let icon = NSApp.applicationIconImage {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: "slider.vertical.3")
                            .font(.system(size: 32))
                            .foregroundColor(.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("EdgeBar")
                            .font(.headline)
                        Text("Version 1.0.0 • Pure Swift Native Utility")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Zero-overhead outer edge hardware control strips for macOS.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            accessibility.checkStatus()
        }
    }
}
