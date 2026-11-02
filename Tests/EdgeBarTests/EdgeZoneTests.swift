import XCTest
@testable import EdgeBar

final class EdgeZoneTests: XCTestCase {
    func testEdgeClassifier() {
        let classifier = EdgeClassifier(edgeWidth: 0.18, edgeHeight: 0.18, cornerSize: 0.20)
        
        // Middle area
        XCTAssertEqual(classifier.classify(x: 0.5, y: 0.5), .middle)
        XCTAssertEqual(classifier.classify(x: 0.3, y: 0.7), .middle)
        
        // Left edge strip
        XCTAssertEqual(classifier.classify(x: 0.05, y: 0.5), .left)
        XCTAssertEqual(classifier.classify(x: 0.18, y: 0.5), .left)
        
        // Right edge strip
        XCTAssertEqual(classifier.classify(x: 0.95, y: 0.5), .right)
        XCTAssertEqual(classifier.classify(x: 0.82, y: 0.5), .right)
        
        // Bottom edge strip
        XCTAssertEqual(classifier.classify(x: 0.5, y: 0.05), .bottom)
        XCTAssertEqual(classifier.classify(x: 0.5, y: 0.18), .bottom)
        
        // Top-right corner
        XCTAssertEqual(classifier.classify(x: 0.9, y: 0.9), .topRightCorner)
        XCTAssertEqual(classifier.classify(x: 0.85, y: 0.85), .topRightCorner)
    }
}
