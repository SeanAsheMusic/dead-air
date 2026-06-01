import Foundation

public enum OSCParser {
    public static func command(from data: Data) -> TransitionCommand? {
        guard !data.isEmpty else { return nil }
        let strings = oscStrings(from: data)
        guard let path = strings.first else {
            return String(data: data, encoding: .utf8).flatMap(commandFromPlainText)
        }

        let payload = String(data: data, encoding: .utf8) ?? ""
        return command(fromPath: path, strings: strings, rawText: payload)
    }

    public static func commandFromPlainText(_ text: String) -> TransitionCommand? {
        let pieces = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)
        guard let path = pieces.first else { return nil }
        return command(fromPath: path, strings: pieces, rawText: text)
    }

    private static func command(fromPath path: String, strings: [String], rawText: String) -> TransitionCommand? {
        switch path {
        case "/lbk/fadeIn", "/deadAir/fadeIn", "/deadair/fadeIn":
            return .fadeIn
        case "/lbk/fadeOut", "/deadAir/fadeOut", "/deadair/fadeOut":
            return .fadeOut
        case "/lbk/panic", "/deadAir/panic", "/deadair/panic":
            return .panic
        case "/lbk/nextBed", "/deadAir/nextBed", "/deadair/nextBed":
            return .nextBed
        case "/lbk/arm", "/deadAir/arm", "/deadair/arm":
            return .arm
        case "/lbk/disarm", "/deadAir/disarm", "/deadair/disarm":
            return .disarm
        case "/lbk/level", "/deadAir/level", "/deadair/level":
            if let value = numericArgument(strings: strings, rawText: rawText) {
                return .setLevel(max(0, min(1, value)))
            }
            return nil
        case "/lbk/heartbeat", "/deadAir/heartbeat", "/deadair/heartbeat":
            let interval = integerArgument(strings: strings, rawText: rawText, index: 1)
            let playing = booleanArgument(strings: strings, rawText: rawText, index: 2)
            let song = strings.dropFirst(3).first
            let uuid = strings.dropFirst(4).first
            return .heartbeat(HeartbeatPayload(intervalMs: interval, isPlaying: playing, songRef: song, uuid: uuid))
        default:
            return nil
        }
    }

    private static func numericArgument(strings: [String], rawText: String) -> Double? {
        if strings.count > 1, let value = Double(strings[1]) {
            return value
        }
        return rawText
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\0" })
            .dropFirst()
            .compactMap { Double($0) }
            .first
    }

    private static func integerArgument(strings: [String], rawText: String, index: Int) -> Int? {
        if strings.indices.contains(index), let value = Int(strings[index]) {
            return value
        }
        let parts = rawText.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\0" }).map(String.init)
        guard parts.indices.contains(index) else { return nil }
        return Int(parts[index])
    }

    private static func booleanArgument(strings: [String], rawText: String, index: Int) -> Bool? {
        let value: String?
        if strings.indices.contains(index) {
            value = strings[index]
        } else {
            let parts = rawText.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\0" }).map(String.init)
            value = parts.indices.contains(index) ? parts[index] : nil
        }

        switch value?.lowercased() {
        case "1", "true", "yes", "playing": return true
        case "0", "false", "no", "stopped": return false
        default: return nil
        }
    }

    private static func oscStrings(from data: Data) -> [String] {
        var strings: [String] = []
        var index = data.startIndex

        while index < data.endIndex {
            var end = index
            while end < data.endIndex, data[end] != 0 {
                end = data.index(after: end)
            }

            guard end > index else {
                index = data.index(after: index)
                continue
            }

            if let string = String(data: data[index..<end], encoding: .utf8), !string.hasPrefix(",") {
                strings.append(string)
            }

            let consumed = data.distance(from: index, to: end) + 1
            let padding = (4 - (consumed % 4)) % 4
            index = data.index(index, offsetBy: consumed + padding, limitedBy: data.endIndex) ?? data.endIndex
        }

        return strings
    }
}
