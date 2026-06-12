import CoreMIDI
import DeadAirCore
@preconcurrency import AVFAudio
import Foundation

struct CheckFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CheckFailure(message: message)
    }
}

func fixtureData(_ string: String) throws -> Data {
    guard let data = string.data(using: .utf8) else {
        throw CheckFailure(message: "fixture could not be encoded as UTF-8")
    }
    return data
}

func runChecks() throws {
    let config = AppConfig()
    try expect(config.midi.channel == 16, "default MIDI channel")
    try expect(config.midi.fadeInNote == 120, "default fade-in note")
    try expect(config.midi.fadeOutNote == 121, "default fade-out note")
    try expect(config.midi.panicNote == 122, "default panic note")
    try expect(config.midi.mappings.count == 7, "default MIDI mapping count")
    try expect(config.osc.port == 38101, "default OSC port")
    try expect(config.audio.targetSampleRate == 48_000, "default sample rate")
    try expect(config.version == "4.0.0", "commercial version default")
    try expect(!config.hasCompletedOnboarding, "onboarding defaults incomplete")
    try expect(config.uiMode == .simple, "default UI mode is simple")
    try expect(config.appearanceMode == .system, "default appearance follows system")
    try expect(!config.accessibility.largerTransportControls, "default large transport controls off")
    try expect(!config.accessibility.reduceGlassEffects, "default reduced glass off")
    try expect(!config.accessibility.increaseStatusContrast, "default status contrast follows standard UI")
    try expect(!config.heartbeat.enabled, "heartbeat supervision defaults off")
    try expect(config.heartbeat.onLoss == .none, "heartbeat loss defaults to flag only")
    try expect(!config.heartbeat.allowsAutoFadeIn, "heartbeat auto fade-in requires explicit consent")
    try expect(config.setupPreset == .abletonLightkey, "default setup preset is guided pro path")
    try expect(config.audio.outputLeftChannel == 1, "default left output channel")
    try expect(config.audio.outputRightChannel == 2, "default right output channel")
    try expect(config.libraryStorageMode == .managedCopy, "default library storage mode")
    try expect(config.lighting.lightkeyPort == 21_600, "default Lightkey OSC port")
    try expect(config.lighting.lightkeyHost == "127.0.0.1", "default Lightkey host")
    try expect(config.lighting.midiChannel == 1, "default lighting MIDI channel avoids Lightkey channel 16")

    let abletonPreset = ShowSetupPreset.abletonLightkey.applying(to: AppConfig())
    try expect(abletonPreset.lighting.enabled, "Ableton Lightkey preset enables lighting")
    try expect(abletonPreset.osc.enabled, "Ableton Lightkey preset enables OSC")
    try expect(abletonPreset.audio.targetSampleRate == 48_000, "preset keeps 48 kHz")
    try expect(abletonPreset.version == "4.0.0", "preset migrates config version")
    try expect(!abletonPreset.heartbeat.enabled, "setup presets keep heartbeat supervision opt-in")
    try expect(abletonPreset.heartbeat.onLoss == .none, "setup presets do not auto-start audio on heartbeat loss")

    let luminescencePreset = ShowSetupPreset.abletonLuminescence.applying(to: AppConfig())
    try expect(luminescencePreset.lighting.defaultProvider == .luminescenceOSC, "Luminescence preset selects Luminescence OSC")
    try expect(luminescencePreset.lighting.lightkeyPort == 9_001, "Luminescence preset sets OSC input port")

    let showOffPreset = ShowSetupPreset.showOffBridge.applying(to: AppConfig())
    try expect(showOffPreset.lighting.defaultProvider == .showOffOSC, "Show Off preset selects Show Off OSC")
    try expect(showOffPreset.lighting.lightkeyPort == 39_051, "Show Off preset sets OSC input port")

    let legacyLoggingJSON = try fixtureData("{}")
    let legacyLogging = try JSONDecoder().decode(LoggingConfig.self, from: legacyLoggingJSON)
    try expect(legacyLogging.redactSensitiveData, "legacy logging defaults redaction on")
    try expect(legacyLogging.retentionDays == 30, "legacy logging defaults 30-day retention")

    let legacyHeartbeatJSON = try fixtureData("""
    {"enabled":true,"timeoutMs":3500,"onLoss":"fadeInIfMuted"}
    """)
    let legacyHeartbeat = try JSONDecoder().decode(HeartbeatConfig.self, from: legacyHeartbeatJSON)
    try expect(legacyHeartbeat.onLoss == .fadeInIfMuted, "legacy heartbeat behavior decodes")
    try expect(!legacyHeartbeat.allowsAutoFadeIn, "legacy heartbeat auto fade-in is not silently consented")
    let explicitHeartbeat = HeartbeatConfig(enabled: true, timeoutMs: 5000, onLoss: .fadeInIfMuted, allowsAutoFadeIn: true)
    let explicitHeartbeatRoundTrip = try JSONDecoder().decode(HeartbeatConfig.self, from: JSONEncoder().encode(explicitHeartbeat))
    try expect(explicitHeartbeatRoundTrip == explicitHeartbeat, "explicit heartbeat auto fade-in consent round trips")

    let endpointConfig = MIDIConfig(iacBusName: "IAC Driver Bus 1", iacSourceUniqueID: 42, iacSourceName: "Ableton Live")
    let endpointRoundTrip = try JSONDecoder().decode(MIDIConfig.self, from: JSONEncoder().encode(endpointConfig))
    try expect(endpointRoundTrip.iacSourceUniqueID == 42, "MIDI endpoint unique ID round trips")
    try expect(endpointRoundTrip.iacSourceName == "Ableton Live", "MIDI endpoint name round trips")

    let legacyConfigJSON = try fixtureData("""
    {"version":"1.0","showModeArmed":false,"bedAdvanceMode":"manualContinuous","libraryStorageMode":"managedCopy"}
    """)
    let legacyConfig = try JSONDecoder().decode(AppConfig.self, from: legacyConfigJSON)
    try expect(!legacyConfig.lighting.enabled, "legacy config defaults lighting disabled")
    try expect(legacyConfig.lighting.lightkeyPort == 21_600, "legacy config defaults Lightkey port")
    try expect(legacyConfig.accessibility == AccessibilityConfig(), "legacy config defaults accessibility options")

    let accessibilityConfig = AccessibilityConfig(largerTransportControls: true, reduceGlassEffects: true, increaseStatusContrast: true)
    let accessibilityRoundTrip = try JSONDecoder().decode(AccessibilityConfig.self, from: JSONEncoder().encode(accessibilityConfig))
    try expect(accessibilityRoundTrip == accessibilityConfig, "accessibility config round trips")

    let automationIDs = DeadAirAutomationID.allCritical
    try expect(Set(automationIDs).count == automationIDs.count, "automation identifiers are unique")
    try expect(automationIDs.allSatisfy { $0.hasPrefix("deadAir.") }, "automation identifiers are namespaced")
    try expect(automationIDs.allSatisfy { !$0.contains(" ") }, "automation identifiers are automation-safe")

    let legacyBedJSON = try fixtureData("""
    {"id":"00000000-0000-0000-0000-000000000001","title":"Legacy","fileName":"legacy.wav","enabled":true,"seamlessLoop":true,"createdAt":"2026-05-11T00:00:00Z"}
    """)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let legacyBed = try decoder.decode(BedItem.self, from: legacyBedJSON)
    try expect(legacyBed.storageMode == .managedCopy, "legacy beds default to managed copy")
    try expect(legacyBed.metadataSource == .none, "legacy beds default to no metadata source")
    try expect(legacyBed.tags.isEmpty, "legacy beds default to empty tags")
    try expect(legacyBed.lightingCues.isEmpty, "legacy beds default to no lighting cues")

    let metadataBed = BedItem(
        title: "Transition",
        fileName: "transition.mp3",
        artist: "Dead Air",
        musicalKey: "8A",
        bpm: 124.0,
        energy: 7,
        tags: ["walk-in", "house"],
        notes: "Works under MC intro",
        metadataSource: .manual,
        cueReference: "Ableton scene 4",
        lightingCues: [
            LightingCue(name: "Walkout Look", trigger: .fadeInStarted, pageName: "Live Page", cueName: "Blue Wash")
        ]
    )
    let encodedMetadataBed = try JSONEncoder().encode(metadataBed)
    let decodedMetadataBed = try JSONDecoder().decode(BedItem.self, from: encodedMetadataBed)
    try expect(decodedMetadataBed.bpm == 124.0, "bed BPM round trips")
    try expect(decodedMetadataBed.musicalKey == "8A", "bed key round trips")
    try expect(decodedMetadataBed.tags == ["walk-in", "house"], "bed tags round trip")
    try expect(decodedMetadataBed.lightingCues.first?.name == "Walkout Look", "bed lighting cues round trip")

    let generatedCue = LightingCue(name: "Generated", pageName: "Main Stage", cueName: "Blue Wash", action: .activate, fadeTimeSeconds: 1.5)
    try expect(generatedCue.lightkeyAddress == "/live/Main_Stage/cue/Blue_Wash/activate", "Lightkey generated address replaces spaces")
    try expect(generatedCue.oscArguments == [.float32(1.5)], "Lightkey fade argument encodes")
    try expect(generatedCue.validationWarnings(config: config.lighting).isEmpty, "valid Lightkey cue passes validation")

    let rawCue = LightingCue(name: "Raw", rawOSCAddress: "/live/Custom/cue/Exact/activate")
    try expect(rawCue.lightkeyAddress == "/live/Custom/cue/Exact/activate", "raw Lightkey address preserved")

    let customCue = LightingCue(name: "QLC Button", provider: .customOSC, rawOSCAddress: "/qlcplus/button/1")
    try expect(customCue.oscAddress == "/qlcplus/button/1", "custom OSC raw address preserved")
    try expect(customCue.displaySummary == "/qlcplus/button/1", "custom OSC display summary uses raw address")
    try expect(customCue.validationWarnings(config: config.lighting).isEmpty, "valid custom OSC cue passes validation")

    let luminescenceCue = LightingCue(name: "Lum Cue", trigger: .fadeInStarted, provider: .luminescenceOSC, cueName: "Blue Wash")
    try expect(luminescenceCue.oscAddress == "/luminescence/cue", "Luminescence OSC address defaults")
    try expect(luminescenceCue.oscArguments == [.string("Blue Wash")], "Luminescence sends cue name argument")
    try expect(luminescenceCue.oscEndpoint(config: config.lighting) == OSCConnectorEndpoint(host: "127.0.0.1", port: 9_001), "Luminescence endpoint defaults")
    try expect(luminescenceCue.validationWarnings(config: config.lighting).isEmpty, "valid Luminescence cue passes validation")

    let showOffCue = LightingCue(name: "Dead Air Fade", trigger: .fadeInStarted, provider: .showOffOSC)
    try expect(showOffCue.oscAddress == "/notify/cue", "Show Off OSC notification defaults")
    try expect(showOffCue.oscEndpoint(config: config.lighting) == OSCConnectorEndpoint(host: "127.0.0.1", port: 39_051), "Show Off endpoint defaults")
    try expect(showOffCue.oscArguments == [.string("Dead Air Fade: Fade In Started"), .string("all"), .int32(3_500)], "Show Off notification arguments encode")
    try expect(showOffCue.validationWarnings(config: config.lighting).isEmpty, "valid Show Off cue passes validation")

    let invalidCustomCue = LightingCue(name: "Broken OSC", provider: .customOSC, rawOSCAddress: "bad path")
    try expect(!invalidCustomCue.validationWarnings(config: config.lighting).isEmpty, "invalid custom OSC cue warns")

    let invalidCue = LightingCue(name: "Invalid", pageName: "Bad/Page", cueName: "")
    try expect(!invalidCue.validationWarnings(config: config.lighting).isEmpty, "invalid Lightkey cue warns")

    let packet = OSCMessageBuilder.packet(address: "/live/Main/cue/Blue/activate", arguments: [.float32(1)])
    try expect(packet.count % 4 == 0, "OSC packet is 4-byte aligned")

    let oscServer = OSCServer()
    let oscPort = 42_500 + Int(ProcessInfo.processInfo.processIdentifier % 1000)
    for _ in 0..<3 {
        try oscServer.start(config: OSCConfig(port: oscPort), handler: { _ in })
        oscServer.stop()
    }

    Diagnostics.shared.configure(persistJsonl: false, redactSensitiveData: true, retentionDays: 1)
    let group = DispatchGroup()
    for index in 0..<30 {
        group.enter()
        DispatchQueue.global().async {
            Diagnostics.shared.record(LogEvent(source: "test", message: "event \(index)", raw: "/Users/example/audio.wav", audioDeviceUID: "device-\(index)"))
            group.leave()
        }
    }
    group.wait()
    Thread.sleep(forTimeInterval: 0.2)
    let diagnosticSnapshot = Diagnostics.shared.snapshot(limit: 30)
    try expect(!diagnosticSnapshot.isEmpty, "diagnostics snapshot returns events")
    try expect(diagnosticSnapshot.allSatisfy { $0.raw != "/Users/example/audio.wav" }, "diagnostics snapshot redacts paths")
    try expect(diagnosticSnapshot.allSatisfy { $0.audioDeviceUID == PrivacyRedactor.marker }, "diagnostics snapshot redacts audio device IDs")
    try runDiagnosticsStressChecks()

    let redactedVolumePath = PrivacyRedactor.redact("/Volumes/Show Drive/Artist/Walk In.wav")
    try expect(!redactedVolumePath.contains("/Volumes/Show Drive"), "privacy redactor removes volume paths")
    let redactedHomeRelativePath = PrivacyRedactor.redact("~/Music/Dead Air/Show.wav")
    try expect(!redactedHomeRelativePath.contains("~/Music"), "privacy redactor removes home-relative paths")
    let redactedFileURL = PrivacyRedactor.redact("file:///Users/operator/Music/Intro.wav")
    try expect(!redactedFileURL.contains("/Users/operator"), "privacy redactor removes file URLs")
    let redactedNetworkURL = PrivacyRedactor.redact("smb://venue-nas.local/show/playlist.wav")
    try expect(!redactedNetworkURL.contains("venue-nas.local"), "privacy redactor removes network paths")
    let redactedUUID = PrivacyRedactor.redact("device 123E4567-E89B-12D3-A456-426614174000 selected")
    try expect(!redactedUUID.contains("123E4567"), "privacy redactor removes UUID-like identifiers")
    let redactedIPv4 = PrivacyRedactor.redact("OSC sent to 192.168.1.42:9001 from console")
    try expect(!redactedIPv4.contains("192.168.1.42"), "privacy redactor removes bare IPv4 addresses")
    let redactedLocalHost = PrivacyRedactor.redact("resolved venue-controller.local before send")
    try expect(!redactedLocalHost.contains("venue-controller.local"), "privacy redactor removes .local hostnames")

    let showTerms = ["Secret Venue 2024", "Walk In Groove", "Ableton House Rig", "VIP Entrance", "Encore.wav"]
    let redactedProfileEvent = PrivacyRedactor.redactedLogEvent(
        LogEvent(source: "profile", message: "show profile applied", raw: "Secret Venue 2024"),
        sensitiveTerms: showTerms
    )
    try expect(redactedProfileEvent.raw?.contains("Secret Venue") == false, "log redaction removes profile names")
    let redactedBedEvent = PrivacyRedactor.redactedLogEvent(
        LogEvent(source: "library", message: "next bed primed", raw: "walk in groove (Encore.wav)"),
        sensitiveTerms: showTerms
    )
    try expect(redactedBedEvent.raw?.contains("groove") == false, "log redaction removes bed titles case-insensitively")
    try expect(redactedBedEvent.raw?.contains("Encore.wav") == false, "log redaction removes bed file names")
    let redactedMIDIEvent = PrivacyRedactor.redactedLogEvent(
        LogEvent(source: "midi", message: "MIDI source selected", raw: "Ableton House Rig #42"),
        sensitiveTerms: showTerms
    )
    try expect(redactedMIDIEvent.raw?.contains("Ableton House Rig") == false, "log redaction removes MIDI endpoint names")
    let redactedCueEvent = PrivacyRedactor.redactedLogEvent(
        LogEvent(source: "lighting", message: "cue skipped: VIP Entrance", raw: "VIP Entrance"),
        sensitiveTerms: showTerms
    )
    try expect(redactedCueEvent.raw?.contains("VIP Entrance") == false, "log redaction removes cue names from raw")
    try expect(!redactedCueEvent.message.contains("VIP Entrance"), "log redaction removes cue names from messages")
    let untouchedEvent = PrivacyRedactor.redactedLogEvent(
        LogEvent(source: "audio", message: "fade complete"),
        sensitiveTerms: showTerms
    )
    try expect(untouchedEvent.message == "fade complete", "log redaction leaves generic messages intact")
    let shortTermEvent = PrivacyRedactor.redactedLogEvent(
        LogEvent(source: "library", message: "removed bed", raw: "A"),
        sensitiveTerms: ["A"]
    )
    try expect(shortTermEvent.raw == "A", "log redaction ignores single-character terms to avoid mass redaction")

    var sensitiveConfig = AppConfig()
    sensitiveConfig.audio.preferredOutputUID = "123E4567-E89B-12D3-A456-426614174000"
    sensitiveConfig.midi.virtualDestinationName = "Dead Air In Private Rig"
    sensitiveConfig.midi.iacBusName = "Logic Venue IAC"
    sensitiveConfig.midi.iacSourceUniqueID = 99
    sensitiveConfig.midi.iacSourceName = "Ableton House Rig"
    sensitiveConfig.midi.mappings = [
        MIDIMapping(action: .fadeIn, messageType: .noteOn, channel: 1, number: 12, sourceContains: "House Controller")
    ]
    sensitiveConfig.lighting.midiDestinationName = "Lightkey Venue Mac"
    sensitiveConfig.lighting.midiDestinationUniqueID = 42
    sensitiveConfig.lighting.cues = [generatedCue]
    let redactedConfig = PrivacyRedactor.redactedConfig(sensitiveConfig)
    try expect(redactedConfig.audio.preferredOutputUID == PrivacyRedactor.marker, "support config redacts output UID")
    try expect(redactedConfig.midi.virtualDestinationName == PrivacyRedactor.marker, "support config redacts virtual MIDI destination")
    try expect(redactedConfig.midi.iacBusName == PrivacyRedactor.marker, "support config redacts IAC bus name")
    try expect(redactedConfig.midi.iacSourceUniqueID == 0, "support config redacts MIDI source unique ID")
    try expect(redactedConfig.midi.iacSourceName == PrivacyRedactor.marker, "support config redacts MIDI source name")
    try expect(redactedConfig.midi.mappings.first?.sourceContains == PrivacyRedactor.marker, "support config redacts mapping source filters")
    try expect(redactedConfig.lighting.midiDestinationName == PrivacyRedactor.marker, "support config redacts lighting MIDI destination")
    try expect(redactedConfig.lighting.midiDestinationUniqueID == 0, "support config redacts lighting MIDI destination ID")
    try expect(redactedConfig.lighting.cues.isEmpty, "support config removes lighting cue map details")

    var profileConfig = AppConfig()
    profileConfig.audio.targetSampleRate = 96_000
    profileConfig.bedAdvanceMode = .autoCrossfadeAtEnd
    profileConfig.lighting.enabled = true
    profileConfig.lighting.cues = [generatedCue]
    let profile = ShowProfile(name: "Main Stage", config: profileConfig)
    let applied = profile.applying(to: AppConfig())
    try expect(applied.audio.targetSampleRate == 96_000, "show profile applies sample rate")
    try expect(applied.bedAdvanceMode == .autoCrossfadeAtEnd, "show profile applies bed mode")
    try expect(applied.lighting.enabled, "show profile applies lighting enabled")
    try expect(applied.lighting.cues.count == 1, "show profile applies lighting cues")
    try expect(applied.activeProfileID == profile.id, "show profile marks active profile")

    let legacyProfileJSON = try fixtureData("""
    {"id":"00000000-0000-0000-0000-000000000002","name":"Legacy Profile","notes":"","createdAt":"2026-05-11T00:00:00Z","updatedAt":"2026-05-11T00:00:00Z","bedAdvanceMode":"manualContinuous","libraryStorageMode":"managedCopy"}
    """)
    let legacyProfile = try decoder.decode(ShowProfile.self, from: legacyProfileJSON)
    try expect(legacyProfile.name == "Legacy Profile", "legacy profile decodes")
    try expect(!legacyProfile.lighting.enabled, "legacy profile defaults lighting disabled")
    try runLargePlaylistStressChecks()

    // Regression: a >256-byte sysex packet must not crash or truncate.
    // The old packet iteration copied each MIDIPacket to the stack and
    // advanced with MIDIPacketNext on the copy, hitting the stack guard
    // page on the CoreMIDI receive thread for variable-length packets.
    do {
        let bufferSize = 4096
        let listPointer = UnsafeMutableRawPointer.allocate(
            byteCount: bufferSize,
            alignment: MemoryLayout<MIDIPacketList>.alignment
        )
        defer { listPointer.deallocate() }
        let list = listPointer.assumingMemoryBound(to: MIDIPacketList.self)
        var bigSysex: [UInt8] = [0xF0, 0x7E]
        bigSysex.append(contentsOf: Array(repeating: 0x42, count: 700))
        bigSysex.append(0xF7)
        let noteOn: [UInt8] = [0x90, 0x3C, 0x64]
        var cursor = MIDIPacketListInit(list)
        cursor = MIDIPacketListAdd(list, bufferSize, cursor, 0, bigSysex.count, bigSysex)
        cursor = MIDIPacketListAdd(list, bufferSize, cursor, 0, noteOn.count, noteOn)
        try expect(list.pointee.numPackets == 2, "packet list accepts a 700-byte sysex plus a note-on")
        let parsed = MIDIEndpointManager.packetBytes(from: list)
        try expect(parsed.count == 2, "packetBytes reads every packet in a multi-packet list")
        try expect(parsed.first == bigSysex, "packetBytes preserves sysex past the 256-byte packet layout")
        try expect(parsed.last == noteOn, "packetBytes reads the packet that follows a large sysex")
    }

    try expect(MIDIParser.command(from: [0x9F, 120, 100], config: MIDIConfig()) == .fadeIn, "MIDI fade-in parse")
    try expect(MIDIParser.command(from: [0x9F, 120, 0], config: MIDIConfig()) == nil, "velocity-zero note-on ignored")
    try expect(MIDIParser.command(from: [0x90, 120, 100], config: MIDIConfig()) == nil, "wrong channel ignored")
    try expect(MIDIParser.command(from: [0xBF, 20, 64], config: MIDIConfig()) == .setLevel(64.0 / 127.0), "MIDI CC level parse")
    try expect(MIDIParser.event(from: [0xCF, 7])?.messageType == .programChange, "program change event parse")
    try expect(MIDIParser.event(from: [0xFA])?.messageType == .transportStart, "transport start event parse")

    let programConfig = MIDIConfig(mappings: [
        MIDIMapping(action: .panic, messageType: .programChange, channel: 16, number: 7)
    ])
    try expect(MIDIParser.command(from: [0xCF, 7], config: programConfig) == .panic, "programmable program-change mapping")

    let learned = MIDIMapping.learned(
        action: .fadeIn,
        from: MIDIInputEvent(messageType: .controlChange, channel: 2, number: 14, value: 127)
    )
    let learnedConfig = MIDIConfig(mappings: [learned])
    try expect(MIDIParser.command(from: [0xB1, 14, 127], config: learnedConfig) == .fadeIn, "learned CC mapping")

    try expect(OSCParser.commandFromPlainText("/lbk/fadeOut") == .fadeOut, "OSC fade-out parse")
    try expect(OSCParser.commandFromPlainText("/deadAir/panic") == .panic, "OSC panic parse")
    try expect(OSCParser.commandFromPlainText("/lbk/level 0.5") == .setLevel(0.5), "OSC level parse")
    try runParserStressChecks()

    let safetyNow = Date()
    let safetyReadyAt = safetyNow.addingTimeInterval(3)
    try expect(
        ShowControlSafetyPolicy.dropReason(
            for: .fadeIn,
            source: .oscLocal,
            showModeArmed: false,
            setupAssistantOpen: false,
            externalControlReadyAt: safetyNow.addingTimeInterval(-1),
            now: safetyNow
        ) == "Show Mode is disarmed",
        "external fade-in requires armed Show Mode"
    )
    try expect(
        ShowControlSafetyPolicy.dropReason(
            for: .fadeIn,
            source: .ui,
            showModeArmed: false,
            setupAssistantOpen: false,
            externalControlReadyAt: safetyReadyAt,
            now: safetyNow
        ) == nil,
        "UI fade-in bypasses external safety interlock"
    )
    try expect(
        ShowControlSafetyPolicy.dropReason(
            for: .panic,
            source: .midiVirtual,
            showModeArmed: false,
            setupAssistantOpen: true,
            externalControlReadyAt: safetyReadyAt,
            now: safetyNow
        ) == nil,
        "external panic remains available during setup and startup"
    )
    try expect(
        ShowControlSafetyPolicy.dropReason(
            for: .arm,
            source: .midiVirtual,
            showModeArmed: false,
            setupAssistantOpen: false,
            externalControlReadyAt: safetyReadyAt,
            now: safetyNow
        ) == "startup safety window",
        "external arm is blocked during startup safety window"
    )
    try expect(
        ShowControlSafetyPolicy.dropReason(
            for: .fadeIn,
            source: .oscLocal,
            showModeArmed: true,
            setupAssistantOpen: false,
            externalControlReadyAt: safetyNow.addingTimeInterval(-1),
            now: safetyNow
        ) == nil,
        "external fade-in is accepted after startup when Show Mode is armed"
    )

    let deduper = CommandDeduper(window: 0.250)
    let now = Date()
    try expect(deduper.shouldAccept(.fadeIn, source: .midiVirtual, at: now), "dedupe first command accepted")
    try expect(!deduper.shouldAccept(.fadeIn, source: .midiVirtual, at: now.addingTimeInterval(0.100)), "dedupe duplicate dropped")
    try expect(deduper.shouldAccept(.fadeIn, source: .midiVirtual, at: now.addingTimeInterval(0.300)), "dedupe later command accepted")

    let panicDeduper = CommandDeduper(window: 10)
    try expect(panicDeduper.shouldAccept(.panic, source: .midiVirtual, at: now), "panic accepted")
    try expect(panicDeduper.shouldAccept(.panic, source: .midiVirtual, at: now.addingTimeInterval(0.001)), "panic bypasses dedupe")

    for state in PlaybackState.allCases {
        var machine = PlaybackStateMachine(state: state)
        try expect(machine.apply(.panic) == .panicMuted, "panic from \(state.rawValue)")
    }

    try expect(abs(FadeMath.equalPower(0) - 0) < 0.0001, "fade starts at zero")
    try expect(abs(FadeMath.equalPower(1) - 1) < 0.0001, "fade ends at one")
    var previous = 0.0
    for step in 1 ... 100 {
        let value = FadeMath.equalPower(Double(step) / 100.0)
        try expect(value >= previous, "fade curve monotonic at step \(step)")
        previous = value
    }

    let toneURL = try writeTestTone(sampleRate: 44_100, durationSeconds: 0.25)
    let audio = AudioEngineController()
    for sampleRate in [44_100.0, 48_000.0, 88_200.0, 96_000.0] {
        let buffer = try audio.loadBuffer(from: toneURL, sampleRate: sampleRate, maxPredecodedBytes: 16_000_000)
        try expect(buffer.format.sampleRate == sampleRate, "buffer converts to \(sampleRate)")
        try expect(buffer.format.channelCount == 2, "buffer converts to stereo at \(sampleRate)")
        try expect(buffer.frameLength > 0, "buffer has frames at \(sampleRate)")
    }

    do {
        _ = try audio.loadBuffer(from: toneURL, sampleRate: 96_000, maxPredecodedBytes: 128)
        throw CheckFailure(message: "oversize predecode limit should fail")
    } catch AudioEngineError.fileTooLarge {
        // Expected.
    }
    try runAudioDecodeStressChecks(audio: audio)
}

func runDiagnosticsStressChecks() throws {
    Diagnostics.shared.configure(persistJsonl: false, redactSensitiveData: true, retentionDays: 1)
    let group = DispatchGroup()
    for index in 0..<1_000 {
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            Diagnostics.shared.record(
                LogEvent(
                    source: "stress",
                    message: "event \(index)",
                    raw: "file:///Users/operator/Show/\(index).wav smb://venue-nas.local/private \(UUID().uuidString)",
                    audioDeviceUID: "device-\(index)"
                )
            )
            group.leave()
        }
    }
    group.wait()
    Thread.sleep(forTimeInterval: 0.5)
    let snapshot = Diagnostics.shared.snapshot(limit: 1_000)
    try expect(snapshot.count <= 250, "diagnostics stress caps retained events")
    try expect(snapshot.count >= 200, "diagnostics stress retains recent events")
    try expect(snapshot.allSatisfy { $0.raw?.contains("/Users/operator") != true }, "diagnostics stress redacts user paths")
    try expect(snapshot.allSatisfy { $0.raw?.contains("venue-nas.local") != true }, "diagnostics stress redacts network hosts")
    try expect(snapshot.allSatisfy { $0.audioDeviceUID == PrivacyRedactor.marker }, "diagnostics stress redacts device IDs")
}

func runLargePlaylistStressChecks() throws {
    let cues = [
        LightingCue(name: "Walk In", trigger: .fadeInStarted, provider: .luminescenceOSC, cueName: "Blue Wash"),
        LightingCue(name: "Show Off", trigger: .fadeOutCompleted, provider: .showOffOSC)
    ]
    let beds = (0..<2_000).map { index in
        BedItem(
            title: "Bed \(index)",
            fileName: "bed-\(index).wav",
            originalPath: "/Volumes/Show Drive/Private/bed-\(index).wav",
            storageMode: index.isMultiple(of: 3) ? .externalReference : .managedCopy,
            durationSeconds: Double(30 + index % 360),
            sampleRate: index.isMultiple(of: 2) ? 44_100 : 48_000,
            channelCount: 2,
            artist: "Artist \(index % 25)",
            musicalKey: "\(index % 12)A",
            bpm: Double(80 + index % 80),
            energy: index % 10,
            tags: ["stress", "show-\(index % 10)"],
            notes: "Stress playlist note \(index)",
            metadataSource: .manual,
            cueReference: "Scene \(index)",
            lightingCues: cues
        )
    }
    let manifest = LibraryManifest(beds: beds, profileID: UUID())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(manifest)
    try expect(data.count < 5_000_000, "large playlist stays bounded enough for support workflows")
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(LibraryManifest.self, from: data)
    try expect(decoded.beds.count == beds.count, "large playlist bed count round trips")
    try expect(decoded.beds[1_999].lightingCues.count == 2, "large playlist cue details round trip")

    var config = AppConfig()
    config.midi.virtualDestinationName = "Dead Air Private Stage"
    config.midi.mappings = [
        MIDIMapping(action: .fadeIn, messageType: .noteOn, channel: 16, number: 120, sourceContains: "Private Controller")
    ]
    config.lighting.cues = cues
    let redacted = PrivacyRedactor.redactedConfig(config)
    try expect(redacted.lighting.cues.isEmpty, "large support redaction removes cue details")
    try expect(redacted.midi.mappings.first?.sourceContains == PrivacyRedactor.marker, "large support redaction removes private MIDI source")
}

func runParserStressChecks() throws {
    let config = MIDIConfig()
    for statusValue in 0 ... Int(UInt8.max) {
        let status = UInt8(statusValue)
        for length in 0 ... 6 {
            var bytes = [UInt8](repeating: 0, count: length)
            if !bytes.isEmpty {
                bytes[0] = status
            }
            if bytes.count > 1 {
                for index in 1..<bytes.count {
                    bytes[index] = UInt8((Int(status) * 31 + index * 17) % 128)
                }
            }
            _ = MIDIParser.command(from: bytes, config: config)
        }
    }
    try expect(MIDIParser.command(from: [0x9F, 120, 100], config: config) == .fadeIn, "MIDI stress still accepts valid mapped commands")
    try expect(MIDIParser.command(from: [0xFF, 0x7F, 0x7F, 0x7F], config: config) == nil, "MIDI system bytes do not map to playback")

    let malformedOSCInputs: [Data] = [
        Data(),
        Data(repeating: 0, count: 512),
        Data([0xFF, 0xFE, 0xFD, 0x00, 0x2F, 0x6C, 0x62, 0x6B]),
        Data("/lbk/level not-a-number".utf8),
        Data("/lbk/level 999999".utf8),
        Data("/lbk/heartbeat nope maybe".utf8),
        Data((0..<4096).map { UInt8($0 % 251) })
    ]
    for payload in malformedOSCInputs {
        _ = OSCParser.command(from: payload)
    }
    try expect(OSCParser.command(from: Data("/lbk/level 999999".utf8)) == .setLevel(1), "OSC level stress clamps high values")
    try expect(OSCParser.command(from: Data("/lbk/level -25".utf8)) == .setLevel(0), "OSC level stress clamps low values")
}

func runAudioDecodeStressChecks(audio: AudioEngineController) throws {
    for duration in [0.05, 0.1, 0.2] {
        let url = try writeTestTone(sampleRate: 48_000, durationSeconds: duration)
        for sampleRate in [44_100.0, 48_000.0, 96_000.0] {
            let buffer = try audio.loadBuffer(from: url, sampleRate: sampleRate, maxPredecodedBytes: 32_000_000)
            try expect(buffer.format.sampleRate == sampleRate, "audio stress converts \(duration)s tone to \(sampleRate)")
            try expect(buffer.frameLength > 0, "audio stress produces frames")
        }
    }

    let badURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("DeadAirChecks", isDirectory: true)
        .appendingPathComponent("not-audio.txt")
    try Data("not audio".utf8).write(to: badURL, options: [.atomic])
    do {
        _ = try audio.loadBuffer(from: badURL, sampleRate: 48_000, maxPredecodedBytes: 32_000_000)
        throw CheckFailure(message: "unsupported audio should fail")
    } catch AudioEngineError.unsupportedFile {
        // Expected.
    }
}

func writeTestTone(sampleRate: Double, durationSeconds: Double) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DeadAirChecks", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("tone-\(Int(sampleRate)).wav")
    try? FileManager.default.removeItem(at: url)

    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else {
        throw CheckFailure(message: "could not create test tone format")
    }
    let frameCount = AVAudioFrameCount(sampleRate * durationSeconds)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
          let channel = buffer.floatChannelData?[0]
    else {
        throw CheckFailure(message: "could not create test tone buffer")
    }
    buffer.frameLength = frameCount
    for frame in 0..<Int(frameCount) {
        channel[frame] = Float(sin((Double(frame) / sampleRate) * 440.0 * 2.0 * .pi) * 0.2)
    }

    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
    return url
}

do {
    try runChecks()
    print("Dead Air checks passed.")
} catch {
    fputs("Dead Air checks failed: \(error)\n", stderr)
    exit(1)
}
