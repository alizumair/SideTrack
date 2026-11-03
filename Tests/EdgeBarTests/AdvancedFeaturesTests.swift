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
    
    func testTabSwitchInSlideEngine() {
        var settings = SettingsModel.default
        let browserProfile = AppProfile(
            name: "Web Browsers",
            bundleIdentifier: "com.apple.Safari",
            bottomEdgeAction: .tabSwitch,
            bottomScrubMode: .tabSwitch
        )
        settings.profiles = [browserProfile]
        
        let engine = SlideEngine(settings: settings)
        engine.activeProfile = browserProfile
        let delegate = MockScrubDelegate()
        engine.delegate = delegate
        
        var t = 1.0
        let c1 = TrackpadContact(id: 1, x: 0.30, y: 0.05, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        // Slide right by 0.09 (> 0.035 step threshold)
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.39, y: 0.05, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        XCTAssertGreaterThanOrEqual(delegate.tabSwitches.count, 1)
        XCTAssertEqual(delegate.tabSwitches.first, true)
    }
    
    func testVideoSeekInSlideEngine() {
        var settings = SettingsModel.default
        let streamProfile = AppProfile(
            name: "Streaming & Video",
            bundleIdentifier: "netflix, disney, prime",
            bottomEdgeAction: .videoSeek,
            bottomScrubMode: .videoSeek
        )
        settings.profiles = [streamProfile]
        
        let engine = SlideEngine(settings: settings)
        engine.activeProfile = streamProfile
        let delegate = MockScrubDelegate()
        engine.delegate = delegate
        
        var t = 1.0
        let c1 = TrackpadContact(id: 1, x: 0.50, y: 0.05, state: .starting, timestamp: t)
        engine.processFrame(contacts: [c1], timestamp: t)
        
        // Slide left by 0.09
        t += 0.05
        let c2 = TrackpadContact(id: 1, x: 0.41, y: 0.05, state: .touching, timestamp: t)
        engine.processFrame(contacts: [c2], timestamp: t)
        
        XCTAssertGreaterThanOrEqual(delegate.videoSeeks.count, 1)
        XCTAssertEqual(delegate.videoSeeks.first, false)
    }
    
    func testStreamingAndBrowserProfileDefaults() {
        let settings = SettingsModel.default
        let stream = settings.profiles.first { $0.name.contains("Streaming") }
        XCTAssertNotNil(stream)
        XCTAssertEqual(stream?.bottomScrubMode, .videoSeek)
        
        let browser = settings.profiles.first { $0.name.contains("Browsers") }
        XCTAssertNotNil(browser)
        XCTAssertEqual(browser?.bottomScrubMode, .tabSwitch)
    }
    
    func testTabSwitchSensitivityDecreased() {
        var settings = SettingsModel.default
        settings.tabSwitchSensitivity = 0.5
        
        let browserProfile = AppProfile(
            name: "Web Browsers",
            bundleIdentifier: "com.google.Chrome",
            bottomEdgeAction: .tabSwitch,
            bottomScrubMode: .tabSwitch
        )
        settings.profiles = [browserProfile]
        
        let engine = SlideEngine(settings: settings)
        engine.activeProfile = browserProfile
        let delegate = MockScrubDelegate()
        engine.delegate = delegate
        
        // Touch lands on bottom strip
        let c1 = TrackpadContact(id: 1, x: 0.50, y: 0.05, state: .starting, timestamp: 1.0)
        engine.processFrame(contacts: [c1], timestamp: 1.0)
        
        // At 0.5 sensitivity, candidate threshold is 0.040 / 0.5 = 0.080 (~11mm)
        // Moving dx = 0.030 should NOT trigger tab switch yet (decreased sensitivity!)
        let c2 = TrackpadContact(id: 1, x: 0.53, y: 0.05, state: .touching, timestamp: 1.05)
        engine.processFrame(contacts: [c2], timestamp: 1.05)
        XCTAssertEqual(delegate.tabSwitches.count, 0)
        
        // Moving past 0.080 threshold (e.g. x = 0.59, dx = 0.09) should trigger exactly 1 tab switch
        let c3 = TrackpadContact(id: 1, x: 0.59, y: 0.05, state: .touching, timestamp: 1.10)
        engine.processFrame(contacts: [c3], timestamp: 1.10)
        XCTAssertEqual(delegate.tabSwitches.count, 1)
        XCTAssertEqual(delegate.tabSwitches.first, true)
    }
    
    func testMediaDestinationResolution() {
        var settings = SettingsModel.default
        settings.customMediaSaveDirectory = "/tmp"
        
        let dir = MediaDestinationManager.effectiveMediaDirectory(settings: settings)
        XCTAssertTrue(dir.path == "/tmp" || dir.path == "/private/tmp")
        
        let screenshotURL = MediaDestinationManager.generateScreenshotURL(settings: settings)
        XCTAssertTrue(screenshotURL.path.contains("/Screenshot"))
        XCTAssertTrue(screenshotURL.path.hasSuffix(".png"))
        
        let recordingURL = MediaDestinationManager.generateRecordingURL(settings: settings)
        XCTAssertTrue(recordingURL.path.contains("/Screen Recording"))
        XCTAssertTrue(recordingURL.path.hasSuffix(".mov"))
    }
}

private final class MockScrubDelegate: SlideEngineDelegate {
    var tabSwitches: [Bool] = []
    var videoSeeks: [Bool] = []
    
    func slideEngineDidAdjustBrightness(delta: Float, isPrecise: Bool) {}
    func slideEngineDidAdjustVolume(delta: Float, isPrecise: Bool) {}
    func slideEngineDidSkipMediaTrack(forward: Bool) {}
    func slideEngineDidPlayPause() {}
    func slideEngineDidToggleMute() {}
    func slideEngineSlideStateChanged(isSliding: Bool) {}
    func slideEngineHapticTick() {}
    
    func slideEngineDidSwitchTab(forward: Bool) {
        tabSwitches.append(forward)
    }
    func slideEngineDidSeekVideo(forward: Bool) {
        videoSeeks.append(forward)
    }
}
