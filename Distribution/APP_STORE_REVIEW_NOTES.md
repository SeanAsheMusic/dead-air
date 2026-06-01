# App Store Review Notes

App name: Dead Air

Company: Undeniable Spectacle

Bundle ID: `com.undeniablespectacle.deadair`

Category: Music

Dead Air is a native macOS live-show utility for transition-bed playback and local show-control cues. It is not a cloud service and does not require an account.

## Reviewer Setup

1. Launch Dead Air.
2. Use the setup wizard or skip it.
3. Import any short audio file.
4. Press Fade In, Fade Out, Next Bed, and Panic Mute.
5. Open Settings to inspect output routing, MIDI/OSC, Lighting, Diagnostics, and Profiles.

## Local Network / OSC

Dead Air uses localhost OSC for optional show control:

- Inbound OSC: `127.0.0.1:38101`
- Optional outbound lighting OSC: `127.0.0.1:21600` by default for Lightkey, user-configurable for other OSC receivers

Lighting failures never block audio playback.

## File Access

The app supports two user-controlled import modes:

- Copy files into Dead Air's managed Application Support library.
- Reference user-selected files with security-scoped bookmarks.

## No Account Required

All features are local. The app does not upload user files or require sign-in.
