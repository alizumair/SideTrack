import Foundation
import AppKit
import SwiftUI

public enum HUDKind {
    case volume(level: Float, isMuted: Bool)
    case brightness(level: Float)
    case keyboardBacklight(level: Float)
    case micGain(level: Float)
    case media(message: String, icon: String, subtitle: String = "")
    case timelineScrub(forward: Bool)
    case tabSwitch(forward: Bool)
    case videoSeek(forward: Bool)
    case countdown(title: String, icon: String, count: Int, total: Int)
}

public final class EdgeBarHUDOverlay {
    public static let shared = EdgeBarHUDOverlay()
    
    private var window: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?
    private let stateObject = HUDState()
    
    fileprivate final class HUDState: ObservableObject {
        @Published var title: String = ""
        @Published var subtitle: String = ""
        @Published var iconName: String = "speaker.wave.3.fill"
        @Published var progress: Float = 0.5
        @Published var hasBar: Bool = true
        @Published var detailText: String = "50%"
        @Published var style: HUDStyle = .minimalPill
        @Published var isCountdown: Bool = false
        @Published var countdownNumber: Int = 1
        @Published var countdownTotal: Int = 3
    }
    
    private init() {
        DispatchQueue.main.async { [weak self] in
            self?.setupWindow()
        }
    }
    
    private func setupWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]
        
        let contentView = HUDContentView(state: stateObject)
        panel.contentView = NSHostingView(rootView: contentView)
        self.window = panel
    }
    
    public func show(_ kind: HUDKind, style: HUDStyle = SettingsStore.shared.settings.hudStyle) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissWorkItem?.cancel()
            self.stateObject.style = style
            
            switch kind {
            case .volume(let level, let isMuted):
                self.stateObject.title = isMuted ? "Muted" : "Volume"
                self.stateObject.iconName = isMuted ? "speaker.slash.fill" : (level < 0.33 ? "speaker.wave.1.fill" : (level < 0.66 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"))
                self.stateObject.progress = isMuted ? 0 : level
                self.stateObject.hasBar = true
                self.stateObject.detailText = isMuted ? "Mute" : "\(Int(round(level * 100)))%"
                
            case .brightness(let level):
                self.stateObject.title = "Brightness"
                self.stateObject.iconName = "sun.max.fill"
                self.stateObject.progress = level
                self.stateObject.hasBar = true
                self.stateObject.detailText = "\(Int(round(level * 100)))%"
                
            case .keyboardBacklight(let level):
                self.stateObject.title = "Keyboard"
                self.stateObject.iconName = "keyboard.fill"
                self.stateObject.progress = level
                self.stateObject.hasBar = true
                self.stateObject.detailText = "\(Int(round(level * 100)))%"
                
            case .micGain(let level):
                self.stateObject.title = "Microphone"
                self.stateObject.iconName = level < 0.05 ? "mic.slash.fill" : "mic.fill"
                self.stateObject.progress = level
                self.stateObject.hasBar = true
                self.stateObject.detailText = "\(Int(round(level * 100)))%"
                
            case .timelineScrub(let forward):
                self.stateObject.title = forward ? "Frame +1 ▶" : "◀ Frame -1"
                self.stateObject.iconName = "film.fill"
                self.stateObject.progress = 1.0
                self.stateObject.hasBar = false
                self.stateObject.detailText = ""
                
            case .tabSwitch(let forward):
                self.stateObject.title = forward ? "Next Tab ▶" : "◀ Previous Tab"
                self.stateObject.iconName = "macwindow.on.rectangle"
                self.stateObject.progress = 1.0
                self.stateObject.hasBar = false
                self.stateObject.detailText = forward ? "Next" : "Prev"
                
            case .videoSeek(let forward):
                self.stateObject.title = forward ? "Seek +10s ▶" : "◀ Seek -10s"
                self.stateObject.iconName = forward ? "goforward.10" : "gobackward.10"
                self.stateObject.progress = 1.0
                self.stateObject.hasBar = false
                self.stateObject.detailText = forward ? "+10s" : "-10s"
                
            case .media(let message, let icon, let subtitle):
                self.stateObject.isCountdown = false
                self.stateObject.title = message
                self.stateObject.subtitle = subtitle
                self.stateObject.iconName = icon
                self.stateObject.progress = 1.0
                self.stateObject.hasBar = false
                self.stateObject.detailText = subtitle
                
            case .countdown(let title, let icon, let count, let total):
                self.stateObject.isCountdown = true
                self.stateObject.countdownNumber = count
                self.stateObject.countdownTotal = total
                self.stateObject.title = title
                self.stateObject.iconName = icon
                self.stateObject.progress = Float(count) / Float(max(total, 1))
                self.stateObject.hasBar = false
                self.stateObject.detailText = "\(count)"
            }
            
            guard let window = self.window, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
            let screenRect = screen.visibleFrame
            
            if style == .minimalPill {
                let pillWidth: CGFloat = self.stateObject.subtitle.isEmpty ? 220 : 250
                let x = screenRect.midX - (pillWidth / 2)
                let y = screenRect.minY + 65
                window.setContentSize(NSSize(width: pillWidth, height: 50))
                window.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                let x = screenRect.midX - 85
                let y = screenRect.minY + 120
                window.setContentSize(NSSize(width: 170, height: 170))
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            window.alphaValue = 1.0
            window.orderFrontRegardless()
            
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, let win = self.window else { return }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.20
                    win.animator().alphaValue = 0.0
                }, completionHandler: {
                    win.orderOut(nil)
                })
            }
            self.dismissWorkItem = item
            // Allow countdown steps to stay active for 1.5s before fade out
            let delay = (self.stateObject.isCountdown) ? 1.5 : 1.1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }
    
    public func dismissImmediately() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let win = self.window else { return }
            self.dismissWorkItem?.cancel()
            win.orderOut(nil)
            win.alphaValue = 0.0
        }
    }
}

private struct HUDContentView: View {
    @ObservedObject var state: EdgeBarHUDOverlay.HUDState
    
    var body: some View {
        if state.isCountdown {
            // Visual Countdown HUD ("1... 2... 3...")
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 26, height: 26)
                    Circle()
                        .trim(from: 0, to: CGFloat(state.progress))
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 26, height: 26)
                    Text("\(state.countdownNumber)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("Hold stationary...")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(width: 220, height: 44)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 6)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
        } else if state.style == .minimalPill {
            // Minimalist compact pill style
            HStack(spacing: 12) {
                Image(systemName: state.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 20)
                
                if state.hasBar {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 5)
                            
                            Capsule()
                                .fill(Color.white)
                                .frame(width: max(5, geo.size.width * CGFloat(state.progress)), height: 5)
                        }
                    }
                    .frame(height: 5)
                    
                    Text(state.detailText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 38, alignment: .trailing)
                        .monospacedDigit()
                } else if !state.subtitle.isEmpty {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(state.subtitle)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                } else {
                    Text(state.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(width: state.subtitle.isEmpty ? 220 : 250, height: 44)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 5)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        } else {
            // Classic Liquid Glass card style
            VStack(spacing: 16) {
                Image(systemName: state.iconName)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundColor(.white)
                    .frame(height: 48)
                
                if state.hasBar {
                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: max(8, geo.size.width * CGFloat(state.progress)), height: 8)
                            }
                        }
                        .frame(height: 8)
                        
                        Text(state.detailText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 14)
                } else {
                    VStack(spacing: 4) {
                        Text(state.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        if !state.subtitle.isEmpty {
                            Text(state.subtitle)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            }
            .padding(20)
            .frame(width: 170, height: 170)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }
}
