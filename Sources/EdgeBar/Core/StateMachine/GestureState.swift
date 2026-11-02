import Foundation

public enum GesturePhase: Equatable, Sendable {
    case idle
    case candidate(touchID: Int32, zone: EdgeZone, startX: Float, startY: Float, startTime: Double)
    case sliding(touchID: Int32, zone: EdgeZone, currentX: Float, currentY: Float)
    case cancelled
}

public struct RecordedTap: Sendable {
    public let zone: EdgeZone
    public let timestamp: Double
    public let x: Float
    public let y: Float
    
    public init(zone: EdgeZone, timestamp: Double, x: Float, y: Float) {
        self.zone = zone
        self.timestamp = timestamp
        self.x = x
        self.y = y
    }
}
