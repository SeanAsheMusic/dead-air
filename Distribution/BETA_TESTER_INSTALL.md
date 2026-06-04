# Dead Air Beta Install Notes

Dead Air beta builds should be distributed as a Developer ID signed and notarized DMG from Undeniable Spectacle.

## Install

1. Open the DMG.
2. Drag `Dead Air.app` into `Applications`.
3. Open `Applications`.
4. Double-click `Dead Air.app`.

If macOS blocks launch, stop and ask for a new DMG. Do not use right-click Open for release QA because that bypasses the Gatekeeper path the release must satisfy.

## First Setup

Use Setup Assistant on first launch:

1. Choose the closest EZ Setup preset.
2. Select your output device and stereo pair.
3. Keep 48 kHz unless your show system requires another sample rate.
4. Choose Copy for maximum safety or Reference to leave files where they are.
5. Select the exact DAW/IAC MIDI source if using MIDI.
6. Use the Connectors step for Lightkey, Luminescence, Show Off, Custom OSC, MIDI fallback, or inbound MIDI/OSC only.
7. Send a test connector cue before rehearsal.

## Beta Feedback

Please note:

- macOS version
- audio interface or virtual output used
- DAW or DJ app used
- connector target used, if any
- exact steps before any issue
- whether Dead Air showed a warning in Preflight or Event Log

Dead Air keeps audio local. It does not upload audio, playlists, MIDI maps, connector cue maps, or logs.
