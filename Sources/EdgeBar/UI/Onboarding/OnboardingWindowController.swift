import SwiftUI
import AppKit

public struct OnboardingView: View {
    @ObservedObject var permissions = AccessibilityManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "slider.vertical.3")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 6) {
                Text("Welcome to SideTrack")
                    .font(.system(size: 20, weight: .bold))
                
                Text("Turn your MacBook trackpad edges into hardware volume and display strips.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "sun.max.fill",
                    color: .blue,
                    title: "Left Edge: Display Brightness",
                    description: "Slide vertically along the left 18% of your trackpad."
                )
                
                FeatureRow(
                    icon: "speaker.wave.3.fill",
                    color: .orange,
                    title: "Right Edge: System Volume",
                    description: "Slide vertically along the right 18% of your trackpad."
                )
                
                FeatureRow(
                    icon: "forward.fill",
                    color: .purple,
                    title: "Bottom Edge: Media Control",
                    description: "Swipe horizontally to skip tracks; double-tap to play/pause."
                )
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            
            Divider()
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("1. Input Monitoring")
                            .font(.headline)
                        Text("Required for macOS to deliver raw edge touch frames.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if permissions.isInputMonitoringGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else {
                        Button("Grant") {
                            permissions.promptForInputMonitoring()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("2. Accessibility")
                            .font(.headline)
                        Text("Required to dispatch native macOS volume & brightness bezels.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if permissions.isAccessibilityGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else {
                        Button("Grant") {
                            permissions.promptForAccessibility()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(24)
        .frame(width: 480, height: 490)
        .onAppear {
            permissions.checkStatus()
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
