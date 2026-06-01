# Dead Air Technical README

## Project Layout

- `Sources/DeadAirApp`: SwiftUI app shell and UI
- `Sources/DeadAirCore`: audio, MIDI, OSC, persistence, Core Audio routing, library management
- `Assets`: app icon and logo mark
- `Bundle`: Info.plist
- `Entitlements`: App Store and Developer ID entitlement starters
- `Scripts`: build and asset generation scripts
- `Distribution`: ship-readiness checklist

## Build

Normal local build:

```sh
./Scripts/build_app.sh
```

Sandbox test build:

```sh
./Scripts/build_app.sh --sandbox
```

Developer ID build once the certificate is available:

```sh
DEAD_AIR_SIGN_IDENTITY="Developer ID Application: Undeniable Spectacle" ./Scripts/build_app.sh --developer-id
```

Automated checks:

```sh
swift run DeadAirChecks
```

## Runtime Data

Dead Air stores runtime data under:

`~/Library/Application Support/Dead Air`

Important files:

- `config.json`
- `library.json`
- `ShowProfiles.json`
- `Beds/`
- `Playlists/`
- `Logs/`

## Window and Menu Bar Behavior

Dead Air uses a SwiftUI `MenuBarExtra` plus an app delegate that returns `false` from `applicationShouldTerminateAfterLastWindowClosed`. Closing the main window leaves the audio engine, MIDI, OSC, heartbeat timer, and menu bar controls alive. The menu bar can reopen the main `WindowGroup` by ID.

## Audio Runtime

Dead Air does not assume a fixed hardware I/O buffer size. Core Audio owns the selected device buffer, while Dead Air schedules looped predecoded PCM buffers through `AVAudioEngine`; device configuration changes are coalesced before engine recovery. If recovery happens while audible, Dead Air reloads muted and surfaces an operator warning rather than restarting audibly.

Audio files are decoded into memory before playback so fades and crossfades remain independent from file I/O during a show. `AudioConfig.maxPredecodedBytes` is enforced before allocation, including the source-plus-converted peak memory estimate when sample-rate conversion is needed. Oversized files fail as recoverable readiness warnings instead of crashing the app.

## Data Model Notes

- `BedItem` is backward-compatible with older playlists and now carries optional DJ/show-prep metadata: artist, BPM, key, energy, tags, notes, metadata source, and cue reference.
- `BedItem` also supports per-track `LightingCue` records for bed-specific OSC/MIDI lighting actions.
- `ShowProfile` stores reusable system configuration separately from the playlist so one Mac can quickly move between venues, interfaces, virtual outputs, or MIDI rigs.
- `ShowProfile` and `AppConfig` include `LightingConfig`, so a venue profile can store OSC host/port, MIDI fallback destination, global cues, and cue dedupe timing.
- `LibraryManifest` can include the active profile ID, but playlists remain loadable without profiles.

## Show Cue / Lighting Control

Dead Air has separate inbound and outbound control paths:

- Inbound Dead Air OSC listens on `127.0.0.1:38101`.
- Outbound OSC sends to `127.0.0.1:21600` by default for Lightkey, and can be changed for other OSC receivers.
- Outbound MIDI fallback targets a destination name match such as `Lightkey Input`.

`OSCServer` serializes start/stop/receive using a generation token so old receive loops cannot outlive a port retry. The outbound OSC client sends UDP OSC packets on a background queue, and app-quit OSC cues can be sent synchronously during termination. `MIDIOutputManager` sends CoreMIDI messages on a background queue. None of these paths run on the audio thread, and failures are reported through diagnostics instead of interrupting playback.

MIDI input and output routing uses endpoint descriptors with exact endpoint identity where available. This avoids broad IAC matching when multiple DAWs, virtual MIDI buses, or controllers are open.

Generated Lightkey OSC addresses use:

`/live/<page>/cue/<cue>/<action>`

For framed Lightkey cues:

`/live/<page>/frame/<frame>/cue/<cue>/<action>`

Raw OSC addresses can be stored when an operator copies the exact address from Lightkey or another lighting app. Custom OSC sends the raw address without applying Lightkey path generation, which is the compatibility path for QLC+, MagicQ, QLab, grandMA, and other OSC-capable show-control systems. Generated Lightkey path parts replace spaces with underscores and warn on Lightkey-unsafe characters.

Cue triggers currently include show mode arm/disarm, bed priming, fade start/complete, next bed, crossfade start/complete, panic mute, heartbeat loss, app quit, and manual test.

## Diagnostics

The app can export a JSON support bundle containing config, readiness state, recent events, audio devices, output pairs, and lighting cue state. Diagnostics are stored behind a synchronized snapshot API. Redaction is enabled by default and removes local paths, device identifiers, and cue-map details from exported support data. Event Log filtering separates audio, MIDI, inbound OSC, outbound OSC, lighting, safety, and diagnostics.

## Sandbox Notes

The App Store entitlement starter enables:

- App Sandbox
- User-selected file read/write access
- App-scoped security bookmarks for persistent referenced-track access
- Network client/server for localhost OSC

External referenced audio uses security-scoped bookmarks. Stale bookmarks are refreshed when possible, and the Track Inspector includes Relink for moved or re-authorized referenced files. Managed copy mode avoids dependency on external paths.

## Distribution Notes

The local builds are ad-hoc signed. App Store or Developer ID shipping requires Apple Developer signing, provisioning, notarization where applicable, and final validation on a clean Mac.
