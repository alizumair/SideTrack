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
    
    public init(edgeWidth: Float = 0.10, edgeHeight: Float = 0.10, cornerSize: Float = 0.10) {
        self.edgeWidth = edgeWidth
        self.edgeHeight = edgeHeight
        self.cornerSize = cornerSize
    }
    
    public func classify(x: Float, y: Float) -> EdgeZone {
        // 1. Top-Right Corner (dedicated area for double-tap mute)
        if x >= (1.0 - cornerSize) && y >= (1.0 - cornerSize) {
            return .topRightCorner
        }
        
        // 2. Bottom Edge strip: dedicated horizontal media control strip across the entire bottom!
        // Prioritizing this ensures swiping to skip tracks is never stolen by left/right edge columns.
        if y <= edgeHeight {
            return .bottom
        }
        
        // 3. Left Edge strip (dedicated column for display brightness)
        if x <= edgeWidth {
            return .left
        }
        
        // 4. Right Edge strip (dedicated column for volume)
        if x >= (1.0 - edgeWidth) {
            return .right
        }
        
        // 5. Standard trackpad surface (normal macOS cursor movement and gestures)
        return .middle
    }
}
