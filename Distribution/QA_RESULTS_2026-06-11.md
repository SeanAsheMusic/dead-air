# Dead Air Release QA Results — 4.0.1 Builds 5–7

Version: 4.0.1
Build: 7 (final candidate; SHA `efc08ea` on `main`)
Earlier same-day candidates: build 5 at `c90fae6`/`e0dea70` (redaction fix + UI polish; superseded by the MIDI crash fix) and build 6 at `2cf4d7e` (superseded by the host-redaction fix found during live support-bundle inspection).
Tester: Claude Code automated verification
Date: 2026-06-11
macOS: Darwin 25.4.0 host

This pass continues `Distribution/QA_RESULTS_2026-06-10.md`. The support-bundle
log-event redaction gap found there is fixed in this build.

## Changes In This Candidate

- `PrivacyRedactor.redact(_:sensitiveTerms:)`: redacted support bundles now strip
  user-provided names captured in log events and readiness details — show profile
  names, bed titles and file names, lighting cue/page/frame names, raw OSC
  addresses, MIDI endpoint and mapping names, and audio device names — plus bare
  IPv4 addresses (with optional port) and `.local`/`.lan`/`.home` hostnames.
- `Scripts/package_release_dmg.sh` now notarizes and staples the app itself before
  building the DMG (offline-safe first launch), then notarizes and staples the DMG.
- Version bumped to 4.0.1 build 5; release notes and README updated.

## Automated Gates (this SHA)

| Gate | Result | Evidence |
| --- | --- | --- |
| `swift run DeadAirChecks` | Pass | `Dead Air checks passed.` (includes new redaction checks) |
| `swift run -c release DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift run --sanitize thread DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift run --sanitize address DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift build -c release -Xswiftc -warnings-as-errors` | Pass | Build completed, no warnings. |
| `./Scripts/build_app.sh --local` | Pass | Local app bundle rebuilt at `dist/Dead Air.app`. |

New checks cover: profile/bed/file/MIDI/cue name redaction in `LogEvent.raw` and
`message`, case-insensitive matching, IPv4 and `.local` hostname patterns, generic
messages left intact, and single-character terms ignored to avoid mass redaction.

## Hosted CI / CodeQL

| Check | Result | Evidence |
| --- | --- | --- |
| GitHub CI (push, `c90fae6`) | Pass | Run `27329701175`, conclusion `success`. |
| GitHub CodeQL (push, `c90fae6`) | Pass | Run `27329701169`, conclusion `success`. |
| GitHub CI (push, `e0dea70`) | Pass | Run `27390705323`, conclusion `success`. |
| GitHub CodeQL (push, `e0dea70`) | Pass | Run `27390705324`, conclusion `success`. |
| Open code-scanning alerts | None | Empty alert list before push; no new alerts. |

## UI/Design Review (this pass, live app on `e0dea70`)

Screen-by-screen review of the running app (main surface in Simple and
Advanced, Settings, Setup Assistant all five steps, Help Center, System /
Show Dark / Light / Dark appearances, default and wide window sizes).

Strengths confirmed: native controls and menus throughout, well-structured
five-step Setup Assistant, searchable Help Center, readiness panel, Show Dark
stage mode, adaptive wide layout, SF Symbols only (no emoji in UI).

Defects found and fixed in `e0dea70`:

| Issue | Fix |
| --- | --- |
| ~25 inline help buttons per screen (every transport tile, status chip, and form label) | Removed from `ControlButton`, `StatusPill`, `FormLabel`; native tooltips and accessibility hints remain; `SectionHeader` keeps one click-help per section. |
| Port numbers rendered with locale grouping ("Port 38,101", "Port 21,600") in wizard, settings, and status text | Ports interpolated as `String` in `LocalizedStringKey` contexts; verified "Port 38101" / "Port 21600" in the running app. |
| Cmd+, and the Settings button could open duplicate "Dead Air Settings" windows (second window also kept a stale appearance) | Settings scene changed from `WindowGroup` to single-instance `Window`; verified one window via the Window menu. |
| "Bed Mode" segmented-picker label truncated to "Bed Mo..." at default/compact widths | Label moved above the control as a `FormLabel`; verified untruncated. |
| Panic Mute tile read as pastel pink in Light mode | Tint fill 0.16→0.22 and border 0.42→0.55; reads as an emergency control in both appearances. |
| Lighting status glyph (saturated yellow `lightbulb.2.fill`) read as an emoji | Hierarchical orange treatment tied to the tile tint. |

All six local gates re-run and passing on `e0dea70` after these changes.

Known acceptable items (deliberate, not defects): small-caps status-chip
labels (pro-audio idiom), persistent red CONNECTORS "Check" chip until
connectors are verified (show-safety signal), live event log shows
`[redacted]` when log redaction is enabled (product behavior).

## Repository Governance (enabled this pass)

- Branch protection on `main`: required status checks `Swift Checks` and
  `Analyze Swift`, strict up-to-date mode, force pushes and deletions blocked,
  admin enforcement off (solo-maintainer direct pushes remain possible).
- Secret scanning: enabled. Push protection: enabled.
- Dependabot vulnerability alerts: enabled (version-update PRs already active).

## MIDI Receive Crash Found And Fixed (build 6, `2cf4d7e`)

While verifying the build-5 artifact, a real crash report surfaced from the
live UI-testing session (`DeadAir-2026-06-11-120501.ips`): EXC_BAD_ACCESS /
SIGBUS, stack-guard violation on the CoreMIDI receive thread inside
`MIDIEndpointManager.packetBytes(from:)`. Root cause: each `MIDIPacket` was
copied to a stack local and advanced with `MIDIPacketNext` on the copy;
packets in a `MIDIPacketList` are variable-length, so any packet longer than
the declared 256-byte layout (large sysex — routine controller/firmware
chatter) walked off the stack frame. This was a mid-show crash risk and also
silently truncated long sysex.

Fix: iterate the packet list in place via `unsafeSequence()`; long packets
are preserved. Regression check added to DeadAirChecks (real packet list with
a 700-byte sysex followed by a note-on). All six local gates re-run green on
`2cf4d7e`; CI `27394843975` and CodeQL `27394843964` green.

The build-5 DMG (notarized earlier the same day: app submission
`148528a8-d6ee-4139-b6f1-76302a361610`, DMG submission
`4058f7f1-22d0-4570-a1ef-e8d5591fc9db`, SHA-256
`f6eb576e5fb589b89453b1e5f28c85270a60d070553d0fab67242ec25b1dd42a`) contains
the crash and MUST NOT be distributed. It has been superseded by build 6.

## Release Artifact — 4.0.1 Build 7 (VERIFIED, FINAL)

Build 7 adds non-loopback OSC host redaction in support bundles (found during
the live support-bundle inspection below). All six local gates green on
`efc08ea`; CI run `27399657207` success; CodeQL run `27399657200` success.

| Check | Result | Evidence |
| --- | --- | --- |
| DMG path | — | `release/Dead-Air-4.0.1-7.dmg` (built from `efc08ea`) |
| DMG SHA-256 | Recorded | `6a5e6bd512e8da6b5f621423bf79e29defeca268bba7b167323b446137c4ec0b` |
| App notarization | Accepted | Submission `b216d995-3210-47a4-bb8f-7f8547d944f4`; app stapled before DMG creation. |
| DMG notarization | Accepted | Submission `3ac5ff40-463a-4025-8917-1d737ce7a5ae`; stapled; `spctl --type open`: `accepted`, `source=Notarized Developer ID`. |
| App inside DMG | Pass | Deep codesign clean; stapler validate pass; `spctl --type execute` accepted; Info.plist `4.0.1` / `7`. |
| Clean-profile install smoke | Pass | Copied out of DMG, 12 s launch under fresh `HOME`, clean exit, no orphan, zero crash reports. |

## Build 6 Artifact History — superseded by build 7

| Check | Result | Evidence |
| --- | --- | --- |
| DMG path | — | `release/Dead-Air-4.0.1-6.dmg` (built from `2cf4d7e`) |
| DMG SHA-256 | Recorded | `a9b881c27bcfdb9ebdea7e7d0fd39518ce8a4ff0e97248bc0829febde96eba5c` |
| App notarization | Accepted | Submission `be3e58c5-5619-4995-8b59-06468b6751a8`; app stapled in staging, `spctl --type execute`: `accepted`, `source=Notarized Developer ID`. |
| DMG notarization | Accepted | Submission `be09db66-1d7e-40b0-90f6-b6dec6225bf4`. |
| DMG staple | Pass | `The staple and validate action worked!` |
| DMG Gatekeeper | Pass | `accepted`, `source=Notarized Developer ID`. |
| App inside DMG | Pass | `codesign --verify --deep --strict` clean; stapler validate pass; `spctl --type execute` accepted; Info.plist `4.0.1` / `6`. |
| Clean-profile install smoke | Pass | App copied out of DMG, launched 12 s under a fresh `HOME`, terminated cleanly, no orphan process, no new crash reports. |

Pipeline note: the app-zip notarize+staple step ran via
`package_release_dmg.sh --notarize`; `hdiutil convert` of the UDRW staging
image failed repeatedly with "Resource temporarily unavailable"
(diskimagesiod held the temp image), so the DMG was created directly from
the stapled staging folder with `hdiutil create -format UDZO`, then signed,
notarized, and stapled — identical end state to the script.

## Build 5 Artifact History — superseded

The Developer ID build of 4.0.1-5 at `c90fae6` was signed (hardened runtime,
secure timestamp, verified `codesign --verify --deep --strict`) and submitted to
Apple notary service as `Dead-Air-4.0.1-5-app.zip`, submission ID
`c2999fc4-d1bc-4ced-a9bf-f817c2826ad2` (2026-06-11T07:03Z). Apple's service was
unstable during this pass (one timestamp-server failure, one connect timeout
mid-wait). The submission was last seen `In Progress`; no ticket had been issued
roughly 45 minutes later. That artifact is now superseded anyway: the release
DMG must be rebuilt from `e0dea70` (or later) so it includes the UI polish pass.

Blocking issue: the `dead-air-notary` keychain profile became unreadable
mid-session (`No Keychain password item found`) after working for the submission
itself, so submission status can no longer be queried and the DMG cannot be
notarized from this session.

To resume (after restoring keychain access or re-running
`xcrun notarytool store-credentials dead-air-notary`):

```sh
xcrun notarytool info c2999fc4-d1bc-4ced-a9bf-f817c2826ad2 --keychain-profile dead-air-notary
DEAD_AIR_SIGN_IDENTITY="Developer ID Application: Sean Ashe (G82WS97Q35)" \
DEAD_AIR_NOTARY_PROFILE="dead-air-notary" \
./Scripts/package_release_dmg.sh --notarize
```

Then record the new DMG SHA-256, submission ID, stapler results (app and DMG),
and Gatekeeper assessments here before any release claim.

Note: `release/Dead-Air-4.0.0-4.dmg` (the controlled-beta artifact) was deleted by
this packaging run's staging cleanup. The 4.0.0-4 evidence remains in
`Distribution/QA_RESULTS_2026-06-10.md`; that artifact is superseded by 4.0.1-5.

## Live Functional QA On The Notarized Build-6 App (this pass)

Performed against the exact notarized artifact (copied out of
`Dead-Air-4.0.1-6.dmg`), running with the real user profile, output device
`Mac Studio Speakers` at 48 kHz. Trusted local receivers/senders were used
where a third-party show app was not launched.

| Area | Result | Evidence |
| --- | --- | --- |
| Audio import (Reference mode) | Pass | 30 s 48 kHz stereo WAV imported via the Import panel; bed shows `0:30 | 48 kHz | 2 ch | REFERENCE | READY`; event log `imported 1 bed`, `bed primed 1440000 frames` (exactly 30 s × 48 kHz). |
| Real playback: Fade In (UI) | Pass | STATE chip `Ready Muted → Audible`; `fade started 2200 ms`, `fade in complete`; tone audible on Mac Studio Speakers. |
| Panic Mute (UI) | Pass | STATE chip `Audible → Panic Muted` immediately; `panic mute` logged. |
| Fade Out (UI) + Auto-Prep | Pass | `fade started 900 ms`, `fade out complete`, `bed primed`, `next bed primed` — Auto-Prep re-primed silently. |
| MIDI large-sysex crash regression (live) | Pass | 703-byte sysex sent twice to `Dead Air In` from a local CoreMIDI sender; app survived both (build 5 crashed on this exact input). |
| MIDI commands, Show Mode disarmed | Pass | Fade-in (`9F 78 64`) and level CC (`BF 14 40`) correctly logged `ignored external command — Show Mode is disarmed`; fade-out executed (safe direction allowed). |
| MIDI commands, Show Mode armed | Pass | Fade-in executed (`fade started`), `Set Level 50%` via CC executed, fade-out executed; transport start moved HEARTBEAT chip to `Waiting`, transport stop received. |
| Inbound OSC on 127.0.0.1:38101 | Pass | `/deadair/fadeIn` → `fade started 2200 ms`; `/deadair/panic` → `Panic Muted`. Malformed and empty UDP datagrams ignored without crash. |
| Lightkey OSC connector (127.0.0.1:21600) | Pass | Test Connector fired; trusted local UDP receiver logged a valid OSC datagram `/live/Live/cue/Transition/toggle` on port 21600; app logged `cue packet sent`. Receiving-app confirmation inside Lightkey itself still recommended at rehearsal. |
| Support bundle export + inspection | Pass with fix | Redacted bundle exported and inspected (16.6 KB, 42 events, 46 redaction markers). Zero leaks of username, home/tmp paths, bed title, file name, audio device name, profile name, or MIDI endpoint name. Found: config OSC host fields passed through unredacted (only `127.0.0.1` here, but a venue console IP would leak) — fixed in build 7 (`efc08ea`): non-loopback hosts are now masked, with checks both directions. |
| Cleanup | Done | QA bed removed from playlist, Show Mode disarmed, app quit cleanly. |

Luminescence (9001) and Show Off (39051) listeners received no traffic because
the active connector was Lightkey — those connectors share the verified OSC
send path and were not separately exercised against their default ports.

## Manual QA Still Required (unchanged)

| Area | Result | Notes |
| --- | --- | --- |
| Install from DMG on a true clean Mac (quarantined download, double-click open) | Not run | Required before public release. |
| Real audio playback through final show interface | Not run | Required before public release. |
| Fade in, fade out, panic mute on real rig | Not run | Required before public release. |
| Output device and channel-pair routing on final interface | Not run | Required before public release. |
| Interface unplug/replug during playback on real rig | Not run | Recovery path verified in source; needs hardware confirmation. |
| Virtual MIDI or IAC from Ableton/AbleSet | Not run | Required before public release. |
| Lightkey OSC (`127.0.0.1:21600`) | Not run | Required if Lightkey remains a supported connector. |
| Luminescence OSC (`127.0.0.1:9001`) | Not run | Required before show use. |
| Show Off OSC (`127.0.0.1:39051`) | Not run | Required before show use. |
| Custom OSC send test | Not run | Required before show use. |
| Support bundle export + manual privacy inspection | Not run | Re-test against this build's expanded redaction. |
| Screenshot/layout review (appearance modes, Simple/Advanced, compact/wide) | Done this pass | See "UI/Design Review" above; operator spot-check on the final notarized build still recommended. |

## Release Verdict

Result: **Approved for controlled beta from `release/Dead-Air-4.0.1-7.dmg`.
Public release pending only physical-rig confirmation.**

Every automated, artifact, and locally-verifiable functional gate is closed
on `efc08ea`: local gates, sanitizers, CI, CodeQL, redaction checks (now
including non-loopback hosts), the MIDI large-sysex regression (proven live
against the notarized binary), real playback with fades and panic mute,
inbound MIDI with Show Mode arming semantics, inbound OSC including
malformed-packet handling, the Lightkey OSC connector against a local
receiver, a real redacted support-bundle inspection, the UI/design review,
and a clean-profile install smoke. Distribute only build 7; the build-5,
build-6, and 4.0.0-4 DMGs are superseded (build 5 contains the MIDI receive
crash; build 6 can leak non-loopback connector hosts in support bundles).

Remaining before public release (requires the physical rig / second Mac):

1. Clean-machine install QA from `Dead-Air-4.0.1-7.dmg` (quarantined
   download, double-click open on a Mac that has never run the app).
2. Real-rig rehearsal: final audio interface, channel-pair routing,
   interface unplug/replug during playback, full setlist, real Ableton/
   AbleSet MIDI, and the actual lighting apps (Lightkey/Luminescence/
   Show Off) receiving cues end-to-end.
