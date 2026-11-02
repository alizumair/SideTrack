import XCTest
@testable import EdgeBar

final class SettingsModelTests: XCTestCase {
    func testJSONSerializationAndDeserialization() throws {
        var original = SettingsModel.default
        original.edgeWidthFraction = 0.22
        original.edgeHeightFraction = 0.15
        original.sensitivity = 1.8
        original.invertVerticalAxis = true
        original.cursorFreezingEnabled = false
        original.hapticsEnabled = false
        original.leftEdgeAction = .volume
        original.rightEdgeAction = .brightness
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SettingsModel.self, from: data)
        
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.edgeWidthFraction, 0.22)
        XCTAssertEqual(decoded.sensitivity, 1.8)
        XCTAssertEqual(decoded.invertVerticalAxis, true)
        XCTAssertEqual(decoded.leftEdgeAction, .volume)
        XCTAssertEqual(decoded.rightEdgeAction, .brightness)
    }
    
    func testSettingsStorePersistence() {
        let suiteName = "io.github.edgebar.test.\(UUID().uuidString)"
        guard let testDefaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Failed to create test user defaults")
            return
        }
        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
        }
        
        let store = SettingsStore(userDefaults: testDefaults)
        XCTAssertEqual(store.settings, SettingsModel.default)
        
        store.settings.edgeWidthFraction = 0.25
        store.settings.sensitivity = 2.0
        
        // Create another instance reading same defaults
        let reloadedStore = SettingsStore(userDefaults: testDefaults)
        XCTAssertEqual(reloadedStore.settings.edgeWidthFraction, 0.25)
        XCTAssertEqual(reloadedStore.settings.sensitivity, 2.0)
        
        // Reset to defaults
        reloadedStore.resetToDefaults()
        XCTAssertEqual(reloadedStore.settings, SettingsModel.default)
    }
}
