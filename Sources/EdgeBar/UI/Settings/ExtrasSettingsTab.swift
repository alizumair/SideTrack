import SwiftUI

public struct ExtrasSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore
    
    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Modifiers & Corner Taps")
                    .font(.headline)
                
                // Precision Modifier
                VStack(alignment: .leading, spacing: 8) {
                    Text("Precision Modifiers (⇧⌥)")
                        .font(.subheadline.bold())
                    
                    HStack {
                        Text("Precision Rate:")
                            .frame(width: 140, alignment: .leading)
                        Slider(
                            value: $settingsStore.settings.precisionMultiplier,
                            in: 0.10...0.50,
                            step: 0.05
                        )
                        Text("\(Int(settingsStore.settings.precisionMultiplier * 100))%")
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()
                    }
                    Text("Hold Shift + Option (⇧⌥) while sliding for micro-adjustments and fine tuning.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Double-Tap Shortcuts
                VStack(alignment: .leading, spacing: 12) {
                    Text("Corner & Tap Shortcuts")
                        .font(.subheadline.bold())
                    
                    Picker("Top-Right Corner Double-Tap:", selection: $settingsStore.settings.topRightCornerAction) {
                        ForEach(CornerAction.allCases) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Bottom Edge Double-Tap:", selection: $settingsStore.settings.bottomDoubleTapAction) {
                        ForEach(CornerAction.allCases) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Divider()
                
                // HUD & OSD Feedback
                VStack(alignment: .leading, spacing: 12) {
                    Text("Visual On-Screen Feedback")
                        .font(.subheadline.bold())
                    
                    Toggle("Use Native macOS System OSD (Bezel)", isOn: $settingsStore.settings.useSystemOSD)
                    
                    if !settingsStore.settings.useSystemOSD {
                        Toggle("Show EdgeBar Floating Glass HUD", isOn: $settingsStore.settings.showHUDOverlay)
                    }
                    
                    Text("EdgeBar directly interfaces with macOS OSDManager or renders a modern floating HUD when levels change.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
}
