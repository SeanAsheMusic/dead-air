# Dead Air Ship-Ready Checklist

## Current Local Build

- Native macOS SwiftUI app
- Local ad-hoc signing for this Mac
- Optional sandbox-signed local test build with `./Scripts/build_app.sh --sandbox`
- Sandbox-first Developer ID build path with `./Scripts/build_app.sh --developer-id`
- App icon and in-app logo mark included
- Managed audio library under Application Support
- Optional external references with security-scoped bookmarks
- Local-only show runtime
- MIDI, OSC, output routing, playlist modes, logs, and preflight readiness panel
- Lighting OSC/MIDI show-cue layer with per-profile global cues, per-track cues, and named Lightkey/Luminescence/Show Off connectors
- Support-bundle export for rehearsal troubleshooting
- First-run Setup Assistant with EZ Setup presets, connector walkthrough, Simple/Advanced UI, Help Center, privacy doc, troubleshooting doc, and release notes

## Mac App Store Path

Apple's current distribution guidance means the App Store build should be produced from Xcode/App Store Connect with:

- App Sandbox enabled
- Icon configured through an asset catalog or Icon Composer
- Final, non-crashing app bundle with complete metadata
- Self-contained app bundle with no third-party installer
- User-selected file access entitlement for imports, external references, and playlist export
- No login item or auto-launch behavior without user consent
- `NSHumanReadableCopyright` set in the app's Info.plist
- Review notes explaining the app's local MIDI/OSC live-show use case
- Bundle ID `com.undeniablespectacle.deadair`
- Version `4.0.0`, build `4`

Use `Entitlements/DeadAir-AppStore.entitlements` as the starting sandbox entitlement file.

## Developer ID Path

For direct distribution outside the Mac App Store:

- Sign with a Developer ID Application certificate
- Enable Hardened Runtime
- Notarize with Apple
- Staple the notarization ticket
- Verify on a clean Mac user account

Use `Entitlements/DeadAir-DeveloperID.entitlements` as the starting entitlement file.

## Final Stage Test Before Release

- Complete `Distribution/QA_RUNBOOK.md`
- Save a completed copy of `Distribution/QA_RESULTS_TEMPLATE.md` for the exact release SHA and DMG
- Import real show transition beds
- Test both Copy and Reference import modes
- Relaunch after Reference imports and confirm external beds still open
- Select the real interface or virtual output and channel pair
- Confirm Ableton/AbleSet can target `Dead Air In`
- Test every learned MIDI mapping
- Test OSC only if it will be used in the show
- If using connectors, complete Setup Assistant > Connectors and confirm the appropriate test cue appears in Lightkey, Luminescence, Show Off, Custom OSC, or MIDI fallback monitoring
- If using Luminescence, start its OSC Listener and confirm Dead Air's Luminescence cue reaches the expected live cue
- If using Show Off, confirm Dead Air's Show Off cue appears as an operator/stage notification over OSC `39051`
- If using another DMX/show-control app, choose Custom OSC or MIDI and confirm the app receives Dead Air's Send Test Cue
- Confirm each global and per-track lighting cue triggers the intended scene
- Confirm the lighting app closed/offline does not stop Dead Air audio
- Export a support bundle after rehearsal and confirm it contains readiness, logs, routing, and lighting cue state
- Run a full setlist rehearsal
- Crash or quit Ableton while Dead Air is audible
- Unplug/replug the audio interface
- Test Show Mode heartbeat behavior
- Verify external MIDI/OSC cannot start audio until Show Mode is deliberately armed
- Export/inspect logs after rehearsal
- Verify Simple/Advanced, Show Dark, System Light/Dark, Help Center, and Setup Assistant at small and large window sizes
- Verify referenced-file Relink and stale bookmark refresh on a moved file
- Verify support-bundle redaction before sending logs externally
