# Dead Air Release Readiness Audit

Date: 2026-06-04

This audit supersedes the older release-level handoff notes for current local work. The app is still private and has not been submitted for notarization in this pass.

## Current Verified State

- GitHub repository remains private.
- Hosted CI and CodeQL were green on the last pushed private `main` SHA before this local connector/icon/design pass.
- Local gate passes:
  - `swift run DeadAirChecks`
  - `swift build -c release -Xswiftc -warnings-as-errors`
- Developer ID signing is configured locally with timestamped app and DMG signing.
- The latest local signed-only DMG validates structurally and by code signature, but Gatekeeper correctly rejects it until notarization is submitted and stapled.
- Support-bundle redaction has automated coverage for local paths, network paths, device identifiers, MIDI/device names, active profile details, and cue maps.
- App icon option C is active in the app bundle and regenerated across the `.icns` sizes.

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
- Remaining visual risk: the app still has a dense glass/material system. It is acceptable for a low-light show utility, but the next visual QA pass should compare actual screenshots in Light, Dark, Show Dark, small window, and external-display sizes.

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

- Notarization has not been submitted or stapled after the user requested no online release action.
- Manual QA with the real audio interface, Ableton/AbleSet, Luminescence, Show Off, Lightkey or final lighting target, and a real show playlist is still required.
- A clean-machine install from the notarized DMG has not been performed.
- Current private GitHub state prevents a code-scanning alerts API proof unless code scanning is enabled for the private repo or the repo is made public later.
- The app should be screenshot-reviewed in all appearance modes after the next signed build to catch layout crowding and text overflow.

## Release Decision

Not approved for public release yet. The code/build gate is green locally, the connector path is now real and covered by tests, and the signed-only artifact is structurally valid. The shareable Gatekeeper-clean artifact still requires explicit approval to submit notarization, staple the result, and run final real-rig QA.
