# Dead Air Privacy

Dead Air is local-first. It does not upload audio, playlists, logs, MIDI maps, lighting cue maps, or device names.

## Data Stored Locally

Dead Air stores app data under:

`~/Library/Application Support/Dead Air`

This can include:

- App settings and show profiles
- Playlist order and metadata
- Managed-copy audio files if Copy import mode is used
- Security-scoped bookmarks for referenced files
- Local diagnostics logs if logging is enabled
- Lighting cue maps and MIDI/OSC routing settings

## Support Bundles

Support bundles are created only when you export them. Redaction is enabled by default and removes local paths, audio device identifiers, and cue maps.

## Network Use

Dead Air uses localhost networking for show control:

- Inbound OSC defaults to `127.0.0.1:38101`.
- Outbound lighting OSC defaults to `127.0.0.1:21600` for Lightkey and can be changed for other local or network OSC receivers.

Dead Air is designed for local show-control traffic, not cloud services.

## File Access

In sandbox builds, referenced audio files use security-scoped bookmarks so Dead Air can reopen user-selected files after relaunch. Managed-copy mode copies audio into Dead Air's Application Support folder.
