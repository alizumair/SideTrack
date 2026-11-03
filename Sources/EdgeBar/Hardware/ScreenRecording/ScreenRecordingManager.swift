import Foundation
import AppKit
import SwiftUI

public final class ScreenRecordingManager: ObservableObject {
    public static let shared = ScreenRecordingManager()
    
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var durationSeconds: Int = 0
    @Published public private(set) var activeOutputFileURL: URL?
    
    private var process: Process?
    private var timer: Timer?
    private var floatingPanel: NSPanel?
    
    private init() {}
    
    public static func defaultRecordingDirectory() -> URL {
        return MediaDestinationManager.effectiveMediaDirectory()
    }
    
    public func startRecording(crop: Bool = false) {
        guard !isRecording else { return }
        
        if crop {
            DispatchQueue.main.async {
                ScreenSelectionOverlay.shared.selectArea(mode: .screenRecording) { [weak self] rect in
                    guard let rect = rect else { return }
                    self?.startRecording(cropRect: rect)
                }
            }
        } else {
            startRecording(cropRect: nil)
        }
    }
    
    public func startRecording(cropRect: CGRect?) {
        guard !isRecording else { return }
        
        if #available(macOS 10.15, *) {
            if !CGPreflightScreenCaptureAccess() {
                _ = CGRequestScreenCaptureAccess()
            }
        }
        
        let fileURL = MediaDestinationManager.generateRecordingURL()
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        if let rect = cropRect {
            let x = Int(round(rect.origin.x))
            let y = Int(round(rect.origin.y))
            let w = max(10, Int(round(rect.size.width)))
            let h = max(10, Int(round(rect.size.height)))
            task.arguments = ["-v", "-R", "\(x),\(y),\(w),\(h)", fileURL.path]
        } else {
            task.arguments = ["-v", fileURL.path]
        }
        
        do {
            try task.run()
            self.process = task
            self.activeOutputFileURL = fileURL
            self.durationSeconds = 0
            self.isRecording = true
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.showFloatingBar()
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    guard let self = self, self.isRecording else { return }
                    self.durationSeconds += 1
                }
            }
            
            EdgeBarLogger.log("Screen recording started: \(fileURL.path)")
            NSLog("[EdgeBar] Screen recording started: %@", fileURL.path)
        } catch {
            NSLog("[EdgeBar] Failed to start screencapture: %@", error.localizedDescription)
            EdgeBarLogger.log("Failed to start screencapture: \(error.localizedDescription)")
            self.isRecording = false
        }
    }
    
    public func stopRecording() {
        guard isRecording, let task = process else { return }
        
        // Signal process with SIGINT to properly finalize the QuickTime movie container
        let pid = task.processIdentifier
        if pid > 0 {
            kill(pid, SIGINT)
        }
        
        timer?.invalidate()
        timer = nil
        isRecording = false
        process = nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hideFloatingBar()
            
            if let fileURL = self.activeOutputFileURL {
                let folderName = MediaDestinationManager.folderDisplayName(for: fileURL.deletingLastPathComponent())
                EdgeBarHUDOverlay.shared.show(.media(message: "Recording Saved", icon: "film.fill", subtitle: "Saved to \(folderName)"))
                // Reveal the recorded movie file in Finder
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                    }
                }
            }
            
            if SettingsStore.shared.settings.hapticsEnabled {
                HapticFeedbackBridge.shared.alignment()
            }
        }
        
        EdgeBarLogger.log("Screen recording stopped.")
        NSLog("[EdgeBar] Screen recording stopped.")
    }
    
    public func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func showFloatingBar() {
        if floatingPanel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 240, height: 44),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.ignoresMouseEvents = false
            panel.collectionBehavior = [.canJoinAllSpaces, .transient]
            
            let hosting = NSHostingView(rootView: ScreenRecordingFloatingView(manager: self))
            panel.contentView = hosting
            self.floatingPanel = panel
        }
        
        guard let panel = floatingPanel, let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let screenRect = screen.visibleFrame
        let x = screenRect.midX - 120
        let y = screenRect.maxY - 55
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.alphaValue = 1.0
        panel.orderFrontRegardless()
    }
    
    private func hideFloatingBar() {
        guard let panel = floatingPanel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.20
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}

private struct ScreenRecordingFloatingView: View {
    @ObservedObject var manager: ScreenRecordingManager
    @State private var isPulsing: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            // Pulsing recording indicator
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .scaleEffect(isPulsing ? 1.25 : 0.85)
                .opacity(isPulsing ? 1.0 : 0.5)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
                .onAppear { isPulsing = true }
            
            Text("REC")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.red)
            
            Text(formattedDuration(manager.durationSeconds))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(minWidth: 44)
            
            Divider()
                .frame(height: 16)
                .background(Color.white.opacity(0.3))
            
            // Stop button
            Button(action: {
                manager.stopRecording()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("Stop Recording")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red.opacity(0.9))
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formattedDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
