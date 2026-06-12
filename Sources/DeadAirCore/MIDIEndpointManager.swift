import CoreMIDI
import Foundation

public final class MIDIEndpointManager: @unchecked Sendable {
    private var client = MIDIClientRef()
    private var virtualDestination = MIDIEndpointRef()
    private var inputPort = MIDIPortRef()
    private let routerQueue = DispatchQueue(label: "dead-air.midi-router", qos: .userInitiated)
    private var config = MIDIConfig()
    private var handler: (@Sendable (RoutedMIDIEvent) -> Void)?

    public init() {}

    deinit {
        stop()
    }

    public func start(config: MIDIConfig, handler: @escaping @Sendable (RoutedMIDIEvent) -> Void) throws {
        stop()
        self.config = config
        self.handler = handler

        var status = MIDIClientCreateWithBlock("Dead Air" as CFString, &client) { _ in
            Diagnostics.shared.record(LogEvent(source: "midi", message: "MIDI topology changed"))
        }
        try check(status, message: "Could not create MIDI client.")

        if config.mode == .virtualDestination || config.mode == .both {
            status = MIDIDestinationCreateWithBlock(client, config.virtualDestinationName as CFString, &virtualDestination) { [weak self] packetList, _ in
                self?.receive(packetList: packetList, source: .midiVirtual, sourceName: config.virtualDestinationName)
            }
            try check(status, message: "Could not create virtual MIDI destination.")
            Diagnostics.shared.record(LogEvent(source: "midi", message: "virtual destination online", raw: config.virtualDestinationName))
        }

        if config.mode == .iacSource || config.mode == .both {
            status = MIDIInputPortCreateWithBlock(client, "Dead Air IAC Input" as CFString, &inputPort) { [weak self] packetList, _ in
                self?.receive(packetList: packetList, source: .midiIAC, sourceName: self?.config.iacSourceName ?? self?.config.iacBusName ?? "IAC")
            }
            try check(status, message: "Could not create MIDI input port.")
            connectIACSources(named: config.iacBusName)
        }
    }

    public func stop() {
        if virtualDestination != 0 {
            MIDIEndpointDispose(virtualDestination)
            virtualDestination = 0
        }
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
            inputPort = 0
        }
        if client != 0 {
            MIDIClientDispose(client)
            client = 0
        }
    }

    private func receive(packetList: UnsafePointer<MIDIPacketList>, source: CommandSource, sourceName: String) {
        let packets = Self.packetBytes(from: packetList)
        let configSnapshot = config
        let handlerSnapshot = handler

        routerQueue.async {
            for bytes in packets {
                let summary = "\(sourceName) " + bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
                guard let event = MIDIParser.event(from: bytes, sourceName: sourceName) else { continue }
                let command = MIDIParser.command(from: event, config: configSnapshot)
                handlerSnapshot?(RoutedMIDIEvent(event: event, command: command, source: source, rawSummary: "\(summary) | \(event.displaySummary)"))
            }
        }
    }

    private func connectIACSources(named busName: String) {
        let sourceCount = MIDIGetNumberOfSources()
        var connected = 0
        for index in 0..<sourceCount {
            let source = MIDIGetSource(index)
            guard source != 0 else { continue }
            let displayName = Self.endpointName(source)
            let uniqueID = Self.endpointUniqueID(source)
            let exactIDMatch = config.iacSourceUniqueID != nil && config.iacSourceUniqueID == uniqueID
            let exactNameMatch = config.iacSourceUniqueID == nil && displayName.caseInsensitiveCompare(busName) == .orderedSame
            guard exactIDMatch || exactNameMatch else { continue }
            let status = MIDIPortConnectSource(inputPort, source, nil)
            if status == noErr {
                connected += 1
                Diagnostics.shared.record(LogEvent(source: "midi", message: "connected MIDI source", raw: "\(displayName) \(uniqueID.map { "#\($0)" } ?? "")"))
            }
        }
        if connected == 0 {
            Diagnostics.shared.record(LogEvent(source: "midi", message: "IAC source not found", raw: busName))
        }
    }

    public static func availableSources() -> [MIDIEndpointDescriptor] {
        endpointDescriptors(count: MIDIGetNumberOfSources, endpoint: MIDIGetSource)
    }

    public static func availableDestinations() -> [MIDIEndpointDescriptor] {
        endpointDescriptors(count: MIDIGetNumberOfDestinations, endpoint: MIDIGetDestination)
    }

    private static func endpointName(_ endpoint: MIDIEndpointRef) -> String {
        var unmanagedName: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &unmanagedName)
        guard status == noErr, let name = unmanagedName?.takeRetainedValue() else { return "Unknown MIDI Source" }
        return name as String
    }

    private static func endpointUniqueID(_ endpoint: MIDIEndpointRef) -> Int? {
        var uniqueID = MIDIUniqueID()
        let status = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
        guard status == noErr else { return nil }
        return Int(uniqueID)
    }

    private static func endpointDescriptors(
        count: () -> Int,
        endpoint: (Int) -> MIDIEndpointRef
    ) -> [MIDIEndpointDescriptor] {
        (0..<count()).compactMap { index in
            let endpointRef = endpoint(index)
            guard endpointRef != 0 else { return nil }
            return MIDIEndpointDescriptor(name: endpointName(endpointRef), uniqueID: endpointUniqueID(endpointRef), isOnline: true)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Reads every packet in place. Packets in a `MIDIPacketList` are
    /// variable-length: copying a `MIDIPacket` to a local and advancing with
    /// `MIDIPacketNext` on that copy walks off the stack frame for any packet
    /// longer than the declared 256-byte layout (large sysex) and crashes the
    /// CoreMIDI receive thread with a stack-guard violation.
    public static func packetBytes(from packetList: UnsafePointer<MIDIPacketList>) -> [[UInt8]] {
        var result: [[UInt8]] = []
        result.reserveCapacity(Int(packetList.pointee.numPackets))
        guard let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data) else { return result }

        for packetPointer in packetList.unsafeSequence() {
            let length = Int(packetPointer.pointee.length)
            guard length > 0 else { continue }
            let dataPointer = UnsafeRawPointer(packetPointer).advanced(by: dataOffset)
            result.append([UInt8](UnsafeRawBufferPointer(start: dataPointer, count: length)))
        }

        return result
    }

    private func check(_ status: OSStatus, message: String) throws {
        if status != noErr {
            throw NSError(domain: "DeadAir.MIDI", code: Int(status), userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
