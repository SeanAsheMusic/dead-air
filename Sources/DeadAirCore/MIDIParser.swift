import Foundation

public enum MIDIParser {
    public static func command(from bytes: [UInt8], config: MIDIConfig) -> TransitionCommand? {
        guard let event = event(from: bytes) else { return nil }
        return command(from: event, config: config)
    }

    public static func command(from event: MIDIInputEvent, config: MIDIConfig) -> TransitionCommand? {
        for mapping in config.mappings where mapping.matches(event) {
            return mapping.action.command(from: event)
        }
        return nil
    }

    public static func event(from bytes: [UInt8], sourceName: String? = nil, receivedAt: Date = Date()) -> MIDIInputEvent? {
        guard !bytes.isEmpty else { return nil }
        let status = bytes[0]
        let messageType = status & 0xF0
        let channel = Int(status & 0x0F) + 1

        switch messageType {
        case 0x80:
            guard bytes.count >= 3 else { return nil }
            return MIDIInputEvent(
                messageType: .noteOff,
                channel: channel,
                number: Int(bytes[1]),
                value: Int(bytes[2]),
                sourceName: sourceName,
                rawBytes: bytes,
                receivedAt: receivedAt
            )
        case 0x90:
            guard bytes.count >= 3 else { return nil }
            let note = Int(bytes[1])
            let velocity = Int(bytes[2])
            return MIDIInputEvent(
                messageType: velocity == 0 ? .noteOff : .noteOn,
                channel: channel,
                number: note,
                value: velocity,
                sourceName: sourceName,
                rawBytes: bytes,
                receivedAt: receivedAt
            )
        case 0xB0:
            guard bytes.count >= 3 else { return nil }
            return MIDIInputEvent(
                messageType: .controlChange,
                channel: channel,
                number: Int(bytes[1]),
                value: Int(bytes[2]),
                sourceName: sourceName,
                rawBytes: bytes,
                receivedAt: receivedAt
            )
        case 0xC0:
            guard bytes.count >= 2 else { return nil }
            return MIDIInputEvent(
                messageType: .programChange,
                channel: channel,
                number: Int(bytes[1]),
                sourceName: sourceName,
                rawBytes: bytes,
                receivedAt: receivedAt
            )
        case 0xE0:
            guard bytes.count >= 3 else { return nil }
            let value = Int(bytes[1]) | (Int(bytes[2]) << 7)
            return MIDIInputEvent(
                messageType: .pitchBend,
                channel: channel,
                value: value,
                sourceName: sourceName,
                rawBytes: bytes,
                receivedAt: receivedAt
            )
        default:
            switch status {
            case 0xFA:
                return MIDIInputEvent(messageType: .transportStart, sourceName: sourceName, rawBytes: bytes, receivedAt: receivedAt)
            case 0xFB:
                return MIDIInputEvent(messageType: .transportContinue, sourceName: sourceName, rawBytes: bytes, receivedAt: receivedAt)
            case 0xFC:
                return MIDIInputEvent(messageType: .transportStop, sourceName: sourceName, rawBytes: bytes, receivedAt: receivedAt)
            default:
                return nil
            }
        }
    }
}
