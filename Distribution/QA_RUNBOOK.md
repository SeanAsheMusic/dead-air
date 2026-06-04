# Dead Air Release QA Runbook

Use this runbook for every notarized beta or release candidate. Record results in `Distribution/QA_RESULTS_TEMPLATE.md` and attach the completed copy to the release.

## Build Gate

1. Confirm `main` is current and clean.
2. Run `swift run DeadAirChecks`.
3. Run `swift build -c release -Xswiftc -warnings-as-errors`.
4. Confirm GitHub CI is green for the release SHA.
5. Confirm GitHub CodeQL is green for the release SHA.
6. Build the notarized DMG with `./Scripts/package_release_dmg.sh --notarize`.
7. Confirm the DMG passes Gatekeeper assessment.

## Install And First Launch

1. Install from the release DMG into `/Applications`.
2. Launch by double-clicking `Dead Air.app`.
3. Confirm macOS does not require right-click Open or quarantine workarounds.
4. Complete the first-run wizard with the target show preset.
5. Quit and relaunch from the menu bar and Dock.

## Core UI

1. Switch Simple and Advanced modes.
2. Verify Show Dark, Light, Dark, and System appearance modes.
3. Resize to the smallest supported window and a large external-display window.
4. Open Help Center, Settings, Diagnostics, and Support Bundle export.
5. Close the main window and reopen it from the menu bar.

## Library And Persistence

1. Drag in individual audio files.
2. Import a folder with nested supported and unsupported files.
3. Test Copy import mode.
4. Test Reference import mode from an external volume.
5. Move a referenced file and confirm stale bookmark detection.
6. Relink the moved file and confirm playback works.
7. Save playlist, load playlist, save default, quit, relaunch, and restore default.
8. Confirm corrupted config or playlist backup recovery does not lose the managed library.

## Audio

1. Play a real transition bed through the target output.
2. Test fade in, fade out, panic mute, clear panic, and next bed.
3. Test crossfade at end and manual crossfade.
4. Test 44.1, 48, 88.2, and 96 kHz files.
5. Select every expected output channel pair.
6. Unplug and replug the target interface during a safe test.
7. Confirm Dead Air enters a clear warning/degraded state when routing fails.

## MIDI And OSC

1. Send virtual MIDI from the target DAW or IAC bus.
2. Learn and trigger fade in, fade out, panic, next bed, arm, disarm, and level.
3. Send inbound OSC to `127.0.0.1:38101`.
4. Confirm duplicate MIDI or OSC commands are deduped except panic.
5. Confirm Show Mode heartbeat behavior when the source stops.

## Lighting And Show Control

1. Send the Lightkey test cue to `127.0.0.1:21600`.
2. Confirm Lightkey External Control Log receives the expected cue.
3. Send a Custom OSC cue to a local UDP/OSC receiver.
4. Send a lighting MIDI cue to the target virtual or hardware destination.
5. Confirm lighting-send failures do not interrupt audio.
6. Confirm global and per-track cue maps trigger as expected.

## Privacy And Support

1. Export a support bundle with redaction enabled.
2. Confirm `redactionStatus` is `enabled`.
3. Confirm local paths under `/Users`, `/Volumes`, `~/`, and network URLs are absent.
4. Confirm audio device names, UIDs, MIDI source names, MIDI destination names, cue maps, active profile details, and UUID-like identifiers are absent or marked `[redacted]`.
5. Export with redaction disabled only on an internal test Mac and confirm the UI setting is explicit.

## Release Decision

Release only if all P0 rows pass, no unresolved P1 issue can cause show audio failure, and the final artifact is the notarized DMG created from the exact SHA whose CI and CodeQL are green.
