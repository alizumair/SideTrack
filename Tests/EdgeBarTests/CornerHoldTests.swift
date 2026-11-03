import XCTest
import CoreGraphics
@testable import EdgeBar

private final class MockCornerHoldDelegate: CornerHoldManagerDelegate {
    var startedCorners: [CornerType] = []
    var triggeredActions: [CornerHoldAction] = []
    var countdownSteps: [(corner: CornerType, count: Int, total: Int)] = []
    var cancelCount = 0
    
    func cornerHoldDidStart(corner: CornerType) {
        startedCorners.append(corner)
    }
    
    func cornerHoldDidCountdown(corner: CornerType, action: CornerHoldAction, count: Int, total: Int) {
        countdownSteps.append((corner, count, total))
    }
    
    func cornerHoldDidCancel() {
        cancelCount += 1
    }
    
    func cornerHoldDidTrigger(action: CornerHoldAction) {
        triggeredActions.append(action)
    }
}

private final class FullMockSlideEngineDelegate: SlideEngineDelegate {
    var brightnessDeltas: [Float] = []
    var volumeDeltas: [Float] = []
    var mediaSkips: [Bool] = []
    var playPauseCount = 0
    var toggleMuteCount = 0
    var slidingStates: [Bool] = []
    var hapticTicks = 0
    var startedCornerHolds: [CornerType] = []
    var screenshotTriggers = 0
    var screenRecordingTriggers = 0
    
    func slideEngineDidAdjustBrightness(delta: Float, isPrecise: Bool) {
        brightnessDeltas.append(delta)
    }
    
    func slideEngineDidAdjustVolume(delta: Float, isPrecise: Bool) {
        volumeDeltas.append(delta)
    }
    
    func slideEngineDidSkipMediaTrack(forward: Bool) {
        mediaSkips.append(forward)
    }
    
    func slideEngineDidPlayPause() {
        playPauseCount += 1
    }
    
    func slideEngineDidToggleMute() {
        toggleMuteCount += 1
    }
    
    func slideEngineSlideStateChanged(isSliding: Bool) {
        slidingStates.append(isSliding)
    }
    
    func slideEngineHapticTick() {
        hapticTicks += 1
    }
    
    func slideEngineDidStartCornerHold(corner: CornerType) {
        startedCornerHolds.append(corner)
    }
    
    func slideEngineDidTriggerScreenshot() {
        screenshotTriggers += 1
    }
    
    func slideEngineDidTriggerScreenRecording() {
        screenRecordingTriggers += 1
    }
}

final class CornerHoldTests: XCTestCase {
    
    func testCornerClassification() {
        let manager = CornerHoldManager()
        
        // 15% outer threshold boundaries:
        // Top-Left: x <= 0.15, y >= 0.85
        XCTAssertEqual(manager.classifyCorner(x: 0.05, y: 0.95), .topLeft)
        XCTAssertEqual(manager.classifyCorner(x: 0.15, y: 0.85), .topLeft)
        
        // Top-Right: x >= 0.85, y >= 0.85
        XCTAssertEqual(manager.classifyCorner(x: 0.95, y: 0.95), .topRight)
        XCTAssertEqual(manager.classifyCorner(x: 0.85, y: 0.85), .topRight)
        
        // Bottom-Left: x <= 0.15, y <= 0.15
        XCTAssertEqual(manager.classifyCorner(x: 0.05, y: 0.05), .bottomLeft)
        XCTAssertEqual(manager.classifyCorner(x: 0.15, y: 0.15), .bottomLeft)
        
        // Bottom-Right: x >= 0.85, y <= 0.15
        XCTAssertEqual(manager.classifyCorner(x: 0.95, y: 0.05), .bottomRight)
        XCTAssertEqual(manager.classifyCorner(x: 0.85, y: 0.15), .bottomRight)
        
        // Non-corner points
        XCTAssertNil(manager.classifyCorner(x: 0.50, y: 0.50))
        XCTAssertNil(manager.classifyCorner(x: 0.20, y: 0.95)) // Inside horizontal top middle
        XCTAssertNil(manager.classifyCorner(x: 0.05, y: 0.50)) // Left edge center
    }
    
    func testTopLeftStationaryHoldTriggersScreenshot() {
        let manager = CornerHoldManager()
        let delegate = MockCornerHoldDelegate()
        manager.delegate = delegate
        
        var scheduledDuration: Double?
        var triggerBlock: (() -> Void)?
        
        manager.customScheduler = { duration, block in
            scheduledDuration = duration
            triggerBlock = block
            return DispatchWorkItem(block: block)
        }
        
        let settings = SettingsModel.default
        let c1 = TrackpadContact(id: 10, x: 0.05, y: 0.95, state: .starting, timestamp: 1.0)
        let handled = manager.processFrame(contacts: [c1], settings: settings)
        
        XCTAssertTrue(handled)
        XCTAssertTrue(manager.isHolding)
        XCTAssertEqual(manager.activeCorner, .topLeft)
        XCTAssertEqual(delegate.startedCorners, [.topLeft])
        XCTAssertEqual(scheduledDuration, settings.screenshotHoldDuration)
        
        // Frame 2: Stationary touch continues
        let c2 = TrackpadContact(id: 10, x: 0.055, y: 0.952, state: .touching, timestamp: 1.1)
        _ = manager.processFrame(contacts: [c2], settings: settings)
        XCTAssertTrue(manager.isHolding)
        
        // Fire scheduled work item
        triggerBlock?()
        
        XCTAssertEqual(delegate.triggeredActions, [.screenshot])
        XCTAssertFalse(manager.isHolding)
        XCTAssertTrue(manager.hasTriggeredForCurrentTouch)
    }
    
    func testBottomLeftStationaryHoldTriggersScreenshot() {
        let manager = CornerHoldManager()
        let delegate = MockCornerHoldDelegate()
        manager.delegate = delegate
        
        var triggerBlock: (() -> Void)?
        manager.customScheduler = { _, block in
            triggerBlock = block
            return DispatchWorkItem(block: block)
        }
        
        let settings = SettingsModel.default
        let c1 = TrackpadContact(id: 11, x: 0.05, y: 0.05, state: .starting, timestamp: 1.0)
        _ = manager.processFrame(contacts: [c1], settings: settings)
        
        XCTAssertEqual(delegate.startedCorners, [.bottomLeft])
        triggerBlock?()
        XCTAssertEqual(delegate.triggeredActions, [.screenshot])
    }
    
    func testBottomRightStationaryHoldTriggersScreenRecording() {
        let manager = CornerHoldManager()
        let delegate = MockCornerHoldDelegate()
        manager.delegate = delegate
        
        var scheduledDuration: Double?
        var triggerBlock: (() -> Void)?
        
        manager.customScheduler = { duration, block in
            scheduledDuration = duration
            triggerBlock = block
            return DispatchWorkItem(block: block)
        }
        
        let settings = SettingsModel.default
        let c1 = TrackpadContact(id: 12, x: 0.95, y: 0.05, state: .starting, timestamp: 1.0)
        let handled = manager.processFrame(contacts: [c1], settings: settings)
        
        XCTAssertTrue(handled)
        XCTAssertEqual(manager.activeCorner, .bottomRight)
        XCTAssertEqual(scheduledDuration, settings.screenRecordingHoldDuration)
        
        triggerBlock?()
        XCTAssertEqual(delegate.triggeredActions, [.screenRecording])
    }
    
    func testTopRightCornerHoldIsReservedAndDisabled() {
        let manager = CornerHoldManager()
        let delegate = MockCornerHoldDelegate()
        manager.delegate = delegate
        
        let settings = SettingsModel.default
        let c1 = TrackpadContact(id: 13, x: 0.95, y: 0.95, state: .starting, timestamp: 1.0)
        let handled = manager.processFrame(contacts: [c1], settings: settings)
        
        XCTAssertFalse(handled)
        XCTAssertFalse(manager.isHolding)
        XCTAssertEqual(delegate.startedCorners.count, 0)
        XCTAssertEqual(delegate.triggeredActions.count, 0)
    }
    
    func testDragMovementCancelsHold() {
        let manager = CornerHoldManager()
        let delegate = MockCornerHoldDelegate()
        manager.delegate = delegate
        
        manager.customScheduler = { _, block in
            let item = DispatchWorkItem(block: block)
            return item
        }
        
        let settings = SettingsModel.default
        let c1 = TrackpadContact(id: 14, x: 0.05, y: 0.95, state: .starting, timestamp: 1.0)
        _ = manager.processFrame(contacts: [c1], settings: settings)
        XCTAssertTrue(manager.isHolding)
        
        // Finger drags downward past maxTapMovementThreshold (0.015)
        let c2 = TrackpadContact(id: 14, x: 0.05, y: 0.90, state: .touching, timestamp: 1.05)
        let handled = manager.processFrame(contacts: [c2], settings: settings)
        
        XCTAssertFalse(handled)
        XCTAssertFalse(manager.isHolding)
        XCTAssertEqual(delegate.triggeredActions.count, 0)
    }
    
    func testPrematureLiftCancelsHold() {
        let manager = CornerHoldManager()
        let delegate = MockCornerHoldDelegate()
        manager.delegate = delegate
        
        let settings = SettingsModel.default
        let c1 = TrackpadContact(id: 15, x: 0.05, y: 0.95, state: .starting, timestamp: 1.0)
        _ = manager.processFrame(contacts: [c1], settings: settings)
        XCTAssertTrue(manager.isHolding)
        
        // Finger lifted before duration
        let c2 = TrackpadContact(id: 15, x: 0.05, y: 0.95, state: .breaking, timestamp: 1.05)
        let handled = manager.processFrame(contacts: [c2], settings: settings)
        
        XCTAssertFalse(handled)
        XCTAssertFalse(manager.isHolding)
        XCTAssertEqual(delegate.triggeredActions.count, 0)
    }
    
    func testMultiFingerCancelsHold() {
        let manager = CornerHoldManager()
        let delegate = MockCornerHoldDelegate()
        manager.delegate = delegate
        
        let settings = SettingsModel.default
        let c1 = TrackpadContact(id: 16, x: 0.05, y: 0.95, state: .starting, timestamp: 1.0)
        _ = manager.processFrame(contacts: [c1], settings: settings)
        XCTAssertTrue(manager.isHolding)
        
        // Second finger touches pad
        let c2 = TrackpadContact(id: 17, x: 0.50, y: 0.50, state: .starting, timestamp: 1.05)
        let handled = manager.processFrame(contacts: [c1, c2], settings: settings)
        
        XCTAssertFalse(handled)
        XCTAssertFalse(manager.isHolding)
        XCTAssertEqual(delegate.triggeredActions.count, 0)
    }
    
    func testDisabledSettingPreventsHold() {
        let manager = CornerHoldManager()
        let delegate = MockCornerHoldDelegate()
        manager.delegate = delegate
        
        var settings = SettingsModel.default
        settings.cornerHoldsEnabled = false
        
        let c1 = TrackpadContact(id: 18, x: 0.05, y: 0.95, state: .starting, timestamp: 1.0)
        let handled = manager.processFrame(contacts: [c1], settings: settings)
        
        XCTAssertFalse(handled)
        XCTAssertFalse(manager.isHolding)
        XCTAssertEqual(delegate.startedCorners.count, 0)
    }
    
    // MARK: - SlideEngine Integration Tests
    
    func testSlideEngineScreenshotIntegration() {
        let engine = SlideEngine(settings: .default)
        let delegate = FullMockSlideEngineDelegate()
        engine.delegate = delegate
        
        var triggerBlock: (() -> Void)?
        engine.cornerHoldManager.customScheduler = { _, block in
            triggerBlock = block
            return DispatchWorkItem(block: block)
        }
        
        // Touch down in Top-Left
        let c1 = TrackpadContact(id: 20, x: 0.05, y: 0.95, state: .starting, timestamp: 1.0)
        engine.processFrame(contacts: [c1], timestamp: 1.0)
        
        XCTAssertEqual(delegate.startedCornerHolds, [.topLeft])
        XCTAssertEqual(delegate.screenshotTriggers, 0)
        
        // Trigger hold
        triggerBlock?()
        
        XCTAssertEqual(delegate.screenshotTriggers, 1)
        
        // Releasing finger should not cause accidental taps or brightness adjustments
        let c2 = TrackpadContact(id: 20, x: 0.05, y: 0.95, state: .breaking, timestamp: 2.5)
        engine.processFrame(contacts: [c2], timestamp: 2.5)
        
        XCTAssertEqual(delegate.brightnessDeltas.count, 0)
    }
    
    func testSlideEngineScreenRecordingIntegration() {
        let engine = SlideEngine(settings: .default)
        let delegate = FullMockSlideEngineDelegate()
        engine.delegate = delegate
        
        var triggerBlock: (() -> Void)?
        engine.cornerHoldManager.customScheduler = { _, block in
            triggerBlock = block
            return DispatchWorkItem(block: block)
        }
        
        // Touch down in Bottom-Right
        let c1 = TrackpadContact(id: 21, x: 0.95, y: 0.05, state: .starting, timestamp: 1.0)
        engine.processFrame(contacts: [c1], timestamp: 1.0)
        
        XCTAssertEqual(delegate.startedCornerHolds, [.bottomRight])
        XCTAssertEqual(delegate.screenRecordingTriggers, 0)
        
        // Trigger hold
        triggerBlock?()
        
        XCTAssertEqual(delegate.screenRecordingTriggers, 1)
    }
    
    func testTopRightMuteDoubleTapRemainsFunctional() {
        let engine = SlideEngine(settings: .default)
        let delegate = FullMockSlideEngineDelegate()
        engine.delegate = delegate
        
        var t = 1.0
        // Tap 1 in Top-Right
        let c1 = TrackpadContact(id: 30, x: 0.95, y: 0.95, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        t += 0.05
        let c2 = TrackpadContact(id: 30, x: 0.95, y: 0.95, state: .breaking, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        // Tap 2 in Top-Right
        t += 0.10
        let c3 = TrackpadContact(id: 31, x: 0.95, y: 0.95, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c3], timestamp: t)
        t += 0.05
        let c4 = TrackpadContact(id: 31, x: 0.95, y: 0.95, state: .breaking, timestamp: t)
        engine.processFrame(contacts: [c4], timestamp: t)
        
        XCTAssertEqual(delegate.toggleMuteCount, 1)
        XCTAssertEqual(delegate.startedCornerHolds.count, 0)
    }
    
    func testCornerHoldCountdownDispatched() {
        let manager = CornerHoldManager()
        let delegate = MockCornerHoldDelegate()
        manager.delegate = delegate
        
        var settings = SettingsModel.default
        settings.showHoldCountdownTimer = true
        settings.screenRecordingHoldDuration = 3.0
        
        let c1 = TrackpadContact(id: 40, x: 0.95, y: 0.05, state: .starting, timestamp: 1.0)
        let handled = manager.processFrame(contacts: [c1], settings: settings)
        
        XCTAssertTrue(handled)
        XCTAssertTrue(manager.isHolding)
        XCTAssertEqual(delegate.startedCorners, [.bottomRight])
        XCTAssertEqual(delegate.countdownSteps.count, 1)
        XCTAssertEqual(delegate.countdownSteps.first?.count, 1)
        XCTAssertEqual(delegate.countdownSteps.first?.total, 3)
        
        // Cancel hold
        manager.cancelHold()
        XCTAssertFalse(manager.isHolding)
        XCTAssertEqual(delegate.cancelCount, 1)
    }
    
    func testConfigurableCornerHoldActions() {
        let manager = CornerHoldManager()
        let delegate = MockCornerHoldDelegate()
        manager.delegate = delegate
        
        var triggerBlock: (() -> Void)?
        manager.customScheduler = { duration, block in
            triggerBlock = block
            return DispatchWorkItem(block: block)
        }
        
        var settings = SettingsModel.default
        settings.bottomLeftHoldAction = .screenRecording
        settings.bottomRightHoldAction = .screenshot
        
        // Touch in Bottom-Left should now trigger screenRecording
        let c1 = TrackpadContact(id: 41, x: 0.05, y: 0.05, state: .starting, timestamp: 1.0)
        _ = manager.processFrame(contacts: [c1], settings: settings)
        triggerBlock?()
        XCTAssertEqual(delegate.triggeredActions.last, .screenRecording)
        
        // Touch in Bottom-Right should now trigger screenshot
        let c2 = TrackpadContact(id: 42, x: 0.95, y: 0.05, state: .starting, timestamp: 2.0)
        _ = manager.processFrame(contacts: [c2], settings: settings)
        triggerBlock?()
        XCTAssertEqual(delegate.triggeredActions.last, .screenshot)
    }
}
