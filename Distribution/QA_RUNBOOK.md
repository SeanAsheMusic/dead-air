# Dead Air Release QA Runbook

Use this runbook for every notarized beta or release candidate. Record results in `Distribution/QA_RESULTS_TEMPLATE.md` and attach the completed copy to the release.

## Build Gate

1. Confirm `main` is current and clean.
2. Run `swift run DeadAirChecks`.
3. Run `swift run -c release DeadAirChecks`.
4. Run `swift run --sanitize thread DeadAirChecks`.
5. Run `swift run --sanitize address DeadAirChecks`.
6. Run `swift build -c release -Xswiftc -warnings-as-errors`.
7. Confirm GitHub CI is green for the release SHA.
8. Confirm GitHub CodeQL is green for the release SHA.
9. Build the notarized DMG with `./Scripts/package_release_dmg.sh --notarize`.
10. Confirm the DMG passes Gatekeeper assessment.
11. Follow `Distribution/STABILITY_TEST_PLAN.md` for stress and clean-profile smoke coverage.

## Install And First Launch

1. Install from the release DMG into `/Applications`.
2. Launch by double-clicking `Dead Air.app`.
3. Confirm macOS does not require right-click Open or quarantine workarounds.
4. Complete Setup Assistant with the target EZ Setup preset and connector path.
5. Quit and relaunch from the menu bar and Dock.

## Core UI

1. Switch Simple and Advanced modes.
2. Verify Show Dark, Light, Dark, and System appearance modes.
3. Resize the main window to roughly 380 x 500, 520 x 500, 920 x 640, and 1200 x 760.
4. Confirm compact width uses one column, mid-size width shows transport and playlist side-by-side, and wide width shows transport, playlist, and readiness/log content together.
5. Confirm Help Center, Setup Assistant, and Settings scroll vertically instead of clipping at short heights.
6. For future iPadOS work, follow `Distribution/IPADOS_READINESS.md` and test full, half, third, quadrant, external-display, and minimum Stage Manager window sizes.
7. Open Help Center, Setup Assistant, Settings, Diagnostics, and redacted Support Bundle export.
8. Close the main window and reopen it from the menu bar.

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
2. Launch Dead Air with MIDI/OSC sources already running and confirm external fade-in, next-bed, and level commands are ignored while Show Mode is disarmed.
3. Arm Show Mode from the app, then learn and trigger fade in, fade out, panic, next bed, arm, disarm, and level.
4. Send inbound OSC to `127.0.0.1:38101`.
5. Confirm duplicate MIDI or OSC commands are deduped except panic.
6. Confirm Show Mode heartbeat behavior when the source stops.
7. Confirm heartbeat loss only changes status/logs by default and does not start audio unless `Fade In If Muted` was explicitly selected in Advanced settings.

## Connectors And Show Control

1. Use Setup Assistant > Connectors and confirm every connector card explains the expected receiver, endpoint, and test behavior.
2. Send the Lightkey test cue to `127.0.0.1:21600`.
3. Confirm Lightkey External Control Log receives the expected cue.
4. Start Luminescence's OSC Listener and send a Luminescence OSC test cue to `127.0.0.1:9001` using `/luminescence/cue`.
5. Run Show Off and send a Show Off OSC notification test cue to `127.0.0.1:39051`.
6. Send a Custom OSC cue to a local UDP/OSC receiver.
7. Send a MIDI fallback cue to the target virtual or hardware destination.
8. Confirm connector-send failures do not interrupt audio.
9. Confirm global and per-track cue maps trigger as expected.

## Privacy And Support

1. Export a support bundle with redaction enabled.
2. Confirm `redactionStatus` is `enabled`.
3. Confirm local paths under `/Users`, `/Volumes`, `~/`, and network URLs are absent.
4. Confirm audio device names, UIDs, MIDI source names, MIDI destination names, cue maps, active profile details, and UUID-like identifiers are absent or marked `[redacted]`.
5. Export with redaction disabled only on an internal test Mac and confirm the UI setting is explicit.

## Accessibility And Automation

1. Enable Settings > Accessibility > Larger transport controls and confirm the four transport controls grow without clipping at compact and wide window sizes.
2. Enable Reduce glass effects and Increase status contrast, then verify status, readiness, setup, and settings remain readable in Light, Dark, and Show Dark.
3. With VoiceOver or Accessibility Inspector, confirm transport buttons expose labels and hints, status pills expose values, and readiness rows say Ready or Needs attention.
4. Confirm a Computer Use or Hermes-style helper can locate `deadAir.transport.fadeIn`, `deadAir.transport.panicMute`, `deadAir.toolbar.showModeToggle`, `deadAir.setup.sheet`, and `deadAir.readiness.panel`.
5. Confirm the compact setup flow uses the Step menu and does not create nested scroll traps.

## Release Decision

Release only if all P0 rows pass, no unresolved P1 issue can cause show audio failure, and the final artifact is the notarized DMG created from the exact SHA whose CI and CodeQL are green.
