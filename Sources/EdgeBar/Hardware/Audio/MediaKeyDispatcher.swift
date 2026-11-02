import Foundation
import AppKit

public enum MediaKey: Int32 {
    case soundUp = 0
    case soundDown = 1
    case brightnessUp = 2
    case brightnessDown = 3
    case mute = 7
    case playPause = 16
    case nextTrack = 17
    case previousTrack = 18
    case fastForward = 19
    case rewind = 20
}

public final class MediaKeyDispatcher {
    public static let shared = MediaKeyDispatcher()
    
    private init() {}
    
    public func send(key: MediaKey) {
        postKey(key.rawValue, down: true)
        postKey(key.rawValue, down: false)
    }
    
    public func playPause() {
        send(key: .playPause)
    }
    
    public func nextTrack() {
        send(key: .nextTrack)
    }
    
    public func previousTrack() {
        send(key: .previousTrack)
    }
    
    public func volumeUp() {
        send(key: .soundUp)
    }
    
    public func volumeDown() {
        send(key: .soundDown)
    }
    
    public func brightnessUp() {
        send(key: .brightnessUp)
    }
    
    public func brightnessDown() {
        send(key: .brightnessDown)
    }
    
    private func postKey(_ keyCode: Int32, down: Bool) {
        let stateFlag: Int = down ? 0xa00 : 0xb00
        let flags = NSEvent.ModifierFlags(rawValue: UInt(stateFlag))
        let data1 = Int((keyCode << 16) | Int32(stateFlag))
        
        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        
        if let cgEvent = event?.cgEvent {
            cgEvent.post(tap: .cghidEventTap)
        }
    }
}
