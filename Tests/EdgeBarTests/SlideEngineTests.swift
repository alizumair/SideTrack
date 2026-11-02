import XCTest
import AppKit
@testable import EdgeBar

private final class MockSlideEngineDelegate: SlideEngineDelegate {
    var brightnessDeltas: [Float] = []
    var volumeDeltas: [Float] = []
    var mediaSkips: [Bool] = []
    var playPauseCount = 0
    var toggleMuteCount = 0
    var slidingStates: [Bool] = []
    var hapticTicks = 0
    
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
}

final class SlideEngineTests: XCTestCase {
    private var engine: SlideEngine!
    private var delegate: MockSlideEngineDelegate!
    
    override func setUp() {
        super.setUp()
        engine = SlideEngine(settings: .default)
        delegate = MockSlideEngineDelegate()
        engine.delegate = delegate
    }
    
    func testLeftEdgeBrightnessSliding() {
        var t = 1.0
        // Touch lands on left edge (x: 0.05, y: 0.5)
        let c1 = TrackpadContact(id: 1, x: 0.05, y: 0.5, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        // Slide upwards on left edge past movement threshold
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.05, y: 0.60, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        // Next frame
        t += 0.05
        let c3 = TrackpadContact(id: 1, x: 0.05, y: 0.65, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c3], timestamp: t)
        
        // Lift finger
        t += 0.05
        let c4 = TrackpadContact(id: 1, x: 0.05, y: 0.65, state: .breaking, timestamp: t)
        engine.processFrame(contacts: [c4], timestamp: t)
        
        XCTAssertGreaterThan(delegate.brightnessDeltas.count, 0)
        let totalBrightnessDelta = delegate.brightnessDeltas.reduce(0, +)
        XCTAssertGreaterThan(totalBrightnessDelta, 0.10)
        XCTAssertEqual(delegate.volumeDeltas.count, 0)
        XCTAssertTrue(delegate.slidingStates.contains(true))
        XCTAssertEqual(delegate.slidingStates.last, false)
    }
    
    func testRightEdgeVolumeSliding() {
        var t = 1.0
        // Touch lands on right edge (x: 0.95, y: 0.5)
        let c1 = TrackpadContact(id: 1, x: 0.95, y: 0.5, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        // Slide upwards on right edge past movement threshold
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.95, y: 0.60, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        // Next frame
        t += 0.05
        let c3 = TrackpadContact(id: 1, x: 0.95, y: 0.70, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c3], timestamp: t)
        
        // Lift finger
        t += 0.05
        let c4 = TrackpadContact(id: 1, x: 0.95, y: 0.70, state: .breaking, timestamp: t)
        engine.processFrame(contacts: [c4], timestamp: t)
        
        XCTAssertGreaterThan(delegate.volumeDeltas.count, 0)
        let totalVolumeDelta = delegate.volumeDeltas.reduce(0, +)
        XCTAssertGreaterThan(totalVolumeDelta, 0.15)
        XCTAssertEqual(delegate.brightnessDeltas.count, 0)
    }
    
    func testMiddleTouchIsIgnored() {
        var t = 1.0
        // Touch lands in middle (x: 0.5, y: 0.5)
        let c1 = TrackpadContact(id: 1, x: 0.5, y: 0.5, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        // Even if finger wanders into left edge, it must be ignored
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.05, y: 0.8, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        XCTAssertEqual(delegate.brightnessDeltas.count, 0)
        XCTAssertEqual(delegate.volumeDeltas.count, 0)
        XCTAssertFalse(delegate.slidingStates.contains(true))
    }
    
    func testHorizontalDragFromEdgeIsIgnored() {
        var t = 1.0
        // 1. Touch lands on left edge (x: 0.05, y: 0.50)
        let c1 = TrackpadContact(id: 1, x: 0.05, y: 0.50, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        // User drags horizontally towards center (x: 0.15, y: 0.50)
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.15, y: 0.50, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        // Because horizontal motion dominates into trackpad, it must be rejected!
        XCTAssertEqual(delegate.brightnessDeltas.count, 0)
        XCTAssertFalse(delegate.slidingStates.contains(true))
        
        // Lift finger
        engine.processFrame(contacts: [], timestamp: t + 0.05)
        
        // 2. Touch lands on right edge (x: 0.95, y: 0.50)
        t += 0.10
        let c3 = TrackpadContact(id: 2, x: 0.95, y: 0.50, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c3], timestamp: t)
        
        // User drags horizontally towards center (x: 0.85, y: 0.50)
        t += 0.05
        let c4 = TrackpadContact(id: 2, x: 0.85, y: 0.50, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c4], timestamp: t)
        
        XCTAssertEqual(delegate.volumeDeltas.count, 0)
        XCTAssertFalse(delegate.slidingStates.contains(true))
    }
    
    func testHorizontalTurnDuringSlideCancelsSlide() {
        var t = 1.0
        // 1. Touch starts on right edge and slides vertically up
        let c1 = TrackpadContact(id: 1, x: 0.95, y: 0.50, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.95, y: 0.60, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        XCTAssertTrue(delegate.slidingStates.contains(true))
        
        // 2. User suddenly turns horizontally towards trackpad center (x: 0.88, y: 0.605)
        t += 0.05
        let c3 = TrackpadContact(id: 1, x: 0.88, y: 0.605, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c3], timestamp: t)
        
        // Slide must end immediately and phase must reset
        XCTAssertEqual(delegate.slidingStates.last, false)
        XCTAssertEqual(engine.phase, .idle)
        
        // Further horizontal movement into center must not trigger volume
        let volumeCountBefore = delegate.volumeDeltas.count
        t += 0.05
        let c4 = TrackpadContact(id: 1, x: 0.70, y: 0.61, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c4], timestamp: t)
        XCTAssertEqual(delegate.volumeDeltas.count, volumeCountBefore)
    }
    
    func testBottomVerticalDragUpIsIgnored() {
        var t = 1.0
        // Touch starts in bottom strip (x: 0.50, y: 0.08)
        let c1 = TrackpadContact(id: 1, x: 0.50, y: 0.08, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        // Drag vertically up into trackpad (x: 0.50, y: 0.25)
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.50, y: 0.25, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        XCTAssertEqual(delegate.mediaSkips.count, 0)
        XCTAssertFalse(delegate.slidingStates.contains(true))
    }
    
    func testTouchIDReuseWorksAfterLift() {
        var t = 1.0
        // Touch 1 starts in middle and is ignored
        let c1 = TrackpadContact(id: 1, x: 0.5, y: 0.5, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        // Touch 1 lifts
        engine.processFrame(contacts: [], timestamp: t + 0.05)
        
        // macOS reuses touch ID 1 on the right edge!
        t += 0.10
        let c2 = TrackpadContact(id: 1, x: 0.95, y: 0.50, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        t += 0.05
        let c3 = TrackpadContact(id: 1, x: 0.95, y: 0.65, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c3], timestamp: t)
        
        // Must succeed and NOT be blocked by previous middle touch!
        XCTAssertGreaterThan(delegate.volumeDeltas.count, 0)
        XCTAssertTrue(delegate.slidingStates.contains(true))
    }
    
    func testMultiFingerGateCancelsSlide() {
        var t = 1.0
        // Finger 1 lands on right edge and begins sliding
        let c1 = TrackpadContact(id: 1, x: 0.95, y: 0.5, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.95, y: 0.6, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        XCTAssertTrue(delegate.slidingStates.contains(true))
        
        // Second finger lands! Multi-finger gate must kick in immediately
        t += 0.05
        let c3_1 = TrackpadContact(id: 1, x: 0.95, y: 0.62, state: .touching, timestamp: t)
        let c3_2 = TrackpadContact(id: 2, x: 0.50, y: 0.50, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c3_1, c3_2], timestamp: t)
        
        // Sliding state must be cancelled immediately
        XCTAssertEqual(delegate.slidingStates.last, false)
        XCTAssertEqual(engine.phase, .cancelled)
        
        // Subsequent moves while fingers are down do not trigger edge events
        let countBefore = delegate.volumeDeltas.count
        t += 0.05
        let c4 = TrackpadContact(id: 1, x: 0.95, y: 0.70, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c4], timestamp: t)
        XCTAssertEqual(delegate.volumeDeltas.count, countBefore)
    }
    
    func testBottomHorizontalSwipeForMediaSkip() {
        var t = 1.0
        // Touch starts in bottom strip (x: 0.30, y: 0.08)
        let c1 = TrackpadContact(id: 1, x: 0.30, y: 0.08, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        // Swipe right past threshold (> 0.08)
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.45, y: 0.08, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        XCTAssertEqual(delegate.mediaSkips.count, 1)
        XCTAssertEqual(delegate.mediaSkips.first, true) // Forward skip
    }
    
    func testTopRightCornerDoubleTapForMute() {
        var t = 1.0
        // Tap 1
        let c1 = TrackpadContact(id: 1, x: 0.95, y: 0.95, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        t += 0.04
        let c1_end = TrackpadContact(id: 1, x: 0.95, y: 0.95, state: .breaking, timestamp: t)
        engine.processFrame(contacts: [c1_end], timestamp: t)
        engine.processFrame(contacts: [], timestamp: t)
        
        XCTAssertEqual(delegate.toggleMuteCount, 0) // Single tap should not mute
        
        // Tap 2 within 0.15s
        t += 0.10
        let c2 = TrackpadContact(id: 2, x: 0.95, y: 0.95, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        t += 0.04
        let c2_end = TrackpadContact(id: 2, x: 0.95, y: 0.95, state: .breaking, timestamp: t)
        engine.processFrame(contacts: [c2_end], timestamp: t)
        
        // Double-tap confirmed!
        XCTAssertEqual(delegate.toggleMuteCount, 1)
    }
    
    func testBottomEdgeDoubleTapForPlayPause() {
        var t = 1.0
        // Tap 1 on bottom edge
        let c1 = TrackpadContact(id: 1, x: 0.50, y: 0.08, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        t += 0.04
        let c1_end = TrackpadContact(id: 1, x: 0.50, y: 0.08, state: .breaking, timestamp: t)
        engine.processFrame(contacts: [c1_end], timestamp: t)
        engine.processFrame(contacts: [], timestamp: t)
        
        XCTAssertEqual(delegate.playPauseCount, 0)
        
        // Tap 2
        t += 0.12
        let c2 = TrackpadContact(id: 2, x: 0.50, y: 0.08, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        t += 0.04
        let c2_end = TrackpadContact(id: 2, x: 0.50, y: 0.08, state: .breaking, timestamp: t)
        engine.processFrame(contacts: [c2_end], timestamp: t)
        
        XCTAssertEqual(delegate.playPauseCount, 1)
    }
    
    func testPrecisionModifierScaling() {
        engine.modifierFlagsProvider = { [.shift, .option] }
        
        var t = 1.0
        let c1 = TrackpadContact(id: 1, x: 0.95, y: 0.5, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.95, y: 0.6, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        let delta = delegate.volumeDeltas.first ?? 0
        // Normal delta would be 0.10. With precisionMultiplier (0.25), expected delta is ~0.025
        XCTAssertEqual(Double(delta), 0.10 * 0.25, accuracy: 0.001)
    }
    
    func testInvertVerticalAxis() {
        engine.settings.invertVerticalAxis = true
        
        var t = 1.0
        let c1 = TrackpadContact(id: 1, x: 0.95, y: 0.5, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.95, y: 0.6, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        let delta = delegate.volumeDeltas.first ?? 0
        // Moving y up from 0.5 to 0.6 is positive, but inverted should be negative
        XCTAssertLessThan(delta, 0)
    }
}
