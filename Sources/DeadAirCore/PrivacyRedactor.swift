import Foundation

public enum PrivacyRedactor {
    public static let marker = "[redacted]"

    private static let uuidPattern = #"\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b"#
    private static let homePathPattern = #"(?i)(?:file://)?/Users/[^/\s"]+(?:/[^\s"]*)?"#
    private static let volumePathPattern = #"(?i)(?:file://)?/Volumes/[^/\s"]+(?:/[^\s"]*)?"#
    private static let networkPathPattern = #"(?i)(?:smb|afp|nfs)://[^\s"]+"#
    private static let homeRelativePathPattern = #"~/[^\s"]*"#

    public static func redact(_ value: String?) -> String? {
        guard let value else { return nil }
        return redact(value)
    }

    public static func redact(_ value: String) -> String {
        var result = value
        for pattern in [networkPathPattern, homePathPattern, volumePathPattern, homeRelativePathPattern, uuidPattern] {
            result = replacing(pattern: pattern, in: result)
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

    public static func redactedLogEvent(_ event: LogEvent) -> LogEvent {
        var copy = event
        copy.raw = redact(copy.raw)
        if let raw = copy.raw, raw != event.raw, raw.contains(marker) {
            copy.raw = raw
        }
        if let uid = copy.audioDeviceUID, !uid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            copy.audioDeviceUID = marker
        }
        return copy
    }

    public static func redactedConfig(_ config: AppConfig) -> AppConfig {
        var redacted = config
        redacted.audio.preferredOutputUID = redactedOrNil(redacted.audio.preferredOutputUID)
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

    private static func replacing(pattern: String, in value: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(in: value, range: range, withTemplate: marker)
    }
}
