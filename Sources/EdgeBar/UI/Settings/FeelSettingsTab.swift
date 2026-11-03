import SwiftUI

public struct FeelSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore
    
    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Haptics, Audio & Physics")
                    .font(.headline)
                
                // Sensitivity
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Slide Sensitivity:")
                                .frame(width: 160, alignment: .leading)
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
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Tab Switch Sensitivity:")
                                .frame(width: 160, alignment: .leading)
                            Slider(
                                value: $settingsStore.settings.tabSwitchSensitivity,
                                in: 0.2...2.0,
                                step: 0.1
                            )
                            Text(String(format: "%.1fx", settingsStore.settings.tabSwitchSensitivity))
                                .frame(width: 45, alignment: .trailing)
                                .monospacedDigit()
                        }
                        Text("Controls the horizontal swipe distance along the bottom edge required to cycle browser tabs.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Slider Activation Mode (Instant vs. Hold-to-Engage)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Slider Activation Style")
                        .font(.subheadline.bold())
                    
                    Picker("", selection: $settingsStore.settings.sliderActivationStyle) {
                        ForEach(SliderActivationStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if settingsStore.settings.sliderActivationStyle == .holdToEngage {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Hold Delay:")
                                    .frame(width: 140, alignment: .leading)
                                Slider(
                                    value: $settingsStore.settings.sliderHoldDwellDuration,
                                    in: 0.10...0.80,
                                    step: 0.05
                                )
                                Text(String(format: "%.2fs", settingsStore.settings.sliderHoldDwellDuration))
                                    .frame(width: 50, alignment: .trailing)
                                    .monospacedDigit()
                            }
                            Text("Requires resting your finger in the edge strip for a fraction of a second before sliding begins, confirmed by a tactile Force Touch tick. Eliminates 100% of accidental grazes.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Sliders respond immediately as soon as vertical movement begins.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Haptics & Audio Clicks
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable Tactile Haptic Ticks", isOn: $settingsStore.settings.hapticsEnabled)
                        .font(.subheadline.bold())
                    
                    if settingsStore.settings.hapticsEnabled {
                        Picker("Haptic Tick Steps:", selection: $settingsStore.settings.hapticSteps) {
                            Text("16 Steps (Classic)").tag(16)
                            Text("32 Steps (Fine)").tag(32)
                            Text("64 Steps (Ultra-Smooth)").tag(64)
                        }
                        .pickerStyle(.segmented)
                        .padding(.leading, 20)
                        
                        Toggle("Play Subtle Mechanical Click Audio", isOn: $settingsStore.settings.audioFeedbackEnabled)
                            .padding(.leading, 20)
                            .font(.body)
                    }
                    Text("Delivers silent Force Touch trackpad feedback whenever a scalar step is crossed. Sliders remain silent.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // HUD Style Selector
                VStack(alignment: .leading, spacing: 10) {
                    Text("On-Screen Display (HUD) Style")
                        .font(.subheadline.bold())
                    
                    Picker("", selection: $settingsStore.settings.hudStyle) {
                        ForEach(HUDStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Minimalist Edge Pill renders an ultra-compact status bar floating near the bottom edge. Liquid Glass provides a classic centered frosted card.")
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
