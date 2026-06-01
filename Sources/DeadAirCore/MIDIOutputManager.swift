import CoreMIDI
import Foundation

public final class MIDIOutputManager: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dead-air.midi-output", qos: .utility)
    private var client = MIDIClientRef()
    private var outputPort = MIDIPortRef()

    public init() {}

    deinit {
        stop()
    }

    public func send(
        cue: LightingCue,
        config: LightingConfig,
        trigger: LightingCueTrigger,
        completion: @escaping @Sendable (LightingCueSendResult) -> Void
    ) {
        let warnings = cue.validationWarnings(config: config)
        guard warnings.isEmpty else {
            completion(
                LightingCueSendResult(
                    success: false,
                    provider: .midi,
                    trigger: trigger,
                    cueName: cue.name,
                    target: cue.displaySummary,
                    errorMessage: warnings.joined(separator: " ")
                )
            )
            return
        }

        let destinationName = config.midiDestinationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinationUniqueID = config.midiDestinationUniqueID
        let bytes = Self.messageBytes(for: cue)
        queue.async { [weak self] in
            guard let self else { return }
            let result = self.send(bytes: bytes, destinationName: destinationName, destinationUniqueID: destinationUniqueID)
            completion(
                LightingCueSendResult(
                    success: result == nil,
                    provider: .midi,
                    trigger: trigger,
                    cueName: cue.name,
                    target: "\(destinationName) \(cue.displaySummary)",
                    errorMessage: result
                )
            )
        }
    }

    public func stop() {
        if outputPort != 0 {
            MIDIPortDispose(outputPort)
            outputPort = 0
        }
        if client != 0 {
            MIDIClientDispose(client)
            client = 0
        }
    }

    private func send(bytes: [UInt8], destinationName: String, destinationUniqueID: Int?) -> String? {
        if client == 0 {
            let clientStatus = MIDIClientCreate("Dead Air Lighting Out" as CFString, nil, nil, &client)
            guard clientStatus == noErr else {
                return "Could not create MIDI output client (\(clientStatus))."
            }
        }

        if outputPort == 0 {
            let portStatus = MIDIOutputPortCreate(client, "Dead Air Lighting Output" as CFString, &outputPort)
            guard portStatus == noErr else {
                return "Could not create MIDI output port (\(portStatus))."
            }
        }

        guard let destination = Self.destination(named: destinationName, uniqueID: destinationUniqueID) else {
            return "Could not find MIDI destination named \(destinationName)."
        }

        var packetList = MIDIPacketList()
        var packet = MIDIPacketListInit(&packetList)
        guard !bytes.isEmpty else {
            return "MIDI message is empty."
        }
        bytes.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            packet = MIDIPacketListAdd(&packetList, MemoryLayout<MIDIPacketList>.size, packet, 0, bytes.count, baseAddress)
        }

        let sendStatus = MIDISend(outputPort, destination, &packetList)
        guard sendStatus == noErr else {
            return "MIDI send failed (\(sendStatus))."
        }
        return nil
    }

    private static func messageBytes(for cue: LightingCue) -> [UInt8] {
        let channel = UInt8(max(1, min(16, cue.midiChannel)) - 1)
        let number = UInt8(max(0, min(127, cue.midiNumber)))
        let value = UInt8(max(0, min(127, cue.midiValue)))

        switch cue.midiMessageType {
        case .noteOn:
            return [0x90 | channel, number, value]
        case .noteOff:
            return [0x80 | channel, number, value]
        case .controlChange:
            return [0xB0 | channel, number, value]
        case .programChange:
            return [0xC0 | channel, number]
        case .pitchBend:
            let bend = max(0, min(16_383, cue.midiValue * 128))
            return [0xE0 | channel, UInt8(bend & 0x7F), UInt8((bend >> 7) & 0x7F)]
        case .transportStart:
            return [0xFA]
        case .transportStop:
            return [0xFC]
        case .transportContinue:
            return [0xFB]
        }
    }

    public static func availableDestinations() -> [MIDIEndpointDescriptor] {
        let count = MIDIGetNumberOfDestinations()
        return (0..<count).compactMap { index in
            let endpoint = MIDIGetDestination(index)
            guard endpoint != 0 else { return nil }
            return MIDIEndpointDescriptor(name: endpointName(endpoint), uniqueID: endpointUniqueID(endpoint), isOnline: true)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func destination(named name: String, uniqueID: Int?) -> MIDIEndpointRef? {
        let count = MIDIGetNumberOfDestinations()
        if let uniqueID {
            for index in 0..<count {
                let endpoint = MIDIGetDestination(index)
                guard endpoint != 0, endpointUniqueID(endpoint) == uniqueID else { continue }
                return endpoint
            }
        }

        for index in 0..<count {
            let endpoint = MIDIGetDestination(index)
            guard endpoint != 0 else { continue }
            let displayName = endpointName(endpoint)
            if displayName.caseInsensitiveCompare(name) == .orderedSame {
                return endpoint
            }
        }
        return nil
    }

    private static func endpointName(_ endpoint: MIDIEndpointRef) -> String {
        var unmanagedName: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &unmanagedName)
        guard status == noErr, let name = unmanagedName?.takeRetainedValue() else { return "Unknown MIDI Destination" }
        return name as String
    }

    private static func endpointUniqueID(_ endpoint: MIDIEndpointRef) -> Int? {
        var uniqueID = MIDIUniqueID()
        let status = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
        guard status == noErr else { return nil }
        return Int(uniqueID)
    }
}
