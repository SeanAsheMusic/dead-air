# Dead Air Release Notes

## 4.0.1 Build 7

Support-bundle host redaction.

- Redacted support bundles now mask non-loopback OSC target hosts (inbound OSC host and lighting connector host). Loopback targets (`127.0.0.1`, `localhost`) stay readable because they are identical for every user; venue console IPs and mDNS names are redacted.

## 4.0.1 Build 6

Show-critical MIDI crash fix and UI polish.

- Fixed a crash on the CoreMIDI receive thread when an input delivered a MIDI packet longer than 256 bytes (large sysex, common from controller firmware chatter). Packets are now read in place from the packet list; long sysex is preserved instead of truncated.
- Removed redundant inline help buttons from transport tiles, status pills, and form labels; tooltips and section-level help remain.
- Port numbers no longer render with locale separators ("38,101" is now "38101").
- The Settings window is single-instance; Cmd+, and the Settings button reuse it.
- The Bed Mode label no longer truncates at compact window widths.
- Panic Mute reads as an emergency control in Light mode; the lighting status glyph uses a quieter hierarchical orange.

## 4.0.1 Build 5

Support-bundle privacy hardening.

- Redacted support bundles now also strip user-provided names captured inside recent log events: show profile names, bed titles and file names, lighting cue/page/frame names, raw OSC addresses, MIDI endpoint and mapping names, and audio device names.
- Privacy redaction now removes bare IPv4 addresses (with optional port) and `.local`/`.lan`/`.home` hostnames from exported logs and readiness details.
- Release DMG packaging now notarizes and staples the app itself before building the DMG, so first launches succeed offline even when the app is copied out of the disk image.

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
