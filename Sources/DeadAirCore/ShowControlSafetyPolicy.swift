import Foundation

public enum ShowControlSafetyPolicy {
    public static func dropReason(
        for command: TransitionCommand,
        source: CommandSource,
        showModeArmed: Bool,
        setupAssistantOpen: Bool,
        externalControlReadyAt: Date,
        now: Date = Date()
    ) -> String? {
        guard isExternalControlSource(source) else { return nil }

        if setupAssistantOpen, isProtectedExternalCommand(command) {
            return "Setup Assistant is open"
        }

        if now < externalControlReadyAt, isStartupProtectedExternalCommand(command) {
            return "startup safety window"
        }

        if requiresArmedShowMode(command), !showModeArmed {
            return "Show Mode is disarmed"
        }

        return nil
    }

    public static func isExternalControlSource(_ source: CommandSource) -> Bool {
        switch source {
        case .midiVirtual, .midiIAC, .oscLocal:
            true
        case .ui, .heartbeat:
            false
        }
    }

    public static func isStartupProtectedExternalCommand(_ command: TransitionCommand) -> Bool {
        switch command {
        case .fadeIn, .nextBed, .arm, .setLevel:
            true
        case .fadeOut, .panic, .disarm, .clearPanic, .heartbeat:
            false
        }
    }

    public static func isProtectedExternalCommand(_ command: TransitionCommand) -> Bool {
        switch command {
        case .fadeIn, .nextBed, .arm, .setLevel:
            true
        case .fadeOut, .panic, .disarm, .clearPanic, .heartbeat:
            false
        }
    }

    public static func requiresArmedShowMode(_ command: TransitionCommand) -> Bool {
        switch command {
        case .fadeIn, .nextBed, .setLevel:
            true
        case .fadeOut, .panic, .arm, .disarm, .clearPanic, .heartbeat:
            false
        }
    }
}
