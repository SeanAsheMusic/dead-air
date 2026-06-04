import Foundation
import OSLog

public final class Diagnostics: @unchecked Sendable {
    public static let shared = Diagnostics()

    private let logger = Logger(subsystem: "com.undeniablespectacle.deadair", category: "runtime")
    private let queue = DispatchQueue(label: "dead-air.diagnostics", qos: .utility)
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private var logURL: URL?
    private var redactSensitiveData = true
    private var retentionDays = 30

    private var recentEvents: [LogEvent] = []

    private init() {}

    public func configure(persistJsonl: Bool, redactSensitiveData: Bool = true, retentionDays: Int = 30) {
        queue.async {
            self.redactSensitiveData = redactSensitiveData
            self.retentionDays = max(1, retentionDays)
            guard persistJsonl else {
                self.logURL = nil
                return
            }

            do {
                let directory = try SupportPaths.logsDirectory()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let name = "show-\(formatter.string(from: Date())).jsonl"
                self.logURL = directory.appendingPathComponent(name)
                self.removeExpiredLogs(in: directory)
            } catch {
                self.logURL = nil
            }
        }
    }

    public func record(_ event: LogEvent) {
        logger.info("\(event.source, privacy: .public): \(event.message, privacy: .public)")

        queue.async {
            let storedEvent = self.redactSensitiveData ? self.redacted(event) : event
            self.recentEvents.append(storedEvent)
            if self.recentEvents.count > 250 {
                self.recentEvents.removeFirst(self.recentEvents.count - 250)
            }

            guard let logURL = self.logURL, let data = try? self.encoder.encode(storedEvent) else { return }
            var line = data
            line.append(0x0A)

            if FileManager.default.fileExists(atPath: logURL.path), let handle = try? FileHandle(forWritingTo: logURL) {
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: line)
                    try handle.close()
                } catch {
                    try? handle.close()
                }
            } else {
                try? line.write(to: logURL, options: [.atomic])
            }
        }
    }

    public func snapshot(limit: Int = 250) -> [LogEvent] {
        queue.sync {
            Array(recentEvents.suffix(max(0, limit)))
        }
    }

    private func redacted(_ event: LogEvent) -> LogEvent {
        PrivacyRedactor.redactedLogEvent(event)
    }

    private func removeExpiredLogs(in directory: URL) {
        let cutoff = Date().addingTimeInterval(TimeInterval(-retentionDays * 24 * 60 * 60))
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for file in files where file.lastPathComponent.hasPrefix("show-") && file.pathExtension == "jsonl" {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if modified < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
