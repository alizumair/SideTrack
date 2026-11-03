import Foundation
import AppKit

public enum SelectionMode {
    case screenshot
    case screenRecording
    
    public var instruction: String {
        switch self {
        case .screenshot:
            return "Drag to crop screenshot • Press Esc to cancel"
        case .screenRecording:
            return "Drag to select recording area • Press Esc to cancel"
        }
    }
}

public final class ScreenSelectionOverlay: NSObject {
    public static let shared = ScreenSelectionOverlay()
    
    private var windows: [NSWindow] = []
    private var activeCompletion: ((CGRect?) -> Void)?
    
    private override init() {
        super.init()
    }
    
    @MainActor
    public func selectArea(mode: SelectionMode = .screenRecording, completion: @escaping (CGRect?) -> Void) {
        cancel()
        
        self.activeCompletion = completion
        
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            completion(nil)
            return
        }
        
        for screen in screens {
            let win = SelectionWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            win.level = .screenSaver
            win.backgroundColor = .clear
            win.isOpaque = false
            win.hasShadow = false
            win.ignoresMouseEvents = false
            win.acceptsMouseMovedEvents = true
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let selectionView = SelectionView(frame: NSRect(origin: .zero, size: screen.frame.size), mode: mode)
            selectionView.onFinish = { [weak self] quartzRect in
                self?.dismissAndReturn(quartzRect)
            }
            selectionView.onCancel = { [weak self] in
                self?.dismissAndReturn(nil)
            }
            
            win.contentView = selectionView
            windows.append(win)
            win.makeKeyAndOrderFront(nil)
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @MainActor
    public func cancel() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        activeCompletion = nil
    }
    
    @MainActor
    private func dismissAndReturn(_ rect: CGRect?) {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        
        let comp = activeCompletion
        activeCompletion = nil
        comp?(rect)
    }
}

private final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionView: NSView {
    var onFinish: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    
    private let mode: SelectionMode
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var isDragging = false
    
    init(frame frameRect: NSRect, mode: SelectionMode) {
        self.mode = mode
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
    
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        isDragging = true
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDragging, let start = startPoint, let current = currentPoint else {
            onCancel?()
            return
        }
        
        isDragging = false
        
        let rect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        
        guard rect.width >= 15 && rect.height >= 15 else {
            onCancel?()
            return
        }
        
        // Convert Cocoa screen rect to Quartz coordinates
        // Quartz (0, 0) is top-left of the primary display (NSScreen.screens.first)
        let primaryScreen = NSScreen.screens.first ?? window?.screen ?? NSScreen.main
        let primaryHeight = primaryScreen?.frame.height ?? bounds.height
        
        let screenOrigin = window?.screen?.frame.origin ?? .zero
        let globalCocoaX = screenOrigin.x + rect.origin.x
        let globalCocoaY = screenOrigin.y + rect.origin.y
        
        let qx = globalCocoaX
        let qy = primaryHeight - (globalCocoaY + rect.size.height)
        
        let quartzRect = CGRect(x: qx, y: qy, width: rect.size.width, height: rect.size.height)
        onFinish?(quartzRect)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Draw dim background
        context.setFillColor(NSColor.black.withAlphaComponent(0.28).cgColor)
        context.fill(bounds)
        
        if isDragging, let start = startPoint, let current = currentPoint {
            let selectionRect = NSRect(
                x: min(start.x, current.x),
                y: min(start.y, current.y),
                width: abs(current.x - start.x),
                height: abs(current.y - start.y)
            )
            
            // Clear selection rectangle to show underlying contents bright and clear
            context.clear(selectionRect)
            
            // Stroke selection rectangle with sleek 2pt white border
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(2.0)
            context.stroke(selectionRect)
            
            // Draw dimension pill badge
            let text = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
            drawPill(text: text, origin: NSPoint(x: selectionRect.midX, y: selectionRect.minY - 26))
        } else {
            // Draw top instructional badge
            let instruction = mode.instruction
            drawPill(text: instruction, origin: NSPoint(x: bounds.midX, y: bounds.maxY - 60))
        }
    }
    
    private func drawPill(text: String, origin: NSPoint) {
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrString.size()
        
        let pillRect = NSRect(
            x: origin.x - (textSize.width + 20) / 2,
            y: origin.y,
            width: textSize.width + 20,
            height: 24
        )
        
        let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 12, yRadius: 12)
        NSColor.black.withAlphaComponent(0.75).setFill()
        pillPath.fill()
        
        let textOrigin = NSPoint(
            x: pillRect.midX - textSize.width / 2,
            y: pillRect.midY - textSize.height / 2
        )
        attrString.draw(at: textOrigin)
    }
}
