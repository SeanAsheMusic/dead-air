# Dead Air Release QA Results — 4.0.1 Build 5 Candidate

Version: 4.0.1
Build: 5
Git SHA: `c90fae66d34035d6ed2ba69f4613a02a4f546f46` (`main`, pushed)
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

## Hosted CI / CodeQL (SHA `c90fae6`)

| Check | Result | Evidence |
| --- | --- | --- |
| GitHub CI (push) | Pass | Run `27329701175`, conclusion `success`. |
| GitHub CodeQL (push) | Pass | Run `27329701169`, conclusion `success`. |
| Open code-scanning alerts | None | Empty alert list before push; no new alerts. |

## Repository Governance (enabled this pass)

- Branch protection on `main`: required status checks `Swift Checks` and
  `Analyze Swift`, strict up-to-date mode, force pushes and deletions blocked,
  admin enforcement off (solo-maintainer direct pushes remain possible).
- Secret scanning: enabled. Push protection: enabled.
- Dependabot vulnerability alerts: enabled (version-update PRs already active).

## Release Artifact — IN PROGRESS / BLOCKED

The Developer ID build of 4.0.1-5 was signed (hardened runtime, secure timestamp,
verified `codesign --verify --deep --strict`) and submitted to Apple notary
service as `Dead-Air-4.0.1-5-app.zip`, submission ID
`c2999fc4-d1bc-4ced-a9bf-f817c2826ad2` (2026-06-11T07:03Z). Apple's service was
unstable during this pass (one timestamp-server failure, one connect timeout
mid-wait). The submission was last seen `In Progress`; no ticket had been issued
roughly 45 minutes later.

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
| Screenshot/layout review (appearance modes, Simple/Advanced, compact/wide) | Not run | Required before public release. |

## Release Verdict

Result: **Not releasable yet — artifact incomplete.**

The 4.0.1-5 source is release-quality by every automated measure (local gates,
sanitizers, CI, CodeQL, redaction checks), but there is no finished notarized DMG
for it, and the previous 4.0.0-4 DMG is superseded by the redaction fix.

Open blockers, in order:

1. Restore notary keychain access; finish notarize/staple of the 4.0.1-5 app and
   DMG; record artifact evidence (SHA-256, submission IDs, stapler, Gatekeeper).
2. Clean-machine install QA from the new DMG.
3. Real-rig audio QA (interface, fades, panic mute, routing, unplug/replug, full setlist).
4. Real MIDI and connector QA (Ableton/AbleSet or IAC; Lightkey/Luminescence/Show Off/custom OSC as used).
5. Support-bundle export and manual privacy inspection against the new redaction.
6. Screenshot/layout review across appearance modes and window sizes.
