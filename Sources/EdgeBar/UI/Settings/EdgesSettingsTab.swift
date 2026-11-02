import SwiftUI

public struct EdgesSettingsTab: View {
    @ObservedObject var settingsStore: SettingsStore
    
    public init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Trackpad Edge Layout & Actions")
                    .font(.headline)
                
                // Trackpad diagram
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 2)
                        )
                        .frame(height: 180)
                    
                    // Left Edge Zone
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.35))
                            .overlay(
                                Text("Left: \(settingsStore.settings.leftEdgeAction.rawValue)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.blue)
                                    .rotationEffect(.degrees(-90))
                                    .fixedSize()
                            )
                            .frame(width: CGFloat(settingsStore.settings.leftEdgeWidthFraction) * 280)
                        Spacer()
                    }
                    .padding(8)
                    
                    // Right Edge Zone
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.35))
                            .overlay(
                                Text("Right: \(settingsStore.settings.rightEdgeAction.rawValue)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.orange)
                                    .rotationEffect(.degrees(90))
                                    .fixedSize()
                            )
                            .frame(width: CGFloat(settingsStore.settings.rightEdgeWidthFraction) * 280)
                    }
                    .padding(8)
                    
                    // Top-Left Corner (Screenshot Hold)
                    if settingsStore.settings.cornerHoldsEnabled {
                        VStack {
                            HStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.opacity(0.5))
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white)
                                    )
                                    .frame(width: 26, height: 26)
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(10)
                    }
                    
                    // Top-Right Corner Mute Target
                    VStack {
                        HStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.yellow.opacity(0.5))
                                .overlay(
                                    Image(systemName: "speaker.slash.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                )
                                .frame(width: 32, height: 32)
                        }
                        Spacer()
                    }
                    .padding(10)
                    
                    // Bottom-Left Corner (Screenshot Hold)
                    if settingsStore.settings.cornerHoldsEnabled {
                        VStack {
                            Spacer()
                            HStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.opacity(0.5))
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white)
                                    )
                                    .frame(width: 26, height: 26)
                                Spacer()
                            }
                        }
                        .padding(10)
                    }
                    
                    // Bottom-Right Corner (Screen Recording Hold)
                    if settingsStore.settings.cornerHoldsEnabled {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.red.opacity(0.5))
                                    .overlay(
                                        Image(systemName: "record.circle")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                    )
                                    .frame(width: 26, height: 26)
                            }
                        }
                        .padding(10)
                    }
                    
                    // Bottom Edge Zone
                    VStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.purple.opacity(0.35))
                            .overlay(
                                Text("Bottom: \(settingsStore.settings.bottomEdgeAction.rawValue)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.purple)
                            )
                            .frame(height: CGFloat(settingsStore.settings.bottomEdgeHeightFraction) * 120)
                            .padding(.horizontal, CGFloat(settingsStore.settings.leftEdgeWidthFraction) * 180)
                    }
                    .padding(8)
                    
                    // Center label
                    Text("Standard Native macOS Gestures Area\n(Scroll, Pinch, 3-Finger Swipes)")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                
                Divider()
                
                // Granular Independent Edge Dimensions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Independent Edge Perimeter Dimensions")
                        .font(.subheadline.bold())
                    
                    HStack {
                        Text("Left Edge Width:")
                            .frame(width: 150, alignment: .leading)
                        Slider(
                            value: $settingsStore.settings.leftEdgeWidthFraction,
                            in: 0.05...0.30,
                            step: 0.01
                        )
                        Text("\(Int(settingsStore.settings.leftEdgeWidthFraction * 100))%")
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()
                    }
                    
                    HStack {
                        Text("Right Edge Width:")
                            .frame(width: 150, alignment: .leading)
                        Slider(
                            value: $settingsStore.settings.rightEdgeWidthFraction,
                            in: 0.05...0.30,
                            step: 0.01
                        )
                        Text("\(Int(settingsStore.settings.rightEdgeWidthFraction * 100))%")
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()
                    }
                    
                    HStack {
                        Text("Bottom Edge Height:")
                            .frame(width: 150, alignment: .leading)
                        Slider(
                            value: $settingsStore.settings.bottomEdgeHeightFraction,
                            in: 0.05...0.30,
                            step: 0.01
                        )
                        Text("\(Int(settingsStore.settings.bottomEdgeHeightFraction * 100))%")
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()
                    }
                    
                    HStack {
                        Text("Top Edge Height:")
                            .frame(width: 150, alignment: .leading)
                        Slider(
                            value: $settingsStore.settings.topEdgeHeightFraction,
                            in: 0.05...0.30,
                            step: 0.01
                        )
                        Text("\(Int(settingsStore.settings.topEdgeHeightFraction * 100))%")
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
                
                Divider()
                
                // Edge Assignments
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hardware Action Mappings")
                        .font(.subheadline.bold())
                    
                    Picker("Left Edge Slide:", selection: $settingsStore.settings.leftEdgeAction) {
                        ForEach(EdgeAction.allCases) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Right Edge Slide:", selection: $settingsStore.settings.rightEdgeAction) {
                        ForEach(EdgeAction.allCases) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("Bottom Edge Swipe:", selection: $settingsStore.settings.bottomEdgeAction) {
                        ForEach(EdgeAction.allCases) { action in
                            Text(action.rawValue).tag(action)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(20)
        }
    }
}
