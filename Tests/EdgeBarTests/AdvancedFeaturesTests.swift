import XCTest
@testable import EdgeBar

final class AdvancedFeaturesTests: XCTestCase {
    
    func testIndependentEdgeClassifier() {
        // Asymmetric dimensions:
        // Left: 0.08, Right: 0.15, Top: 0.05, Bottom: 0.20, Corner: 0.10
        let classifier = EdgeClassifier(
            leftWidth: 0.08,
            rightWidth: 0.15,
            topHeight: 0.05,
            bottomHeight: 0.20,
            cornerSize: 0.10
        )
        
        // Left strip: x = 0.07 is within 0.08
        XCTAssertEqual(classifier.classify(x: 0.07, y: 0.50), .left)
        // x = 0.09 is beyond left width (middle)
        XCTAssertEqual(classifier.classify(x: 0.09, y: 0.50), .middle)
        
        // Right strip: x = 0.86 is within 1.0 - 0.15 = 0.85
        XCTAssertEqual(classifier.classify(x: 0.86, y: 0.50), .right)
        // x = 0.84 is beyond right width (middle)
        XCTAssertEqual(classifier.classify(x: 0.84, y: 0.50), .middle)
        
        // Bottom strip: y = 0.18 is within 0.20
        XCTAssertEqual(classifier.classify(x: 0.50, y: 0.18), .bottom)
        // y = 0.22 is beyond bottom height (middle)
        XCTAssertEqual(classifier.classify(x: 0.50, y: 0.22), .middle)
        
        // Top-right corner
        XCTAssertEqual(classifier.classify(x: 0.95, y: 0.95), .topRightCorner)
    }
    
    func testAppProfileResolutionInSlideEngine() {
        var settings = SettingsModel.default
        let fcpProfile = AppProfile(
            name: "Final Cut Pro",
            bundleIdentifier: "com.apple.FinalCut",
            bottomEdgeAction: .timelineScrub,
            bottomScrubMode: .timelineScrub
        )
        settings.profiles = [fcpProfile]
        
        let engine = SlideEngine(settings: settings)
        XCTAssertEqual(engine.effectiveBottomAction, .mediaTrack)
        XCTAssertEqual(engine.effectiveBottomScrubMode, .mediaTrack)
        
        // Activate profile
        engine.activeProfile = fcpProfile
        XCTAssertEqual(engine.effectiveBottomAction, .timelineScrub)
        XCTAssertEqual(engine.effectiveBottomScrubMode, .timelineScrub)
    }
    
    func testGameModeBypassInSlideEngine() {
        let engine = SlideEngine(settings: .default)
        engine.isGameModeBypassed = true
        
        // Touch on left edge should be immediately ignored because Game Mode is active
        let c1 = TrackpadContact(id: 1, x: 0.05, y: 0.5, state: .starting, timestamp: 1.0)
        engine.processFrame(contacts: [c1], timestamp: 1.0)
        
        XCTAssertEqual(engine.phase, .idle)
    }
    
    func testShellScriptExecution() {
        let exp = expectation(description: "Shell command execution")
        let trigger = CustomScriptTrigger(type: .shell, payload: "echo 'EdgeBarOK'")
        
        ScriptDispatcher.shared.execute(trigger: trigger) { result in
            switch result {
            case .success(let output):
                XCTAssertTrue(output.contains("EdgeBarOK"))
                exp.fulfill()
            case .failure(let error):
                XCTFail("Shell script failed: \(error)")
            }
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    func testEmptyScriptPayloadFailsFast() {
        let exp = expectation(description: "Empty payload failure")
        let trigger = CustomScriptTrigger(type: .shell, payload: "   ")
        
        ScriptDispatcher.shared.execute(trigger: trigger) { result in
            switch result {
            case .success:
                XCTFail("Empty payload should fail")
            case .failure:
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 2.0)
    }
    
    func testKeyboardBacklightClamping() {
        let bridge = KeyboardBacklightBridge.shared
        bridge.setBrightness(-0.5)
        XCTAssertGreaterThanOrEqual(bridge.getBrightness(), 0.0)
        
        bridge.setBrightness(1.5)
        XCTAssertLessThanOrEqual(bridge.getBrightness(), 1.0)
    }
    
    func testAudioFeedbackToggle() {
        let haptics = HapticFeedbackBridge.shared
        haptics.audioFeedbackEnabled = true
        XCTAssertTrue(haptics.audioFeedbackEnabled)
        haptics.audioFeedbackEnabled = false
        XCTAssertFalse(haptics.audioFeedbackEnabled)
    }
}
