# Dead Air Release Notes

## 4.0.0 Build 4

Commercial-readiness pass for Undeniable Spectacle.

- Bundle ID aligned to `com.undeniablespectacle.deadair`.
- App version reads from the bundle instead of a hardcoded label.
- Added first-run and New Setup wizard.
- Added built-in setup presets for Ableton/AbleSet + Lightkey, generic DAW MIDI, IAC legacy rigs, DJ manual use, QLab OSC, and reference-file workflows.
- Added Custom OSC lighting provider for other DMX/show-control apps that receive UDP OSC.
- Added Simple and Advanced UI modes.
- Added System, Show Dark, Light, and Dark appearance modes.
- Added searchable built-in Help Center and Help menu entry.
- Added exact MIDI source and output destination selection.
- Hardened OSC restart behavior with socket generation tracking.
- Added diagnostics snapshot synchronization and log retention/redaction controls.
- Added backup-before-write persistence and corrupted JSON quarantine.
- Added stale bookmark refresh support and Relink for referenced tracks.
- Added output preflight details for selected device, stereo pair, nominal sample rate, and engine format.
- Changed Lightkey success wording to `packet sent` unless externally verified in Lightkey.
- Added synchronous app-quit OSC send for configured quit cues.
- Added support-bundle redaction controls.
- Added sandbox-first Developer ID entitlements and build modes.

Known commercial requirement: final App Store or Developer ID release still requires an Apple Developer account, production certificate, notarization where applicable, and final clean-Mac QA.
