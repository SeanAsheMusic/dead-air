import Foundation

public enum DeadAirAutomationID {
    public static let root = "deadAir.root"
    public static let mainSurface = "deadAir.mainSurface"
    public static let toolbarModePicker = "deadAir.toolbar.modePicker"
    public static let toolbarActionsMenu = "deadAir.toolbar.actionsMenu"
    public static let toolbarShowModeToggle = "deadAir.toolbar.showModeToggle"

    public static let statusState = "deadAir.status.state"
    public static let statusMIDI = "deadAir.status.midi"
    public static let statusOSC = "deadAir.status.osc"
    public static let statusConnectors = "deadAir.status.connectors"
    public static let statusHeartbeat = "deadAir.status.heartbeat"
    public static let statusControl = "deadAir.status.control"

    public static let nowPlaying = "deadAir.nowPlaying"
    public static let transportFadeIn = "deadAir.transport.fadeIn"
    public static let transportFadeOut = "deadAir.transport.fadeOut"
    public static let transportNextBed = "deadAir.transport.nextBed"
    public static let transportPanicMute = "deadAir.transport.panicMute"

    public static let setupSheet = "deadAir.setup.sheet"
    public static let setupStepPicker = "deadAir.setup.stepPicker"
    public static let setupContinue = "deadAir.setup.continue"
    public static let setupBack = "deadAir.setup.back"
    public static let setupCancel = "deadAir.setup.cancel"

    public static let playlistSearch = "deadAir.playlist.search"
    public static let playlistFilter = "deadAir.playlist.filter"
    public static let playlistList = "deadAir.playlist.list"
    public static let playlistImport = "deadAir.playlist.import"

    public static let readinessPanel = "deadAir.readiness.panel"
    public static let readinessCopyCueMap = "deadAir.readiness.copyCueMap"
    public static let readinessTestConnector = "deadAir.readiness.testConnector"
    public static let readinessExportSupport = "deadAir.readiness.exportSupport"

    public static let settingsWindow = "deadAir.settings.window"
    public static let settingsAccessibility = "deadAir.settings.accessibility"

    public static let menuBarControls = "deadAir.menuBar.controls"
    public static let menuBarFadeIn = "deadAir.menuBar.fadeIn"
    public static let menuBarFadeOut = "deadAir.menuBar.fadeOut"
    public static let menuBarNextBed = "deadAir.menuBar.nextBed"
    public static let menuBarPanicMute = "deadAir.menuBar.panicMute"

    public static let allCritical: [String] = [
        root,
        mainSurface,
        toolbarModePicker,
        toolbarActionsMenu,
        toolbarShowModeToggle,
        statusState,
        statusMIDI,
        statusOSC,
        statusConnectors,
        statusHeartbeat,
        statusControl,
        nowPlaying,
        transportFadeIn,
        transportFadeOut,
        transportNextBed,
        transportPanicMute,
        setupSheet,
        setupStepPicker,
        setupContinue,
        setupBack,
        setupCancel,
        playlistSearch,
        playlistFilter,
        playlistList,
        playlistImport,
        readinessPanel,
        readinessCopyCueMap,
        readinessTestConnector,
        readinessExportSupport,
        settingsWindow,
        settingsAccessibility,
        menuBarControls,
        menuBarFadeIn,
        menuBarFadeOut,
        menuBarNextBed,
        menuBarPanicMute
    ]
}
