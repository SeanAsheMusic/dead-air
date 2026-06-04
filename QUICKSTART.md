# Dead Air Quick Start

Dead Air is a native macOS show utility from Undeniable Spectacle. It keeps transition beds, fades, crossfades, MIDI/OSC control, and lighting cue packets running independently from Ableton, AbleSet, or other show apps.

## First Launch

1. Open `Dead Air.app`.
2. Use Setup Assistant: EZ Setup, Audio, Files & Control, Connectors, Finish.
3. Choose the closest EZ Setup preset. `Ableton/AbleSet + Lightkey` is the best starting point for most show rigs.
4. Select the output device and stereo pair.
5. Keep 48 kHz unless the venue or virtual audio route requires another rate.
6. Choose `Copy` for maximum show reliability or `Reference` to leave files where they are.
7. Pick the exact DAW/IAC MIDI source if you use external MIDI.
8. In Connectors, walk through the path you use: Lightkey, Luminescence, Show Off, Custom OSC, MIDI fallback, or inbound MIDI/OSC only.
9. Send a test connector cue and confirm it in the receiving app's OSC/MIDI monitor or External Control Log.
10. Save Setup.

## Show Workflow

1. Drag audio files or a folder into the playlist.
2. Reorder tracks into show order.
3. Add BPM, key, tags, energy, and notes where useful.
4. Set Fade In, Fade Out, and Live Crossfade times.
5. Choose bed mode:
   - `Continuous`: current bed loops until you choose another.
   - `Auto-Prep`: Fade Out primes the next bed.
   - `Auto-Crossfade`: end of bed crossfades to the next bed.
6. Arm Show Mode when you are ready for external MIDI/OSC show-control to start audio.
7. Use Keep in Menu Bar after programming.

## Before Doors

- Confirm Preflight is green or understood.
- Confirm output device, pair, and sample-rate warning state.
- Confirm MIDI/OSC input only responds to the intended controller or DAW.
- Confirm the connector test cue appears in Lightkey, Luminescence, Show Off, or your chosen OSC/MIDI receiver.
- Test Fade In, Fade Out, Next Bed, Crossfade, Panic Mute, and menu-bar controls.
- Save Profile and Save Default.
