# Dead Air Accessibility And Automation Contract

Date: 2026-06-04

Dead Air is a live-show utility, so accessibility and automation must protect against accidental audio, not just expose controls.

## Operator Accessibility

- The app follows macOS Reduce Transparency through SwiftUI environment values.
- Settings > Accessibility includes larger transport controls, reduced glass effects, and higher status contrast.
- Critical transport buttons expose explicit accessibility labels and hints.
- Status pills expose accessibility values, so VoiceOver can read `State: Ready Muted`, `MIDI: Online`, and similar status without relying on color.
- Readiness rows expose `Ready` or `Needs attention` values instead of relying only on green/orange icon color.
- Setup Assistant uses a compact step menu at narrow widths and avoids nested scroll views.

## Agent Automation

Stable accessibility identifiers are intentionally part of the release contract. A local helper such as Hermes, AppleScript/UI scripting, or Computer Use should target identifiers first, then visible labels as a fallback.

Critical identifiers:

- `deadAir.root`
- `deadAir.mainSurface`
- `deadAir.toolbar.modePicker`
- `deadAir.toolbar.actionsMenu`
- `deadAir.toolbar.showModeToggle`
- `deadAir.status.state`
- `deadAir.status.midi`
- `deadAir.status.osc`
- `deadAir.status.connectors`
- `deadAir.status.heartbeat`
- `deadAir.transport.fadeIn`
- `deadAir.transport.fadeOut`
- `deadAir.transport.nextBed`
- `deadAir.transport.panicMute`
- `deadAir.setup.sheet`
- `deadAir.setup.stepPicker`
- `deadAir.playlist.search`
- `deadAir.playlist.filter`
- `deadAir.playlist.list`
- `deadAir.readiness.panel`
- `deadAir.readiness.copyCueMap`
- `deadAir.readiness.testConnector`
- `deadAir.readiness.exportSupport`
- `deadAir.settings.accessibility`
- `deadAir.menuBar.controls`

## Automation Safety Rules

- Never send Fade In from automation unless Show Mode is armed and the current bed/readiness state has been checked.
- Prefer Panic Mute over Fade Out when the source of audio is unknown.
- Treat Show Mode Disarmed as the default safe launch state.
- Do not infer release readiness from color; read the readiness panel values.
- Do not parse private file paths or device IDs from support bundles; support bundles are designed to be redacted.
