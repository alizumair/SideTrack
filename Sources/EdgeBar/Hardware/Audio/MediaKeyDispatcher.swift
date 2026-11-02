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
    
    private typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int32, AnyObject?) -> DarwinBoolean
    private var sendMediaRemoteCommand: MRMediaRemoteSendCommandFunction?
    
    private init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW) {
            if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
                sendMediaRemoteCommand = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFunction.self)
            }
        }
    }
    
    public func playPause() {
        if let sendMR = sendMediaRemoteCommand {
            _ = sendMR(2, nil) // kMRTogglePlayPause = 2
        } else {
            postKey(MediaKey.playPause.rawValue, down: true)
            postKey(MediaKey.playPause.rawValue, down: false)
        }
    }
    
    public func nextTrack() {
        if let sendMR = sendMediaRemoteCommand {
            _ = sendMR(4, nil) // kMRNextTrack = 4
        } else {
            postKey(MediaKey.nextTrack.rawValue, down: true)
            postKey(MediaKey.nextTrack.rawValue, down: false)
        }
    }
    
    public func previousTrack() {
        if let sendMR = sendMediaRemoteCommand {
            _ = sendMR(5, nil) // kMRPreviousTrack = 5
        } else {
            postKey(MediaKey.previousTrack.rawValue, down: true)
            postKey(MediaKey.previousTrack.rawValue, down: false)
        }
    }
    
    public func volumeUp() {
        postKey(MediaKey.soundUp.rawValue, down: true)
        postKey(MediaKey.soundUp.rawValue, down: false)
    }
    
    public func volumeDown() {
        postKey(MediaKey.soundDown.rawValue, down: true)
        postKey(MediaKey.soundDown.rawValue, down: false)
    }
    
    public func brightnessUp() {
        postKey(MediaKey.brightnessUp.rawValue, down: true)
        postKey(MediaKey.brightnessUp.rawValue, down: false)
    }
    
    public func brightnessDown() {
        postKey(MediaKey.brightnessDown.rawValue, down: true)
        postKey(MediaKey.brightnessDown.rawValue, down: false)
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
