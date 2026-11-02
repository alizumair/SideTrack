import Foundation

public enum EdgeZone: String, Equatable, Sendable {
    case left
    case right
    case bottom
    case topRightCorner
    case middle
    
    public var isEdge: Bool {
        self != .middle
    }
}

public struct EdgeClassifier {
    public let edgeWidth: Float
    public let edgeHeight: Float
    public let cornerSize: Float
    
    public init(edgeWidth: Float = 0.18, edgeHeight: Float = 0.18, cornerSize: Float = 0.12) {
        self.edgeWidth = edgeWidth
        self.edgeHeight = edgeHeight
        self.cornerSize = cornerSize
    }
    
    public func classify(x: Float, y: Float) -> EdgeZone {
        // 1. Top-Right Corner (compact area dedicated for double-tap mute)
        if x >= (1.0 - cornerSize) && y >= (1.0 - cornerSize) {
            return .topRightCorner
        }
        
        // 2. Left Edge strip (dedicated column for display brightness)
        if x <= edgeWidth {
            return .left
        }
        
        // 3. Right Edge strip (dedicated column for volume)
        if x >= (1.0 - edgeWidth) {
            return .right
        }
        
        // 4. Bottom Edge strip: ONLY the bottom area BETWEEN left and right strips!
        // This strictly prevents the left and right sliders from interfering with media skipping.
        if y <= edgeHeight && x > edgeWidth && x < (1.0 - edgeWidth) {
            return .bottom
        }
        
        // 5. Standard trackpad surface (for macOS gestures and mouse movement)
        return .middle
    }
}
