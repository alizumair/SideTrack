import Foundation
import AppKit
import SwiftUI

public enum HUDKind {
    case volume(level: Float, isMuted: Bool)
    case brightness(level: Float)
    case media(message: String, icon: String)
}

public final class EdgeBarHUDOverlay {
    public static let shared = EdgeBarHUDOverlay()
    
    private var window: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?
    private let stateObject = HUDState()
    
    fileprivate final class HUDState: ObservableObject {
        @Published var title: String = ""
        @Published var iconName: String = "speaker.wave.3.fill"
        @Published var progress: Float = 0.5
        @Published var hasBar: Bool = true
        @Published var detailText: String = "50%"
    }
    
    private init() {
        DispatchQueue.main.async { [weak self] in
            self?.setupWindow()
        }
    }
    
    private func setupWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
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
    
    public func show(_ kind: HUDKind) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissWorkItem?.cancel()
            
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
                
            case .media(let message, let icon):
                self.stateObject.title = message
                self.stateObject.iconName = icon
                self.stateObject.progress = 1.0
                self.stateObject.hasBar = false
                self.stateObject.detailText = ""
            }
            
            guard let window = self.window, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - 100
            let y = screenRect.minY + 120
            window.setFrameOrigin(NSPoint(x: x, y: y))
            
            window.alphaValue = 1.0
            window.orderFrontRegardless()
            
            let item = DispatchWorkItem { [weak self] in
                guard let self = self, let win = self.window else { return }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.25
                    win.animator().alphaValue = 0.0
                }, completionHandler: {
                    win.orderOut(nil)
                })
            }
            self.dismissWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: item)
        }
    }
}

private struct HUDContentView: View {
    @ObservedObject var state: EdgeBarHUDOverlay.HUDState
    
    var body: some View {
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
                Text(state.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
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
