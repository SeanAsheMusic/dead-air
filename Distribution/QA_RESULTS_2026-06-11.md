# Dead Air Release QA Results — 4.0.1 Builds 5–6

Version: 4.0.1
Build: 6 (final candidate; SHA `2cf4d7e` on `main`)
Earlier same-day candidates: build 5 at `c90fae6` (redaction fix) and `e0dea70` (UI polish), both superseded by the MIDI crash fix below.
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

## Release Artifact — 4.0.1 Build 6 (VERIFIED)

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

Result: **Approved for controlled beta from `release/Dead-Air-4.0.1-6.dmg`.
Not yet approved for public release — remaining blockers are all operator/
hardware QA.**

Every automated and artifact gate is closed on `2cf4d7e`: local gates,
sanitizers, CI, CodeQL, redaction checks, the MIDI large-sysex regression,
notarized+stapled app and DMG, Gatekeeper acceptance, and a clean-profile
install smoke. The UI/design review is closed. Distribute only build 6;
the build-5 and 4.0.0-4 DMGs are superseded (build 5 contains the MIDI
receive crash).

Open blockers, in order:

1. Clean-machine install QA from `Dead-Air-4.0.1-6.dmg` (quarantined
   download, double-click open on a Mac that has never run the app).
2. Real-rig audio QA (interface, fades, panic mute, routing, unplug/replug,
   full setlist) — pay extra attention to MIDI-heavy rigs to confirm the
   build-6 crash fix under real controller traffic.
3. Real MIDI and connector QA (Ableton/AbleSet or IAC; Lightkey/Luminescence/
   Show Off/custom OSC as used).
4. Support-bundle export and manual privacy inspection against the new
   redaction.
