import AppKit
import DeadAirCore
import SwiftUI
import UniformTypeIdentifiers

struct ReadinessItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let isReady: Bool
}

struct SupportReadinessItem: Codable {
    let title: String
    let detail: String
    let isReady: Bool
}

struct SupportBundle: Codable {
    let generatedAt: Date
    let redactionStatus: String
    let config: AppConfig
    let activeProfile: ShowProfile?
    let readiness: [SupportReadinessItem]
    let recentEvents: [LogEvent]
    let audioDevices: [AudioOutputDevice]
    let outputPairs: [String]
    let lightingCueMap: String
    let appVersion: String
}

enum EventLogFilter: String, CaseIterable, Identifiable {
    case all
    case audio
    case midi
    case oscIn
    case oscOut
    case lighting
    case safety
    case diagnostics

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "All"
        case .audio: "Audio"
        case .midi: "MIDI"
        case .oscIn: "OSC In"
        case .oscOut: "OSC Out"
        case .lighting: "Lighting"
        case .safety: "Safety"
        case .diagnostics: "Diag"
        }
    }

    func includes(_ event: LogEvent) -> Bool {
        switch self {
        case .all:
            return true
        case .audio:
            return event.source == "audio"
        case .midi:
            return ["midiVirtual", "midiIAC", "midi", "midiOut"].contains(event.source)
        case .oscIn:
            return ["oscLocal", "osc"].contains(event.source)
        case .oscOut:
            return event.source == "oscOut"
        case .lighting:
            return event.source == "lighting" || event.source == "oscOut" || event.source == "midiOut"
        case .safety:
            return ["power", "heartbeat", "storage"].contains(event.source) || event.message.contains("recovered") || event.message.contains("degraded")
        case .diagnostics:
            return ["system", "profile", "library", "setup"].contains(event.source)
        }
    }
}

enum LibraryFilter: String, CaseIterable, Identifiable {
    case all
    case ready
    case needsMetadata
    case referenced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "All"
        case .ready: "Ready"
        case .needsMetadata: "Needs Meta"
        case .referenced: "Referenced"
        }
    }
}

private extension ShowSetupPreset {
    var systemIcon: String {
        switch self {
        case .genericDAWVirtualMIDI: "cable.connector"
        case .abletonLightkey: "sparkles"
        case .iacLegacyDAW: "point.3.connected.trianglepath.dotted"
        case .djManual: "headphones"
        case .qlabOSC: "network"
        case .referenceExternalDrive: "externaldrive"
        }
    }

    var shortSummary: String {
        switch self {
        case .genericDAWVirtualMIDI:
            "Clean virtual MIDI setup for most DAWs."
        case .abletonLightkey:
            "Ableton/AbleSet handoffs with Lightkey OSC."
        case .iacLegacyDAW:
            "Exact IAC source workflow for older rigs."
        case .djManual:
            "Manual playback with fewer control surfaces."
        case .qlabOSC:
            "Local OSC control from QLab or show systems."
        case .referenceExternalDrive:
            "References show folders without copying audio."
        }
    }
}

private extension BedItem {
    var searchBlob: String {
        [
            title,
            artist ?? "",
            musicalKey ?? "",
            tags.joined(separator: " "),
            notes ?? "",
            cueReference ?? "",
            lightingCues.map(\.name).joined(separator: " "),
            fileName
        ]
        .joined(separator: " ")
        .lowercased()
    }
}

@main
struct DeadAirApp: App {
    @NSApplicationDelegateAdaptor(DeadAirAppDelegate.self) private var appDelegate
    @StateObject private var model = DeadAirModel()

    var body: some Scene {
        WindowGroup("Dead Air", id: "main") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1180, minHeight: 760)
                .task {
                    model.start()
                }
        }
        .commands {
            CommandMenu("Show") {
                Button("Fade In") { model.uiCommand(.fadeIn) }
                    .keyboardShortcut("i", modifiers: [.command])
                Button("Fade Out") { model.uiCommand(.fadeOut) }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("Next Bed") { model.uiCommand(.nextBed) }
                    .keyboardShortcut(.rightArrow, modifiers: [.command])
                Divider()
                Button("Panic Mute") { model.uiCommand(.panic) }
                    .keyboardShortcut(.escape, modifiers: [.command])
                Divider()
                Button("Close to Menu Bar") {
                    closeMainWindowToMenuBar()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
            CommandMenu("Setup") {
                Button("New Setup") { model.presentSetupWizard() }
                    .keyboardShortcut(",", modifiers: [.command, .shift])
                Button("Save Default Setup") { model.saveDefaultSetup() }
                Button("Export Support Bundle") { model.exportSupportBundle() }
            }
            CommandGroup(replacing: .help) {
                Button("Dead Air Help") { model.presentHelpCenter() }
                    .keyboardShortcut("?", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("Dead Air", systemImage: "waveform") {
            MenuBarControls()
                .environmentObject(model)
        }

        Settings {
            DeadAirSettingsWindow()
                .environmentObject(model)
                .frame(width: 780, height: 620)
                .preferredColorScheme(model.preferredColorScheme)
                .task {
                    model.start()
                }
        }
    }
}

final class DeadAirAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@MainActor
private func closeMainWindowToMenuBar() {
    let mainWindows = NSApplication.shared.windows.filter { window in
        window.title == "Dead Air"
    }

    if mainWindows.isEmpty {
        NSApplication.shared.hide(nil)
        return
    }

    for window in mainWindows {
        window.performClose(nil)
    }
}

@MainActor
final class DeadAirModel: ObservableObject {
    @Published var config = AppConfig()
    @Published var beds: [BedItem] = []
    @Published var state: PlaybackState = .launching
    @Published var devices: [AudioOutputDevice] = []
    @Published var outputPairs: [(left: Int, right: Int)] = []
    @Published var recentEvents: [LogEvent] = []
    @Published var lastCommand = "None"
    @Published var warning: String?
    @Published var lastSavedPlaylistName = "Unsaved"
    @Published var midiOnline = false
    @Published var oscOnline = false
    @Published var heartbeatStatus = "Waiting"
    @Published var droppedEventCount = 0
    @Published var learningMIDIAction: MIDIMappableAction?
    @Published var lastMIDIEventSummary = "No MIDI received"
    @Published var showProfiles: [ShowProfile] = []
    @Published var librarySearch = ""
    @Published var libraryFilter: LibraryFilter = .all
    @Published var eventLogFilter: EventLogFilter = .all
    @Published var lastLightingEventSummary = "No lighting cue sent"
    @Published var lastLightingTestAt: Date?
    @Published var midiSources: [MIDIEndpointDescriptor] = []
    @Published var midiDestinations: [MIDIEndpointDescriptor] = []
    @Published var persistenceRecoveryMessages: [String] = []
    @Published var isSetupWizardPresented = false
    @Published var isHelpCenterPresented = false

    private let persistence = PersistenceStore()
    private let library = LibraryManager()
    private let audio = AudioEngineController()
    private let midi = MIDIEndpointManager()
    private let osc = OSCServer()
    private let lightkeyOSC = LightkeyOSCClient()
    private let lightingMIDI = MIDIOutputManager()
    private let power = PowerManager()
    private let deduper = CommandDeduper()
    private var stateMachine = PlaybackStateMachine()
    private var timer: Timer?
    private var lastHeartbeat: Date?
    private var heartbeatLossHandled = false
    private var pendingBedID: UUID?
    private var playthroughTimer: Timer?
    private var hasStarted = false
    private var isRecoveringAudio = false
    private var pendingAudioRecoveryWorkItem: DispatchWorkItem?
    private var lastLightingFireTimes: [String: Date] = [:]
    private var terminationObserver: NSObjectProtocol?

    var selectedBedID: UUID? {
        get { config.selectedBedID }
        set {
            config.selectedBedID = newValue
            saveConfig()
        }
    }

    var activeBed: BedItem? {
        beds.first { $0.id == config.selectedBedID } ?? beds.first
    }

    var activeProfile: ShowProfile? {
        showProfiles.first { $0.id == config.activeProfileID }
    }

    var filteredBeds: [BedItem] {
        let query = librarySearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return beds.filter { bed in
            let matchesFilter: Bool
            switch libraryFilter {
            case .all:
                matchesFilter = true
            case .ready:
                matchesFilter = bed.enabled
            case .needsMetadata:
                matchesFilter = bed.bpm == nil || (bed.musicalKey ?? "").isEmpty
            case .referenced:
                matchesFilter = bed.storageMode == .externalReference
            }

            guard matchesFilter else { return false }
            guard !query.isEmpty else { return true }
            return bed.searchBlob.contains(query)
        }
    }

    var readinessItems: [ReadinessItem] {
        [
            ReadinessItem(
                title: "Audio Engine",
                detail: state == .degraded ? "Needs attention" : "Running",
                isReady: state != .degraded && state != .launching
            ),
            ReadinessItem(
                title: "Output Route",
                detail: outputRouteDetail,
                isReady: outputRouteIsReady
            ),
            ReadinessItem(
                title: "Sample Rate",
                detail: sampleRatePreflightDetail,
                isReady: sampleRateRouteIsReady
            ),
            ReadinessItem(
                title: "Engine Format",
                detail: audio.engineOutputSummary,
                isReady: state != .degraded
            ),
            ReadinessItem(
                title: "Playlist",
                detail: activeBed.map { "\($0.title) | \($0.storageMode.displayName)" } ?? "No bed loaded",
                isReady: activeBed != nil
            ),
            ReadinessItem(
                title: "Control",
                detail: controlSummary,
                isReady: midiOnline || oscOnline
            ),
            ReadinessItem(
                title: "Show Mode",
                detail: config.showModeArmed ? "Armed" : "Disarmed",
                isReady: config.showModeArmed
            ),
            lightingReadinessItem
        ]
    }

    var filteredRecentEvents: [LogEvent] {
        recentEvents.filter { eventLogFilter.includes($0) }
    }

    var lightingStatusValue: String {
        if !config.lighting.enabled { return "Off" }
        let warnings = config.lighting.validationWarnings(for: activeBed?.lightingCues ?? [])
        if !warnings.isEmpty { return "Check" }
        let count = config.lighting.enabledCueCount + (activeBed?.lightingCues.filter(\.enabled).count ?? 0)
        return count > 0 ? "Ready" : "No Cues"
    }

    var lightingStatusTone: StatusPill.Tone {
        if !config.lighting.enabled { return .neutral }
        return config.lighting.validationWarnings(for: activeBed?.lightingCues ?? []).isEmpty ? .good : .bad
    }

    private var lightingReadinessItem: ReadinessItem {
        guard config.lighting.enabled else {
            return ReadinessItem(title: "Lighting", detail: "Off", isReady: true)
        }
        let warnings = config.lighting.validationWarnings(for: activeBed?.lightingCues ?? [])
        let total = config.lighting.enabledCueCount + (activeBed?.lightingCues.filter(\.enabled).count ?? 0)
        if !warnings.isEmpty {
            return ReadinessItem(title: "Lighting", detail: warnings.first ?? "Needs attention", isReady: false)
        }
        return ReadinessItem(
            title: "Lighting",
            detail: "\(config.lighting.defaultProvider.displayName) | \(total) cue\(total == 1 ? "" : "s")",
            isReady: total > 0
        )
    }

    var lightkeySetupNotes: String {
        """
        Dead Air -> Lighting Setup

        Lightkey:
        1. Open Settings > External Control and enable OSC.
        2. Keep Lightkey listening on 127.0.0.1:\(config.lighting.lightkeyPort).
        3. Copy OSC addresses from cues if you want exact paths.

        Other lighting apps:
        1. Choose Custom OSC in Dead Air.
        2. Set the app's host and receive port.
        3. Paste the exact OSC address that your lighting app expects.

        Dead Air:
        - OSC target: \(config.lighting.lightkeyHost):\(config.lighting.lightkeyPort)
        - Lightkey generated cue example: /live/Live/cue/Transition/activate
        - Custom OSC example: /deadAir/fadeInStarted
        - Audio never waits for lighting cues; failed cues are logged only.

        MIDI fallback:
        - Destination contains: \(config.lighting.midiDestinationName)
        - Default channel: \(config.lighting.midiChannel)
        - Avoid Lightkey channel 16 unless you intentionally use Live Triggers.
        """
    }

    var lightingCueMapText: String {
        let global = config.lighting.cues.map { cue in
            "\(cue.trigger.displayName): \(cue.name) -> \(cue.displaySummary)"
        }
        let bed = beds.flatMap { bed in
            bed.lightingCues.map { cue in
                "\(bed.title) / \(cue.trigger.displayName): \(cue.name) -> \(cue.displaySummary)"
            }
        }
        return (["Dead Air Lighting Cue Map"] + global + bed).joined(separator: "\n")
    }

    var selectedOutputName: String {
        guard let uid = config.audio.preferredOutputUID else { return "System Default" }
        return devices.first { $0.uid == uid }?.name ?? "Selected Output"
    }

    var selectedOutputDevice: AudioOutputDevice? {
        let uid = config.audio.preferredOutputUID ?? CoreAudioDeviceManager.defaultOutputUID()
        guard let uid else { return devices.first(where: \.isDefault) }
        return devices.first { $0.uid == uid } ?? devices.first(where: \.isDefault)
    }

    var outputRouteDetail: String {
        let pair = "\(config.audio.outputLeftChannel)-\(config.audio.outputRightChannel)"
        guard let device = selectedOutputDevice else {
            return "No output device found"
        }
        return "\(device.name) | pair \(pair) | \(device.channelCount) outputs"
    }

    var outputRouteIsReady: Bool {
        guard let device = selectedOutputDevice else { return false }
        return device.channelCount >= max(config.audio.outputLeftChannel, config.audio.outputRightChannel)
            && config.audio.outputLeftChannel != config.audio.outputRightChannel
    }

    var sampleRatePreflightDetail: String {
        guard let device = selectedOutputDevice else {
            return "No device rate"
        }
        let target = Int(config.audio.targetSampleRate)
        let nominal = Int(device.nominalSampleRate)
        if abs(device.nominalSampleRate - config.audio.targetSampleRate) > 1 {
            return "Target \(target) Hz | Device \(nominal) Hz"
        }
        return "Target and device \(target) Hz"
    }

    var sampleRateRouteIsReady: Bool {
        guard let device = selectedOutputDevice, device.nominalSampleRate > 0 else { return false }
        return abs(device.nominalSampleRate - config.audio.targetSampleRate) <= 1
    }

    var preferredColorScheme: ColorScheme? {
        switch config.appearanceMode {
        case .system:
            return nil
        case .showDark, .dark:
            return .dark
        case .light:
            return .light
        }
    }

    var controlSummary: String {
        switch (midiOnline, oscOnline) {
        case (true, true): "MIDI + OSC"
        case (true, false): "MIDI"
        case (false, true): "OSC"
        case (false, false): "Offline"
        }
    }

    var logsDirectory: URL? {
        try? SupportPaths.logsDirectory()
    }

    var appVersionDisplay: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "4.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "4"
        return "v\(version) (\(build))"
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        config = persistence.loadConfig()
        config.version = "4.0.0"
        beds = persistence.loadManifest().beds
        showProfiles = persistence.loadProfiles()
        if beds.isEmpty, let defaultManifest = persistence.loadDefaultManifest() {
            beds = defaultManifest.beds
        }
        if config.activeProfileID == nil {
            config.activeProfileID = showProfiles.first?.id
        }
        if config.selectedBedID == nil {
            config.selectedBedID = beds.first?.id
        }

        persistenceRecoveryMessages = persistence.recoveryMessages
        if warning == nil, let firstRecovery = persistenceRecoveryMessages.first {
            warning = firstRecovery
        }

        Diagnostics.shared.configure(
            persistJsonl: config.logging.persistJsonl,
            redactSensitiveData: config.logging.redactSensitiveData,
            retentionDays: config.logging.retentionDays
        )
        refreshDevices()
        refreshMIDIEndpoints()
        audio.setConfigurationChangeHandler { [weak self] in
            DispatchQueue.main.async {
                self?.scheduleAudioRecovery(reason: "audio device configuration changed")
            }
        }

        do {
            try audio.buildGraph(
                sampleRate: config.audio.targetSampleRate,
                outputUID: config.audio.preferredOutputUID,
                leftChannel: config.audio.outputLeftChannel,
                rightChannel: config.audio.outputRightChannel
            )
            audio.setTargetLevel(db: config.audio.targetLevelDb)
            try primeSelectedBed(muted: true)
            markReadyMuted()
        } catch {
            markDegraded(error.localizedDescription)
        }

        startControlIngress()
        applyPowerState()
        startTimer()
        installTerminationObserver()
        saveAll()
    }

    func uiCommand(_ command: TransitionCommand) {
        handle(RoutedCommand(command: command, source: .ui, rawSummary: "ui"))
    }

    func presentSetupWizard() {
        isSetupWizardPresented = true
    }

    func presentHelpCenter() {
        isHelpCenterPresented = true
    }

    func importAudio(urls: [URL]) {
        do {
            let imported = try library.importFiles(urls, existing: beds, storageMode: config.libraryStorageMode)
            guard !imported.isEmpty else { return }
            beds.append(contentsOf: imported)
            if config.selectedBedID == nil {
                config.selectedBedID = imported.first?.id
                try primeSelectedBed(muted: true)
            }
            saveAll()
            log(source: "library", message: "imported \(imported.count) bed\(imported.count == 1 ? "" : "s")", raw: config.libraryStorageMode.displayName)
        } catch {
            warning = error.localizedDescription
            log(source: "library", message: "import failed", raw: error.localizedDescription)
        }
    }

    func openImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "Import Audio"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio] + ["wav", "aiff", "caf", "mp3", "m4a", "flac"].compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK {
            importAudio(urls: panel.urls)
        }
    }

    func exportPlaylist() {
        let panel = NSSavePanel()
        panel.title = "Save Playlist"
        panel.nameFieldStringValue = suggestedPlaylistName()
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try persistence.exportPlaylist(LibraryManifest(beds: beds, profileID: config.activeProfileID), to: url)
                lastSavedPlaylistName = url.deletingPathExtension().lastPathComponent
                log(source: "library", message: "playlist exported", raw: url.path)
            } catch {
                warning = error.localizedDescription
            }
        }
    }

    func savePlaylistInApp() {
        do {
            let name = suggestedPlaylistName()
            let url = try persistence.saveNamedPlaylist(LibraryManifest(beds: beds, profileID: config.activeProfileID), name: name)
            lastSavedPlaylistName = url.deletingPathExtension().lastPathComponent
            saveManifest()
            log(source: "library", message: "playlist saved", raw: url.lastPathComponent)
        } catch {
            warning = error.localizedDescription
        }
    }

    func saveDefaultSetup() {
        do {
            var defaultConfig = config
            defaultConfig.selectedBedID = selectedBedID
            try persistence.saveDefaultConfig(defaultConfig)
            try persistence.saveDefaultManifest(LibraryManifest(beds: beds, profileID: config.activeProfileID))
            saveAll()
            lastSavedPlaylistName = "Default"
            log(source: "system", message: "default setup saved")
        } catch {
            warning = error.localizedDescription
        }
    }

    func saveCurrentProfile(name: String? = nil) {
        let profileName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = activeProfile?.name ?? "Show Profile \(showProfiles.count + 1)"
        let finalName = profileName?.isEmpty == false ? profileName! : fallbackName

        if let profileID = config.activeProfileID,
           let index = showProfiles.firstIndex(where: { $0.id == profileID }) {
            var profile = ShowProfile(name: finalName, config: config, notes: showProfiles[index].notes)
            profile.id = profileID
            profile.createdAt = showProfiles[index].createdAt
            profile.updatedAt = Date()
            showProfiles[index] = profile
        } else {
            let profile = ShowProfile(name: finalName, config: config)
            showProfiles.append(profile)
            config.activeProfileID = profile.id
        }

        saveProfiles()
        saveConfig()
        log(source: "profile", message: "show profile saved", raw: finalName)
    }

    func createProfileFromCurrent() {
        let profile = ShowProfile(name: "Show Profile \(showProfiles.count + 1)", config: config)
        showProfiles.append(profile)
        config.activeProfileID = profile.id
        saveProfiles()
        saveConfig()
        log(source: "profile", message: "show profile created", raw: profile.name)
    }

    func duplicateActiveProfile() {
        guard let activeProfile else {
            createProfileFromCurrent()
            return
        }
        var copy = activeProfile
        copy.id = UUID()
        copy.name = "\(activeProfile.name) Copy"
        copy.createdAt = Date()
        copy.updatedAt = Date()
        showProfiles.append(copy)
        config.activeProfileID = copy.id
        saveProfiles()
        saveConfig()
        log(source: "profile", message: "show profile duplicated", raw: copy.name)
    }

    func applyProfile(_ id: UUID?) {
        guard let id, let profile = showProfiles.first(where: { $0.id == id }) else { return }
        config = profile.applying(to: config)
        saveConfig()
        startControlIngress()
        applyPowerState()
        recoverAudioEngine(reason: "show profile applied")
        log(source: "profile", message: "show profile applied", raw: profile.name)
    }

    func renameActiveProfile(_ name: String) {
        guard let id = config.activeProfileID,
              let index = showProfiles.firstIndex(where: { $0.id == id }) else { return }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        showProfiles[index].name = cleaned
        showProfiles[index].updatedAt = Date()
        saveProfiles()
    }

    func updateActiveProfileNotes(_ notes: String) {
        guard let id = config.activeProfileID,
              let index = showProfiles.firstIndex(where: { $0.id == id }) else { return }
        showProfiles[index].notes = notes
        showProfiles[index].updatedAt = Date()
        saveProfiles()
    }

    func deleteActiveProfile() {
        guard let id = config.activeProfileID,
              let index = showProfiles.firstIndex(where: { $0.id == id }) else { return }
        let removed = showProfiles.remove(at: index)
        config.activeProfileID = showProfiles.first?.id
        saveProfiles()
        saveConfig()
        log(source: "profile", message: "show profile deleted", raw: removed.name)
    }

    func restoreDefaultSetup() {
        guard let defaultManifest = persistence.loadDefaultManifest() else {
            warning = "No default setup has been saved yet."
            return
        }

        if let defaultConfig = persistence.loadDefaultConfig() {
            config = defaultConfig
        }
        beds = defaultManifest.beds
        if selectedBedID == nil || !beds.contains(where: { $0.id == selectedBedID }) {
            selectedBedID = beds.first?.id
        }
        saveAll()
        do {
            try primeSelectedBed(muted: state != .audible)
            recoverAudioEngine(reason: "default setup restored")
            lastSavedPlaylistName = "Default"
            log(source: "system", message: "default setup restored")
        } catch {
            markDegraded(error.localizedDescription)
        }
    }

    func importPlaylist() {
        let panel = NSOpenPanel()
        panel.title = "Load Playlist"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let manifest = try persistence.importPlaylist(from: url)
                beds = manifest.beds
                config.selectedBedID = beds.first?.id
                saveAll()
                try primeSelectedBed(muted: state != .audible)
                lastSavedPlaylistName = url.deletingPathExtension().lastPathComponent
                log(source: "library", message: "playlist imported", raw: url.path)
            } catch {
                warning = error.localizedDescription
            }
        }
    }

    func moveBed(from source: IndexSet, to destination: Int) {
        beds.move(fromOffsets: source, toOffset: destination)
        saveManifest()
    }

    func moveSelectedBed(up: Bool) {
        guard let id = selectedBedID, let index = beds.firstIndex(where: { $0.id == id }) else { return }
        let target = up ? index - 1 : index + 1
        guard beds.indices.contains(target) else { return }
        beds.swapAt(index, target)
        saveManifest()
    }

    func selectBed(_ id: UUID?) {
        selectedBedID = id
        guard id != nil else { return }
        if state == .readyMuted || state == .panicMuted || state == .launching {
            do {
                try primeSelectedBed(muted: true)
            } catch {
                markDegraded(error.localizedDescription)
            }
        } else if state == .audible || state == .fadingIn {
            crossfadeToSelectedBed(reason: "manual bed selection")
        } else {
            pendingBedID = id
            log(source: "library", message: "bed switch queued until muted")
        }
    }

    func removeSelectedBed() {
        guard let id = selectedBedID, let index = beds.firstIndex(where: { $0.id == id }) else { return }
        let removed = beds.remove(at: index)
        selectedBedID = beds.indices.contains(index) ? beds[index].id : beds.first?.id
        saveAll()
        log(source: "library", message: "removed bed", raw: removed.title)
    }

    func updateBed(_ updated: BedItem) {
        guard let index = beds.firstIndex(where: { $0.id == updated.id }) else { return }
        beds[index] = updated
        saveManifest()
    }

    func relinkSelectedBed() {
        guard let bed = activeBed else { return }
        let panel = NSOpenPanel()
        panel.title = "Relink \(bed.title)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio] + ["wav", "aiff", "caf", "mp3", "m4a", "flac"].compactMap { UTType(filenameExtension: $0) }
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let updated = try library.relink(bed, to: url)
                updateBed(updated)
                if selectedBedID == updated.id {
                    try primeSelectedBed(muted: state != .audible)
                }
                log(source: "library", message: "referenced file relinked", raw: updated.fileName)
            } catch {
                warning = error.localizedDescription
                log(source: "library", message: "relink failed", raw: error.localizedDescription)
            }
        }
    }

    func bindingForSelectedBed() -> Binding<BedItem>? {
        guard let id = selectedBedID,
              beds.contains(where: { $0.id == id }) else { return nil }
        return Binding(
            get: {
                self.beds.first { $0.id == id } ?? BedItem(title: "Missing Bed", fileName: "")
            },
            set: { updated in
                var corrected = updated
                corrected.id = id
                self.updateBed(corrected)
            }
        )
    }

    func refreshDevices() {
        devices = CoreAudioDeviceManager.outputDevices()
        outputPairs = CoreAudioDeviceManager.channelPairs(forUID: config.audio.preferredOutputUID)
        if outputPairs.isEmpty {
            outputPairs = [(1, 2)]
        }
        if !outputPairs.contains(where: { $0.left == config.audio.outputLeftChannel && $0.right == config.audio.outputRightChannel }) {
            config.audio.outputLeftChannel = 1
            config.audio.outputRightChannel = 2
        }
    }

    func refreshMIDIEndpoints() {
        midiSources = MIDIEndpointManager.availableSources()
        midiDestinations = MIDIOutputManager.availableDestinations()
    }

    func setUIMode(_ mode: DeadAirUIMode) {
        config.uiMode = mode
        saveConfig()
    }

    func setAppearanceMode(_ mode: DeadAirAppearanceMode) {
        config.appearanceMode = mode
        saveConfig()
    }

    func applySetupPreset(_ preset: ShowSetupPreset) {
        config = preset.applying(to: config)
        config.setupPreset = preset
        refreshDevices()
        refreshMIDIEndpoints()
        saveConfig()
        startControlIngress()
        recoverAudioEngine(reason: "setup preset applied")
        log(source: "setup", message: "setup preset applied", raw: preset.displayName)
    }

    func completeOnboarding(profileName: String, closeToMenuBar: Bool) {
        let cleanedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        config.hasCompletedOnboarding = true
        if !cleanedName.isEmpty {
            saveCurrentProfile(name: cleanedName)
        }
        saveDefaultSetup()
        saveConfig()
        log(source: "setup", message: "guided setup completed")
        if closeToMenuBar {
            closeMainWindowToMenuBar()
        }
    }

    func setOutputUID(_ uid: String?) {
        config.audio.preferredOutputUID = uid
        refreshDevices()
        saveConfig()
        recoverAudioEngine(reason: "output device selected")
        log(source: "audio", message: "output device selected", raw: uid ?? "system default")
    }

    func setOutputPair(left: Int, right: Int) {
        config.audio.outputLeftChannel = left
        config.audio.outputRightChannel = right
        saveConfig()
        recoverAudioEngine(reason: "output channel pair changed")
        log(source: "audio", message: "output channel pair selected", raw: "\(left)-\(right)")
    }

    func setSampleRate(_ sampleRate: Double) {
        config.audio.targetSampleRate = sampleRate
        saveConfig()
        recoverAudioEngine(reason: "sample rate changed")
        log(source: "audio", message: "sample rate selected", raw: "\(Int(sampleRate)) Hz")
    }

    func setIACSource(_ descriptor: MIDIEndpointDescriptor?) {
        config.midi.iacSourceUniqueID = descriptor?.uniqueID
        config.midi.iacSourceName = descriptor?.name
        config.midi.iacBusName = descriptor?.name ?? config.midi.iacBusName
        saveConfig()
        startControlIngress()
        log(source: "midi", message: "MIDI source selected", raw: descriptor?.name ?? "None")
    }

    func setTargetLevelDb(_ db: Double) {
        config.audio.targetLevelDb = db
        audio.setTargetLevel(db: db)
        saveConfig()
    }

    func setFadeInMs(_ value: Int) {
        config.audio.fadeInMs = value
        saveConfig()
    }

    func setFadeOutMs(_ value: Int) {
        config.audio.fadeOutMs = value
        saveConfig()
    }

    func setLiveCrossfadeMs(_ value: Int) {
        config.audio.liveCrossfadeMs = value
        saveConfig()
        schedulePlaythroughCrossfadeIfNeeded()
    }

    func setBedAdvanceMode(_ mode: BedAdvanceMode) {
        config.bedAdvanceMode = mode
        saveConfig()
        schedulePlaythroughCrossfadeIfNeeded()
        log(source: "library", message: "bed mode changed", raw: mode.displayName)
    }

    func setLibraryStorageMode(_ mode: LibraryStorageMode) {
        config.libraryStorageMode = mode
        saveConfig()
        log(source: "library", message: "library storage mode changed", raw: mode.displayName)
    }

    func setOSCEnabled(_ enabled: Bool) {
        config.osc.enabled = enabled
        saveConfig()
        restartOSC()
    }

    func setOSCPort(_ port: Int) {
        config.osc.port = max(1, min(65_535, port))
        saveConfig()
        restartOSC()
    }

    func retryOSC() {
        restartOSC()
        log(source: "osc", message: "OSC retry requested", raw: "\(config.osc.host):\(config.osc.port)")
    }

    func setLightingEnabled(_ enabled: Bool) {
        config.lighting.enabled = enabled
        saveConfig()
        log(source: "lighting", message: enabled ? "lighting enabled" : "lighting disabled")
    }

    func setLightingDefaultProvider(_ provider: LightingProvider) {
        config.lighting.defaultProvider = provider
        saveConfig()
    }

    func setLightkeyHost(_ host: String) {
        config.lighting.lightkeyHost = host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "127.0.0.1" : host
        saveConfig()
    }

    func setLightkeyPort(_ port: Int) {
        config.lighting.lightkeyPort = max(1, min(65_535, port))
        saveConfig()
    }

    func setLightingMIDIDestination(_ name: String) {
        config.lighting.midiDestinationName = name
        config.lighting.midiDestinationUniqueID = nil
        saveConfig()
    }

    func setLightingMIDIDestination(_ descriptor: MIDIEndpointDescriptor?) {
        config.lighting.midiDestinationName = descriptor?.name ?? ""
        config.lighting.midiDestinationUniqueID = descriptor?.uniqueID
        saveConfig()
    }

    func setLightingMIDIChannel(_ channel: Int) {
        config.lighting.midiChannel = max(1, min(15, channel))
        saveConfig()
    }

    func setLightingMIDIVelocity(_ velocity: Int) {
        config.lighting.midiVelocity = max(0, min(127, velocity))
        saveConfig()
    }

    func setLightingDedupeWindowMs(_ value: Int) {
        config.lighting.dedupeWindowMs = max(0, min(10_000, value))
        saveConfig()
    }

    func addGlobalLightingCue(trigger: LightingCueTrigger = .fadeInStarted) {
        var cue = LightingCue.template(trigger: trigger, provider: config.lighting.defaultProvider)
        cue.midiChannel = config.lighting.midiChannel
        cue.midiValue = config.lighting.midiVelocity
        config.lighting.cues.append(cue)
        saveConfig()
        log(source: "lighting", message: "global cue added", raw: cue.trigger.displayName)
    }

    func updateGlobalLightingCue(_ cue: LightingCue) {
        guard let index = config.lighting.cues.firstIndex(where: { $0.id == cue.id }) else { return }
        config.lighting.cues[index] = cue
        saveConfig()
    }

    func removeGlobalLightingCue(_ id: UUID) {
        config.lighting.cues.removeAll { $0.id == id }
        saveConfig()
    }

    func addLightingCueToSelectedBed(trigger: LightingCueTrigger = .bedPrimed) {
        guard var bed = activeBed else { return }
        var cue = LightingCue.template(trigger: trigger, provider: config.lighting.defaultProvider)
        cue.name = "\(trigger.displayName) - \(bed.title)"
        cue.midiChannel = config.lighting.midiChannel
        cue.midiValue = config.lighting.midiVelocity
        bed.lightingCues.append(cue)
        updateBed(bed)
        log(source: "lighting", message: "track cue added", raw: bed.title)
    }

    func updateSelectedBedLightingCue(_ cue: LightingCue) {
        guard var bed = activeBed,
              let index = bed.lightingCues.firstIndex(where: { $0.id == cue.id })
        else { return }
        bed.lightingCues[index] = cue
        updateBed(bed)
    }

    func removeSelectedBedLightingCue(_ id: UUID) {
        guard var bed = activeBed else { return }
        bed.lightingCues.removeAll { $0.id == id }
        updateBed(bed)
    }

    func testLightingCue() {
        let cue = (config.lighting.cues + (activeBed?.lightingCues ?? [])).first(where: \.enabled)
            ?? LightingCue(name: "Dead Air Test", trigger: .manualTest, pageName: "Live", cueName: "Transition", action: .toggle)
        fireLighting(trigger: .manualTest, bed: activeBed, extraCues: [cue], bypassDedupe: true)
        lastLightingTestAt = Date()
    }

    func copyLightkeySetupNotesToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lightkeySetupNotes, forType: .string)
        log(source: "lighting", message: "Lightkey setup notes copied")
    }

    func copyLightingCueMapToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lightingCueMapText, forType: .string)
        log(source: "lighting", message: "lighting cue map copied")
    }

    func exportSupportBundle() {
        let panel = NSSavePanel()
        panel.title = "Export Dead Air Support Bundle"
        panel.nameFieldStringValue = "Dead Air Support \(supportBundleTimestamp()).json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let shouldRedact = config.logging.redactSensitiveData
                let bundle = SupportBundle(
                    generatedAt: Date(),
                    redactionStatus: shouldRedact ? "enabled" : "disabled",
                    config: shouldRedact ? redactedSupportConfig() : config,
                    activeProfile: shouldRedact ? nil : activeProfile,
                    readiness: redactedReadinessItems(shouldRedact: shouldRedact),
                    recentEvents: redactedRecentEvents(shouldRedact: shouldRedact),
                    audioDevices: shouldRedact ? redactedAudioDevices() : devices,
                    outputPairs: outputPairs.map { "\($0.left)-\($0.right)" },
                    lightingCueMap: shouldRedact ? "[redacted]" : lightingCueMapText,
                    appVersion: appVersionDisplay
                )
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(bundle)
                try data.write(to: url, options: Data.WritingOptions.atomic)
                log(source: "system", message: "support bundle exported", raw: url.path)
            } catch {
                warning = error.localizedDescription
                log(source: "system", message: "support bundle export failed", raw: error.localizedDescription)
            }
        }
    }

    private func redactedSupportConfig() -> AppConfig {
        PrivacyRedactor.redactedConfig(config)
    }

    private func redactedReadinessItems(shouldRedact: Bool) -> [SupportReadinessItem] {
        readinessItems.map { item in
            SupportReadinessItem(
                title: item.title,
                detail: shouldRedact ? PrivacyRedactor.redact(item.detail) : item.detail,
                isReady: item.isReady
            )
        }
    }

    private func redactedRecentEvents(shouldRedact: Bool) -> [LogEvent] {
        let events = Diagnostics.shared.snapshot(limit: 250)
        return shouldRedact ? events.map(PrivacyRedactor.redactedLogEvent) : events
    }

    private func redactedAudioDevices() -> [AudioOutputDevice] {
        devices.enumerated().map { index, device in
            AudioOutputDevice(
                uid: "[redacted-\(index + 1)]",
                name: "Audio Device \(index + 1)",
                nominalSampleRate: device.nominalSampleRate,
                channelCount: device.channelCount,
                isDefault: device.isDefault
            )
        }
    }

    func setPreventIdleSleep(_ enabled: Bool) {
        config.power.preventIdleSleep = enabled
        saveConfig()
        applyPowerState()
    }

    func setHeartbeatEnabled(_ enabled: Bool) {
        config.heartbeat.enabled = enabled
        saveConfig()
    }

    func setHeartbeatTimeoutMs(_ timeout: Int) {
        config.heartbeat.timeoutMs = timeout
        saveConfig()
    }

    func setDiagnosticsLogging(enabled: Bool) {
        config.logging.persistJsonl = enabled
        saveConfig()
        Diagnostics.shared.configure(
            persistJsonl: config.logging.persistJsonl,
            redactSensitiveData: config.logging.redactSensitiveData,
            retentionDays: config.logging.retentionDays
        )
    }

    func setDiagnosticsRedaction(enabled: Bool) {
        config.logging.redactSensitiveData = enabled
        saveConfig()
        Diagnostics.shared.configure(
            persistJsonl: config.logging.persistJsonl,
            redactSensitiveData: config.logging.redactSensitiveData,
            retentionDays: config.logging.retentionDays
        )
    }

    func setDiagnosticsRetentionDays(_ days: Int) {
        config.logging.retentionDays = max(1, min(365, days))
        saveConfig()
        Diagnostics.shared.configure(
            persistJsonl: config.logging.persistJsonl,
            redactSensitiveData: config.logging.redactSensitiveData,
            retentionDays: config.logging.retentionDays
        )
    }

    func setShowModeArmed(_ armed: Bool) {
        handle(RoutedCommand(command: armed ? .arm : .disarm, source: .ui, rawSummary: "ui show mode"))
    }

    func copyCueMapToClipboard() {
        let text = """
        Dead Air Cue Map

        Default MIDI:
        Ch 16 Note 120 = Fade In
        Ch 16 Note 121 = Fade Out
        Ch 16 Note 122 = Panic Mute
        Ch 16 Note 123 = Next Bed
        Ch 16 Note 124 = Arm Show Mode
        Ch 16 Note 125 = Disarm Show Mode
        Ch 16 CC 20 = Target Level

        OSC:
        /lbk/fadeIn
        /lbk/fadeOut
        /lbk/panic
        /lbk/nextBed
        /lbk/arm
        /lbk/disarm
        /lbk/level 0.0..1.0
        /lbk/heartbeat <ms> <isPlaying> <songRef?> <uuid?>

        Lighting OSC Out:
        Target \(config.lighting.lightkeyHost):\(config.lighting.lightkeyPort)
        Lightkey example /live/Live/cue/Transition/activate
        Custom OSC example /deadAir/fadeInStarted
        \(lightingCueMapText)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        log(source: "system", message: "cue map copied")
    }

    private func startControlIngress() {
        do {
            try midi.start(config: config.midi) { [weak self] routed in
                DispatchQueue.main.async {
                    self?.handleMIDI(routed)
                }
            }
            midiOnline = true
        } catch {
            midiOnline = false
            warning = error.localizedDescription
            log(source: "midi", message: "MIDI failed", raw: error.localizedDescription)
        }

        restartOSC()
    }

    private func restartOSC() {
        do {
            try osc.start(config: config.osc) { [weak self] routed in
                DispatchQueue.main.async {
                    self?.handle(routed)
                }
            }
            oscOnline = config.osc.enabled
        } catch {
            oscOnline = false
            warning = error.localizedDescription
            log(source: "osc", message: "OSC failed", raw: error.localizedDescription)
        }
    }

    private func handleMIDI(_ routed: RoutedMIDIEvent) {
        lastMIDIEventSummary = routed.event.displaySummary

        if let learningMIDIAction {
            let mapping = MIDIMapping.learned(action: learningMIDIAction, from: routed.event)
            setMIDIMapping(mapping, for: learningMIDIAction)
            self.learningMIDIAction = nil
            log(
                source: routed.source.rawValue,
                message: "learned MIDI \(learningMIDIAction.displayName)",
                raw: mapping.displaySummary
            )
            return
        }

        guard let command = routed.command else { return }
        handle(RoutedCommand(command: command, source: routed.source, rawSummary: routed.rawSummary, receivedAt: routed.event.receivedAt))
    }

    func mapping(for action: MIDIMappableAction) -> MIDIMapping {
        config.midi.mappings.first { $0.action == action } ?? MIDIMapping.learned(
            action: action,
            from: MIDIInputEvent(
                messageType: action == .level ? .controlChange : .noteOn,
                channel: config.midi.channel,
                number: defaultNumber(for: action),
                value: action == .level ? nil : 127
            )
        )
    }

    func beginMIDILearn(_ action: MIDIMappableAction) {
        learningMIDIAction = action
        log(source: "midi", message: "MIDI learn armed", raw: action.displayName)
    }

    func cancelMIDILearn() {
        learningMIDIAction = nil
    }

    func resetMIDIMappings() {
        config.midi.mappings = MIDIConfig.defaultMappings(
            channel: config.midi.channel,
            fadeInNote: config.midi.fadeInNote,
            fadeOutNote: config.midi.fadeOutNote,
            panicNote: config.midi.panicNote,
            nextBedNote: config.midi.nextBedNote,
            armNote: config.midi.armNote,
            disarmNote: config.midi.disarmNote,
            levelCC: config.midi.levelCC
        )
        saveConfig()
        startControlIngress()
        log(source: "midi", message: "MIDI map reset")
    }

    func updateMIDIMapping(_ mapping: MIDIMapping) {
        setMIDIMapping(mapping, for: mapping.action)
        startControlIngress()
    }

    func setMIDIMode(_ mode: MIDIConfig.Mode) {
        config.midi.mode = mode
        saveConfig()
        startControlIngress()
    }

    func setMIDIChannel(_ channel: Int) {
        config.midi.channel = channel
        saveConfig()
    }

    private func setMIDIMapping(_ mapping: MIDIMapping, for action: MIDIMappableAction) {
        config.midi.mappings.removeAll { $0.action == action }
        config.midi.mappings.append(mapping)
        config.midi.mappings.sort { $0.action.rawValue < $1.action.rawValue }
        saveConfig()
        startControlIngress()
    }

    private func defaultNumber(for action: MIDIMappableAction) -> Int? {
        switch action {
        case .fadeIn: config.midi.fadeInNote
        case .fadeOut: config.midi.fadeOutNote
        case .panic: config.midi.panicNote
        case .nextBed: config.midi.nextBedNote
        case .arm: config.midi.armNote
        case .disarm: config.midi.disarmNote
        case .level: config.midi.levelCC
        }
    }

    private func handle(_ routed: RoutedCommand) {
        if !deduper.shouldAccept(routed.command, source: routed.source, at: routed.receivedAt) {
            droppedEventCount += 1
            return
        }

        let pre = state
        lastCommand = "\(routed.source.rawValue): \(routed.command.displayName)"

        switch routed.command {
        case .fadeIn:
            guard activeBed != nil else {
                warning = "Import at least one audio bed before fading in."
                return
            }
            cancelPlaythroughCrossfade()
            stateMachine.apply(.fadeIn)
            state = stateMachine.state
            fireLighting(trigger: .fadeInStarted, bed: activeBed)
            audio.fadeIn(durationMs: config.audio.fadeInMs) { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.stateMachine.markAudible()
                    self.state = self.stateMachine.state
                    self.schedulePlaythroughCrossfadeIfNeeded()
                    self.fireLighting(trigger: .fadeInCompleted, bed: self.activeBed)
                    self.log(source: "audio", message: "fade in complete")
                }
            }
        case .fadeOut:
            cancelPlaythroughCrossfade()
            if state == .readyMuted || state == .panicMuted { break }
            stateMachine.apply(.fadeOut)
            state = stateMachine.state
            fireLighting(trigger: .fadeOutStarted, bed: activeBed)
            audio.fadeOut(durationMs: config.audio.fadeOutMs) { [weak self] in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.stateMachine.markReadyMuted()
                    self.state = self.stateMachine.state
                    self.handlePostFadeOutBedPrep()
                    self.fireLighting(trigger: .fadeOutCompleted, bed: self.activeBed)
                    self.log(source: "audio", message: "fade out complete")
                }
            }
        case .panic:
            cancelPlaythroughCrossfade()
            stateMachine.apply(.panic)
            state = stateMachine.state
            audio.panicMute()
            fireLighting(trigger: .panicMuted, bed: activeBed)
        case .nextBed:
            advanceBed()
        case .arm:
            config.showModeArmed = true
            stateMachine.apply(.arm)
            if state == .panicMuted || state == .launching || state == .degraded {
                state = stateMachine.state
            }
            applyPowerState()
            saveConfig()
            fireLighting(trigger: .showModeArmed, bed: activeBed)
        case .disarm:
            config.showModeArmed = false
            stateMachine.apply(.disarm)
            applyPowerState()
            saveConfig()
            fireLighting(trigger: .showModeDisarmed, bed: activeBed)
        case .clearPanic:
            stateMachine.apply(.clearPanic)
            state = stateMachine.state
        case .setLevel(let value):
            audio.setTargetLevel(linear: value)
        case .heartbeat(let payload):
            lastHeartbeat = payload.receivedAt
            heartbeatLossHandled = false
            heartbeatStatus = "OK"
        }

        log(
            source: routed.source.rawValue,
            message: routed.command.displayName,
            raw: routed.rawSummary,
            command: routed.command.key,
            pre: pre,
            post: state
        )
    }

    private func advanceBed() {
        let enabledBeds = beds.filter(\.enabled)
        guard !enabledBeds.isEmpty else { return }
        let currentID = selectedBedID
        let currentIndex = enabledBeds.firstIndex { $0.id == currentID } ?? -1
        let next = enabledBeds[(currentIndex + 1) % enabledBeds.count]
        selectedBedID = next.id
        fireLighting(trigger: .nextBedSelected, bed: next)

        if state == .readyMuted || state == .panicMuted || state == .launching {
            do {
                try primeSelectedBed(muted: true)
            } catch {
                markDegraded(error.localizedDescription)
            }
        } else if state == .audible || state == .fadingIn {
            crossfadeToSelectedBed(reason: "next bed")
        } else {
            pendingBedID = next.id
        }
    }

    private func handlePostFadeOutBedPrep() {
        if pendingBedID != nil {
            primePendingBedIfNeeded()
            return
        }

        guard config.bedAdvanceMode == .autoPrepareNextOnFadeOut else { return }
        selectNextBedSilently()
    }

    private func primePendingBedIfNeeded() {
        guard let pendingBedID else { return }
        selectedBedID = pendingBedID
        self.pendingBedID = nil
        do {
            try primeSelectedBed(muted: true)
        } catch {
            markDegraded(error.localizedDescription)
        }
    }

    private func refreshBookmarkIfNeeded(for bed: BedItem) {
        guard let refreshed = try? library.refreshedBookmarkDataIfNeeded(for: bed),
              let index = beds.firstIndex(where: { $0.id == bed.id })
        else { return }
        beds[index].bookmarkData = refreshed
        saveManifest()
        log(source: "library", message: "security bookmark refreshed", raw: beds[index].fileName)
    }

    private func primeSelectedBed(muted: Bool) throws {
        guard let bed = activeBed else { return }
        refreshBookmarkIfNeeded(for: bed)
        let currentBed = activeBed ?? bed
        try library.withSecurityScopedAccess(to: currentBed) { url in
            try audio.prime(
                url: url,
                sampleRate: config.audio.targetSampleRate,
                muted: muted,
                maxPredecodedBytes: config.audio.maxPredecodedBytes
            )
        }
        fireLighting(trigger: .bedPrimed, bed: currentBed)
    }

    private func selectNextBedSilently() {
        guard let next = nextEnabledBed(after: selectedBedID) else { return }
        selectedBedID = next.id
        do {
            try primeSelectedBed(muted: true)
            log(source: "library", message: "next bed primed", raw: next.title)
        } catch {
            markDegraded(error.localizedDescription)
        }
    }

    private func nextEnabledBed(after id: UUID?) -> BedItem? {
        let enabledBeds = beds.filter(\.enabled)
        guard !enabledBeds.isEmpty else { return nil }
        let currentIndex = enabledBeds.firstIndex { $0.id == id } ?? -1
        return enabledBeds[(currentIndex + 1) % enabledBeds.count]
    }

    private func crossfadeToSelectedBed(reason: String) {
        guard let bed = activeBed else { return }
        do {
            cancelPlaythroughCrossfade()
            refreshBookmarkIfNeeded(for: bed)
            let currentBed = activeBed ?? bed
            try library.withSecurityScopedAccess(to: currentBed) { url in
                fireLighting(trigger: .crossfadeStarted, bed: currentBed)
                try audio.crossfadeTo(
                    url: url,
                    sampleRate: config.audio.targetSampleRate,
                    durationMs: config.audio.liveCrossfadeMs,
                    maxPredecodedBytes: config.audio.maxPredecodedBytes
                ) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.stateMachine.markAudible()
                        self.state = self.stateMachine.state
                        self.schedulePlaythroughCrossfadeIfNeeded()
                        self.fireLighting(trigger: .crossfadeCompleted, bed: currentBed)
                        self.log(source: "audio", message: "crossfade complete", raw: currentBed.title)
                    }
                }
            }
            stateMachine.markAudible()
            state = stateMachine.state
            log(source: "audio", message: "crossfade started", raw: "\(reason): \(currentBed.title)")
        } catch {
            markDegraded(error.localizedDescription)
        }
    }

    private func schedulePlaythroughCrossfadeIfNeeded() {
        cancelPlaythroughCrossfade()
        guard config.bedAdvanceMode == .autoCrossfadeAtEnd,
              state == .audible,
              let bed = activeBed,
              let durationSeconds = bed.durationSeconds,
              beds.filter(\.enabled).count > 1
        else {
            return
        }

        let leadTime = Double(config.audio.liveCrossfadeMs) / 1000.0
        let fireAfter = max(1.0, durationSeconds - leadTime)
        playthroughTimer = Timer.scheduledTimer(withTimeInterval: fireAfter, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.advanceBed()
            }
        }
        log(source: "library", message: "auto-crossfade armed", raw: "\(bed.title) in \(Int(fireAfter))s")
    }

    private func cancelPlaythroughCrossfade() {
        playthroughTimer?.invalidate()
        playthroughTimer = nil
    }

    private func fireLighting(
        trigger: LightingCueTrigger,
        bed: BedItem?,
        extraCues: [LightingCue] = [],
        bypassDedupe: Bool = false
    ) {
        guard config.lighting.enabled || bypassDedupe else { return }
        let cues: [LightingCue]
        if extraCues.isEmpty {
            cues = config.lighting.cues.filter { $0.trigger == trigger } + (bed?.lightingCues.filter { $0.trigger == trigger } ?? [])
        } else {
            cues = extraCues
        }
        guard !cues.isEmpty else { return }

        let lightingConfig = config.lighting
        for cue in cues where cue.enabled {
            if !bypassDedupe, shouldDedupeLightingCue(cue, trigger: trigger) {
                continue
            }

            let warnings = cue.validationWarnings(config: lightingConfig)
            if !warnings.isEmpty {
                log(source: "lighting", message: "cue skipped", raw: "\(cue.name): \(warnings.joined(separator: " "))")
                lastLightingEventSummary = "Skipped \(cue.name)"
                continue
            }

            switch cue.provider {
            case .lightkeyOSC, .customOSC:
                lightkeyOSC.send(cue: cue, config: lightingConfig, trigger: trigger) { [weak self] result in
                    Task { @MainActor in
                        self?.handleLightingResult(result)
                    }
                }
            case .midi:
                lightingMIDI.send(cue: cue, config: lightingConfig, trigger: trigger) { [weak self] result in
                    Task { @MainActor in
                        self?.handleLightingResult(result)
                    }
                }
            }
        }
    }

    private func fireAppQuitLightingSynchronously() {
        guard config.lighting.enabled else { return }
        let lightingConfig = config.lighting
        let cues = (config.lighting.cues + (activeBed?.lightingCues ?? []))
            .filter { $0.enabled && $0.trigger == .appQuit && $0.provider.usesOSC }
        for cue in cues {
            let result = lightkeyOSC.sendSynchronously(cue: cue, config: lightingConfig, trigger: .appQuit)
            handleLightingResult(result)
        }
    }

    private func shouldDedupeLightingCue(_ cue: LightingCue, trigger: LightingCueTrigger) -> Bool {
        let window = Double(config.lighting.dedupeWindowMs) / 1000.0
        guard window > 0 else { return false }
        let key = "\(cue.id.uuidString)-\(trigger.rawValue)"
        let now = Date()
        if let last = lastLightingFireTimes[key], now.timeIntervalSince(last) < window {
            return true
        }
        lastLightingFireTimes[key] = now
        return false
    }

    private func handleLightingResult(_ result: LightingCueSendResult) {
        let status = result.success ? "packet sent" : "failed"
        let raw = result.errorMessage.map { "\(result.target) | \($0)" } ?? result.target
        lastLightingEventSummary = "\(result.trigger.displayName): \(result.cueName) \(status)"
        log(source: result.provider.usesOSC ? "oscOut" : "midiOut", message: "cue \(status)", raw: raw)
    }

    private func scheduleAudioRecovery(reason: String) {
        pendingAudioRecoveryWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.recoverAudioEngine(reason: reason)
            }
        }
        pendingAudioRecoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func recoverAudioEngine(reason: String) {
        guard !isRecoveringAudio else { return }
        isRecoveringAudio = true
        let wasAudible = state == .audible || state == .fadingIn

        do {
            try audio.rebuild(
                sampleRate: config.audio.targetSampleRate,
                outputUID: config.audio.preferredOutputUID,
                leftChannel: config.audio.outputLeftChannel,
                rightChannel: config.audio.outputRightChannel
            )
            try primeSelectedBed(muted: true)
            if state == .degraded {
                markReadyMuted()
            } else if wasAudible {
                stateMachine.markReadyMuted()
                state = stateMachine.state
                warning = "Audio route changed. Dead Air recovered muted so the show output does not jump unexpectedly."
            }
            if !wasAudible {
                warning = nil
            }
            schedulePlaythroughCrossfadeIfNeeded()
            log(source: "audio", message: "engine recovered", raw: reason)
        } catch {
            markDegraded(error.localizedDescription)
        }

        isRecoveringAudio = false
    }

    private func markReadyMuted() {
        stateMachine.markReadyMuted()
        state = stateMachine.state
    }

    private func markDegraded(_ message: String) {
        warning = message
        stateMachine.markDegraded()
        state = stateMachine.state
        log(source: "system", message: "degraded", raw: message)
    }

    private func applyPowerState() {
        if config.showModeArmed, config.power.preventIdleSleep {
            power.arm()
        } else {
            power.disarm()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func installTerminationObserver() {
        guard terminationObserver == nil else { return }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.fireAppQuitLightingSynchronously()
            }
        }
    }

    private func tick() {
        recentEvents = Diagnostics.shared.snapshot(limit: 80)
        refreshDevices()
        refreshMIDIEndpoints()
        checkHeartbeat()
    }

    private func checkHeartbeat() {
        guard config.showModeArmed, config.heartbeat.enabled else {
            heartbeatStatus = "Off"
            return
        }

        guard let lastHeartbeat else {
            heartbeatStatus = "Waiting"
            return
        }

        let elapsedMs = Int(Date().timeIntervalSince(lastHeartbeat) * 1000)
        if elapsedMs <= config.heartbeat.timeoutMs {
            heartbeatStatus = "\(elapsedMs) ms ago"
            return
        }

        heartbeatStatus = "Lost"
        guard !heartbeatLossHandled else { return }
        heartbeatLossHandled = true
        fireLighting(trigger: .heartbeatLost, bed: activeBed)

        switch config.heartbeat.onLoss {
        case .none:
            log(source: "heartbeat", message: "heartbeat lost")
        case .fadeInIfMuted:
            if state == .readyMuted {
                handle(RoutedCommand(command: .fadeIn, source: .heartbeat, rawSummary: "heartbeat timeout"))
            } else {
                log(source: "heartbeat", message: "heartbeat lost; already audible or busy")
            }
        case .enterDegraded:
            markDegraded("Heartbeat lost.")
        }
    }

    private func saveAll() {
        saveConfig()
        saveManifest()
    }

    private func suggestedPlaylistName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "Dead Air Playlist \(formatter.string(from: Date())).json"
    }

    private func supportBundleTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return formatter.string(from: Date())
    }

    private func saveConfig() {
        do {
            try persistence.saveConfig(config)
        } catch {
            warning = "Dead Air could not save settings: \(error.localizedDescription)"
            log(source: "storage", message: "settings save failed", raw: error.localizedDescription)
        }
    }

    private func saveManifest() {
        do {
            try persistence.saveManifest(LibraryManifest(beds: beds, profileID: config.activeProfileID))
        } catch {
            warning = "Dead Air could not save the playlist: \(error.localizedDescription)"
            log(source: "storage", message: "playlist save failed", raw: error.localizedDescription)
        }
    }

    private func saveProfiles() {
        do {
            try persistence.saveProfiles(showProfiles)
        } catch {
            warning = "Dead Air could not save show profiles: \(error.localizedDescription)"
            log(source: "storage", message: "profiles save failed", raw: error.localizedDescription)
        }
    }

    private func log(
        source: String,
        message: String,
        raw: String? = nil,
        command: String? = nil,
        pre: PlaybackState? = nil,
        post: PlaybackState? = nil
    ) {
        Diagnostics.shared.record(
            LogEvent(
                source: source,
                message: message,
                raw: raw,
                command: command,
                preState: pre?.rawValue,
                postState: post?.rawValue,
                bedID: selectedBedID,
                audioDeviceUID: config.audio.preferredOutputUID,
                droppedEventCount: droppedEventCount
            )
        )
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: DeadAirModel
    @Environment(\.openSettings) private var openSettings
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
            HStack(alignment: .top, spacing: 0) {
                MainControlsView()
                    .frame(minWidth: 390, maxWidth: 430)
                LibraryView(isDropTargeted: $isDropTargeted)
                    .frame(minWidth: 430)
                if model.config.uiMode == .advanced {
                    EventLogView()
                        .frame(minWidth: 300, maxWidth: 350)
                } else {
                    SimpleShowPanel()
                        .frame(minWidth: 300, maxWidth: 350)
                }
            }
            .padding(14)
            .gaplessPanelStyle()
        }
        .stageGlassBackground()
        .preferredColorScheme(model.preferredColorScheme)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .onAppear {
            if !model.config.hasCompletedOnboarding {
                model.presentSetupWizard()
            }
        }
        .sheet(isPresented: Binding(get: {
            model.isSetupWizardPresented
        }, set: { model.isSetupWizardPresented = $0 })) {
            SetupWizardView(isPresented: Binding(get: {
                model.isSetupWizardPresented
            }, set: { model.isSetupWizardPresented = $0 }))
                .environmentObject(model)
                .frame(width: 920, height: 640)
                .preferredColorScheme(model.preferredColorScheme)
        }
        .sheet(isPresented: Binding(get: {
            model.isHelpCenterPresented
        }, set: { model.isHelpCenterPresented = $0 })) {
            HelpCenterView()
                .environmentObject(model)
                .frame(width: 760, height: 620)
                .preferredColorScheme(model.preferredColorScheme)
        }
        .toolbar {
            ToolbarItemGroup {
                Picker("Mode", selection: Binding(get: {
                    model.config.uiMode
                }, set: { model.setUIMode($0) })) {
                    ForEach(DeadAirUIMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    model.openImportPanel()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                Button {
                    model.savePlaylistInApp()
                } label: {
                    Label("Save Playlist", systemImage: "tray.and.arrow.down")
                }
                Button {
                    model.copyCueMapToClipboard()
                } label: {
                    Label("Cue Map", systemImage: "doc.on.doc")
                }
            }

            ToolbarItemGroup {
                Button {
                    model.presentSetupWizard()
                } label: {
                    Label("New Setup", systemImage: "wand.and.stars")
                }
                Button {
                    model.presentHelpCenter()
                } label: {
                    Label("Help", systemImage: "questionmark.circle")
                }
                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                Button {
                    closeMainWindowToMenuBar()
                } label: {
                    Label("Menu Bar", systemImage: "menubar.rectangle")
                }
                Button {
                    model.setShowModeArmed(!model.config.showModeArmed)
                } label: {
                    Label(model.config.showModeArmed ? "Disarm Show" : "Arm Show", systemImage: model.config.showModeArmed ? "shield.slash" : "checkmark.shield")
                }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let nsURL = item as? NSURL {
                    url = nsURL as URL
                }
                if let url {
                    DispatchQueue.main.async {
                        model.importAudio(urls: [url])
                    }
                }
            }
        }
        return true
    }
}

struct SimpleShowPanel: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Preflight", systemImage: "checklist.checked", help: "Live-readiness checks for output, control, playlist, lighting, and show safety.")
            ReadinessPanel()
            if let warning = model.warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(4)
            }
            Divider()
            Button {
                model.presentSetupWizard()
            } label: {
                Label("New Setup", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            Button {
                model.saveDefaultSetup()
            } label: {
                Label("Save Default", systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .padding(16)
    }
}

private enum SetupWizardStep: String, CaseIterable, Identifiable {
    case preset
    case audio
    case files
    case lightkey
    case finish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preset: "Preset"
        case .audio: "Audio"
        case .files: "Files & Control"
        case .lightkey: "Lighting"
        case .finish: "Finish"
        }
    }

    var systemImage: String {
        switch self {
        case .preset: "wand.and.stars"
        case .audio: "speaker.wave.3"
        case .files: "folder.badge.gearshape"
        case .lightkey: "lightbulb.2"
        case .finish: "checkmark.seal"
        }
    }
}

struct SetupWizardView: View {
    @EnvironmentObject private var model: DeadAirModel
    @Binding var isPresented: Bool
    @State private var preset: ShowSetupPreset = .abletonLightkey
    @State private var profileName = "Guided Pro Setup"
    @State private var closeToMenuBar = false
    @State private var step: SetupWizardStep = .preset

    var body: some View {
        HStack(spacing: 0) {
            wizardRail
                .frame(width: 235)
                .padding(18)
                .background(.regularMaterial)

            VStack(spacing: 0) {
                wizardHeader
                    .padding(.horizontal, 26)
                    .padding(.top, 22)
                    .padding(.bottom, 14)

                Divider()

                ScrollView {
                    stepContent
                        .padding(26)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                Divider()
                wizardFooter
                    .padding(18)
                    .background(.regularMaterial)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(.regularMaterial)
        }
        .onAppear {
            preset = model.config.setupPreset
            profileName = model.activeProfile?.name ?? model.config.setupPreset.profileName
            model.refreshMIDIEndpoints()
            model.refreshDevices()
            if !model.config.hasCompletedOnboarding {
                model.applySetupPreset(preset)
            }
        }
    }

    private var wizardRail: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                LogoMarkView(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dead Air")
                        .font(.title3.bold())
                    Text("Setup")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Text("A show-ready setup in five steps.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(SetupWizardStep.allCases) { item in
                    Button {
                        step = item
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(stepIndex(item) <= currentStepIndex ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.12))
                                Image(systemName: stepIndex(item) < currentStepIndex ? "checkmark" : item.systemImage)
                                    .font(.caption.bold())
                                    .foregroundStyle(stepIndex(item) <= currentStepIndex ? Color.accentColor : Color.secondary)
                            }
                            .frame(width: 30, height: 30)

                            Text(item.title)
                                .font(.callout.weight(step == item ? .bold : .medium))
                                .foregroundStyle(step == item ? Color.primary : Color.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(step == item ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            WizardMiniStatus(title: "Output", value: model.selectedOutputName, systemImage: "speaker.wave.2")
            WizardMiniStatus(title: "Control", value: model.controlSummary, systemImage: "cable.connector")
        }
    }

    private var wizardHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.largeTitle.bold())
                Text(headerSubtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(currentStepIndex + 1) of \(SetupWizardStep.allCases.count)")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.14), in: Capsule())
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .preset:
            presetStep
        case .audio:
            audioStep
        case .files:
            filesStep
        case .lightkey:
            lightkeyStep
        case .finish:
            finishStep
        }
    }

    private var presetStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(ShowSetupPreset.allCases) { option in
                    WizardPresetCard(
                        preset: option,
                        isSelected: preset == option,
                        isRecommended: option == .abletonLightkey
                    ) {
                        preset = option
                        profileName = option.profileName
                        model.applySetupPreset(option)
                    }
                }
            }

            WizardInsightRow(
                title: "Selected",
                detail: preset.helpText,
                systemImage: preset.systemIcon
            )
        }
    }

    private var audioStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardControlCard(title: "Output") {
                Picker("Device", selection: Binding(get: {
                    model.config.audio.preferredOutputUID ?? ""
                }, set: { value in
                    model.setOutputUID(value.isEmpty ? nil : value)
                })) {
                    Text("System Default").tag("")
                    ForEach(model.devices) { device in
                        Text("\(device.name) | \(device.channelCount) out").tag(device.uid)
                    }
                }
                Picker("Stereo Pair", selection: stereoPairBinding) {
                    ForEach(model.outputPairs, id: \.left) { pair in
                        Text("\(pair.left)-\(pair.right)").tag("\(pair.left)-\(pair.right)")
                    }
                }
                .pickerStyle(.segmented)
            }

            WizardControlCard(title: "Sample Rate") {
                Picker("Sample Rate", selection: Binding(get: {
                    model.config.audio.targetSampleRate
                }, set: { model.setSampleRate($0) })) {
                    Text("44.1").tag(44_100.0)
                    Text("48").tag(48_000.0)
                    Text("88.2").tag(88_200.0)
                    Text("96").tag(96_000.0)
                }
                .pickerStyle(.segmented)
            }

            WizardReadinessStrip(
                title: model.outputRouteDetail,
                detail: model.sampleRatePreflightDetail,
                isReady: model.outputRouteIsReady && model.sampleRateRouteIsReady
            )
        }
    }

    private var filesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardControlCard(title: "Audio Files") {
                Picker("Import Mode", selection: Binding(get: {
                    model.config.libraryStorageMode
                }, set: { model.setLibraryStorageMode($0) })) {
                    ForEach(LibraryStorageMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(model.config.libraryStorageMode.helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            WizardControlCard(title: "MIDI Source") {
                Picker("Input", selection: Binding(get: {
                    model.config.midi.iacSourceUniqueID ?? 0
                }, set: { id in
                    model.setIACSource(model.midiSources.first { ($0.uniqueID ?? $0.id) == id })
                })) {
                    Text("Virtual Dead Air In").tag(0)
                    ForEach(model.midiSources) { source in
                        Text(source.name).tag(source.uniqueID ?? source.id)
                    }
                }
                Text(model.lastMIDIEventSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            WizardInsightRow(
                title: "Current input",
                detail: model.config.midi.iacSourceName ?? model.config.midi.virtualDestinationName,
                systemImage: "dot.radiowaves.left.and.right"
            )
        }
    }

    private var lightkeyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardControlCard(title: "Lighting Control") {
                Toggle("Enable lighting cues", isOn: Binding(get: {
                    model.config.lighting.enabled
                }, set: { model.setLightingEnabled($0) }))
                Picker("Provider", selection: Binding(get: {
                    model.config.lighting.defaultProvider
                }, set: { model.setLightingDefaultProvider($0) })) {
                    ForEach(LightingProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                HStack {
                    TextField("Host", text: Binding(get: {
                        model.config.lighting.lightkeyHost
                    }, set: { model.setLightkeyHost($0) }))
                    .textFieldStyle(.roundedBorder)

                    Stepper("Port \(model.config.lighting.lightkeyPort)", value: Binding(get: {
                        model.config.lighting.lightkeyPort
                    }, set: { model.setLightkeyPort($0) }), in: 1 ... 65_535)
                }
            }

            HStack(spacing: 12) {
                Button {
                    model.testLightingCue()
                } label: {
                    Label("Send Test Cue", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.copyLightkeySetupNotesToClipboard()
                } label: {
                    Label("Copy Notes", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
            }

            WizardReadinessStrip(
                title: model.lightingStatusValue,
                detail: model.lastLightingEventSummary,
                isReady: model.config.lighting.enabled ? model.config.lighting.validationWarnings(for: model.activeBed?.lightingCues ?? []).isEmpty : true
            )
        }
    }

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            WizardControlCard(title: "Save Setup") {
                TextField("Profile Name", text: $profileName)
                    .textFieldStyle(.roundedBorder)
                Toggle("Close to menu bar after setup", isOn: $closeToMenuBar)
            }

            ReadinessPanel()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var wizardFooter: some View {
        HStack {
            Button("Cancel") {
                isPresented = false
            }

            Spacer()

            Button("Back") {
                moveStep(-1)
            }
            .disabled(currentStepIndex == 0)

            Button(currentStepIndex == SetupWizardStep.allCases.count - 1 ? "Save Default Setup" : "Continue") {
                if currentStepIndex == SetupWizardStep.allCases.count - 1 {
                    model.completeOnboarding(profileName: profileName, closeToMenuBar: closeToMenuBar)
                    isPresented = false
                } else {
                    moveStep(1)
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
    }

    private var headerSubtitle: String {
        switch step {
        case .preset: "Start from the rig that matches the show."
        case .audio: "Choose the output Dead Air should own."
        case .files: "Pick file behavior and the control source."
        case .lightkey: "Connect Lightkey or any OSC/MIDI lighting app."
        case .finish: "Name it, verify it, save it."
        }
    }

    private var currentStepIndex: Int {
        stepIndex(step)
    }

    private func stepIndex(_ item: SetupWizardStep) -> Int {
        SetupWizardStep.allCases.firstIndex(of: item) ?? 0
    }

    private func moveStep(_ delta: Int) {
        let steps = SetupWizardStep.allCases
        let nextIndex = min(max(currentStepIndex + delta, 0), steps.count - 1)
        step = steps[nextIndex]
    }

    private var stereoPairBinding: Binding<String> {
        Binding {
            "\(model.config.audio.outputLeftChannel)-\(model.config.audio.outputRightChannel)"
        } set: { value in
            let parts = value.split(separator: "-").compactMap { Int($0) }
            if parts.count == 2 {
                model.setOutputPair(left: parts[0], right: parts[1])
            }
        }
    }
}

private struct WizardPresetCard: View {
    let preset: ShowSetupPreset
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: preset.systemIcon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    Spacer()
                    if isRecommended {
                        Text("Recommended")
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.16), in: Capsule())
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }

                Text(preset.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(preset.shortSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(minHeight: 138, alignment: .topLeading)
            .background(isSelected ? Color.accentColor.opacity(0.10) : Color(nsColor: .controlBackgroundColor).opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.09), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct WizardControlCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassTile()
    }
}

private struct WizardInsightRow: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct WizardReadinessStrip: View {
    let title: String
    let detail: String
    let isReady: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(isReady ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.bold())
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .background((isReady ? Color.green : Color.orange).opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct WizardMiniStatus: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct HelpCenterView: View {
    @EnvironmentObject private var model: DeadAirModel
    @State private var query = ""

    private let topics: [(title: String, body: String)] = [
        ("Quick Start", "Import audio, choose the output, arm Show Mode, then use Fade In and Fade Out. Save Default when the playlist and route are correct."),
        ("Reference vs Copy", "Reference keeps files where they are and stores a sandbox bookmark. Copy duplicates files into Dead Air's managed library for travel-safe shows."),
        ("MIDI Learn", "Open Settings, MIDI and OSC, then press Learn for a command and send the note or CC from Ableton, a controller, IAC, or another DAW."),
        ("Lighting OSC", "Lightkey is the default preset, but Custom OSC can send raw addresses to QLC+, MagicQ, QLab, grandMA, or any app that accepts UDP OSC. Dead Air logs packet sent, not external confirmation."),
        ("Menu Bar Mode", "Close to Menu Bar hides the main window while keeping Dead Air running, audio-ready, and controllable from the menu bar."),
        ("Preflight", "Preflight checks output, sample rate, playlist, control inputs, show mode, and lighting cue validity before a set."),
        ("Recovery", "If the audio device changes while audible, Dead Air rebuilds muted and warns you so the show output does not jump unexpectedly.")
    ]

    private var filteredTopics: [(title: String, body: String)] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return topics }
        return topics.filter { "\($0.title) \($0.body)".lowercased().contains(cleaned) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Dead Air Help")
                    .font(.largeTitle.bold())
                Spacer()
                Text(model.appVersionDisplay)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            TextField("Search help", text: $query)
                .textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(filteredTopics, id: \.title) { topic in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(topic.title)
                                .font(.headline)
                            Text(topic.body)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            HStack {
                Button("Open User Guide") {
                    openDocument("USER_GUIDE")
                }
                Button("Open Troubleshooting") {
                    openDocument("TROUBLESHOOTING")
                }
            }
        }
        .padding(24)
    }

    private func openDocument(_ name: String) {
        if let bundled = Bundle.main.url(forResource: name, withExtension: "md") {
            NSWorkspace.shared.open(bundled)
        }
    }
}

struct HeaderView: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        HStack(spacing: 16) {
            LogoMarkView(size: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(model.activeBed?.title ?? "No bed loaded")
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Text(model.appVersionDisplay)
                        .font(.caption2.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.16), in: Capsule())
                    HelpIcon("Dead Air stays open outside Ableton and keeps transition music available while Live Sets load or unload.")
                }
                Label("Profile: \(model.activeProfile?.name ?? "No Profile")  |  Out: \(model.selectedOutputName) \(model.config.audio.outputLeftChannel)-\(model.config.audio.outputRightChannel)  |  Mode: \(model.config.bedAdvanceMode.displayName)", systemImage: "music.note.list")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            StatusPill(title: "State", value: model.state.displayName, tone: stateTone, help: "Current playback state. Degraded means the app stayed alive but needs attention.")
            StatusPill(title: "MIDI", value: model.midiOnline ? "Online" : "Offline", tone: model.midiOnline ? .good : .bad, help: "Shows whether Dead Air is listening for MIDI on its virtual input or selected IAC sources.")
            StatusPill(title: "OSC", value: model.oscOnline ? "On" : "Off", tone: model.oscOnline ? .good : .neutral, help: "Shows whether localhost OSC is listening on the configured port.")
            StatusPill(title: "Lighting", value: model.lightingStatusValue, tone: model.lightingStatusTone, help: "Outbound Lightkey/MIDI cue status. Lighting failures are logged and do not stop audio.")
            StatusPill(title: "Heartbeat", value: model.heartbeatStatus, tone: model.heartbeatStatus == "Lost" ? .bad : .neutral, help: "Optional AbleSet supervision signal. If it stops, Dead Air can react based on the heartbeat policy.")
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .glassHeader()
    }

    private var stateTone: StatusPill.Tone {
        switch model.state {
        case .audible, .fadingIn: .good
        case .panicMuted, .degraded: .bad
        case .fadingOut, .readyMuted, .launching: .neutral
        }
    }
}

struct LogoMarkView: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "DeadAirLogoMark", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .foregroundStyle(.teal)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .shadow(color: Color.black.opacity(0.22), radius: 7, x: 0, y: 4)
        .accessibilityLabel("Dead Air logo")
    }
}

struct MainControlsView: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NowPlayingCard()

            SectionHeader(
                title: "Transport",
                systemImage: "slider.horizontal.3",
                help: "Manual controls are always available. MIDI and OSC trigger the same commands."
            )

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ControlButton(title: "FADE IN", systemImage: "speaker.wave.2.fill", tint: StagePalette.fadeIn, help: "Fade the selected bed up to the target level without restarting it if it is already audible.") {
                        model.uiCommand(.fadeIn)
                    }
                    ControlButton(title: "FADE OUT", systemImage: "speaker.slash.fill", tint: StagePalette.fadeOut, help: "Fade the active bed down to silence while keeping the engine ready.") {
                        model.uiCommand(.fadeOut)
                    }
                }
                HStack(spacing: 12) {
                    ControlButton(title: "NEXT BED", systemImage: "forward.fill", tint: StagePalette.nextBed, help: "Select the next enabled bed. If audio is playing, Dead Air crossfades to the next bed.") {
                        model.uiCommand(.nextBed)
                    }
                    ControlButton(title: "PANIC MUTE", systemImage: "exclamationmark.octagon.fill", tint: StagePalette.panic, help: "Immediate hard mute. This has the highest priority and cancels any active fade.") {
                        model.uiCommand(.panic)
                    }
                }
            }

            if let warning = model.warning {
                Text(warning)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red, in: RoundedRectangle(cornerRadius: 8))
            }

            ShowQuickPanel()
        }
        .padding(16)
        .liquidGlassPanel()
    }
}

struct NowPlayingCard: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Current Bed", systemImage: "music.note")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(model.state.displayName)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stateColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(stateColor)
            }

            Text(model.activeBed?.title ?? "No bed loaded")
                .font(.title3.weight(.semibold))
                .lineLimit(1)

            HStack(spacing: 12) {
                Label(model.selectedOutputName, systemImage: "speaker.wave.2")
                Label("\(model.config.audio.outputLeftChannel)-\(model.config.audio.outputRightChannel)", systemImage: "arrow.left.and.right")
                Label("\(Int(model.config.audio.targetSampleRate / 1000)) kHz", systemImage: "waveform")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .padding(12)
        .liquidGlassTile()
    }

    private var stateColor: Color {
        switch model.state {
        case .audible, .fadingIn: .green
        case .panicMuted, .degraded: .red
        case .fadingOut: .orange
        case .readyMuted, .launching: .secondary
        }
    }
}

struct ShowQuickPanel: View {
    @EnvironmentObject private var model: DeadAirModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Show Surface", systemImage: "rectangle.3.group", help: "Only live-critical settings stay here. Deep routing, profiles, MIDI, and diagnostics live in Settings.")

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(model.activeProfile?.name ?? "No Profile", systemImage: "person.crop.rectangle.stack")
                        .font(.callout.bold())
                    Spacer()
                    Button {
                        openSettings()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                Text("Out \(model.selectedOutputName) \(model.config.audio.outputLeftChannel)-\(model.config.audio.outputRightChannel) | \(Int(model.config.audio.targetSampleRate / 1000)) kHz")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(10)
            .liquidGlassTile()

            FadeTimeSlider(
                title: "Fade In",
                help: "Handled inside Dead Air. Ableton can close or reopen while this fade continues.",
                milliseconds: model.config.audio.fadeInMs,
                range: 100 ... 180_000,
                update: model.setFadeInMs
            )
            FadeTimeSlider(
                title: "Fade Out",
                help: "Handled inside Dead Air. Use long fade-outs for songs with slow endings or walkout beds.",
                milliseconds: model.config.audio.fadeOutMs,
                range: 100 ... 180_000,
                update: model.setFadeOutMs
            )

            Picker("Bed Mode", selection: Binding(get: {
                model.config.bedAdvanceMode
            }, set: { model.setBedAdvanceMode($0) })) {
                ForEach(BedAdvanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .help("Continuous keeps the current bed ready until you choose next. Auto-Prep prepares the next bed after fade-out. Auto-Crossfade changes near the end.")

            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("All fades run inside Dead Air, independent of Ableton.")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .statusGlassTile(tint: .green)

            HStack(spacing: 8) {
                Image(systemName: "lightbulb.2.fill")
                    .foregroundStyle(model.config.lighting.enabled ? .yellow : .secondary)
                Text("Lighting \(model.lightingStatusValue): \(model.lastLightingEventSummary)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .statusGlassTile(tint: model.config.lighting.enabled ? .yellow : .secondary)
        }
    }
}

struct DeadAirSettingsWindow: View {
    var body: some View {
        TabView {
            SettingsPanel()
                .tabItem {
                    Label("Audio", systemImage: "speaker.wave.2")
                }
            PlaybackSettingsTab()
                .tabItem {
                    Label("Playback", systemImage: "play.circle")
                }
            ControlSettingsTab()
                .tabItem {
                    Label("MIDI/OSC", systemImage: "cable.connector")
                }
            LightingSettingsTab()
                .tabItem {
                    Label("Lighting", systemImage: "lightbulb.2")
                }
            LibrarySettingsTab()
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
            ProfilesSettingsTab()
                .tabItem {
                    Label("Profiles", systemImage: "person.crop.rectangle.stack")
                }
            DiagnosticsSettingsTab()
                .tabItem {
                    Label("Diagnostics", systemImage: "stethoscope")
                }
            AdvancedSettingsTab()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .padding(16)
        .stageGlassBackground()
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    let help: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, systemImage: systemImage, help: help)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlassPanel()
    }
}

struct PlaybackSettingsTab: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        ScrollView {
            SettingsCard(title: "Playback", systemImage: "play.circle", help: "Defaults for how beds fade, crossfade, loop, and advance.") {
                FadeTimeSlider(title: "Fade In", help: "Default fade-in time for live commands.", milliseconds: model.config.audio.fadeInMs, range: 100 ... 180_000, update: model.setFadeInMs)
                FadeTimeSlider(title: "Fade Out", help: "Default fade-out time for live commands.", milliseconds: model.config.audio.fadeOutMs, range: 100 ... 180_000, update: model.setFadeOutMs)
                FadeTimeSlider(title: "Live Crossfade", help: "Default crossfade time when selecting or advancing while audible.", milliseconds: model.config.audio.liveCrossfadeMs, range: 250 ... 60_000, update: model.setLiveCrossfadeMs)
                Picker("Bed Mode", selection: Binding(get: { model.config.bedAdvanceMode }, set: { model.setBedAdvanceMode($0) })) {
                    ForEach(BedAdvanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(model.config.bedAdvanceMode.helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ControlSettingsTab: View {
    var body: some View {
        ScrollView {
            SettingsCard(title: "MIDI and OSC", systemImage: "cable.connector", help: "Programmable show control for Ableton, controllers, and other show systems.") {
                SettingsOSCPanel()
                MIDIMappingPanel()
            }
        }
    }
}

struct SettingsOSCPanel: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable OSC", isOn: Binding(get: {
                model.config.osc.enabled
            }, set: { model.setOSCEnabled($0) }))
            Text("Listening on \(model.config.osc.host):\(model.config.osc.port). Last command: \(model.lastCommand)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Stepper("Inbound port \(model.config.osc.port)", value: Binding(get: {
                    model.config.osc.port
                }, set: { model.setOSCPort($0) }), in: 1 ... 65_535)
                Button("Retry OSC") {
                    model.retryOSC()
                }
            }
            Button("Copy Cue Map") {
                model.copyCueMapToClipboard()
            }
        }
    }
}

struct LightingSettingsTab: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SettingsCard(title: "Lighting / Show Cues", systemImage: "lightbulb.2", help: "Outbound show-control cues for Lightkey, custom OSC receivers, or MIDI devices. Audio keeps running if a lighting cue fails.") {
                    Toggle("Enable Lighting Cues", isOn: Binding(get: {
                        model.config.lighting.enabled
                    }, set: { model.setLightingEnabled($0) }))

                    Picker("Default Provider", selection: Binding(get: {
                        model.config.lighting.defaultProvider
                    }, set: { model.setLightingDefaultProvider($0) })) {
                        ForEach(LightingProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        TextField("OSC host", text: Binding(get: {
                            model.config.lighting.lightkeyHost
                        }, set: { model.setLightkeyHost($0) }))
                        .textFieldStyle(.roundedBorder)
                        Stepper("OSC \(model.config.lighting.lightkeyPort)", value: Binding(get: {
                            model.config.lighting.lightkeyPort
                        }, set: { model.setLightkeyPort($0) }), in: 1 ... 65_535)
                    }

                    HStack {
                        Picker("MIDI Destination", selection: Binding(get: {
                            model.config.lighting.midiDestinationUniqueID ?? 0
                        }, set: { id in
                            model.setLightingMIDIDestination(model.midiDestinations.first { ($0.uniqueID ?? $0.id) == id })
                        })) {
                            Text("None").tag(0)
                            ForEach(model.midiDestinations) { destination in
                                Text(destination.name).tag(destination.uniqueID ?? destination.id)
                            }
                        }
                        Stepper("Ch \(model.config.lighting.midiChannel)", value: Binding(get: {
                            model.config.lighting.midiChannel
                        }, set: { model.setLightingMIDIChannel($0) }), in: 1 ... 15)
                        Stepper("Vel \(model.config.lighting.midiVelocity)", value: Binding(get: {
                            model.config.lighting.midiVelocity
                        }, set: { model.setLightingMIDIVelocity($0) }), in: 0 ... 127)
                    }
                    Text("Selected MIDI fallback: \(model.config.lighting.midiDestinationName.isEmpty ? "None" : model.config.lighting.midiDestinationName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Stepper("Cue dedupe \(model.config.lighting.dedupeWindowMs) ms", value: Binding(get: {
                        model.config.lighting.dedupeWindowMs
                    }, set: { model.setLightingDedupeWindowMs($0) }), in: 0 ... 10_000, step: 100)

                    HStack {
                        Button {
                            model.testLightingCue()
                        } label: {
                            Label("Send Test Cue", systemImage: "paperplane")
                        }
                        Button {
                            model.copyLightkeySetupNotesToClipboard()
                        } label: {
                            Label("Copy Setup Notes", systemImage: "doc.on.doc")
                        }
                        Button {
                            model.copyLightingCueMapToClipboard()
                        } label: {
                            Label("Copy Cue List", systemImage: "list.bullet.clipboard")
                        }
                    }

                    Text(model.lastLightingEventSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Lightkey OSC default: 127.0.0.1:21600. Custom OSC can target QLC+, MagicQ, QLab, grandMA, or any listener by host, port, and raw address.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SettingsCard(title: "Global Show Cues", systemImage: "rectangle.stack.badge.play", help: "Global cues fire from Dead Air show events. Track-specific cues live in the Track Inspector.") {
                    HStack {
                        Menu {
                            ForEach(LightingCueTrigger.allCases) { trigger in
                                Button(trigger.displayName) {
                                    model.addGlobalLightingCue(trigger: trigger)
                                }
                            }
                        } label: {
                            Label("Add Cue", systemImage: "plus")
                        }
                        Spacer()
                        Text("\(model.config.lighting.cues.count) global")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if model.config.lighting.cues.isEmpty {
                        Text("Add a cue for events like Fade In Started, Fade Out Completed, Panic Muted, or Crossfade Started.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(model.config.lighting.cues) { cue in
                            LightingCueEditor(
                                cue: cue,
                                config: model.config.lighting,
                                update: model.updateGlobalLightingCue,
                                remove: { model.removeGlobalLightingCue(cue.id) }
                            )
                        }
                    }
                }
            }
        }
    }
}

struct LightingCueEditor: View {
    let cue: LightingCue
    let config: LightingConfig
    let update: (LightingCue) -> Void
    let remove: () -> Void

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Toggle("Enabled", isOn: binding(\.enabled))
                    Picker("Trigger", selection: binding(\.trigger)) {
                        ForEach(LightingCueTrigger.allCases) { trigger in
                            Text(trigger.displayName).tag(trigger)
                        }
                    }
                }

                HStack {
                    TextField("Cue name", text: binding(\.name))
                        .textFieldStyle(.roundedBorder)
                    Picker("Provider", selection: binding(\.provider)) {
                        ForEach(LightingProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .frame(width: 160)
                }

                if cue.provider.usesOSC {
                    oscFields
                } else {
                    midiFields
                }

                let warnings = cue.validationWarnings(config: config)
                if !warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(warnings, id: \.self) { warning in
                            Label(warning, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                HStack {
                    Text(cue.displaySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    Button(role: .destructive, action: remove) {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: cue.provider.usesOSC ? "dot.radiowaves.left.and.right" : "pianokeys")
                    .foregroundStyle(cue.enabled ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cue.name)
                        .font(.callout.weight(.semibold))
                    Text("\(cue.trigger.displayName) | \(cue.provider.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(10)
        .liquidGlassTile()
    }

    private var oscFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            if cue.provider == .lightkeyOSC {
                HStack {
                    TextField("Page", text: binding(\.pageName))
                        .textFieldStyle(.roundedBorder)
                    TextField("Frame optional", text: optionalStringBinding(\.frameName))
                        .textFieldStyle(.roundedBorder)
                    TextField("Cue", text: binding(\.cueName))
                        .textFieldStyle(.roundedBorder)
                }
            }
            HStack {
                Picker("Action", selection: binding(\.action)) {
                    ForEach(LightkeyCueAction.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                .frame(width: 170)
                TextField(cue.provider == .customOSC ? "Raw OSC address" : "Raw OSC address optional", text: optionalStringBinding(\.rawOSCAddress))
                    .textFieldStyle(.roundedBorder)
            }
            if cue.provider == .customOSC {
                Text("Custom OSC sends exactly the raw address above. Use your lighting app's receive port and expected path.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                TextField("Fade seconds optional", text: optionalDoubleBinding(\.fadeTimeSeconds))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 170)
                Slider(value: Binding(get: {
                    cue.intensity ?? 1
                }, set: { value in
                    var updated = cue
                    updated.intensity = value
                    update(updated)
                }), in: 0 ... 1)
                Text("Intensity \(Int(((cue.intensity ?? 1) * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 92, alignment: .trailing)
            }
        }
    }

    private var midiFields: some View {
        HStack {
            Picker("Message", selection: binding(\.midiMessageType)) {
                ForEach(MIDIMessageType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            Stepper("Ch \(cue.midiChannel)", value: binding(\.midiChannel), in: 1 ... 16)
            Stepper("#\(cue.midiNumber)", value: binding(\.midiNumber), in: 0 ... 127)
            Stepper("Val \(cue.midiValue)", value: binding(\.midiValue), in: 0 ... 127)
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<LightingCue, Value>) -> Binding<Value> {
        Binding {
            cue[keyPath: keyPath]
        } set: { value in
            var updated = cue
            updated[keyPath: keyPath] = value
            update(updated)
        }
    }

    private func optionalStringBinding(_ keyPath: WritableKeyPath<LightingCue, String?>) -> Binding<String> {
        Binding {
            cue[keyPath: keyPath] ?? ""
        } set: { value in
            var updated = cue
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            updated[keyPath: keyPath] = cleaned.isEmpty ? nil : value
            update(updated)
        }
    }

    private func optionalDoubleBinding(_ keyPath: WritableKeyPath<LightingCue, Double?>) -> Binding<String> {
        Binding {
            guard let value = cue[keyPath: keyPath] else { return "" }
            return String(format: "%.2f", value)
        } set: { value in
            var updated = cue
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            updated[keyPath: keyPath] = cleaned.isEmpty ? nil : Double(cleaned)
            update(updated)
        }
    }
}

struct LibrarySettingsTab: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        ScrollView {
            SettingsCard(title: "Library", systemImage: "music.note.list", help: "How Dead Air stores or references imported tracks.") {
                Picker("Import Mode", selection: Binding(get: {
                    model.config.libraryStorageMode
                }, set: { model.setLibraryStorageMode($0) })) {
                    ForEach(LibraryStorageMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(model.config.libraryStorageMode.helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Import Audio") { model.openImportPanel() }
                    Button("Save Playlist") { model.savePlaylistInApp() }
                    Button("Load Playlist") { model.importPlaylist() }
                }
                Text("Metadata fields are manual-first for show reliability. Dead Air imports title/artist/BPM/key when the file exposes compatible tags.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProfilesSettingsTab: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        ScrollView {
            SettingsCard(title: "Show Profiles", systemImage: "person.crop.rectangle.stack", help: "Profiles save the routing, control, playback, safety, and diagnostic setup for a venue or show.") {
                HStack {
                    Picker("Active Profile", selection: Binding(get: {
                        model.config.activeProfileID
                    }, set: { model.applyProfile($0) })) {
                        Text("No Profile").tag(Optional<UUID>.none)
                        ForEach(model.showProfiles) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    }
                    Button("New") { model.createProfileFromCurrent() }
                    Button("Save") { model.saveCurrentProfile() }
                    Button("Duplicate") { model.duplicateActiveProfile() }
                    Button("Delete", role: .destructive) { model.deleteActiveProfile() }
                }
                if let profile = model.activeProfile {
                    TextField("Profile Name", text: Binding(get: {
                        profile.name
                    }, set: { model.renameActiveProfile($0) }))
                    .textFieldStyle(.roundedBorder)
                    TextField("Notes", text: Binding(get: {
                        model.activeProfile?.notes ?? ""
                    }, set: { model.updateActiveProfileNotes($0) }), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3 ... 6)
                } else {
                    Text("Create a profile to save this Mac/output/controller setup for reuse.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct DiagnosticsSettingsTab: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        ScrollView {
            SettingsCard(title: "Diagnostics", systemImage: "stethoscope", help: "Show-ready diagnostics and support information.") {
                ReadinessPanel()
                Divider()
                Text("Last MIDI: \(model.lastMIDIEventSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Dropped events: \(model.droppedEventCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Last lighting: \(model.lastLightingEventSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Persist local diagnostics log", isOn: Binding(get: {
                    model.config.logging.persistJsonl
                }, set: { model.setDiagnosticsLogging(enabled: $0) }))
                Toggle("Redact paths and device identifiers in support data", isOn: Binding(get: {
                    model.config.logging.redactSensitiveData
                }, set: { model.setDiagnosticsRedaction(enabled: $0) }))
                Stepper("Keep logs \(model.config.logging.retentionDays) days", value: Binding(get: {
                    model.config.logging.retentionDays
                }, set: { model.setDiagnosticsRetentionDays($0) }), in: 1 ... 365)
                if !model.persistenceRecoveryMessages.isEmpty {
                    Divider()
                    ForEach(model.persistenceRecoveryMessages, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if let logsDirectory = model.logsDirectory {
                    HStack {
                        Button("Reveal Logs") {
                            NSWorkspace.shared.activateFileViewerSelecting([logsDirectory])
                        }
                        Button("Export Support Bundle") {
                            model.exportSupportBundle()
                        }
                    }
                }
            }
        }
    }
}

struct AdvancedSettingsTab: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        ScrollView {
            SettingsCard(title: "Show Safety", systemImage: "checkmark.shield", help: "Safety behavior for live playback and recovery.") {
                Toggle("Prevent idle sleep in Show Mode", isOn: Binding(get: {
                    model.config.power.preventIdleSleep
                }, set: { value in
                    model.setPreventIdleSleep(value)
                }))
                Toggle("Heartbeat supervision", isOn: Binding(get: {
                    model.config.heartbeat.enabled
                }, set: { value in
                    model.setHeartbeatEnabled(value)
                }))
                Stepper("Heartbeat timeout \(model.config.heartbeat.timeoutMs) ms", value: Binding(get: {
                    model.config.heartbeat.timeoutMs
                }, set: { value in
                    model.setHeartbeatTimeoutMs(value)
                }), in: 500 ... 30_000, step: 250)
                Text("Automatic BPM/key analysis is intentionally deferred; this build keeps metadata manual/imported for maximum package stability.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SettingsPanel: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Show Settings", systemImage: "gearshape.2", help: "Persistent show settings for audio routing, level, fades, OSC, and MIDI mapping.")

            HStack(spacing: 12) {
                Picker("Mode", selection: Binding(get: {
                    model.config.uiMode
                }, set: { model.setUIMode($0) })) {
                    ForEach(DeadAirUIMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Appearance", selection: Binding(get: {
                    model.config.appearanceMode
                }, set: { model.setAppearanceMode($0) })) {
                    ForEach(DeadAirAppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                FormLabel("Output Device", help: "Routes Dead Air's own audio engine to this device. Use virtual devices, aggregate devices, interfaces, or the system default.")
                Picker("Output", selection: Binding(get: {
                    model.config.audio.preferredOutputUID ?? ""
                }, set: { value in
                    model.setOutputUID(value.isEmpty ? nil : value)
                })) {
                    Text("System Default").tag("")
                    ForEach(model.devices) { device in
                        Text(deviceLabel(device)).tag(device.uid)
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    FormLabel("Output Pair", help: "Selects the physical or virtual stereo pair Dead Air should feed. Pairs are shown as one-based device channels.")
                    Picker("Output Pair", selection: outputPairBinding) {
                        ForEach(model.outputPairs, id: \.left) { pair in
                            Text("\(pair.left)-\(pair.right)").tag("\(pair.left)-\(pair.right)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 8) {
                    FormLabel("Sample Rate", help: "Internal playback and conversion rate. Use 48 kHz unless the show rig specifically needs another rate.")
                    Picker("Sample Rate", selection: Binding(get: {
                        model.config.audio.targetSampleRate
                    }, set: { model.setSampleRate($0) })) {
                        Text("44.1").tag(44_100.0)
                        Text("48").tag(48_000.0)
                        Text("88.2").tag(88_200.0)
                        Text("96").tag(96_000.0)
                    }
                    .pickerStyle(.segmented)
                }
            }

            HStack {
                FormLabel("Target", help: "Fade-in destination level. Set this conservatively and trim at FOH.")
                Slider(value: Binding(get: {
                    model.config.audio.targetLevelDb
                }, set: { model.setTargetLevelDb($0) }), in: -36 ... 0, step: 1)
                Text("\(Int(model.config.audio.targetLevelDb)) dB")
                    .monospacedDigit()
                    .frame(width: 58, alignment: .trailing)
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("Fades and crossfades run inside Dead Air, independent of Ableton reloads.")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .statusGlassTile(tint: .green)

            VStack(spacing: 10) {
                FadeTimeSlider(
                    title: "Fade In",
                    help: "Handled inside Dead Air. Ableton can close or reopen while this fade continues.",
                    milliseconds: model.config.audio.fadeInMs,
                    range: 100 ... 180_000,
                    update: model.setFadeInMs
                )
                FadeTimeSlider(
                    title: "Fade Out",
                    help: "Handled inside Dead Air. Use long fade-outs for songs with slow endings or walkout beds.",
                    milliseconds: model.config.audio.fadeOutMs,
                    range: 100 ... 180_000,
                    update: model.setFadeOutMs
                )
                FadeTimeSlider(
                    title: "Live Crossfade",
                    help: "Used when you manually switch while audible or when Auto-Crossfade reaches the end of a bed.",
                    milliseconds: model.config.audio.liveCrossfadeMs,
                    range: 250 ... 60_000,
                    update: model.setLiveCrossfadeMs
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                FormLabel("Bed Mode", help: "Controls what happens after fade-out or at the end of an audible bed.")
                Picker("Bed Mode", selection: Binding(get: {
                    model.config.bedAdvanceMode
                }, set: { model.setBedAdvanceMode($0) })) {
                    ForEach(BedAdvanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(model.config.bedAdvanceMode.helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Toggle(isOn: Binding(get: {
                model.config.osc.enabled
            }, set: { model.setOSCEnabled($0) })) {
                HStack(spacing: 5) {
                    Text("OSC")
                    HelpIcon("Enables localhost OSC control on 127.0.0.1:\(model.config.osc.port).")
                }
            }
            Text("Port \(model.config.osc.port)  |  Last command: \(model.lastCommand)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Stepper("OSC Port \(model.config.osc.port)", value: Binding(get: {
                    model.config.osc.port
                }, set: { model.setOSCPort($0) }), in: 1 ... 65_535)
                Button("Retry") {
                    model.retryOSC()
                }
            }

            MIDIMappingPanel()
        }
        .padding(14)
        .liquidGlassPanel()
    }

    private var outputPairBinding: Binding<String> {
        Binding {
            "\(model.config.audio.outputLeftChannel)-\(model.config.audio.outputRightChannel)"
        } set: { value in
            let pieces = value.split(separator: "-").compactMap { Int($0) }
            guard pieces.count == 2 else { return }
            model.setOutputPair(left: pieces[0], right: pieces[1])
        }
    }

    private func deviceLabel(_ device: AudioOutputDevice) -> String {
        let marker = device.isDefault ? " *" : ""
        return "\(device.name)\(marker)  |  \(device.channelCount) out"
    }
}

struct MIDIMappingPanel: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Picker("Input", selection: Binding(get: {
                        model.config.midi.mode
                    }, set: { model.setMIDIMode($0) })) {
                        Text("Virtual").tag(MIDIConfig.Mode.virtualDestination)
                        Text("IAC").tag(MIDIConfig.Mode.iacSource)
                        Text("Both").tag(MIDIConfig.Mode.both)
                    }
                    .pickerStyle(.segmented)

                    Button("Reset") {
                        model.resetMIDIMappings()
                    }
                }

                Text("Virtual port: \(model.config.midi.virtualDestinationName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Exact IAC / DAW Source", selection: Binding(get: {
                    model.config.midi.iacSourceUniqueID ?? 0
                }, set: { id in
                    model.setIACSource(model.midiSources.first { ($0.uniqueID ?? $0.id) == id })
                })) {
                    Text("None selected").tag(0)
                    ForEach(model.midiSources) { source in
                        Text(source.name).tag(source.uniqueID ?? source.id)
                    }
                }
                Text("Exact source selection prevents broad IAC matching from picking up the wrong DAW or controller.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Last MIDI: \(model.lastMIDIEventSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                ForEach(MIDIMappableAction.allCases) { action in
                    MIDIMappingRow(action: action)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("MIDI Map")
                    .font(.headline)
                if let learning = model.learningMIDIAction {
                    Text("Learning \(learning.displayName)")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

struct FadeTimeSlider: View {
    let title: String
    let help: String
    let milliseconds: Int
    let range: ClosedRange<Int>
    let update: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            header
            fadeSlider
        }
    }

    private var header: some View {
        HStack {
            FormLabel(title, help: help)
            Spacer()
            Text(formattedTime(milliseconds))
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(.primary)
        }
    }

    private var fadeSlider: some View {
        Slider(value: secondsBinding, in: secondsRange, step: 0.1)
            .help(help)
    }

    private var secondsBinding: Binding<Double> {
        Binding<Double>(
            get: { Double(milliseconds) / 1000.0 },
            set: { newValue in
                let roundedMilliseconds = Int((newValue * 1000).rounded(.toNearestOrAwayFromZero))
                update(roundedMilliseconds)
            }
        )
    }

    private var secondsRange: ClosedRange<Double> {
        let lower = Double(range.lowerBound) / 1000.0
        let upper = Double(range.upperBound) / 1000.0
        return lower ... upper
    }

    private func formattedTime(_ milliseconds: Int) -> String {
        let seconds = Double(milliseconds) / 1000.0
        if seconds >= 60 {
            let wholeSeconds = Int(seconds.rounded())
            return "\(wholeSeconds / 60)m \(wholeSeconds % 60)s"
        }
        return String(format: "%.1fs", seconds)
    }
}

struct MIDIMappingRow: View {
    @EnvironmentObject private var model: DeadAirModel
    let action: MIDIMappableAction

    var body: some View {
        let mapping = model.mapping(for: action)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(action.displayName)
                    .font(.callout.weight(.semibold))
                    .frame(width: 104, alignment: .leading)

                Picker("", selection: messageTypeBinding) {
                    ForEach(MIDIMessageType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 170)

                if mapping.messageType.usesChannel {
                    Picker("", selection: channelBinding) {
                        Text("Any Ch").tag(0)
                        ForEach(1 ... 16, id: \.self) { channel in
                            Text("Ch \(channel)").tag(channel)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 92)
                }

                if mapping.messageType.usesNumber {
                    Stepper("#\(mapping.number ?? 0)", value: numberBinding, in: 0 ... 127)
                        .frame(width: 90)
                }

                Button(model.learningMIDIAction == action ? "Cancel" : "Learn") {
                    if model.learningMIDIAction == action {
                        model.cancelMIDILearn()
                    } else {
                        model.beginMIDILearn(action)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(model.learningMIDIAction == action ? .orange : .accentColor)
            }

            HStack(spacing: 8) {
                Text(mapping.displaySummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if action != .level, mapping.messageType != .programChange {
                    Stepper("Min \(mapping.valueMin ?? 0)", value: valueMinBinding, in: 0 ... 127)
                        .font(.caption)
                        .frame(width: 122)
                }
            }
        }
        .padding(8)
        .liquidGlassTile()
    }

    private var messageTypeBinding: Binding<MIDIMessageType> {
        Binding {
            model.mapping(for: action).messageType
        } set: { newType in
            var mapping = model.mapping(for: action)
            mapping.messageType = newType
            if !newType.usesChannel { mapping.channel = nil }
            if !newType.usesNumber { mapping.number = nil }
            mapping.valueMin = MIDIMapping.defaultMinimumValue(for: newType, action: action)
            model.updateMIDIMapping(mapping)
        }
    }

    private var channelBinding: Binding<Int> {
        Binding {
            model.mapping(for: action).channel ?? 0
        } set: { newChannel in
            var mapping = model.mapping(for: action)
            mapping.channel = newChannel == 0 ? nil : newChannel
            model.updateMIDIMapping(mapping)
        }
    }

    private var numberBinding: Binding<Int> {
        Binding {
            model.mapping(for: action).number ?? 0
        } set: { newNumber in
            var mapping = model.mapping(for: action)
            mapping.number = newNumber
            model.updateMIDIMapping(mapping)
        }
    }

    private var valueMinBinding: Binding<Int> {
        Binding {
            model.mapping(for: action).valueMin ?? 0
        } set: { newValue in
            var mapping = model.mapping(for: action)
            mapping.valueMin = newValue
            model.updateMIDIMapping(mapping)
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var model: DeadAirModel
    @Binding var isDropTargeted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "Playlist", systemImage: "music.quarternote.3", help: "Drag audio files or folders here. Reorder the list to control Next Bed order.")
                    Spacer()
                    Text("\(model.beds.count) item\(model.beds.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button {
                        model.openImportPanel()
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        model.savePlaylistInApp()
                    } label: {
                        Label("Save", systemImage: "tray.and.arrow.down")
                    }
                    Button {
                        model.exportPlaylist()
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        model.importPlaylist()
                    } label: {
                        Label("Load", systemImage: "folder")
                    }
                    Menu {
                        Button("Save Default") {
                            model.saveDefaultSetup()
                        }
                        Button("Restore Default") {
                            model.restoreDefaultSetup()
                        }
                    } label: {
                        Label("Default", systemImage: "star")
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 10) {
                FormLabel("Import Mode", help: "Copy stores files in Dead Air's managed library. Reference leaves files where they are and stores sandbox-safe file access.")
                Picker("Import Mode", selection: Binding(get: {
                    model.config.libraryStorageMode
                }, set: { model.setLibraryStorageMode($0) })) {
                    ForEach(LibraryStorageMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
            }
            Text(model.config.libraryStorageMode.helpText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.secondary)
                Text("Last saved: \(model.lastSavedPlaylistName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 10) {
                TextField("Search title, artist, key, tags, notes", text: $model.librarySearch)
                    .textFieldStyle(.roundedBorder)
                Picker("Filter", selection: $model.libraryFilter) {
                    ForEach(LibraryFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 132)
            }

            List(selection: Binding(get: {
                model.selectedBedID
            }, set: { model.selectBed($0) })) {
                if model.librarySearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && model.libraryFilter == .all {
                    ForEach(Array(model.beds.enumerated()), id: \.element.id) { index, bed in
                        BedRow(index: index + 1, bed: bed, isActive: bed.id == model.selectedBedID)
                            .tag(Optional(bed.id))
                    }
                    .onMove(perform: model.moveBed)
                } else {
                    ForEach(model.filteredBeds) { bed in
                        let index = (model.beds.firstIndex(where: { $0.id == bed.id }) ?? 0) + 1
                        BedRow(index: index, bed: bed, isActive: bed.id == model.selectedBedID)
                            .tag(Optional(bed.id))
                    }
                }
            }
            .overlay {
                if model.beds.isEmpty || model.filteredBeds.isEmpty || isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .padding(8)
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.badge.plus")
                            .font(.system(size: 36))
                        Text("Audio Import")
                            .font(.title3.bold())
                        Text("WAV, AIFF, CAF, MP3, M4A, FLAC")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Button {
                    model.moveSelectedBed(up: true)
                } label: {
                    Image(systemName: "arrow.up")
                }
                Button {
                    model.moveSelectedBed(up: false)
                } label: {
                    Image(systemName: "arrow.down")
                }
                Button(role: .destructive) {
                    model.removeSelectedBed()
                } label: {
                    Image(systemName: "trash")
                }
                Spacer()
                Text(model.filteredBeds.count == model.beds.count ? "\(model.beds.count) total" : "\(model.filteredBeds.count) shown / \(model.beds.count) total")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TrackInspectorView()
        }
        .padding(16)
        .liquidGlassPanel()
    }
}

struct BedRow: View {
    let index: Int
    let bed: BedItem
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .font(.system(.caption, design: .monospaced).weight(.black))
                .foregroundStyle(isActive ? .white : .secondary)
                .frame(width: 34, height: 28)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(bed.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let artist = bed.artist, !artist.isEmpty {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(bed.storageMode.displayName.uppercased())
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(storageColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(storageColor)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Image(systemName: isActive ? "speaker.wave.2.fill" : "waveform")
                    .foregroundStyle(isActive ? .green : .secondary)
                HStack(spacing: 4) {
                    if let bpm = bed.bpm {
                        Text("\(Int(bpm.rounded()))")
                    }
                    if let key = bed.musicalKey, !key.isEmpty {
                        Text(key)
                    }
                    Text(bed.enabled ? "READY" : "OFF")
                }
                .font(.caption2.bold())
                .foregroundStyle(bed.enabled ? .green : .secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var detail: String {
        var parts: [String] = []
        if let durationSeconds = bed.durationSeconds {
            parts.append(formatDuration(durationSeconds))
        }
        if let sampleRate = bed.sampleRate {
            parts.append("\(Int(sampleRate / 1000)) kHz")
        }
        if let channelCount = bed.channelCount {
            parts.append("\(channelCount) ch")
        }
        return parts.joined(separator: "  |  ")
    }

    private var storageColor: Color {
        switch bed.storageMode {
        case .managedCopy: .green
        case .externalReference: .orange
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

struct TrackInspectorView: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        Group {
            if let binding = model.bindingForSelectedBed() {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Track Inspector", systemImage: "tag", help: "Edit DJ-useful metadata for sorting, filtering, and choosing compatible next beds.")
                    TextField("Title", text: binding.title)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        TextField("Artist", text: optionalString(binding.artist))
                            .textFieldStyle(.roundedBorder)
                        TextField("Key", text: optionalString(binding.musicalKey))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        TextField("BPM", text: bpmBinding(binding.bpm))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 88)
                    }
                    HStack {
                        Stepper("Energy \(binding.wrappedValue.energy ?? 0)", value: optionalInt(binding.energy), in: 0 ... 10)
                        Toggle("Enabled", isOn: binding.enabled)
                        Toggle("Loop", isOn: binding.seamlessLoop)
                    }
                    TextField("Tags, comma separated", text: tagsBinding(binding.tags))
                        .textFieldStyle(.roundedBorder)
                    TextField("Cue / Ableton note", text: optionalString(binding.cueReference))
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Label("\(binding.wrappedValue.storageMode.displayName): \(binding.wrappedValue.fileName)", systemImage: binding.wrappedValue.storageMode == .externalReference ? "link" : "folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        if binding.wrappedValue.storageMode == .externalReference {
                            Button("Relink") {
                                model.relinkSelectedBed()
                            }
                            .help("Choose the moved or re-authorized audio file for this referenced track.")
                        }
                    }
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Menu {
                                    ForEach(LightingCueTrigger.allCases) { trigger in
                                        Button(trigger.displayName) {
                                            model.addLightingCueToSelectedBed(trigger: trigger)
                                        }
                                    }
                                } label: {
                                    Label("Add Track Cue", systemImage: "plus")
                                }
                                Spacer()
                                Text("\(binding.wrappedValue.lightingCues.count) cue\(binding.wrappedValue.lightingCues.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if binding.wrappedValue.lightingCues.isEmpty {
                                Text("Track cues fire only for this selected bed. Use them for walkout looks, transition cover scenes, or panic looks tied to one bed.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(binding.wrappedValue.lightingCues) { cue in
                                    LightingCueEditor(
                                        cue: cue,
                                        config: model.config.lighting,
                                        update: model.updateSelectedBedLightingCue,
                                        remove: { model.removeSelectedBedLightingCue(cue.id) }
                                    )
                                }
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        Label("Lighting Cues", systemImage: "lightbulb.2")
                            .font(.callout.weight(.semibold))
                    }
                    TextField("Notes", text: optionalString(binding.notes), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2 ... 4)
                    HStack {
                        Label("Metadata: \(binding.wrappedValue.metadataSource.displayName)", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Mark Manual") {
                            var bed = binding.wrappedValue
                            bed.metadataSource = .manual
                            binding.wrappedValue = bed
                        }
                    }
                }
                .padding(12)
                .liquidGlassTile()
            }
        }
    }

    private func optionalString(_ binding: Binding<String?>) -> Binding<String> {
        Binding {
            binding.wrappedValue ?? ""
        } set: { value in
            binding.wrappedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
        }
    }

    private func bpmBinding(_ binding: Binding<Double?>) -> Binding<String> {
        Binding {
            guard let bpm = binding.wrappedValue else { return "" }
            return String(format: "%.1f", bpm)
        } set: { value in
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            binding.wrappedValue = cleaned.isEmpty ? nil : Double(cleaned)
        }
    }

    private func optionalInt(_ binding: Binding<Int?>) -> Binding<Int> {
        Binding {
            binding.wrappedValue ?? 0
        } set: { value in
            binding.wrappedValue = value == 0 ? nil : value
        }
    }

    private func tagsBinding(_ binding: Binding<[String]>) -> Binding<String> {
        Binding {
            binding.wrappedValue.joined(separator: ", ")
        } set: { value in
            binding.wrappedValue = value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }
}

struct EventLogView: View {
    @EnvironmentObject private var model: DeadAirModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReadinessPanel()
            Divider()

            HStack {
                SectionHeader(title: "Event Log", systemImage: "list.bullet.rectangle", help: "Local diagnostics for commands, engine events, routing changes, MIDI learn, and recoveries.")
                Spacer()
                Picker("Filter", selection: $model.eventLogFilter) {
                    ForEach(EventLogFilter.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 104)
                if let logsDirectory = model.logsDirectory {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([logsDirectory])
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(model.filteredRecentEvents.enumerated()), id: \.offset) { index, event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.message)
                                    .font(.callout.weight(.semibold))
                                HStack {
                                    Text(event.source)
                                    if let raw = event.raw {
                                        Text(raw)
                                            .lineLimit(1)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .id(index)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: model.filteredRecentEvents.count) { _, count in
                    proxy.scrollTo(max(0, count - 1), anchor: .bottom)
                }
            }

            Text("Dropped events: \(model.droppedEventCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .liquidGlassPanel()
    }
}

struct ReadinessPanel: View {
    @EnvironmentObject private var model: DeadAirModel

    private var readyCount: Int {
        model.readinessItems.filter(\.isReady).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Show Readiness", systemImage: "checklist.checked", help: "A fast preflight check before rehearsal or showtime.")
                Spacer()
                Text("\(readyCount)/\(model.readinessItems.count)")
                    .font(.system(.caption, design: .monospaced).weight(.black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(readyCount == model.readinessItems.count ? Color.green.opacity(0.18) : Color.orange.opacity(0.18), in: Capsule())
            }

            ForEach(model.readinessItems) { item in
                HStack(spacing: 9) {
                    Image(systemName: item.isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(item.isReady ? .green : .orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.caption.bold())
                        Text(item.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(8)
                .liquidGlassTile()
            }

            Button {
                model.copyCueMapToClipboard()
            } label: {
                Label("Copy Cue Map", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .help("Copies the Ableton/AbleSet MIDI and OSC cue map to the clipboard.")

            HStack {
                Button {
                    model.testLightingCue()
                } label: {
                    Label("Test Lighting", systemImage: "paperplane")
                        .frame(maxWidth: .infinity)
                }
                .help("Sends the first enabled lighting cue or a sample OSC cue.")

                Button {
                    model.exportSupportBundle()
                } label: {
                    Label("Support", systemImage: "shippingbox")
                        .frame(maxWidth: .infinity)
                }
                .help("Exports config, readiness, logs, audio devices, and lighting cue state for troubleshooting.")
            }
        }
    }
}

struct MenuBarControls: View {
    @EnvironmentObject private var model: DeadAirModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                LogoMarkView(size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dead Air")
                        .font(.headline)
                    Text(model.state.displayName)
                        .foregroundStyle(.secondary)
                }
            }
            Text(model.activeBed?.title ?? "No bed loaded")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("Out \(model.selectedOutputName) \(model.config.audio.outputLeftChannel)-\(model.config.audio.outputRightChannel)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Divider()
            Button("Fade In") { model.uiCommand(.fadeIn) }
            Button("Fade Out") { model.uiCommand(.fadeOut) }
            Button("Next Bed") { model.uiCommand(.nextBed) }
            Button("Panic Mute") { model.uiCommand(.panic) }
            Divider()
            Toggle("Show Mode", isOn: Binding(get: {
                model.config.showModeArmed
            }, set: { model.setShowModeArmed($0) }))
            Button("Open Dead Air") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "main")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
            }
            Button("Settings") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openSettings()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
        .frame(width: 260)
    }
}

struct ControlButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 31, weight: .bold))
                    Text(title)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                }
                .frame(maxWidth: .infinity, minHeight: 112)

                HelpIcon(help)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(10)
            }
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.92), tint.opacity(0.68)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.25), .white.opacity(0.035), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: tint.opacity(0.18), radius: 9, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct StatusPill: View {
    enum Tone {
        case good
        case neutral
        case bad
    }

    let title: String
    let value: String
    let tone: Tone
    let help: String

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.bold())
                    .monospacedDigit()
            }
            HelpIcon(help)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(background, in: RoundedRectangle(cornerRadius: 8))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.13), lineWidth: 1)
        )
        .help(help)
    }

    private var background: Color {
        switch tone {
        case .good: Color.green.opacity(0.16)
        case .neutral: Color.secondary.opacity(0.12)
        case .bad: Color.red.opacity(0.20)
        }
    }
}

struct SectionHeader: View {
    let title: String
    let systemImage: String
    let help: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.callout.weight(.medium))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.callout.weight(.semibold))
            HelpIcon(help)
                .foregroundStyle(.secondary)
        }
        .help(help)
    }
}

struct FormLabel: View {
    let title: String
    let help: String

    init(_ title: String, help: String) {
        self.title = title
        self.help = help
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            HelpIcon(help)
                .foregroundStyle(.secondary)
        }
        .help(help)
    }
}

struct HelpIcon: View {
    let text: String
    @State private var isPresented = false

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle.fill")
                .font(.caption2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.plain)
        .help(text)
        .accessibilityLabel(Text("Help: \(text)"))
        .onHover { hovering in
            if hovering {
                isPresented = true
            }
        }
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Help")
                        .font(.headline)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(width: 280)
        }
    }
}

enum StagePalette {
    static let fadeIn = Color(red: 0.24, green: 0.72, blue: 0.50)
    static let fadeOut = Color(red: 0.25, green: 0.52, blue: 0.86)
    static let nextBed = Color(red: 0.88, green: 0.54, blue: 0.24)
    static let panic = Color(red: 0.82, green: 0.26, blue: 0.33)
}

struct StageGlassBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(
                colors: baseColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [
                    StagePalette.fadeOut.opacity(colorScheme == .dark ? 0.06 : 0.08),
                    .clear,
                    StagePalette.fadeIn.opacity(colorScheme == .dark ? 0.05 : 0.09)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var baseColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(nsColor: .controlBackgroundColor).opacity(0.72),
                Color(red: 0.02, green: 0.05, blue: 0.055).opacity(0.92)
            ]
        }
        return [
            Color(nsColor: .windowBackgroundColor).opacity(0.92),
            Color(red: 0.90, green: 0.95, blue: 0.96).opacity(0.78)
        ]
    }
}

extension View {
    func stageGlassBackground() -> some View {
        self.background {
            StageGlassBackgroundView()
            .ignoresSafeArea()
        }
    }

    func glassHeader() -> some View {
        self
            .background(.regularMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.white.opacity(0.06))
                    .frame(height: 1)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.13), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 34)
                    .allowsHitTesting(false)
            }
    }

    func liquidGlassPanel() -> some View {
        self
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.11), .white.opacity(0.025), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.16), radius: 12, x: 0, y: 6)
    }

    func liquidGlassTile() -> some View {
        self
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            )
    }

    func statusGlassTile(tint: Color) -> some View {
        self
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(tint.opacity(0.20), lineWidth: 1)
            )
    }

    func gaplessPanelStyle() -> some View {
        self
            .padding(0)
    }
}
