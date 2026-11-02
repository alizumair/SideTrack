import Foundation

public struct MTPoint {
    public var x: Float
    public var y: Float
    
    public init(x: Float = 0, y: Float = 0) {
        self.x = x
        self.y = y
    }
}

public struct MTVector {
    public var position: MTPoint
    public var velocity: MTPoint
    
    public init(position: MTPoint = MTPoint(), velocity: MTPoint = MTPoint()) {
        self.position = position
        self.velocity = velocity
    }
}

public enum TouchContactState: Int32, Sendable {
    case notTouching = 0
    case starting = 1
    case hovering = 2
    case making = 3
    case touching = 4
    case breaking = 5
    case lingering = 6
    case cancelled = 7
    
    public var isActive: Bool {
        switch self {
        case .starting, .making, .touching:
            return true
        default:
            return false
        }
    }
    
    public var isTerminating: Bool {
        switch self {
        case .breaking, .lingering, .notTouching, .cancelled:
            return true
        default:
            return false
        }
    }
}

public struct MTTouchRaw {
    public var frame: Int32
    public var timestamp: Double
    public var identifier: Int32
    public var state: Int32
    public var fingerId: Int32
    public var handId: Int32
    public var normalized: MTVector
    public var size: Float
    public var zero1: Int32
    public var angle: Float
    public var majorAxis: Float
    public var minorAxis: Float
    public var unknown: MTVector
    public var zero2_0: Int32
    public var zero2_1: Int32
    public var density: Float
}

public struct TrackpadContact: Identifiable, Sendable {
    public let id: Int32
    public let x: Float            // 0.0 (left) to 1.0 (right)
    public let y: Float            // 0.0 (bottom) to 1.0 (top)
    public let vx: Float           // velocity x
    public let vy: Float           // velocity y
    public let state: TouchContactState
    public let size: Float
    public let timestamp: Double
    
    public init(
        id: Int32,
        x: Float,
        y: Float,
        vx: Float = 0,
        vy: Float = 0,
        state: TouchContactState,
        size: Float = 0,
        timestamp: Double = 0
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.state = state
        self.size = size
        self.timestamp = timestamp
    }
    
    public init(raw: MTTouchRaw) {
        self.id = raw.identifier
        self.x = raw.normalized.position.x
        self.y = raw.normalized.position.y
        self.vx = raw.normalized.velocity.x
        self.vy = raw.normalized.velocity.y
        self.state = TouchContactState(rawValue: raw.state) ?? .touching
        self.size = raw.size
        self.timestamp = raw.timestamp
    }
}
