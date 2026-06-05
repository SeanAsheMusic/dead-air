# iPadOS Readiness

Dead Air is currently a macOS release target. The SwiftUI layout now uses compact, mid-size, and wide breakpoints so the main window behaves more like a modern resizable Apple app, but the package is still declared as macOS-only.

Apple's current layout guidance says iPadOS windows can be freely resized down to a minimum size and should be tested at halves, thirds, quadrants, and minimum sizes. Dead Air's main surface should keep the wide view as long as it fits, then hide tertiary content below the primary transport and playlist.

References:

- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines
- Apple HIG layout guidance: https://developer.apple.com/design/human-interface-guidelines/layout
- Apple HIG windows guidance: https://developer.apple.com/design/human-interface-guidelines/windows

## Already Portable

- SwiftUI view structure for the primary show surface.
- DeadAirCore data models, MIDI/OSC parsing, privacy redaction, diagnostics, state machine, and support-bundle shaping.
- Adaptive visual hierarchy: compact one-column, mid-size transport-plus-playlist, and wide three-column layout.
- Stable accessibility identifiers for VoiceOver and local automation agents.

## macOS-Specific Before iPad

- App shell: `NSApplication`, menu bar extra, Settings scene, and close-to-menu-bar behavior.
- File workflows: `NSOpenPanel`, `NSWorkspace`, Finder reveal, and pasteboard APIs.
- Visual system colors and image loading that use `NSColor` and `NSImage`.
- Audio routing: Core Audio device UID and stereo output-pair selection are Mac-specific.
- Distribution: Developer ID/notarized DMG is separate from an iPad TestFlight or App Store package.

## iPad Target Plan

1. Add platform wrappers for file picking, clipboard, image loading, and window/application actions.
2. Split the app shell from the show surface so macOS keeps menu bar and Settings behavior while iPadOS uses NavigationSplitView/sheets.
3. Replace Core Audio device-routing UI with iPad-appropriate route selection and document the differences.
4. Verify the layout at iPad full screen, half, third, quadrant, Stage Manager, external display, and minimum window sizes.
5. Keep heartbeat and external-control safety defaults identical: no external or heartbeat path can start audio unless the operator explicitly arms the behavior.
