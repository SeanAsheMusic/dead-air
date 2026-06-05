# Dead Air Release QA Results

Version: 4.0.0
Build: 4
Git SHA: release checkout containing this QA record; verify with `git rev-parse HEAD`.
DMG: `release/Dead-Air-4.0.0-4.dmg`
Tester: Codex local verification
Date: 2026-06-04
macOS: 26.4.1 (25E253)
Audio interface: Mac Studio Speakers
DAW/DJ/show-control tools: Not connected in this pass
Lighting tool: Not connected in this pass

## Automated Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| `swift run DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift build -c release -Xswiftc -warnings-as-errors` | Pass | Release build completed with warnings as errors. |
| `./Scripts/build_app.sh --local` | Pass | Local app bundle rebuilt at `dist/Dead Air.app`. |
| Developer ID app signature | Pass | `dist-developer-id/Dead Air.app: valid on disk`. |
| Notarytool submission | Pass | Submission `632fe7dc-ed69-4708-bafe-0a77332dee70`, status `Accepted`. |
| Stapler | Pass | `The validate action worked!` |
| Gatekeeper assessment | Pass | `accepted`, `source=Notarized Developer ID`. |
| DMG checksum | Pass | SHA-256 `03f0050ff4598797b2da37d2b273f68382d6e0072a93682c096c87a9a2b8f85f`. |
| GitHub CI | Not checked | Needs push of this candidate. |
| GitHub CodeQL | Not checked | Needs push of this candidate. |

## Local UI And Safety QA

| Area | Result | Notes |
| --- | --- | --- |
| Main window resize | Pass | Verified compact, mid-size, and wide layouts at roughly 380, 520, 920, and 1200 px widths. |
| Settings resize | Pass | Verified custom Settings window at roughly 420 x 392 with compact section picker and vertical scrolling. |
| Setup resize | Pass | Compact Setup Assistant uses a vertical layout and does not force the old wide card grid. |
| Accessibility anchors | Pass | Root, main surface, readiness panel, settings window, and critical controls expose stable `deadAir.*` automation IDs. |
| Unexpected audio start guard | Pass | Heartbeat defaults off, heartbeat loss defaults to flag-only, legacy auto-fade config does not imply consent, and launch resets Show Mode disarmed. |
| Running app stopped after QA | Pass | No `DeadAir` process remained after verification. |

## Manual QA Still Required

| Area | Result | Notes |
| --- | --- | --- |
| Install from DMG on a clean Mac without right-click Open | Not run | Required before public release. |
| Real audio playback through final show interface | Not run | Required before public release. |
| Fade in, fade out, panic mute on real rig | Not run | Required before public release. |
| Output device and channel-pair routing on final interface | Not run | Required before public release. |
| Virtual MIDI or IAC from Ableton/AbleSet | Not run | Required before public release. |
| Lightkey OSC | Not run | Required if Lightkey remains a supported connector. |
| Luminescence OSC | Not run | Required before using the Luminescence connector in a show. |
| Show Off OSC | Not run | Required before using the Show Off connector in a show. |
| Support bundle visual/privacy inspection from exported file | Not run | Automated redaction coverage passes; exported-file inspection still required. |

## Release Verdict

Result: Approved for controlled beta sharing from the notarized DMG. Not approved for public release.

Open blockers:

- Push this candidate and recheck GitHub CI and CodeQL on the final SHA.
- Run clean-machine install QA from the notarized DMG.
- Run real-rig audio and connector QA with the final playback interface and show-control apps.
