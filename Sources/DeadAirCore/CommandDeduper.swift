import Foundation

public final class CommandDeduper: @unchecked Sendable {
    private let window: TimeInterval
    private var lastSeen: [String: Date] = [:]
    private let lock = NSLock()

    public init(window: TimeInterval = 0.250) {
        self.window = window
    }

    public func shouldAccept(_ command: TransitionCommand, source: CommandSource, at date: Date = Date()) -> Bool {
        if case .panic = command {
            return true
        }

        let key = "\(source.rawValue):\(command.key)"
        lock.lock()
        defer { lock.unlock() }

        if let last = lastSeen[key], date.timeIntervalSince(last) < window {
            return false
        }

        lastSeen[key] = date
        return true
    }
}
