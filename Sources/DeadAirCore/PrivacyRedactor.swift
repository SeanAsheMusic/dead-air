import Foundation

public enum PrivacyRedactor {
    public static let marker = "[redacted]"

    private static let uuidPattern = #"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b"#
    private static let homePathPattern = #"(?i)(?:file://)?/Users/[^/\s"]+(?:/[^\s"]*)?"#
    private static let volumePathPattern = #"(?i)(?:file://)?/Volumes/[^/\s"]+(?:/[^\s"]*)?"#
    private static let networkPathPattern = #"(?i)(?:smb|afp|nfs)://[^\s"]+"#
    private static let homeRelativePathPattern = #"~/[^\s"]*"#
    private static let ipv4Pattern = #"\b(?:\d{1,3}\.){3}\d{1,3}(?::\d{1,5})?\b"#
    private static let localHostnamePattern = #"(?i)\b[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:local|lan|home)\b"#

    public static func redact(_ value: String?) -> String? {
        guard let value else { return nil }
        return redact(value)
    }

    public static func redact(_ value: String) -> String {
        var result = value
        for pattern in [networkPathPattern, homePathPattern, volumePathPattern, homeRelativePathPattern, uuidPattern, ipv4Pattern, localHostnamePattern] {
            result = replacing(pattern: pattern, in: result)
        }
        return result
    }

    /// Redacts path/identifier patterns plus literal occurrences of user-provided
    /// names (profiles, beds, cues, MIDI/audio devices). Matching is
    /// case-insensitive; longer terms are replaced first so overlapping names
    /// cannot leave fragments behind.
    public static func redact(_ value: String, sensitiveTerms: [String]) -> String {
        var result = redact(value)
        for term in normalizedTerms(sensitiveTerms) {
            result = replacing(pattern: "(?i)" + NSRegularExpression.escapedPattern(for: term), in: result)
        }
        return result
    }

    public static func redactedOrEmpty(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : marker
    }

    public static func redactedOrNil(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return marker
    }

    public static func redactedDeviceID(_ value: Int?) -> Int? {
        value == nil ? nil : 0
    }

    /// Loopback targets stay readable because they are identical for every
    /// user; anything else (venue console IPs, mDNS names) is redacted.
    public static func redactedHost(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let loopback: Set<String> = ["", "127.0.0.1", "localhost", "::1"]
        return loopback.contains(trimmed) ? value : marker
    }

    public static func redactedLogEvent(_ event: LogEvent) -> LogEvent {
        redactedLogEvent(event, sensitiveTerms: [])
    }

    public static func redactedLogEvent(_ event: LogEvent, sensitiveTerms: [String]) -> LogEvent {
        var copy = event
        if let raw = copy.raw {
            copy.raw = redact(raw, sensitiveTerms: sensitiveTerms)
        }
        copy.message = redact(copy.message, sensitiveTerms: sensitiveTerms)
        if let uid = copy.audioDeviceUID, !uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.audioDeviceUID = marker
        }
        return copy
    }

    public static func redactedConfig(_ config: AppConfig) -> AppConfig {
        var redacted = config
        redacted.audio.preferredOutputUID = redactedOrNil(redacted.audio.preferredOutputUID)
        redacted.osc.host = redactedHost(redacted.osc.host)
        redacted.lighting.lightkeyHost = redactedHost(redacted.lighting.lightkeyHost)
        redacted.midi.virtualDestinationName = redactedOrEmpty(redacted.midi.virtualDestinationName)
        redacted.midi.iacBusName = redactedOrEmpty(redacted.midi.iacBusName)
        redacted.midi.iacSourceUniqueID = redactedDeviceID(redacted.midi.iacSourceUniqueID)
        redacted.midi.iacSourceName = redactedOrNil(redacted.midi.iacSourceName)
        redacted.midi.mappings = redacted.midi.mappings.map { mapping in
            var copy = mapping
            copy.sourceContains = redactedOrNil(copy.sourceContains)
            return copy
        }
        redacted.lighting.midiDestinationName = redactedOrEmpty(redacted.lighting.midiDestinationName)
        redacted.lighting.midiDestinationUniqueID = redactedDeviceID(redacted.lighting.midiDestinationUniqueID)
        redacted.lighting.cues = []
        return redacted
    }

    private static func normalizedTerms(_ terms: [String]) -> [String] {
        var seen = Set<String>()
        return terms
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 && seen.insert($0.lowercased()).inserted }
            .sorted { $0.count > $1.count }
    }

    private static func replacing(pattern: String, in value: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: marker)
    }
}
