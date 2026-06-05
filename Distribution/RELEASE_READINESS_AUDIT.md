# Dead Air Release Readiness Audit

Date: 2026-06-04

This audit supersedes the older release-level handoff notes for current local work. The GitHub repository is public, and the direct-download Developer ID notarization path is configured.

## Current Verified State

- GitHub repository is public at `https://github.com/SeanAsheMusic/dead-air`.
- Hosted CI and CodeQL were green on the last pushed `main` SHA before this local connector/icon/design pass; the current local patch must be pushed and rechecked before public release.
- Local gate passes:
  - `swift run DeadAirChecks`
  - `swift build -c release -Xswiftc -warnings-as-errors`
  - `./Scripts/build_app.sh --local`
- Developer ID signing is configured locally with timestamped app and DMG signing.
- The notary credentials are stored in the `dead-air-notary` keychain profile.
- The latest fresh notarization submission for `Dead-Air-4.0.0-4.dmg` is `632fe7dc-ed69-4708-bafe-0a77332dee70`; it was accepted, stapled, and assessed with Gatekeeper as `source=Notarized Developer ID`.
- Release artifact: `release/Dead-Air-4.0.0-4.dmg`, SHA-256 `03f0050ff4598797b2da37d2b273f68382d6e0072a93682c096c87a9a2b8f85f`.
- Support-bundle redaction has automated coverage for local paths, network paths, device identifiers, MIDI/device names, active profile details, and cue maps.
- App icon option C is active in the app bundle and regenerated across the `.icns` sizes.
- The main window now has compact, mid-size, and wide layouts for native macOS resizing. Setup, Help, and Settings use compact scrollable shells at narrow widths.
- Heartbeat recovery is opt-in and cannot fade audio in from legacy config files unless the operator explicitly chooses `Fade In If Muted` in current settings.

## Native macOS Design Audit

Reference guidance:

- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines
- Color: https://developer.apple.com/design/human-interface-guidelines/color
- Layout: https://developer.apple.com/design/human-interface-guidelines/layout
- Typography: https://developer.apple.com/design/human-interface-guidelines/typography
- Toolbars: https://developer.apple.com/design/human-interface-guidelines/toolbars
- Settings: https://developer.apple.com/design/human-interface-guidelines/settings
- Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- App icons: https://developer.apple.com/design/human-interface-guidelines/app-icons

Findings and actions taken:

- Native controls are already used for menus, settings, pickers, toggles, steppers, sliders, text fields, and the menu bar extra.
- Setup connector selection now uses a menu picker instead of an overcrowded segmented control.
- Help popovers no longer open automatically on pointer hover; native tooltips remain available and click-to-open help is still present.
- Transport buttons now use title case labels and a quieter treatment instead of all-caps glossy styling.
- Repeated custom card corners were tightened to 8 pt in the edited surfaces to better match a restrained macOS utility feel.
- Current visual direction: the app now leans more on native macOS materials and system colors while preserving large show-safe transport controls. Final visual QA should still compare actual screenshots in Light, Dark, Show Dark, small window, and external-display sizes.
- Resize QA on this candidate covered roughly 380 px, 420 px, 520 px, 920 px, and 1200 px window widths. The old Settings minimum-width trap was removed by replacing the fixed macOS Settings scene with an adaptive resizable window.

## Integration Audit

Implemented connector surfaces:

- Lightkey OSC: `127.0.0.1:21600`, generated `/live/...` paths or raw Lightkey paths.
- Luminescence OSC: `127.0.0.1:9001`, `/luminescence/cue`, first argument is the Luminescence cue name.
- Show Off OSC: `127.0.0.1:39051`, default safe `/notify/cue` or `/notify/critical` messages.
- Custom OSC: arbitrary raw OSC address to user-configured host/port.
- MIDI fallback remains available for show-control apps that expose MIDI input.

Intentional limit:

- Dead Air does not store Show Off HTTP write tokens. Show Off HTTP writes stay inside Show Off's tokened trusted workflow. Dead Air's release connector uses local OSC only.

## Remaining Release Blockers

- Manual QA with the real audio interface, Ableton/AbleSet, Luminescence, Show Off, Lightkey or final connector target, and a real show playlist is still required.
- A clean-machine install from the notarized DMG has not been performed.
- GitHub CI and CodeQL must be rechecked on the final pushed SHA.
- The app should still be screenshot-reviewed in all appearance modes after the final pushed build to catch layout crowding and text overflow.

## Release Decision

Approved for controlled beta sharing from the notarized DMG above. Not approved for public release yet: final GitHub CI/CodeQL proof, clean-machine install QA, and real-rig audio/connector rehearsal QA are still required before calling this a full release.
