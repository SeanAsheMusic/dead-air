# Dead Air Release QA Results

Version: 4.0.0
Build: 4
Git SHA: `cbf743fe52c8c0bf6a25eafe1e045880cc71f5a4` (local `main` == `origin/main`)
DMG: `release/Dead-Air-4.0.0-4.dmg`
Tester: Claude Code automated verification
Date: 2026-06-10
macOS: Darwin 25.4.0 host
Audio interface: Not connected in this pass
DAW/DJ/show-control tools: Not connected in this pass
Lighting tool: Not connected in this pass

Production-code state: `git diff HEAD -- Sources/ Tests/ Bundle/ Entitlements/ Scripts/ Package.swift` is empty.
Only Markdown working notes differ from the release SHA, so the existing notarization
evidence for `Dead-Air-4.0.0-4.dmg` remains valid.

## Automated Gates (clean rebuild — `.build/` wiped first)

Note: the checkout was moved from the old Codex working path to
`/Users/ashemacstudio/Documents/Dead Air`, which left a stale SwiftPM module cache.
`rm -rf .build` resolved it; all gates were then run from scratch.

| Gate | Result | Evidence |
| --- | --- | --- |
| `swift run DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift run -c release DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift run --sanitize thread DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift run --sanitize address DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift build -c release -Xswiftc -warnings-as-errors` | Pass | Build completed, no warnings. |
| `./Scripts/build_app.sh --local` | Pass | Local app bundle rebuilt at `dist/Dead Air.app`. |

## Hosted CI / CodeQL (target SHA `cbf743f`)

| Check | Result | Evidence |
| --- | --- | --- |
| GitHub CI (push) | Pass | Run `26988399072`, conclusion `success`. |
| GitHub CodeQL (push) | Pass | Run `26988399092`, conclusion `success`. |
| GitHub CodeQL (scheduled 2026-06-08) | Pass | Run `27140347519`, conclusion `success`. |
| Open code-scanning alerts | None | `gh api .../code-scanning/alerts` returned empty. |
| Dependabot PR #1 (checkout v6) | Closed | Workflows already use checkout v6 on `main`. |

## Release Artifact Verification

| Check | Result | Evidence |
| --- | --- | --- |
| DMG SHA-256 | Pass | `c518b92a92b7ca5a231eb4d4e1038441425fb56c836aa44529d2bf8ab95c1c67` (matches recorded value). |
| DMG Gatekeeper (`spctl --type open`) | Pass | `accepted`, `source=Notarized Developer ID`. |
| DMG staple (`stapler validate`) | Pass | `The validate action worked!` |
| App signature inside DMG (`codesign --verify --deep --strict`) | Pass | `valid on disk`, `satisfies its Designated Requirement`. |
| App Gatekeeper (`spctl --type execute`) | Pass | `accepted`, `source=Notarized Developer ID`. |
| App staple inside DMG | Note | App itself carries no stapled ticket; the DMG does. Acceptable, but staple the app before DMG creation in the next release cycle for fully offline first launches. |
| App Info.plist | Pass | `4.0.0` / `4`, `com.undeniablespectacle.deadair`, `LSMinimumSystemVersion 14.0` — all match docs. |

## Clean-Profile Install Smoke (from the notarized DMG)

Performed on this Mac (not a separate clean machine): mounted the DMG read-only,
copied `Dead Air.app` out, re-verified the copied signature, then launched the binary
with a fresh temporary `HOME`.

| Check | Result | Evidence |
| --- | --- | --- |
| Copied-app signature | Pass | `codesign --verify --deep --strict` clean. |
| 12-second launch smoke under fresh HOME | Pass | Process alive at 12 s, terminated cleanly. |
| Orphan process check | Pass | No `DeadAir` process remained. |
| Crash reports | Pass | No `DeadAir` entries in DiagnosticReports (host or temp profile). |
| stdout/stderr | Pass | Empty launch log. |

This does not replace true clean-machine Gatekeeper QA (quarantine-flagged download,
double-click open on a Mac that has never run the app). That remains a manual blocker.

## Code Audit Findings (this pass)

### Show-safety paths — clean

Audited `AudioEngineController`, `MIDIEndpointManager`, `MIDIOutputManager`,
`OSCServer`, `OSCParser`, `MIDIParser`, `LightingCueSupport`, `Persistence`:

- No force unwraps, `try!`, `as!`, `fatalError`, or unchecked indexing in production paths.
- OSC and MIDI parsers bounds-check all input; malformed UDP/MIDI packets cannot crash the app. Receive buffer is fixed at 4096 bytes.
- `fadeIn()` refuses to run without a primed buffer; `panicMute()` stops the player, silences both mixers, and cancels fade timers.
- Device unplug/replug: `AVAudioEngineConfigurationChange` is wired (`DeadAirApp.swift:566`) to a debounced `recoverAudioEngine` that rebuilds the graph and deliberately recovers **muted** with an operator warning — no surprise audio after route changes.
- Persistence uses atomic writes, timestamped backups, and corrupt-file quarantine.
- Threading uses dedicated dispatch queues and short-lived locks; sanitizer gates pass.

### Support-bundle redaction — gap found (new)

`PrivacyRedactor.redact()` only strips path-like strings (`/Users/`, `/Volumes/`,
`~/`, `smb|afp|nfs://`) and UUIDs. Config-field redaction is solid, but `LogEvent.raw`
values that are plain names survive into a "redacted" support bundle:

- Show profile names (`DeadAirApp.swift:707, 724, 734, 762` — `raw: profile.name`).
- Bed/track titles (e.g. `DeadAirApp.swift:846, 1626, 1659, 1665, 1690`).
- MIDI endpoint names (`DeadAirApp.swift:989` — `raw: descriptor?.name`; `MIDIEndpointManager.swift:89`).
- Lighting cue names (`DeadAirApp.swift:1721`).
- Bare hostnames/IPs (e.g. `venue-nas.local`, `192.168.1.x`) match no pattern.

This means the claim in `RELEASE_READINESS_AUDIT.md` that redaction covers
"MIDI/device names, active profile details, and cue maps" is only true for config
fields, not for the event log. Mitigation today: the existing manual support-bundle
review blocker. Recommendation: redact these log sites (or placeholder user-provided
names in events) before public release, then rebuild/re-notarize as build 5.

### Repo hygiene / release infra — clean

- No tracked secrets; Team ID in docs is public information; `.gitignore` covers all artifacts.
- Version `4.0.0`/`4` is sourced from `Bundle/Info.plist` and consistent across scripts and docs; macOS 14+ consistent everywhere.
- Entitlements are sandbox-first with no dangerous exceptions; hardened runtime applied at codesign time for Developer ID builds.
- Signing/notarization scripts are fully env-var driven.
- Known, documented gap: CodeQL workflow analyzes `DeadAirCore` + `DeadAirChecks` only, not the `DeadAirApp` target (SwiftUI type-check cost; revisit after the planned file split).

### GitHub governance (recommended, not blocking)

- `main` has no branch protection.
- Secret scanning and push protection are disabled.
- Dependabot vulnerability alerts are disabled (version-update PRs are enabled).

## Manual QA Still Required

| Area | Result | Notes |
| --- | --- | --- |
| Install from DMG on a true clean Mac (quarantined download, double-click open) | Not run | Required before public release. |
| Real audio playback through final show interface | Not run | Required before public release. |
| Fade in, fade out, panic mute on real rig | Not run | Required before public release. |
| Output device and channel-pair routing on final interface | Not run | Required before public release. |
| Interface unplug/replug during playback on real rig | Not run | Recovery code path verified in source; needs hardware confirmation. |
| Virtual MIDI or IAC from Ableton/AbleSet | Not run | Required before public release. |
| Lightkey OSC (`127.0.0.1:21600`) | Not run | Required if Lightkey remains a supported connector. |
| Luminescence OSC (`127.0.0.1:9001`) | Not run | Required before show use. |
| Show Off OSC (`127.0.0.1:39051`) | Not run | Required before show use. |
| Custom OSC send test | Not run | Required before show use. |
| Support bundle export + manual privacy inspection | Not run | Now higher priority given the log-event redaction gap above. |
| Screenshot/layout review (appearance modes, Simple/Advanced, compact/wide) | Not run | Required before public release. |

## Release Verdict

Result: **Approved for controlled beta sharing** from the existing notarized DMG.
**Not approved for public release.**

Open blockers, in order:

1. Decide on the support-bundle log-event redaction gap: fix and cut build 5
   (rebuild, re-notarize, re-staple, new checksum, re-run gates) — recommended —
   or document it as a known limitation and rely on manual bundle review.
2. Clean-machine install QA from the notarized DMG.
3. Real-rig audio QA (interface, fades, panic mute, routing, unplug/replug, full setlist).
4. Real MIDI and connector QA (Ableton/AbleSet or IAC; Lightkey/Luminescence/Show Off/custom OSC as applicable).
5. Support-bundle export and manual privacy inspection.
6. Screenshot/layout review across appearance modes and window sizes.

Non-blocking recommendations: staple the app before DMG packaging next cycle; enable
branch protection, secret scanning, push protection, and Dependabot alerts on the repo.
