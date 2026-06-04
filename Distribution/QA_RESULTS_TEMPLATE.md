# Dead Air Release QA Results

Version:
Build:
Git SHA:
DMG:
Tester:
Date:
macOS:
Audio interface:
DAW/DJ/show-control tools:
Lighting tool:

## Automated Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| `swift run DeadAirChecks` | Not run | |
| `swift build -c release -Xswiftc -warnings-as-errors` | Not run | |
| GitHub CI | Not checked | |
| GitHub CodeQL | Not checked | |
| Developer ID app signature | Not run | |
| Notarytool submission | Not run | |
| Stapler | Not run | |
| Gatekeeper assessment | Not run | |

## Manual QA

| Area | Result | Notes |
| --- | --- | --- |
| Install from DMG without right-click Open | Not run | |
| First-run wizard | Not run | |
| Simple and Advanced modes | Not run | |
| Appearance modes | Not run | |
| Menu bar close/reopen | Not run | |
| Drag/drop import | Not run | |
| Folder import | Not run | |
| Copy import mode | Not run | |
| Reference import mode | Not run | |
| Stale bookmark refresh and Relink | Not run | |
| Save/load/default playlist | Not run | |
| Real audio playback | Not run | |
| Fade in, fade out, panic mute | Not run | |
| Crossfade | Not run | |
| 44.1/48/88.2/96 kHz routing | Not run | |
| Output device and channel-pair routing | Not run | |
| Virtual MIDI or IAC input | Not run | |
| Inbound OSC on `127.0.0.1:38101` | Not run | |
| Lightkey OSC on `127.0.0.1:21600` | Not run | |
| Luminescence OSC on `127.0.0.1:9001` | Not run | |
| Show Off OSC on `127.0.0.1:39051` | Not run | |
| Custom OSC to local receiver | Not run | |
| Lighting MIDI cue | Not run | |
| Lighting app offline does not block audio | Not run | |
| Support bundle redaction | Not run | |
| Sandbox launch | Not run | |

## Privacy Inspection

| Check | Result | Notes |
| --- | --- | --- |
| `redactionStatus` is `enabled` | Not run | |
| `/Users` paths absent | Not run | |
| `/Volumes` paths absent | Not run | |
| `~/` paths absent | Not run | |
| Network URLs absent | Not run | |
| Device names and UIDs absent | Not run | |
| MIDI source/destination names absent | Not run | |
| Lighting cue map absent | Not run | |
| Active profile absent | Not run | |
| UUID-like identifiers absent | Not run | |

## Release Verdict

Result: Not approved

Open blockers:

- 

Release notes:

- 
