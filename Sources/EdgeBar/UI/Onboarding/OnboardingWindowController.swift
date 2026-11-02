import SwiftUI
import AppKit

public struct OnboardingView: View {
    @ObservedObject var accessibility = AccessibilityManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "slider.vertical.3")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 8) {
                Text("Welcome to EdgeBar")
                    .font(.system(size: 22, weight: .bold))
                
                Text("Turn your MacBook trackpad edges into hardware volume and display strips.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(
                    icon: "sun.max.fill",
                    color: .blue,
                    title: "Left Edge: Display Brightness",
                    description: "Slide up or down along the left edge."
                )
                
                FeatureRow(
                    icon: "speaker.wave.3.fill",
                    color: .orange,
                    title: "Right Edge: System Volume",
                    description: "Slide up or down along the right edge."
                )
                
                FeatureRow(
                    icon: "forward.fill",
                    color: .purple,
                    title: "Bottom Edge: Media Control",
                    description: "Swipe horizontally to skip tracks; double-tap to play/pause."
                )
                
                FeatureRow(
                    icon: "hand.raised.fill",
                    color: .green,
                    title: "Intelligent Multi-Finger Gate",
                    description: "Standard 2-finger scrolling and native gestures are never affected."
                )
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            
            Divider()
            
            HStack {
                if accessibility.isTrusted {
                    Label("Accessibility Granted!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                } else {
                    Button(action: {
                        accessibility.promptForAccessibility()
                    }) {
                        Text("Grant Accessibility Permission")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(28)
        .frame(width: 480, height: 460)
        .onAppear {
            accessibility.checkStatus()
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
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
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
