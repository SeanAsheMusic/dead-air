import Foundation

public enum PlaybackState: String, Codable, CaseIterable, Sendable {
    case launching
    case readyMuted
    case fadingIn
    case audible
    case fadingOut
    case panicMuted
    case degraded

    public var displayName: String {
        switch self {
        case .launching: "Launching"
        case .readyMuted: "Ready Muted"
        case .fadingIn: "Fading In"
        case .audible: "Audible"
        case .fadingOut: "Fading Out"
        case .panicMuted: "Panic Muted"
        case .degraded: "Degraded"
        }
    }
}

public enum CommandSource: String, Codable, Sendable {
    case midiVirtual
    case midiIAC
    case oscLocal
    case ui
    case heartbeat
}

public struct HeartbeatPayload: Codable, Equatable, Sendable {
    public var intervalMs: Int?
    public var isPlaying: Bool?
    public var songRef: String?
    public var uuid: String?
    public var receivedAt: Date

    public init(intervalMs: Int? = nil, isPlaying: Bool? = nil, songRef: String? = nil, uuid: String? = nil, receivedAt: Date = Date()) {
        self.intervalMs = intervalMs
        self.isPlaying = isPlaying
        self.songRef = songRef
        self.uuid = uuid
        self.receivedAt = receivedAt
    }
}

public enum TransitionCommand: Equatable, Sendable {
    case fadeIn
    case fadeOut
    case panic
    case nextBed
    case arm
    case disarm
    case clearPanic
    case setLevel(Double)
    case heartbeat(HeartbeatPayload)

    public var key: String {
        switch self {
        case .fadeIn: "fadeIn"
        case .fadeOut: "fadeOut"
        case .panic: "panic"
        case .nextBed: "nextBed"
        case .arm: "arm"
        case .disarm: "disarm"
        case .clearPanic: "clearPanic"
        case .setLevel(let value): "setLevel:\(String(format: "%.3f", value))"
        case .heartbeat(let payload): "heartbeat:\(payload.uuid ?? payload.songRef ?? "anonymous")"
        }
    }

    public var displayName: String {
        switch self {
        case .fadeIn: "Fade In"
        case .fadeOut: "Fade Out"
        case .panic: "Panic Mute"
        case .nextBed: "Next Bed"
        case .arm: "Arm Show Mode"
        case .disarm: "Disarm Show Mode"
        case .clearPanic: "Clear Panic"
        case .setLevel(let value): "Set Level \(Int(value * 100))%"
        case .heartbeat: "Heartbeat"
        }
    }
}

public struct RoutedCommand: Equatable, Sendable {
    public var command: TransitionCommand
    public var source: CommandSource
    public var rawSummary: String
    public var receivedAt: Date

    public init(command: TransitionCommand, source: CommandSource, rawSummary: String, receivedAt: Date = Date()) {
        self.command = command
        self.source = source
        self.rawSummary = rawSummary
        self.receivedAt = receivedAt
    }
}

public enum BedAdvanceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case manualContinuous
    case autoPrepareNextOnFadeOut
    case autoCrossfadeAtEnd

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .manualContinuous: "Continuous"
        case .autoPrepareNextOnFadeOut: "Auto-Prep"
        case .autoCrossfadeAtEnd: "Auto-Crossfade"
        }
    }

    public var helpText: String {
        switch self {
        case .manualContinuous:
            "Current bed loops until you manually select or advance to another bed."
        case .autoPrepareNextOnFadeOut:
            "After a fade-out completes, Dead Air silently primes the next bed in the playlist."
        case .autoCrossfadeAtEnd:
            "When an audible bed reaches its end, Dead Air crossfades into the next bed."
        }
    }
}

public enum LibraryStorageMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case managedCopy
    case externalReference

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .managedCopy: "Copy"
        case .externalReference: "Reference"
        }
    }

    public var helpText: String {
        switch self {
        case .managedCopy:
            "Copies imported audio into Dead Air's managed library. Best for show reliability."
        case .externalReference:
            "Leaves audio where it is and stores a sandbox bookmark. Best when you do not want duplicates."
        }
    }
}

public enum DeadAirUIMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case simple
    case advanced

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .simple: "Simple"
        case .advanced: "Advanced"
        }
    }
}

public enum DeadAirAppearanceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case showDark
    case light
    case dark

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: "System"
        case .showDark: "Show Dark"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

public enum ShowSetupPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case genericDAWVirtualMIDI
    case abletonLightkey
    case abletonLuminescence
    case showOffBridge
    case iacLegacyDAW
    case djManual
    case qlabOSC
    case referenceExternalDrive

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .genericDAWVirtualMIDI: "Generic DAW"
        case .abletonLightkey: "Ableton + Lightkey"
        case .abletonLuminescence: "Ableton + Luminescence"
        case .showOffBridge: "Show Off Bridge"
        case .iacLegacyDAW: "IAC / Legacy DAW"
        case .djManual: "DJ Manual"
        case .qlabOSC: "QLab / OSC"
        case .referenceExternalDrive: "External Drive"
        }
    }

    public var helpText: String {
        switch self {
        case .genericDAWVirtualMIDI:
            "Creates a simple virtual MIDI input for any DAW or controller that can send MIDI notes or CC."
        case .abletonLightkey:
            "Uses Dead Air's virtual MIDI input and enables Lightkey OSC at 127.0.0.1:21600."
        case .abletonLuminescence:
            "Uses Dead Air's virtual MIDI input and sends named cue triggers to Luminescence OSC at 127.0.0.1:9001."
        case .showOffBridge:
            "Keeps Dead Air local while publishing show notifications to Show Off's OSC server at 127.0.0.1:39051."
        case .iacLegacyDAW:
            "Listens to a specific IAC bus for older DAW routing workflows."
        case .djManual:
            "Keeps controls manual-first with continuous beds and no lighting by default."
        case .qlabOSC:
            "Keeps MIDI optional and prepares localhost OSC control from QLab or similar show-control tools."
        case .referenceExternalDrive:
            "References files in place and stores security-scoped bookmarks instead of copying audio."
        }
    }

    public var profileName: String {
        switch self {
        case .genericDAWVirtualMIDI: "Generic DAW Virtual MIDI"
        case .abletonLightkey: "Ableton + Lightkey"
        case .abletonLuminescence: "Ableton + Luminescence"
        case .showOffBridge: "Show Off Bridge"
        case .iacLegacyDAW: "IAC Legacy DAW"
        case .djManual: "DJ Manual"
        case .qlabOSC: "QLab OSC"
        case .referenceExternalDrive: "External Drive Reference"
        }
    }
}

public enum MIDIMappableAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case fadeIn
    case fadeOut
    case panic
    case nextBed
    case arm
    case disarm
    case level

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fadeIn: "Fade In"
        case .fadeOut: "Fade Out"
        case .panic: "Panic Mute"
        case .nextBed: "Next Bed"
        case .arm: "Arm Show Mode"
        case .disarm: "Disarm Show Mode"
        case .level: "Target Level"
        }
    }

    public func command(from event: MIDIInputEvent) -> TransitionCommand {
        switch self {
        case .fadeIn: .fadeIn
        case .fadeOut: .fadeOut
        case .panic: .panic
        case .nextBed: .nextBed
        case .arm: .arm
        case .disarm: .disarm
        case .level: .setLevel(event.normalizedValue ?? 1)
        }
    }
}

public struct MIDIEndpointDescriptor: Identifiable, Codable, Equatable, Sendable {
    public var id: Int { uniqueID ?? name.hashValue }
    public var name: String
    public var uniqueID: Int?
    public var isOnline: Bool

    public init(name: String, uniqueID: Int? = nil, isOnline: Bool = true) {
        self.name = name
        self.uniqueID = uniqueID
        self.isOnline = isOnline
    }
}

public enum MIDIMessageType: String, Codable, CaseIterable, Identifiable, Sendable {
    case noteOn
    case noteOff
    case controlChange
    case programChange
    case pitchBend
    case transportStart
    case transportStop
    case transportContinue

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .noteOn: "Note On"
        case .noteOff: "Note Off"
        case .controlChange: "Control Change"
        case .programChange: "Program Change"
        case .pitchBend: "Pitch Bend"
        case .transportStart: "Transport Start"
        case .transportStop: "Transport Stop"
        case .transportContinue: "Transport Continue"
        }
    }

    public var usesChannel: Bool {
        switch self {
        case .transportStart, .transportStop, .transportContinue: false
        default: true
        }
    }

    public var usesNumber: Bool {
        switch self {
        case .noteOn, .noteOff, .controlChange, .programChange: true
        case .pitchBend, .transportStart, .transportStop, .transportContinue: false
        }
    }
}

public enum LightingProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case lightkeyOSC
    case luminescenceOSC
    case showOffOSC
    case customOSC
    case midi

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .lightkeyOSC: "Lightkey OSC"
        case .luminescenceOSC: "Luminescence OSC"
        case .showOffOSC: "Show Off OSC"
        case .customOSC: "Custom OSC"
        case .midi: "MIDI"
        }
    }

    public var usesOSC: Bool {
        switch self {
        case .lightkeyOSC, .luminescenceOSC, .showOffOSC, .customOSC: true
        case .midi: false
        }
    }
}

public enum LightingCueTrigger: String, Codable, CaseIterable, Identifiable, Sendable {
    case showModeArmed
    case showModeDisarmed
    case bedPrimed
    case fadeInStarted
    case fadeInCompleted
    case fadeOutStarted
    case fadeOutCompleted
    case nextBedSelected
    case crossfadeStarted
    case crossfadeCompleted
    case panicMuted
    case heartbeatLost
    case appQuit
    case manualTest

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .showModeArmed: "Show Mode Armed"
        case .showModeDisarmed: "Show Mode Disarmed"
        case .bedPrimed: "Bed Primed"
        case .fadeInStarted: "Fade In Started"
        case .fadeInCompleted: "Fade In Completed"
        case .fadeOutStarted: "Fade Out Started"
        case .fadeOutCompleted: "Fade Out Completed"
        case .nextBedSelected: "Next Bed Selected"
        case .crossfadeStarted: "Crossfade Started"
        case .crossfadeCompleted: "Crossfade Completed"
        case .panicMuted: "Panic Muted"
        case .heartbeatLost: "Heartbeat Lost"
        case .appQuit: "App Quit"
        case .manualTest: "Manual Test"
        }
    }
}

public enum LightkeyCueAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case activate
    case deactivate
    case toggle
    case intensity
    case selectPage
    case nextCue
    case previousCue

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .activate: "Activate"
        case .deactivate: "Deactivate"
        case .toggle: "Toggle"
        case .intensity: "Intensity"
        case .selectPage: "Select Page"
        case .nextCue: "Next Cue"
        case .previousCue: "Previous Cue"
        }
    }

    public var requiresCueName: Bool {
        switch self {
        case .activate, .deactivate, .toggle, .intensity: true
        case .selectPage, .nextCue, .previousCue: false
        }
    }
}

public struct LightingCue: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var enabled: Bool
    public var name: String
    public var trigger: LightingCueTrigger
    public var provider: LightingProvider
    public var pageName: String
    public var frameName: String?
    public var cueName: String
    public var action: LightkeyCueAction
    public var fadeTimeSeconds: Double?
    public var intensity: Double?
    public var rawOSCAddress: String?
    public var oscHostOverride: String?
    public var oscPortOverride: Int?
    public var midiMessageType: MIDIMessageType
    public var midiChannel: Int
    public var midiNumber: Int
    public var midiValue: Int

    public init(
        id: UUID = UUID(),
        enabled: Bool = true,
        name: String = "Lighting Cue",
        trigger: LightingCueTrigger = .fadeInStarted,
        provider: LightingProvider = .lightkeyOSC,
        pageName: String = "Live",
        frameName: String? = nil,
        cueName: String = "",
        action: LightkeyCueAction = .activate,
        fadeTimeSeconds: Double? = nil,
        intensity: Double? = nil,
        rawOSCAddress: String? = nil,
        oscHostOverride: String? = nil,
        oscPortOverride: Int? = nil,
        midiMessageType: MIDIMessageType = .noteOn,
        midiChannel: Int = 1,
        midiNumber: Int = 60,
        midiValue: Int = 100
    ) {
        self.id = id
        self.enabled = enabled
        self.name = name
        self.trigger = trigger
        self.provider = provider
        self.pageName = pageName
        self.frameName = frameName
        self.cueName = cueName
        self.action = action
        self.fadeTimeSeconds = fadeTimeSeconds
        self.intensity = intensity
        self.rawOSCAddress = rawOSCAddress
        self.oscHostOverride = oscHostOverride
        self.oscPortOverride = oscPortOverride
        self.midiMessageType = midiMessageType
        self.midiChannel = midiChannel
        self.midiNumber = midiNumber
        self.midiValue = midiValue
    }
}

public struct LightingConfig: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var defaultProvider: LightingProvider
    public var lightkeyHost: String
    public var lightkeyPort: Int
    public var midiDestinationName: String
    public var midiDestinationUniqueID: Int?
    public var midiChannel: Int
    public var midiVelocity: Int
    public var dedupeWindowMs: Int
    public var cues: [LightingCue]

    public init(
        enabled: Bool = false,
        defaultProvider: LightingProvider = .lightkeyOSC,
        lightkeyHost: String = "127.0.0.1",
        lightkeyPort: Int = 21_600,
        midiDestinationName: String = "Lightkey Input",
        midiDestinationUniqueID: Int? = nil,
        midiChannel: Int = 1,
        midiVelocity: Int = 100,
        dedupeWindowMs: Int = 500,
        cues: [LightingCue] = []
    ) {
        self.enabled = enabled
        self.defaultProvider = defaultProvider
        self.lightkeyHost = lightkeyHost
        self.lightkeyPort = lightkeyPort
        self.midiDestinationName = midiDestinationName
        self.midiDestinationUniqueID = midiDestinationUniqueID
        self.midiChannel = midiChannel
        self.midiVelocity = midiVelocity
        self.dedupeWindowMs = dedupeWindowMs
        self.cues = cues
    }
}

public struct MIDIInputEvent: Codable, Equatable, Sendable {
    public var messageType: MIDIMessageType
    public var channel: Int?
    public var number: Int?
    public var value: Int?
    public var sourceName: String?
    public var rawBytes: [UInt8]
    public var receivedAt: Date

    public init(
        messageType: MIDIMessageType,
        channel: Int? = nil,
        number: Int? = nil,
        value: Int? = nil,
        sourceName: String? = nil,
        rawBytes: [UInt8] = [],
        receivedAt: Date = Date()
    ) {
        self.messageType = messageType
        self.channel = channel
        self.number = number
        self.value = value
        self.sourceName = sourceName
        self.rawBytes = rawBytes
        self.receivedAt = receivedAt
    }

    public var normalizedValue: Double? {
        guard let value else { return nil }
        switch messageType {
        case .pitchBend:
            return max(0, min(1, Double(value) / 16_383.0))
        default:
            return max(0, min(1, Double(value) / 127.0))
        }
    }

    public var displaySummary: String {
        var parts = [messageType.displayName]
        if let channel { parts.append("Ch \(channel)") }
        if let number { parts.append("#\(number)") }
        if let value { parts.append("Val \(value)") }
        if let sourceName, !sourceName.isEmpty { parts.append(sourceName) }
        return parts.joined(separator: " ")
    }
}

public struct MIDIMapping: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var action: MIDIMappableAction
    public var messageType: MIDIMessageType
    public var channel: Int?
    public var number: Int?
    public var valueMin: Int?
    public var valueMax: Int?
    public var sourceContains: String?
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        action: MIDIMappableAction,
        messageType: MIDIMessageType,
        channel: Int? = nil,
        number: Int? = nil,
        valueMin: Int? = nil,
        valueMax: Int? = nil,
        sourceContains: String? = nil,
        enabled: Bool = true
    ) {
        self.id = id
        self.action = action
        self.messageType = messageType
        self.channel = channel
        self.number = number
        self.valueMin = valueMin
        self.valueMax = valueMax
        self.sourceContains = sourceContains
        self.enabled = enabled
    }

    public func matches(_ event: MIDIInputEvent) -> Bool {
        guard enabled, messageType == event.messageType else { return false }
        if let channel, channel != event.channel { return false }
        if let number, number != event.number { return false }
        if let value = event.value {
            if let valueMin, value < valueMin { return false }
            if let valueMax, value > valueMax { return false }
        } else if valueMin != nil || valueMax != nil {
            return false
        }
        if let sourceContains, !sourceContains.isEmpty {
            guard let sourceName = event.sourceName,
                  sourceName.localizedCaseInsensitiveContains(sourceContains)
            else {
                return false
            }
        }
        return true
    }

    public var displaySummary: String {
        var parts = [messageType.displayName]
        if let channel {
            parts.append("Ch \(channel)")
        } else if messageType.usesChannel {
            parts.append("Any Ch")
        }
        if let number {
            parts.append("#\(number)")
        } else if messageType.usesNumber {
            parts.append("Any #")
        }
        if let valueMin, let valueMax {
            parts.append("Val \(valueMin)-\(valueMax)")
        } else if let valueMin {
            parts.append("Val >= \(valueMin)")
        } else if let valueMax {
            parts.append("Val <= \(valueMax)")
        }
        if let sourceContains, !sourceContains.isEmpty {
            parts.append("Src \(sourceContains)")
        }
        return parts.joined(separator: " ")
    }

    public static func learned(action: MIDIMappableAction, from event: MIDIInputEvent) -> MIDIMapping {
        MIDIMapping(
            action: action,
            messageType: event.messageType,
            channel: event.channel,
            number: event.messageType.usesNumber ? event.number : nil,
            valueMin: defaultMinimumValue(for: event.messageType, action: action),
            valueMax: nil,
            sourceContains: nil,
            enabled: true
        )
    }

    public static func defaultMinimumValue(for messageType: MIDIMessageType, action: MIDIMappableAction) -> Int? {
        switch (messageType, action) {
        case (.noteOn, _), (.controlChange, .fadeIn), (.controlChange, .fadeOut), (.controlChange, .panic), (.controlChange, .nextBed), (.controlChange, .arm), (.controlChange, .disarm):
            1
        default:
            nil
        }
    }
}

public struct RoutedMIDIEvent: Equatable, Sendable {
    public var event: MIDIInputEvent
    public var command: TransitionCommand?
    public var source: CommandSource
    public var rawSummary: String

    public init(event: MIDIInputEvent, command: TransitionCommand?, source: CommandSource, rawSummary: String) {
        self.event = event
        self.command = command
        self.source = source
        self.rawSummary = rawSummary
    }
}

public enum MetadataSource: String, Codable, CaseIterable, Sendable {
    case none
    case imported
    case manual

    public var displayName: String {
        switch self {
        case .none: "None"
        case .imported: "Imported"
        case .manual: "Manual"
        }
    }
}

public struct BedItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var fileName: String
    public var originalPath: String?
    public var bookmarkData: Data?
    public var storageMode: LibraryStorageMode
    public var durationSeconds: Double?
    public var sampleRate: Double?
    public var channelCount: Int?
    public var enabled: Bool
    public var seamlessLoop: Bool
    public var createdAt: Date
    public var artist: String?
    public var musicalKey: String?
    public var bpm: Double?
    public var energy: Int?
    public var tags: [String]
    public var notes: String?
    public var metadataSource: MetadataSource
    public var cueReference: String?
    public var lightingCues: [LightingCue]

    public init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        originalPath: String? = nil,
        bookmarkData: Data? = nil,
        storageMode: LibraryStorageMode = .managedCopy,
        durationSeconds: Double? = nil,
        sampleRate: Double? = nil,
        channelCount: Int? = nil,
        enabled: Bool = true,
        seamlessLoop: Bool = true,
        createdAt: Date = Date(),
        artist: String? = nil,
        musicalKey: String? = nil,
        bpm: Double? = nil,
        energy: Int? = nil,
        tags: [String] = [],
        notes: String? = nil,
        metadataSource: MetadataSource = .none,
        cueReference: String? = nil,
        lightingCues: [LightingCue] = []
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.originalPath = originalPath
        self.bookmarkData = bookmarkData
        self.storageMode = storageMode
        self.durationSeconds = durationSeconds
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.enabled = enabled
        self.seamlessLoop = seamlessLoop
        self.createdAt = createdAt
        self.artist = artist
        self.musicalKey = musicalKey
        self.bpm = bpm
        self.energy = energy
        self.tags = tags
        self.notes = notes
        self.metadataSource = metadataSource
        self.cueReference = cueReference
        self.lightingCues = lightingCues
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case fileName
        case originalPath
        case bookmarkData
        case storageMode
        case durationSeconds
        case sampleRate
        case channelCount
        case enabled
        case seamlessLoop
        case createdAt
        case artist
        case musicalKey
        case bpm
        case energy
        case tags
        case notes
        case metadataSource
        case cueReference
        case lightingCues
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Bed",
            fileName: try container.decodeIfPresent(String.self, forKey: .fileName) ?? "",
            originalPath: try container.decodeIfPresent(String.self, forKey: .originalPath),
            bookmarkData: try container.decodeIfPresent(Data.self, forKey: .bookmarkData),
            storageMode: try container.decodeIfPresent(LibraryStorageMode.self, forKey: .storageMode) ?? .managedCopy,
            durationSeconds: try container.decodeIfPresent(Double.self, forKey: .durationSeconds),
            sampleRate: try container.decodeIfPresent(Double.self, forKey: .sampleRate),
            channelCount: try container.decodeIfPresent(Int.self, forKey: .channelCount),
            enabled: try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true,
            seamlessLoop: try container.decodeIfPresent(Bool.self, forKey: .seamlessLoop) ?? true,
            createdAt: try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(),
            artist: try container.decodeIfPresent(String.self, forKey: .artist),
            musicalKey: try container.decodeIfPresent(String.self, forKey: .musicalKey),
            bpm: try container.decodeIfPresent(Double.self, forKey: .bpm),
            energy: try container.decodeIfPresent(Int.self, forKey: .energy),
            tags: try container.decodeIfPresent([String].self, forKey: .tags) ?? [],
            notes: try container.decodeIfPresent(String.self, forKey: .notes),
            metadataSource: try container.decodeIfPresent(MetadataSource.self, forKey: .metadataSource) ?? .none,
            cueReference: try container.decodeIfPresent(String.self, forKey: .cueReference),
            lightingCues: try container.decodeIfPresent([LightingCue].self, forKey: .lightingCues) ?? []
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(fileName, forKey: .fileName)
        try container.encodeIfPresent(originalPath, forKey: .originalPath)
        try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
        try container.encode(storageMode, forKey: .storageMode)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(sampleRate, forKey: .sampleRate)
        try container.encodeIfPresent(channelCount, forKey: .channelCount)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(seamlessLoop, forKey: .seamlessLoop)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(musicalKey, forKey: .musicalKey)
        try container.encodeIfPresent(bpm, forKey: .bpm)
        try container.encodeIfPresent(energy, forKey: .energy)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(metadataSource, forKey: .metadataSource)
        try container.encodeIfPresent(cueReference, forKey: .cueReference)
        try container.encode(lightingCues, forKey: .lightingCues)
    }
}

public struct MIDIConfig: Codable, Equatable, Sendable {
    public enum Mode: String, Codable, CaseIterable, Sendable {
        case virtualDestination
        case iacSource
        case both
    }

    public var mode: Mode
    public var virtualDestinationName: String
    public var iacBusName: String
    public var iacSourceUniqueID: Int?
    public var iacSourceName: String?
    public var channel: Int
    public var fadeInNote: Int
    public var fadeOutNote: Int
    public var panicNote: Int
    public var nextBedNote: Int
    public var armNote: Int
    public var disarmNote: Int
    public var levelCC: Int
    public var mappings: [MIDIMapping]

    public init(
        mode: Mode = .virtualDestination,
        virtualDestinationName: String = "Dead Air In",
        iacBusName: String = "LBK_PLAYER_CONTROL",
        iacSourceUniqueID: Int? = nil,
        iacSourceName: String? = nil,
        channel: Int = 16,
        fadeInNote: Int = 120,
        fadeOutNote: Int = 121,
        panicNote: Int = 122,
        nextBedNote: Int = 123,
        armNote: Int = 124,
        disarmNote: Int = 125,
        levelCC: Int = 20,
        mappings: [MIDIMapping]? = nil
    ) {
        self.mode = mode
        self.virtualDestinationName = virtualDestinationName
        self.iacBusName = iacBusName
        self.iacSourceUniqueID = iacSourceUniqueID
        self.iacSourceName = iacSourceName
        self.channel = channel
        self.fadeInNote = fadeInNote
        self.fadeOutNote = fadeOutNote
        self.panicNote = panicNote
        self.nextBedNote = nextBedNote
        self.armNote = armNote
        self.disarmNote = disarmNote
        self.levelCC = levelCC
        self.mappings = mappings ?? Self.defaultMappings(
            channel: channel,
            fadeInNote: fadeInNote,
            fadeOutNote: fadeOutNote,
            panicNote: panicNote,
            nextBedNote: nextBedNote,
            armNote: armNote,
            disarmNote: disarmNote,
            levelCC: levelCC
        )
    }

    public static func defaultMappings(
        channel: Int = 16,
        fadeInNote: Int = 120,
        fadeOutNote: Int = 121,
        panicNote: Int = 122,
        nextBedNote: Int = 123,
        armNote: Int = 124,
        disarmNote: Int = 125,
        levelCC: Int = 20
    ) -> [MIDIMapping] {
        [
            MIDIMapping(action: .fadeIn, messageType: .noteOn, channel: channel, number: fadeInNote, valueMin: 1),
            MIDIMapping(action: .fadeOut, messageType: .noteOn, channel: channel, number: fadeOutNote, valueMin: 1),
            MIDIMapping(action: .panic, messageType: .noteOn, channel: channel, number: panicNote, valueMin: 1),
            MIDIMapping(action: .nextBed, messageType: .noteOn, channel: channel, number: nextBedNote, valueMin: 1),
            MIDIMapping(action: .arm, messageType: .noteOn, channel: channel, number: armNote, valueMin: 1),
            MIDIMapping(action: .disarm, messageType: .noteOn, channel: channel, number: disarmNote, valueMin: 1),
            MIDIMapping(action: .level, messageType: .controlChange, channel: channel, number: levelCC)
        ]
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case virtualDestinationName
        case iacBusName
        case iacSourceUniqueID
        case iacSourceName
        case channel
        case fadeInNote
        case fadeOutNote
        case panicNote
        case nextBedNote
        case armNote
        case disarmNote
        case levelCC
        case mappings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let channel = try container.decodeIfPresent(Int.self, forKey: .channel) ?? 16
        let fadeInNote = try container.decodeIfPresent(Int.self, forKey: .fadeInNote) ?? 120
        let fadeOutNote = try container.decodeIfPresent(Int.self, forKey: .fadeOutNote) ?? 121
        let panicNote = try container.decodeIfPresent(Int.self, forKey: .panicNote) ?? 122
        let nextBedNote = try container.decodeIfPresent(Int.self, forKey: .nextBedNote) ?? 123
        let armNote = try container.decodeIfPresent(Int.self, forKey: .armNote) ?? 124
        let disarmNote = try container.decodeIfPresent(Int.self, forKey: .disarmNote) ?? 125
        let levelCC = try container.decodeIfPresent(Int.self, forKey: .levelCC) ?? 20

        self.init(
            mode: try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .virtualDestination,
            virtualDestinationName: try container.decodeIfPresent(String.self, forKey: .virtualDestinationName) ?? "Dead Air In",
            iacBusName: try container.decodeIfPresent(String.self, forKey: .iacBusName) ?? "LBK_PLAYER_CONTROL",
            iacSourceUniqueID: try container.decodeIfPresent(Int.self, forKey: .iacSourceUniqueID),
            iacSourceName: try container.decodeIfPresent(String.self, forKey: .iacSourceName),
            channel: channel,
            fadeInNote: fadeInNote,
            fadeOutNote: fadeOutNote,
            panicNote: panicNote,
            nextBedNote: nextBedNote,
            armNote: armNote,
            disarmNote: disarmNote,
            levelCC: levelCC,
            mappings: try container.decodeIfPresent([MIDIMapping].self, forKey: .mappings)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(virtualDestinationName, forKey: .virtualDestinationName)
        try container.encode(iacBusName, forKey: .iacBusName)
        try container.encodeIfPresent(iacSourceUniqueID, forKey: .iacSourceUniqueID)
        try container.encodeIfPresent(iacSourceName, forKey: .iacSourceName)
        try container.encode(channel, forKey: .channel)
        try container.encode(fadeInNote, forKey: .fadeInNote)
        try container.encode(fadeOutNote, forKey: .fadeOutNote)
        try container.encode(panicNote, forKey: .panicNote)
        try container.encode(nextBedNote, forKey: .nextBedNote)
        try container.encode(armNote, forKey: .armNote)
        try container.encode(disarmNote, forKey: .disarmNote)
        try container.encode(levelCC, forKey: .levelCC)
        try container.encode(mappings, forKey: .mappings)
    }
}

public struct OSCConfig: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var host: String
    public var port: Int
    public var acceptLocalhostOnly: Bool

    public init(enabled: Bool = true, host: String = "127.0.0.1", port: Int = 38101, acceptLocalhostOnly: Bool = true) {
        self.enabled = enabled
        self.host = host
        self.port = port
        self.acceptLocalhostOnly = acceptLocalhostOnly
    }
}

public struct HeartbeatConfig: Codable, Equatable, Sendable {
    public enum OnLoss: String, Codable, CaseIterable, Sendable {
        case none
        case fadeInIfMuted
        case enterDegraded

        public var displayName: String {
            switch self {
            case .none: "Flag Only"
            case .fadeInIfMuted: "Fade In If Muted"
            case .enterDegraded: "Enter Degraded"
            }
        }

        public var helpText: String {
            switch self {
            case .none:
                "Show the heartbeat as lost and write a log entry. Audio does not change."
            case .fadeInIfMuted:
                "Start a fade-in after heartbeat loss only after this behavior is explicitly selected."
            case .enterDegraded:
                "Mark Dead Air as needing attention. Audio does not start automatically."
            }
        }
    }

    public var enabled: Bool
    public var timeoutMs: Int
    public var onLoss: OnLoss
    public var allowsAutoFadeIn: Bool

    public init(enabled: Bool = false, timeoutMs: Int = 3500, onLoss: OnLoss = .none, allowsAutoFadeIn: Bool = false) {
        self.enabled = enabled
        self.timeoutMs = timeoutMs
        self.onLoss = onLoss
        self.allowsAutoFadeIn = allowsAutoFadeIn
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case timeoutMs
        case onLoss
        case allowsAutoFadeIn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            enabled: try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false,
            timeoutMs: try container.decodeIfPresent(Int.self, forKey: .timeoutMs) ?? 3500,
            onLoss: try container.decodeIfPresent(OnLoss.self, forKey: .onLoss) ?? .none,
            allowsAutoFadeIn: try container.decodeIfPresent(Bool.self, forKey: .allowsAutoFadeIn) ?? false
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(timeoutMs, forKey: .timeoutMs)
        try container.encode(onLoss, forKey: .onLoss)
        try container.encode(allowsAutoFadeIn, forKey: .allowsAutoFadeIn)
    }
}

public struct AudioConfig: Codable, Equatable, Sendable {
    public var targetSampleRate: Double
    public var targetLevelDb: Double
    public var fadeInMs: Int
    public var fadeOutMs: Int
    public var loopCrossfadeMs: Int
    public var liveCrossfadeMs: Int
    public var preferredOutputUID: String?
    public var outputLeftChannel: Int
    public var outputRightChannel: Int
    public var maxPredecodedBytes: Int

    public init(
        targetSampleRate: Double = 48_000,
        targetLevelDb: Double = -14.0,
        fadeInMs: Int = 2_200,
        fadeOutMs: Int = 900,
        loopCrossfadeMs: Int = 80,
        liveCrossfadeMs: Int = 2_500,
        preferredOutputUID: String? = nil,
        outputLeftChannel: Int = 1,
        outputRightChannel: Int = 2,
        maxPredecodedBytes: Int = 314_572_800
    ) {
        self.targetSampleRate = targetSampleRate
        self.targetLevelDb = targetLevelDb
        self.fadeInMs = fadeInMs
        self.fadeOutMs = fadeOutMs
        self.loopCrossfadeMs = loopCrossfadeMs
        self.liveCrossfadeMs = liveCrossfadeMs
        self.preferredOutputUID = preferredOutputUID
        self.outputLeftChannel = outputLeftChannel
        self.outputRightChannel = outputRightChannel
        self.maxPredecodedBytes = maxPredecodedBytes
    }

    enum CodingKeys: String, CodingKey {
        case targetSampleRate
        case targetLevelDb
        case fadeInMs
        case fadeOutMs
        case loopCrossfadeMs
        case liveCrossfadeMs
        case preferredOutputUID
        case outputLeftChannel
        case outputRightChannel
        case maxPredecodedBytes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            targetSampleRate: try container.decodeIfPresent(Double.self, forKey: .targetSampleRate) ?? 48_000,
            targetLevelDb: try container.decodeIfPresent(Double.self, forKey: .targetLevelDb) ?? -14.0,
            fadeInMs: try container.decodeIfPresent(Int.self, forKey: .fadeInMs) ?? 2_200,
            fadeOutMs: try container.decodeIfPresent(Int.self, forKey: .fadeOutMs) ?? 900,
            loopCrossfadeMs: try container.decodeIfPresent(Int.self, forKey: .loopCrossfadeMs) ?? 80,
            liveCrossfadeMs: try container.decodeIfPresent(Int.self, forKey: .liveCrossfadeMs) ?? 2_500,
            preferredOutputUID: try container.decodeIfPresent(String.self, forKey: .preferredOutputUID),
            outputLeftChannel: try container.decodeIfPresent(Int.self, forKey: .outputLeftChannel) ?? 1,
            outputRightChannel: try container.decodeIfPresent(Int.self, forKey: .outputRightChannel) ?? 2,
            maxPredecodedBytes: try container.decodeIfPresent(Int.self, forKey: .maxPredecodedBytes) ?? 314_572_800
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(targetSampleRate, forKey: .targetSampleRate)
        try container.encode(targetLevelDb, forKey: .targetLevelDb)
        try container.encode(fadeInMs, forKey: .fadeInMs)
        try container.encode(fadeOutMs, forKey: .fadeOutMs)
        try container.encode(loopCrossfadeMs, forKey: .loopCrossfadeMs)
        try container.encode(liveCrossfadeMs, forKey: .liveCrossfadeMs)
        try container.encodeIfPresent(preferredOutputUID, forKey: .preferredOutputUID)
        try container.encode(outputLeftChannel, forKey: .outputLeftChannel)
        try container.encode(outputRightChannel, forKey: .outputRightChannel)
        try container.encode(maxPredecodedBytes, forKey: .maxPredecodedBytes)
    }
}

public struct LoggingConfig: Codable, Equatable, Sendable {
    public var level: String
    public var persistJsonl: Bool
    public var redactSensitiveData: Bool
    public var retentionDays: Int

    public init(level: String = "info", persistJsonl: Bool = true, redactSensitiveData: Bool = true, retentionDays: Int = 30) {
        self.level = level
        self.persistJsonl = persistJsonl
        self.redactSensitiveData = redactSensitiveData
        self.retentionDays = retentionDays
    }

    enum CodingKeys: String, CodingKey {
        case level
        case persistJsonl
        case redactSensitiveData
        case retentionDays
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            level: try container.decodeIfPresent(String.self, forKey: .level) ?? "info",
            persistJsonl: try container.decodeIfPresent(Bool.self, forKey: .persistJsonl) ?? true,
            redactSensitiveData: try container.decodeIfPresent(Bool.self, forKey: .redactSensitiveData) ?? true,
            retentionDays: try container.decodeIfPresent(Int.self, forKey: .retentionDays) ?? 30
        )
    }
}

public struct PowerConfig: Codable, Equatable, Sendable {
    public var preventIdleSleep: Bool

    public init(preventIdleSleep: Bool = true) {
        self.preventIdleSleep = preventIdleSleep
    }
}

public struct AccessibilityConfig: Codable, Equatable, Sendable {
    public var largerTransportControls: Bool
    public var reduceGlassEffects: Bool
    public var increaseStatusContrast: Bool

    public init(
        largerTransportControls: Bool = false,
        reduceGlassEffects: Bool = false,
        increaseStatusContrast: Bool = false
    ) {
        self.largerTransportControls = largerTransportControls
        self.reduceGlassEffects = reduceGlassEffects
        self.increaseStatusContrast = increaseStatusContrast
    }

    enum CodingKeys: String, CodingKey {
        case largerTransportControls
        case reduceGlassEffects
        case increaseStatusContrast
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            largerTransportControls: try container.decodeIfPresent(Bool.self, forKey: .largerTransportControls) ?? false,
            reduceGlassEffects: try container.decodeIfPresent(Bool.self, forKey: .reduceGlassEffects) ?? false,
            increaseStatusContrast: try container.decodeIfPresent(Bool.self, forKey: .increaseStatusContrast) ?? false
        )
    }
}

public struct AppConfig: Codable, Equatable, Sendable {
    public var version: String
    public var showModeArmed: Bool
    public var hasCompletedOnboarding: Bool
    public var uiMode: DeadAirUIMode
    public var appearanceMode: DeadAirAppearanceMode
    public var setupPreset: ShowSetupPreset
    public var bedAdvanceMode: BedAdvanceMode
    public var libraryStorageMode: LibraryStorageMode
    public var midi: MIDIConfig
    public var osc: OSCConfig
    public var heartbeat: HeartbeatConfig
    public var audio: AudioConfig
    public var logging: LoggingConfig
    public var power: PowerConfig
    public var accessibility: AccessibilityConfig
    public var lighting: LightingConfig
    public var selectedBedID: UUID?
    public var activeProfileID: UUID?

    public init(
        version: String = "4.0.0",
        showModeArmed: Bool = false,
        hasCompletedOnboarding: Bool = false,
        uiMode: DeadAirUIMode = .simple,
        appearanceMode: DeadAirAppearanceMode = .system,
        setupPreset: ShowSetupPreset = .abletonLightkey,
        bedAdvanceMode: BedAdvanceMode = .manualContinuous,
        libraryStorageMode: LibraryStorageMode = .managedCopy,
        midi: MIDIConfig = MIDIConfig(),
        osc: OSCConfig = OSCConfig(),
        heartbeat: HeartbeatConfig = HeartbeatConfig(),
        audio: AudioConfig = AudioConfig(),
        logging: LoggingConfig = LoggingConfig(),
        power: PowerConfig = PowerConfig(),
        accessibility: AccessibilityConfig = AccessibilityConfig(),
        lighting: LightingConfig = LightingConfig(),
        selectedBedID: UUID? = nil,
        activeProfileID: UUID? = nil
    ) {
        self.version = version
        self.showModeArmed = showModeArmed
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.uiMode = uiMode
        self.appearanceMode = appearanceMode
        self.setupPreset = setupPreset
        self.bedAdvanceMode = bedAdvanceMode
        self.libraryStorageMode = libraryStorageMode
        self.midi = midi
        self.osc = osc
        self.heartbeat = heartbeat
        self.audio = audio
        self.logging = logging
        self.power = power
        self.accessibility = accessibility
        self.lighting = lighting
        self.selectedBedID = selectedBedID
        self.activeProfileID = activeProfileID
    }

    enum CodingKeys: String, CodingKey {
        case version
        case showModeArmed
        case hasCompletedOnboarding
        case uiMode
        case appearanceMode
        case setupPreset
        case bedAdvanceMode
        case libraryStorageMode
        case midi
        case osc
        case heartbeat
        case audio
        case logging
        case power
        case accessibility
        case lighting
        case selectedBedID
        case activeProfileID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            version: try container.decodeIfPresent(String.self, forKey: .version) ?? "4.0.0",
            showModeArmed: try container.decodeIfPresent(Bool.self, forKey: .showModeArmed) ?? false,
            hasCompletedOnboarding: try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false,
            uiMode: try container.decodeIfPresent(DeadAirUIMode.self, forKey: .uiMode) ?? .simple,
            appearanceMode: try container.decodeIfPresent(DeadAirAppearanceMode.self, forKey: .appearanceMode) ?? .system,
            setupPreset: try container.decodeIfPresent(ShowSetupPreset.self, forKey: .setupPreset) ?? .abletonLightkey,
            bedAdvanceMode: try container.decodeIfPresent(BedAdvanceMode.self, forKey: .bedAdvanceMode) ?? .manualContinuous,
            libraryStorageMode: try container.decodeIfPresent(LibraryStorageMode.self, forKey: .libraryStorageMode) ?? .managedCopy,
            midi: try container.decodeIfPresent(MIDIConfig.self, forKey: .midi) ?? MIDIConfig(),
            osc: try container.decodeIfPresent(OSCConfig.self, forKey: .osc) ?? OSCConfig(),
            heartbeat: try container.decodeIfPresent(HeartbeatConfig.self, forKey: .heartbeat) ?? HeartbeatConfig(),
            audio: try container.decodeIfPresent(AudioConfig.self, forKey: .audio) ?? AudioConfig(),
            logging: try container.decodeIfPresent(LoggingConfig.self, forKey: .logging) ?? LoggingConfig(),
            power: try container.decodeIfPresent(PowerConfig.self, forKey: .power) ?? PowerConfig(),
            accessibility: try container.decodeIfPresent(AccessibilityConfig.self, forKey: .accessibility) ?? AccessibilityConfig(),
            lighting: try container.decodeIfPresent(LightingConfig.self, forKey: .lighting) ?? LightingConfig(),
            selectedBedID: try container.decodeIfPresent(UUID.self, forKey: .selectedBedID),
            activeProfileID: try container.decodeIfPresent(UUID.self, forKey: .activeProfileID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(showModeArmed, forKey: .showModeArmed)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try container.encode(uiMode, forKey: .uiMode)
        try container.encode(appearanceMode, forKey: .appearanceMode)
        try container.encode(setupPreset, forKey: .setupPreset)
        try container.encode(bedAdvanceMode, forKey: .bedAdvanceMode)
        try container.encode(libraryStorageMode, forKey: .libraryStorageMode)
        try container.encode(midi, forKey: .midi)
        try container.encode(osc, forKey: .osc)
        try container.encode(heartbeat, forKey: .heartbeat)
        try container.encode(audio, forKey: .audio)
        try container.encode(logging, forKey: .logging)
        try container.encode(power, forKey: .power)
        try container.encode(accessibility, forKey: .accessibility)
        try container.encode(lighting, forKey: .lighting)
        try container.encodeIfPresent(selectedBedID, forKey: .selectedBedID)
        try container.encodeIfPresent(activeProfileID, forKey: .activeProfileID)
    }
}

public extension ShowSetupPreset {
    func applying(to config: AppConfig) -> AppConfig {
        var updated = config
        updated.version = "4.0.0"
        updated.setupPreset = self
        updated.showModeArmed = false
        updated.power.preventIdleSleep = true
        updated.heartbeat.enabled = false
        updated.heartbeat.onLoss = .none
        updated.heartbeat.allowsAutoFadeIn = false
        updated.audio.targetSampleRate = 48_000
        updated.audio.targetLevelDb = -14

        switch self {
        case .genericDAWVirtualMIDI:
            updated.uiMode = .simple
            updated.libraryStorageMode = .managedCopy
            updated.bedAdvanceMode = .manualContinuous
            updated.midi.mode = .virtualDestination
            updated.osc.enabled = true
            updated.lighting.enabled = false
        case .abletonLightkey:
            updated.uiMode = .advanced
            updated.libraryStorageMode = .managedCopy
            updated.bedAdvanceMode = .autoPrepareNextOnFadeOut
            updated.midi.mode = .virtualDestination
            updated.midi.channel = 16
            updated.osc.enabled = true
            updated.lighting.enabled = true
            updated.lighting.defaultProvider = .lightkeyOSC
            updated.lighting.lightkeyHost = "127.0.0.1"
            updated.lighting.lightkeyPort = 21_600
        case .abletonLuminescence:
            updated.uiMode = .advanced
            updated.libraryStorageMode = .managedCopy
            updated.bedAdvanceMode = .autoPrepareNextOnFadeOut
            updated.midi.mode = .virtualDestination
            updated.midi.channel = 16
            updated.osc.enabled = true
            updated.lighting.enabled = true
            updated.lighting.defaultProvider = .luminescenceOSC
            updated.lighting.lightkeyHost = "127.0.0.1"
            updated.lighting.lightkeyPort = 9_001
        case .showOffBridge:
            updated.uiMode = .advanced
            updated.libraryStorageMode = .managedCopy
            updated.bedAdvanceMode = .manualContinuous
            updated.midi.mode = .virtualDestination
            updated.osc.enabled = true
            updated.lighting.enabled = true
            updated.lighting.defaultProvider = .showOffOSC
            updated.lighting.lightkeyHost = "127.0.0.1"
            updated.lighting.lightkeyPort = 39_051
        case .iacLegacyDAW:
            updated.uiMode = .advanced
            updated.libraryStorageMode = .managedCopy
            updated.bedAdvanceMode = .manualContinuous
            updated.midi.mode = .iacSource
            updated.osc.enabled = true
            updated.lighting.enabled = false
        case .djManual:
            updated.uiMode = .simple
            updated.libraryStorageMode = .managedCopy
            updated.bedAdvanceMode = .manualContinuous
            updated.midi.mode = .virtualDestination
            updated.osc.enabled = false
            updated.lighting.enabled = false
        case .qlabOSC:
            updated.uiMode = .advanced
            updated.libraryStorageMode = .managedCopy
            updated.bedAdvanceMode = .manualContinuous
            updated.midi.mode = .virtualDestination
            updated.osc.enabled = true
            updated.lighting.enabled = false
        case .referenceExternalDrive:
            updated.uiMode = .advanced
            updated.libraryStorageMode = .externalReference
            updated.bedAdvanceMode = .manualContinuous
            updated.midi.mode = .virtualDestination
            updated.osc.enabled = true
            updated.lighting.enabled = false
        }

        return updated
    }
}

public struct ShowProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    public var bedAdvanceMode: BedAdvanceMode
    public var libraryStorageMode: LibraryStorageMode
    public var midi: MIDIConfig
    public var osc: OSCConfig
    public var heartbeat: HeartbeatConfig
    public var audio: AudioConfig
    public var logging: LoggingConfig
    public var power: PowerConfig
    public var lighting: LightingConfig

    public init(
        id: UUID = UUID(),
        name: String = "Show Profile",
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        bedAdvanceMode: BedAdvanceMode = .manualContinuous,
        libraryStorageMode: LibraryStorageMode = .managedCopy,
        midi: MIDIConfig = MIDIConfig(),
        osc: OSCConfig = OSCConfig(),
        heartbeat: HeartbeatConfig = HeartbeatConfig(),
        audio: AudioConfig = AudioConfig(),
        logging: LoggingConfig = LoggingConfig(),
        power: PowerConfig = PowerConfig(),
        lighting: LightingConfig = LightingConfig()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.bedAdvanceMode = bedAdvanceMode
        self.libraryStorageMode = libraryStorageMode
        self.midi = midi
        self.osc = osc
        self.heartbeat = heartbeat
        self.audio = audio
        self.logging = logging
        self.power = power
        self.lighting = lighting
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case notes
        case createdAt
        case updatedAt
        case bedAdvanceMode
        case libraryStorageMode
        case midi
        case osc
        case heartbeat
        case audio
        case logging
        case power
        case lighting
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: try container.decodeIfPresent(String.self, forKey: .name) ?? "Show Profile",
            notes: try container.decodeIfPresent(String.self, forKey: .notes) ?? "",
            createdAt: try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(),
            updatedAt: try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date(),
            bedAdvanceMode: try container.decodeIfPresent(BedAdvanceMode.self, forKey: .bedAdvanceMode) ?? .manualContinuous,
            libraryStorageMode: try container.decodeIfPresent(LibraryStorageMode.self, forKey: .libraryStorageMode) ?? .managedCopy,
            midi: try container.decodeIfPresent(MIDIConfig.self, forKey: .midi) ?? MIDIConfig(),
            osc: try container.decodeIfPresent(OSCConfig.self, forKey: .osc) ?? OSCConfig(),
            heartbeat: try container.decodeIfPresent(HeartbeatConfig.self, forKey: .heartbeat) ?? HeartbeatConfig(),
            audio: try container.decodeIfPresent(AudioConfig.self, forKey: .audio) ?? AudioConfig(),
            logging: try container.decodeIfPresent(LoggingConfig.self, forKey: .logging) ?? LoggingConfig(),
            power: try container.decodeIfPresent(PowerConfig.self, forKey: .power) ?? PowerConfig(),
            lighting: try container.decodeIfPresent(LightingConfig.self, forKey: .lighting) ?? LightingConfig()
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(bedAdvanceMode, forKey: .bedAdvanceMode)
        try container.encode(libraryStorageMode, forKey: .libraryStorageMode)
        try container.encode(midi, forKey: .midi)
        try container.encode(osc, forKey: .osc)
        try container.encode(heartbeat, forKey: .heartbeat)
        try container.encode(audio, forKey: .audio)
        try container.encode(logging, forKey: .logging)
        try container.encode(power, forKey: .power)
        try container.encode(lighting, forKey: .lighting)
    }

    public init(name: String, config: AppConfig, notes: String = "") {
        self.init(
            name: name,
            notes: notes,
            bedAdvanceMode: config.bedAdvanceMode,
            libraryStorageMode: config.libraryStorageMode,
            midi: config.midi,
            osc: config.osc,
            heartbeat: config.heartbeat,
            audio: config.audio,
            logging: config.logging,
            power: config.power,
            lighting: config.lighting
        )
    }

    public func applying(to config: AppConfig) -> AppConfig {
        var updated = config
        updated.bedAdvanceMode = bedAdvanceMode
        updated.libraryStorageMode = libraryStorageMode
        updated.midi = midi
        updated.osc = osc
        updated.heartbeat = heartbeat
        updated.audio = audio
        updated.logging = logging
        updated.power = power
        updated.lighting = lighting
        updated.activeProfileID = id
        return updated
    }
}

public struct ShowProfileCollection: Codable, Equatable, Sendable {
    public var version: String
    public var profiles: [ShowProfile]

    public init(version: String = "1.0", profiles: [ShowProfile] = []) {
        self.version = version
        self.profiles = profiles
    }
}

public struct LibraryManifest: Codable, Equatable, Sendable {
    public var version: String
    public var beds: [BedItem]
    public var profileID: UUID?

    public init(version: String = "1.0", beds: [BedItem] = [], profileID: UUID? = nil) {
        self.version = version
        self.beds = beds
        self.profileID = profileID
    }
}

public struct LogEvent: Codable, Sendable {
    public var wallClock: Date
    public var source: String
    public var message: String
    public var raw: String?
    public var command: String?
    public var preState: String?
    public var postState: String?
    public var bedID: UUID?
    public var audioDeviceUID: String?
    public var droppedEventCount: Int

    public init(
        wallClock: Date = Date(),
        source: String,
        message: String,
        raw: String? = nil,
        command: String? = nil,
        preState: String? = nil,
        postState: String? = nil,
        bedID: UUID? = nil,
        audioDeviceUID: String? = nil,
        droppedEventCount: Int = 0
    ) {
        self.wallClock = wallClock
        self.source = source
        self.message = message
        self.raw = raw
        self.command = command
        self.preState = preState
        self.postState = postState
        self.bedID = bedID
        self.audioDeviceUID = audioDeviceUID
        self.droppedEventCount = droppedEventCount
    }
}
