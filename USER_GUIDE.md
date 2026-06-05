# Dead Air User Guide

## What Dead Air Does

Dead Air is a live-show transition bed player. It stays open outside Ableton Live/AbleSet, so fade-ins, fade-outs, crossfades, and playlist changes continue even while Ableton is closing or opening another Live Set.

## First Setup

1. Open `Dead Air.app`.
2. Use Setup Assistant.
3. Choose the preset closest to the current rig.
4. Choose the output device and output channel pair.
5. Open Dead Air Settings and create or select a Show Profile for the venue/system.
6. Choose an import mode:
   - `Copy`: copies files into Dead Air's managed library. This is safest for shows.
   - `Reference`: leaves files where they are and stores sandbox-safe access to them.
7. Import or drag audio files/folders into the playlist.
8. Set Fade In, Fade Out, and Live Crossfade times.
9. Choose Bed Mode.
10. Fill in BPM, key, artist, tags, notes, and cue references for tracks where that helps show prep.
11. Use the Connectors step if Dead Air should trigger Lightkey, Luminescence, Show Off, Custom OSC, or MIDI show cues.
12. Map MIDI if the defaults are not what your Ableton/AbleSet show uses.
13. Save Setup, then arm Show Mode before a real rehearsal/show.

The macOS toolbar contains the common setup and show actions: Import, Save Playlist, Cue Map, Setup Assistant, Help, Settings, Keep in Menu Bar, and Show Mode.

## Help Icons

The help icons use standard macOS help text and can be clicked for longer context. Use the Help button or Help menu for the searchable Help Center.

## Simple and Advanced Modes

`Simple` keeps the main window focused on transport, playlist, readiness, and setup.

`Advanced` exposes the full event log, deeper routing, cue maps, diagnostics, MIDI/OSC, lighting, and profile editing.

Appearance defaults to the macOS system setting. Use `Show Dark` for low-light live environments.

## Menu Bar Mode

Dead Air keeps running when the main window is closed. Use `Close Main Window to Menu Bar` from the Show menu or the `Keep in Menu Bar` toolbar button after programming the show.

From the macOS menu bar, you can fade in, fade out, advance to the next bed, panic mute, arm/disarm Show Mode, reopen Dead Air, open Settings, or quit the app. This is the intended set-and-forget mode for rehearsals and shows after the playlist, profile, and MIDI/OSC map are ready.

Dead Air always opens Show Mode disarmed. External MIDI/OSC fade-in, next-bed, and level commands are ignored until Show Mode is armed, while panic mute, fade out, and disarm remain available as protective commands.

## Import Modes

### Copy

Dead Air copies the audio file into:

`~/Library/Application Support/Dead Air/Beds`

Use this when show reliability matters more than disk duplication.

### Reference

Dead Air leaves the audio where it is and stores a security-scoped bookmark. This is useful for Desktop folders, show folders, or external drives. The original files must remain available.

## Playlist Saving

`Save Playlist` saves the current track list, order, storage mode, references/bookmarks, and metadata into Dead Air's internal playlist folder.

`Export` writes a playlist file wherever you choose.

`Load` loads a playlist file.

`Default -> Save Default` saves the current playlist and show setup as the default.

`Default -> Restore Default` restores that saved default setup.

## Settings Window

Use the macOS Settings window for deeper setup:

- `Audio`: output device, stereo pair, sample rate, target level, and routing.
- `Playback`: fade/crossfade defaults and bed advance behavior.
- `MIDI/OSC`: MIDI Learn, manual MIDI mapping, OSC enable state, and cue-map copy.
- `Connectors`: Lightkey, Luminescence, Show Off, Custom OSC, outbound MIDI fallback, global show cues, and test-cue controls.
- `Library`: import mode, playlist save/load, and metadata guidance.
- `Profiles`: save, apply, duplicate, rename, and delete Show Profiles.
- `Diagnostics`: readiness, logs, last MIDI event, and dropped-event count.
- `Advanced`: sleep prevention and opt-in heartbeat safety settings. Heartbeat loss is flag-only by default; choose any automatic response deliberately before rehearsal.

## Show Profiles

Show Profiles save a reusable system setup for a room, tour, venue, controller, interface, or virtual routing chain. A profile stores audio route, sample rate, output pair, bed mode, import mode, MIDI map, OSC settings, heartbeat, logging, and sleep-prevention behavior.

Create a profile once the system is working, then press `Save` after later changes. Use `Duplicate` when building a similar setup for another venue or device.

## DJ Metadata

Each playlist item can store artist, BPM, musical key, energy, tags, notes, and a cue/Ableton reference. Dead Air imports common metadata when the file exposes it, but the workflow is manual-first so show playback stays stable and predictable.

Use search and filters to find tracks by title, artist, key, tag, note, referenced-file status, or missing BPM/key metadata.

## Sample Rates and Buffers

Dead Air supports 44.1, 48, 88.2, and 96 kHz internal playback. Use 48 kHz for most Ableton/AbleSet show rigs unless the venue interface or virtual routing chain requires a different rate.

Hardware I/O buffer size is handled by macOS/Core Audio and your audio interface. Dead Air does not require a specific buffer setting; if the device changes its buffer or route, Dead Air rebuilds the audio engine and reloads the selected bed at the active sample rate. If that happens while audible, Dead Air recovers muted and warns the operator so the show output does not jump unexpectedly.

Very long audio files may be refused if they exceed the predecode safety limit. That warning is intentional: it keeps the app from risking show-time memory pressure. For unusually long material, split the file or use a shorter transition bed.

## Connectors And Show Cues

Dead Air can send show cues while it keeps transition audio playing. The main intended workflow is for Dead Air to activate a transition scene or stage notification when a bed starts, then deactivate or change that scene when the fade-out or crossfade completes. Setup Assistant walks through Lightkey, Luminescence, Show Off, Custom OSC, MIDI fallback, and inbound MIDI/OSC control.

### Lightkey OSC Setup

1. Open Lightkey.
2. Go to Settings > External Control.
3. Enable OSC.
4. Use `127.0.0.1` and port `21600`.
5. In Dead Air, open Settings > Connectors.
6. Enable Outbound Show Cues.
7. Add a global cue or a track cue.
8. Press Send Test Cue and confirm it appears in Lightkey's External Control Log.

Dead Air can generate Lightkey addresses from page/cue names. Spaces are sent as underscores. You can also paste a raw OSC address copied directly from Lightkey.

Example generated address:

`/live/Live/cue/Transition/activate`

### Luminescence OSC Setup

1. Start Luminescence's OSC listener.
2. Use `127.0.0.1` and port `9001`.
3. In Dead Air, open Settings > Connectors.
4. Choose `Luminescence OSC`.
5. Set the cue name to the matching Luminescence cue.
6. Press Send Test Cue and confirm Luminescence receives `/luminescence/cue`.

### Show Off OSC Setup

1. Run Show Off locally.
2. Confirm its OSC server is listening on `127.0.0.1:39051`.
3. In Dead Air, open Settings > Connectors.
4. Choose `Show Off OSC`.
5. Use the default `/notify/cue` path for stage-safe notices.
6. Keep tokened HTTP write actions inside Show Off's own trusted workflow.

### Custom OSC Setup

1. In the target lighting app, enable OSC input.
2. Note its receive host and port.
3. In Dead Air, open Settings > Connectors.
4. Choose `Custom OSC`.
5. Enter the host and port.
6. Paste the exact OSC address expected by the lighting app.
7. Press Send Test Cue and confirm the app's OSC monitor/log receives it.

Custom OSC is the compatibility path for apps such as QLC+, MagicQ, QLab, grandMA, and other tools that can receive OSC. Dead Air sends the raw address exactly as entered, so the receiving app controls the command syntax.

### Global Cues

Global cues can fire on show-wide events: Show Mode armed/disarmed, bed primed, Fade In started/completed, Fade Out started/completed, Next Bed selected, Crossfade started/completed, Panic Muted, Heartbeat Lost, and App Quit.

### Track Cues

Track cues live in the Track Inspector and fire only for that selected bed. Use these when one transition bed needs a specific lighting look.

### MIDI Fallback

Dead Air can also send outbound MIDI to a destination name such as `Lightkey Input`. The default channel is 1. Avoid channel 16 unless you specifically intend to use Lightkey Live Triggers.

Connector failures are diagnostics-only. Dead Air does not stop or block audio if the receiving app is closed, the MIDI destination is missing, or a cue path is wrong.

## Bed Modes

`Continuous`: the selected bed keeps looping until you manually select another bed or press Next Bed.

`Auto-Prep`: after Fade Out completes, Dead Air silently primes the next bed.

`Auto-Crossfade`: if a bed reaches its end while audible, Dead Air crossfades into the next bed.

## MIDI Defaults

- Ch 16 Note 120: Fade In
- Ch 16 Note 121: Fade Out
- Ch 16 Note 122: Panic Mute
- Ch 16 Note 123: Next Bed
- Ch 16 Note 124: Arm Show Mode
- Ch 16 Note 125: Disarm Show Mode
- Ch 16 CC 20: Target Level

You can use MIDI Learn for each command.

For IAC or multi-DAW systems, select the exact MIDI source in Settings. Dead Air avoids broad source matching so another app does not accidentally trigger the show.

## OSC Defaults

OSC listens on `127.0.0.1:38101`.

- `/lbk/fadeIn`
- `/lbk/fadeOut`
- `/lbk/panic`
- `/lbk/nextBed`
- `/lbk/arm`
- `/lbk/disarm`
- `/lbk/level 0.0..1.0`

## Show Checklist

1. Confirm Show Readiness panel is green.
2. Confirm the output device and pair.
3. Confirm the active bed.
4. Confirm MIDI or OSC is online.
5. Send a test connector cue and confirm it in the receiving app.
6. Test Fade In, Fade Out, Next Bed, Crossfade, and Panic.
7. Save the active Show Profile and Save Default once the setup is correct.
8. Use Keep in Menu Bar and verify the menu bar controls still work.
9. Run a full rehearsal with the actual Ableton/AbleSet and connector targets.
