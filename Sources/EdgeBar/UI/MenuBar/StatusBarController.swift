import Foundation
import AppKit
import SwiftUI

public final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let appState: AppState
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    
    public init(appState: AppState = .shared) {
        self.appState = appState
        super.init()
        setupStatusItem()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "SideTrackStatusItem"
        statusItem.behavior = [.removalAllowed]
        statusItem.isVisible = true
        
        if let button = statusItem.button {
            if let icon = NSApp.applicationIconImage ?? NSImage(named: "AppIcon") {
                let size = NSSize(width: 18, height: 18)
                let menuImage = NSImage(size: size)
                menuImage.lockFocus()
                let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 4, yRadius: 4)
                path.addClip()
                icon.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
                menuImage.unlockFocus()
                menuImage.isTemplate = false
                button.image = menuImage
            } else {
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
                let image = NSImage(systemSymbolName: "slider.vertical.3", accessibilityDescription: "SideTrack")?.withSymbolConfiguration(config)
                image?.isTemplate = true
                button.image = image
            }
            button.imagePosition = .imageOnly
            button.toolTip = "SideTrack"
        }
        
        buildMenu()
    }
    
    public func buildMenu() {
        menu = NSMenu()
        menu.delegate = self
        
        // Status header
        let isEnabled = appState.settingsStore.settings.isEnabled
        let titleItem = NSMenuItem(
            title: isEnabled ? "EdgeBar: Active" : "EdgeBar: Paused",
            action: nil,
            keyEquivalent: ""
        )
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Live readouts
        let volPercent = Int(round(appState.currentVolume * 100))
        let volTitle = appState.isMuted ? "Volume: Muted" : "Volume: \(volPercent)%"
        let volItem = NSMenuItem(title: volTitle, action: nil, keyEquivalent: "")
        volItem.image = NSImage(systemSymbolName: appState.isMuted ? "speaker.slash" : "speaker.wave.2", accessibilityDescription: nil)
        volItem.isEnabled = false
        menu.addItem(volItem)
        
        let brightPercent = Int(round(appState.currentBrightness * 100))
        let brightItem = NSMenuItem(title: "Brightness: \(brightPercent)%", action: nil, keyEquivalent: "")
        brightItem.image = NSImage(systemSymbolName: "sun.max", accessibilityDescription: nil)
        brightItem.isEnabled = false
        menu.addItem(brightItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quick toggle
        let toggleItem = NSMenuItem(
            title: isEnabled ? "Disable EdgeBar" : "Enable EdgeBar",
            action: #selector(toggleEnabled),
            keyEquivalent: "e"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Edge assignment summaries
        let s = appState.settingsStore.settings
        let leftSummary = NSMenuItem(title: "Left Edge: \(s.leftEdgeAction.rawValue)", action: nil, keyEquivalent: "")
        leftSummary.isEnabled = false
        menu.addItem(leftSummary)
        
        let rightSummary = NSMenuItem(title: "Right Edge: \(s.rightEdgeAction.rawValue)", action: nil, keyEquivalent: "")
        rightSummary.isEnabled = false
        menu.addItem(rightSummary)
        
        let bottomSummary = NSMenuItem(title: "Bottom Edge: \(s.bottomEdgeAction.rawValue)", action: nil, keyEquivalent: "")
        bottomSummary.isEnabled = false
        menu.addItem(bottomSummary)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings & Permissions
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let permItem = NSMenuItem(title: "Permissions...", action: #selector(openPermissions), keyEquivalent: "")
        permItem.target = self
        menu.addItem(permItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit EdgeBar", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    public func menuWillOpen(_ menu: NSMenu) {
        appState.syncSystemValues()
        buildMenu()
    }
    
    @objc private func toggleEnabled() {
        appState.settingsStore.settings.isEnabled.toggle()
        buildMenu()
    }
    
    @objc public func openSettings() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.settingsWindow == nil {
                let view = SettingsView(settingsStore: self.appState.settingsStore)
                let hosting = NSHostingView(rootView: view)
                
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 620, height: 520),
                    styleMask: [.titled, .closable, .miniaturizable],
                    backing: .buffered,
                    defer: false
                )
                window.title = "SideTrack Settings"
                window.contentView = hosting
                window.center()
                window.isReleasedWhenClosed = false
                self.settingsWindow = window
            }
            
            NSApp.activate(ignoringOtherApps: true)
            self.settingsWindow?.makeKeyAndOrderFront(nil)
            self.settingsWindow?.orderFrontRegardless()
        }
    }
    
    @objc public func openPermissions() {
        if onboardingWindow == nil {
            let view = OnboardingView()
            let hosting = NSHostingView(rootView: view)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "EdgeBar Permissions"
            window.contentView = hosting
            window.center()
            window.isReleasedWhenClosed = false
            self.onboardingWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc private func quitApp() {
        appState.stopEngine()
        NSApplication.shared.terminate(nil)
    }
}
