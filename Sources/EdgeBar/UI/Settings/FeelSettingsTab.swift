import SwiftUI

public struct FeelSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore
    
    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Haptics & Slide Physics")
                    .font(.headline)
                
                // Sensitivity
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Slide Sensitivity:")
                            .frame(width: 140, alignment: .leading)
                        Slider(
                            value: $settingsStore.settings.sensitivity,
                            in: 0.5...2.5,
                            step: 0.1
                        )
                        Text(String(format: "%.1fx", settingsStore.settings.sensitivity))
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()
                    }
                    Text("Controls how rapidly volume and brightness ramp up per centimeter of physical slide.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Haptics
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Tactile Haptic Ticks", isOn: $settingsStore.settings.hapticsEnabled)
                        .font(.subheadline.bold())
                    
                    if settingsStore.settings.hapticsEnabled {
                        Picker("Haptic Tick Steps:", selection: $settingsStore.settings.hapticSteps) {
                            Text("16 Steps (Classic macOS)").tag(16)
                            Text("32 Steps (Fine)").tag(32)
                            Text("64 Steps (Ultra-Smooth)").tag(64)
                        }
                        .pickerStyle(.segmented)
                        .padding(.leading, 20)
                    }
                    Text("Delivers Force Touch trackpad feedback whenever a scalar volume or brightness step is crossed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Cursor Freezing
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Freeze Cursor Position While Sliding", isOn: $settingsStore.settings.cursorFreezingEnabled)
                        .font(.subheadline.bold())
                    
                    Text("Dissociates the mouse cursor during edge sliding gestures so your cursor stays parked on screen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Invert Axis
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Invert Vertical Sliding Direction", isOn: $settingsStore.settings.invertVerticalAxis)
                        .font(.subheadline.bold())
                    
                    Text("Flips vertical sliding (slide downwards to increase, upwards to decrease).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
        }
    }
}
