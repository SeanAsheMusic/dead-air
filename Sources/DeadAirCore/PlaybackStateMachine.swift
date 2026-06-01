import Foundation

public struct PlaybackStateMachine: Sendable {
    public private(set) var state: PlaybackState

    public init(state: PlaybackState = .launching) {
        self.state = state
    }

    @discardableResult
    public mutating func apply(_ command: TransitionCommand) -> PlaybackState {
        switch command {
        case .panic:
            state = .panicMuted
        case .clearPanic, .arm:
            if state == .panicMuted || state == .launching || state == .degraded {
                state = .readyMuted
            }
        case .disarm:
            break
        case .fadeIn:
            if state == .readyMuted || state == .panicMuted {
                state = .fadingIn
            }
        case .fadeOut:
            if state == .audible || state == .fadingIn {
                state = .fadingOut
            }
        case .nextBed:
            break
        case .setLevel:
            break
        case .heartbeat:
            break
        }
        return state
    }

    public mutating func markReadyMuted() {
        state = .readyMuted
    }

    public mutating func markAudible() {
        state = .audible
    }

    public mutating func markDegraded() {
        state = .degraded
    }
}
