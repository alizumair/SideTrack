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
    
    public init(edgeWidth: Float = 0.18, edgeHeight: Float = 0.18, cornerSize: Float = 0.20) {
        self.edgeWidth = edgeWidth
        self.edgeHeight = edgeHeight
        self.cornerSize = cornerSize
    }
    
    public func classify(x: Float, y: Float) -> EdgeZone {
        // Check top-right corner first (intersection of right edge & top area)
        if x >= (1.0 - cornerSize) && y >= (1.0 - cornerSize) {
            return .topRightCorner
        }
        
        // Left edge strip
        if x <= edgeWidth {
            return .left
        }
        
        // Right edge strip
        if x >= (1.0 - edgeWidth) {
            return .right
        }
        
        // Bottom edge strip (excluding left/right corners)
        if y <= edgeHeight {
            return .bottom
        }
        
        return .middle
    }
}
