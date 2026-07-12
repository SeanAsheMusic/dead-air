# Dead Air

Dead Air is a native macOS transition-bed player for live-show handoffs. It keeps its own audio engine running outside Ableton Live/AbleSet, accepts explicit MIDI and OSC commands, and provides large manual controls plus a menu bar fallback.

For fast setup, see [QUICKSTART.md](QUICKSTART.md). For operator instructions, see [USER_GUIDE.md](USER_GUIDE.md). For project/build details, see [TECHNICAL_README.md](TECHNICAL_README.md).

## Commercial Readiness V4.0.1

- Company and bundle identity aligned to Undeniable Spectacle: `com.undeniablespectacle.deadair`
- Version reads from the app bundle: `4.0.1` build `11`
- First-run Setup Assistant with guided rig presets, audio routing, file behavior, inbound control, connector walkthroughs, and final readiness checks
- Built-in setup presets for Ableton/AbleSet + Lightkey, Ableton/AbleSet + Luminescence, Show Off bridge, generic DAW MIDI, IAC legacy rigs, DJ manual operation, QLab OSC, and reference-file workflows
- Simple/Advanced UI modes plus System, Show Dark, Light, and Dark appearance modes
- Searchable built-in Help Center and macOS Help menu entry
- Exact MIDI input source selection and exact outbound MIDI destination selection
- OSC restart protection for repeated port retries
- Backup-before-write persistence, corrupted JSON quarantine, stale bookmark refresh, and Relink for referenced tracks
- Diagnostics snapshot synchronization, redaction, retention, and support-bundle export controls
- Sandbox-first App Store and Developer ID entitlement baselines

## V2 Additions

- Cleaner stage-safe UI with larger sections and clearer status indicators
- Help icons/tooltips on show-critical controls and settings
- Per-app Core Audio output routing instead of only changing the Mac's default output
- Output device selection for interfaces, aggregate devices, and virtual devices
- Stereo output-pair selection such as 1-2, 3-4, 5-6, based on the selected device's exposed outputs
- Audio engine configuration-change recovery for route/sample-rate changes
- Startup guard to prevent duplicate engine/control initialization
- Removed forced unwraps in the import picker

## V2.1 Additions

- Long fade-in and fade-out sliders up to 3 minutes
- Separate live crossfade slider for audible bed changes
- Explicit in-app confirmation that fades/crossfades are handled by Dead Air, not Ableton
- Visual playlist numbering
- Bed modes:
  - `Continuous`: current bed loops until you manually pick or advance
  - `Auto-Prep`: after fade-out, Dead Air silently primes the next bed
  - `Auto-Crossfade`: if a bed reaches its end while audible, Dead Air crossfades into the next bed
- Manual Next Bed or selecting another bed while audible now crossfades inside Dead Air

## V3 Additions

- Custom Dead Air app icon and logo mark
- Finder/Dock app icon wired into the macOS bundle
- Header branding now uses the same logo mark
- Show Readiness preflight panel
- One-click cue-map copy for Ableton/AbleSet setup notes
- App Store and Developer ID entitlement starter files
- Ship-ready checklist for App Store, Developer ID, and final stage testing

## Production-Grade V3.5 Additions

- Dedicated macOS Settings window with Audio, Playback, MIDI/OSC, Library, Profiles, Diagnostics, and Advanced tabs
- Cleaner live show surface: transport, fade timing, bed mode, current route, profile, preflight, and log stay visible without burying the operator in setup controls
- Show Profiles for reusable venue/system setups, including audio route, sample rate, bed mode, import mode, MIDI map, OSC, heartbeat, logging, and power settings
- DJ-useful metadata on every bed: artist, BPM, musical key, energy, tags, notes, metadata source, and cue/Ableton reference
- Playlist search and filters for all beds, ready beds, referenced files, and tracks needing BPM/key metadata
- Track Inspector for manual show-prep edits without opening a separate tool
- Imported metadata support for common title/artist tags and compatible BPM/key tags when exposed by the audio file
- Diagnostics and preflight controls are available from both the main window and Settings
- Main window can be closed to the macOS menu bar for set-and-forget show operation
- Menu bar controls can fade in, fade out, advance, panic mute, arm Show Mode, reopen the main window, or open Settings
- Dead Air opens Show Mode disarmed and blocks external fade-in, next-bed, and level commands until the operator arms Show Mode
- More native macOS interface treatment across the main window, Setup Assistant, and Settings
- Native macOS toolbar actions for Import, Save Playlist, Cue Map, Setup Assistant, Help, Settings, Keep in Menu Bar, and Show Mode
- Current Bed panel for fast operator confirmation before showtime
- Accessibility settings for larger transport controls, reduced glass effects, higher status contrast, and stable automation identifiers for local helpers

## V4 Show Cue / Connector Additions

- Outbound show-control cues so Dead Air can trigger lighting while Ableton/AbleSet loads the next session
- Lightkey OSC target defaults to `127.0.0.1:21600`
- Luminescence OSC connector defaults to `127.0.0.1:9001` with `/luminescence/cue` and a cue-name argument
- Show Off OSC connector defaults to `127.0.0.1:39051` with safe `/notify/*` messages for stage/operator devices
- Custom OSC provider for QLC+, MagicQ, QLab, grandMA, and other show-control/DMX apps that accept UDP OSC
- EZ Setup connector walkthrough for Lightkey, Luminescence, Show Off, Custom OSC, MIDI fallback, and inbound MIDI/OSC-only rigs
- Global show cues for show mode, bed priming, fade in/out, next bed, crossfade, panic, heartbeat loss, and app quit
- Per-track lighting cues in the Track Inspector for bed-specific looks or transition scenes
- Lightkey-safe OSC path generation such as `/live/Live/cue/Transition/activate`
- Raw OSC address support for addresses copied directly from Lightkey or another lighting app
- MIDI fallback output to destinations such as `Lightkey Input`, defaulting to channels 1-15 instead of Lightkey Live Trigger channel 16
- Lighting readiness, last-cue status, event-log filtering, test-cue button, and support-bundle export
- Inbound OSC port retry/change controls so a port conflict is visible and recoverable without stopping playback

## Sandbox and Storage

- Import mode can be set per future import:
  - `Copy`: copy files into Dead Air's managed library for maximum show safety.
  - `Reference`: leave files on Desktop, an external drive, or another folder and store a security-scoped bookmark for sandbox-safe reopen access.
- Referenced files are not duplicated, but the show depends on those original files staying available at showtime.
- The default local build is under `dist/Dead Air.app`.
- A sandbox-signed local test build can be created with:

```sh
./Scripts/build_app.sh --sandbox
```

That writes `dist-sandbox/Dead Air.app`.

## Playlist Defaults

- `Save Playlist` stores the current playlist internally for quick reuse.
- `Export` writes a portable `.json` playlist file to a location you choose.
- `Load` restores a playlist file, including track order and references/bookmarks.
- `Default -> Save Default` saves the current playlist and show settings as the default setup.
- `Default -> Restore Default` restores that saved setup.
- `Show Profiles` save reusable system setups for different venues, interfaces, virtual devices, MIDI controllers, or show templates.

## Included

- SwiftUI macOS app shell and menu bar controls
- AVAudioEngine playback with equal-power fades
- Drag/drop and folder import into a managed Application Support library
- Playlist reorder, save, and load
- Playlist search, filters, numbered rows, and track metadata inspector
- Show Profiles for venue/system setup recall
- Lighting/show-cue integration with global and per-track cue maps
- WAV, AIFF, CAF, MP3, M4A, AAC, ALAC, and FLAC import path where AVFoundation supports the file
- Switchable internal sample rate: 44.1, 48, 88.2, and 96 kHz
- Core Audio buffer-size agnostic playback with engine recovery on device configuration changes
- Core Audio output-device picker and stereo channel-pair routing
- App-owned virtual MIDI destination: `Dead Air In`
- Optional IAC source mode in config
- Programmable MIDI map with MIDI Learn and manual editing
- Note On, Note Off, Control Change, Program Change, Pitch Bend, and MIDI transport Start/Stop/Continue matching
- Per-command channel, number, value-threshold, and source-text matching in the config
- OSC listener on `127.0.0.1:38101`
- Outbound OSC sender on `127.0.0.1:21600` by default for Lightkey, named local connectors for Luminescence (`9001`) and Show Off (`39051`), plus custom host/port/address support for other show-control apps
- Optional outbound MIDI lighting fallback
- Show Mode sleep-prevention assertion
- Menu bar operation after the main window is closed
- Opt-in heartbeat supervision; heartbeat loss is flag-only by default and cannot start audio unless explicitly selected
- Adaptive macOS window layout with compact, mid-size, and wide breakpoints; see `Distribution/IPADOS_READINESS.md` for the real iPadOS portability plan
- JSONL diagnostics under `~/Library/Application Support/Dead Air/Logs`
- Local automated check runner for config, MIDI, OSC, dedupe, state machine, and fade math

## Default Control Map

| Function | MIDI | OSC |
|---|---|---|
| Fade In | Ch. 16 Note 120 | `/lbk/fadeIn` |
| Fade Out | Ch. 16 Note 121 | `/lbk/fadeOut` |
| Panic Mute | Ch. 16 Note 122 | `/lbk/panic` |
| Next Bed | Ch. 16 Note 123 | `/lbk/nextBed` |
| Arm | Ch. 16 Note 124 | `/lbk/arm` |
| Disarm | Ch. 16 Note 125 | `/lbk/disarm` |
| Level | Ch. 16 CC 20 | `/lbk/level 0.0..1.0` |

The map is editable in the app under **Show Settings -> MIDI Map**. Click **Learn** beside any action, then send the MIDI event from Ableton, a controller, IAC, or another MIDI source. The learned mapping is saved automatically.

## Connector / Show Cue Workflow

1. In Lightkey, open Settings > External Control and enable OSC.
2. Keep Lightkey listening on `127.0.0.1:21600`.
3. In Dead Air, run Setup Assistant > Connectors or open Settings > Connectors and enable Outbound Show Cues.
4. Add global cues for common events such as Fade In Started, Fade Out Completed, Crossfade Started, or Panic Muted.
5. Add per-track cues in the Track Inspector when a specific bed needs a specific Lightkey look.
6. Use Send Test Cue and Lightkey's External Control Log before rehearsal.

For Luminescence, choose **Luminescence OSC**, start Luminescence's OSC Listener, and set the Dead Air cue name to the matching Luminescence live cue. For Show Off, choose **Show Off OSC** to publish local stage/operator notifications over UDP `39051`; tokened HTTP write actions remain inside Show Off's own trusted workflow. For other lighting apps, choose **Custom OSC**, enter the app's receive host/port, and paste the exact OSC address expected by that app. MIDI remains available as a fallback when the lighting app or console exposes MIDI input instead of OSC.

Lighting cue failures are logged but never stop Dead Air audio playback.

## Build

Run:

```sh
./Scripts/build_app.sh --local
```

The double-clickable app bundle is created at:

```text
dist/Dead Air.app
```

Sandbox test build:

```sh
./Scripts/build_app.sh --sandbox
```

Developer ID build after the Apple Developer account and certificate exist:

```sh
DEAD_AIR_SIGN_IDENTITY="Developer ID Application: Sean Ashe (G82WS97Q35)" ./Scripts/build_app.sh --developer-id
```

Local builds are ad-hoc signed for development. Developer ID signing, notarization, stapling, and App Store archive/export require the Apple Developer account, a Developer ID Application certificate, and notarization credentials.

## Checks

Run:

```sh
swift run DeadAirChecks
```
