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
    public let leftWidth: Float
    public let rightWidth: Float
    public let topHeight: Float
    public let bottomHeight: Float
    public let cornerSize: Float
    
    // Backward-compatibility aliases
    public var edgeWidth: Float { leftWidth }
    public var edgeHeight: Float { bottomHeight }
    
    public init(
        leftWidth: Float,
        rightWidth: Float,
        topHeight: Float,
        bottomHeight: Float,
        cornerSize: Float = 0.10
    ) {
        self.leftWidth = leftWidth
        self.rightWidth = rightWidth
        self.topHeight = topHeight
        self.bottomHeight = bottomHeight
        self.cornerSize = cornerSize
    }
    
    public init(edgeWidth: Float = 0.10, edgeHeight: Float = 0.10, cornerSize: Float = 0.10) {
        self.leftWidth = edgeWidth
        self.rightWidth = edgeWidth
        self.topHeight = edgeHeight
        self.bottomHeight = edgeHeight
        self.cornerSize = cornerSize
    }
    
    public func classify(x: Float, y: Float) -> EdgeZone {
        // 1. Top-Right Corner (dedicated area for double-tap mute)
        if x >= (1.0 - cornerSize) && y >= (1.0 - cornerSize) {
            return .topRightCorner
        }
        
        // 2. Bottom Edge strip: dedicated horizontal control strip across the entire bottom
        if y <= bottomHeight {
            return .bottom
        }
        
        // 3. Left Edge strip
        if x <= leftWidth {
            return .left
        }
        
        // 4. Right Edge strip
        if x >= (1.0 - rightWidth) {
            return .right
        }
        
        // 5. Standard trackpad surface (normal macOS cursor movement and gestures)
        return .middle
    }
}
