# Dead Air Troubleshooting

## No Audio

- Check Preflight > Output Route.
- Confirm the selected device and pair are connected.
- Try System Default, then switch back to the show device.
- Press Panic Mute, then Fade In.
- If the device changed while playing, Dead Air recovers muted by design to avoid surprise output.

## Sample Rate Warning

Dead Air can run at 44.1, 48, 88.2, or 96 kHz. The warning means the selected device's current nominal sample rate differs from Dead Air's target. For Ableton/AbleSet show rigs, 48 kHz is usually correct. Change the device rate in Audio MIDI Setup or change Dead Air's target rate to match the rig.

## Referenced File Missing

Referenced files are not copied. If a desktop folder or external drive moved, select the track and press `Relink` in the Track Inspector. Managed-copy imports avoid this dependency.

## MIDI Not Responding

- Use the guided setup wizard or Settings > MIDI/OSC.
- Confirm the exact IAC/DAW source is selected.
- Use MIDI Learn and send the event from Ableton, a controller, IAC, or another DAW.
- Avoid generic source names such as just `IAC` when multiple apps are open.
- Confirm Ableton is sending on the mapped channel.

## OSC Port Conflict

Dead Air listens on `127.0.0.1:38101` by default. If another Dead Air copy or app owns the port, Settings > MIDI/OSC shows the failure. Press Retry OSC after closing the other app, or change the port.

## Lightkey Test Shows No Match

This means Lightkey received the packet but no matching cue exists. That is still useful: it proves the OSC path is alive. Create a matching Lightkey page/cue or paste the exact OSC address from Lightkey into Dead Air.

## Lighting App Closed

Dead Air keeps audio running. UDP OSC packets can be sent even when Lightkey is not listening, so Dead Air logs `packet sent` rather than `confirmed`.

## Other Lighting App Not Responding

- Choose `Custom OSC` for apps such as QLC+, MagicQ, QLab, grandMA, or other DMX/show-control tools.
- Confirm the target app is listening for UDP OSC on the host and port entered in Dead Air.
- Paste the exact OSC address the lighting app expects. Custom OSC does not generate Lightkey-style paths.
- Confirm the target app allows local network/loopback traffic and that its receive port is not already owned by another app.
- If the app does not support OSC input, use Dead Air's MIDI provider and select the exact MIDI destination.

## Export Support Bundle

Open Settings > Diagnostics > Export Support Bundle. With redaction enabled, Dead Air removes local paths, device identifiers, and cue maps from the bundle.
