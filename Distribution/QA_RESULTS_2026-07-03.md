# Dead Air Release QA Results — 4.0.1 Build 8 (Setup Assistant Redesign)

Version: 4.0.1
Build: 8 (SHA `4488b4d` on `main`)
Tester: Claude Code automated + live UI verification
Date: 2026-07-03
macOS: Darwin 25.4.0 host

Build 8 is a from-scratch-quality redesign of the Setup Assistant (setup
wizard), driven by a five-lens design audit (macOS HIG, responsive robustness,
visual craft, information architecture, accessibility) and an independent
adversarial implementation review. No behavior or capability change — every
`model.*` call and binding preserved.

## What Changed (design)

- Opens in the guided sidebar (rail) layout by default; the rail was
  previously unreachable because the sheet always sized to its compact
  minimum. Adapts down to a compact progress-bar layout on narrow windows.
- One unified `WizardSelectableCard` replaces three hand-rolled card idioms —
  fixes preset-card borders that were invisible in Light mode; inherits
  Reduce Transparency / Increase Contrast; bakes in VoiceOver labels/traits.
- Connectors step: two overlapping selectors (menu picker + card grid)
  collapsed to a single grid (providers + "No Outbound Cues") with a
  conditional address card.
- Renamed "EZ Setup"→"Preset", "Files & Control"→"Control"; moved the
  import-mode card to Audio; Escape-to-cancel; unified `.title2` header;
  8/16/24 spacing; Dynamic-Type-gated card heights; capped grids; gated rail
  navigator with completed/current/upcoming a11y state.

## Automated Gates (SHA `4488b4d`)

| Gate | Result | Evidence |
| --- | --- | --- |
| `swift run DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift run -c release DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift run --sanitize thread DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift run --sanitize address DeadAirChecks` | Pass | `Dead Air checks passed.` |
| `swift build -c release -Xswiftc -warnings-as-errors` | Pass | No warnings. |
| `./Scripts/build_app.sh --local` | Pass | Bundle rebuilt. |
| GitHub CI | Pass | Run `28691720552`, `success`. |
| GitHub CodeQL | Pass | Run `28691720218`, `success`. |

## Live UI Verification (local build, real display)

Verified on-screen across the full flow:

| Check | Result |
| --- | --- |
| Regular sidebar layout is the default | Pass — rail + step navigator + Output/Inbound/Connector mini-status |
| All 5 steps navigate (Preset→Audio→Control→Connectors→Finish) | Pass — rail shows completion checkmarks; primary becomes "Save Setup" on the last step |
| Light-mode card borders | Pass — unselected cards have visible native borders; selected shows accent border + Recommended + checkmark (the audit's top finding, fixed) |
| Port labels | Pass — "Port 38101" / "Port 21600", no locale commas |
| Connectors single-selection grid | Pass — 5 providers + "No Outbound Cues", conditional address card |
| Audio step owns the import-mode card | Pass |
| Compact progress-bar layout renders on narrow width | Pass (observed) |
| Adversarial implementation review | Pass — no lost bindings, no regressions; two minor consistency items found and fixed |

Signed Developer ID app: `codesign --verify --deep --strict` valid on disk,
hardened runtime, secure timestamp (Jul 3 2026 19:28).

## Release Artifact — BLOCKED (Apple account agreement)

The notarized DMG could NOT be produced. The build succeeded and the app is
correctly Developer-ID signed with a secure timestamp, but Apple's notary
service rejects every request for team `G82WS97Q35`:

```
Error: HTTP status code: 403. A required agreement is missing or has expired.
This request requires an in-effect agreement that has not been signed or has
expired. Ensure your team has signed the necessary legal agreements and that
they are not expired.
```

This affects `notarytool history` and `submit` alike — the whole notary
service is blocked for this team until the account holder accepts the pending
Apple Developer Program License Agreement (Apple periodically pushes a new PLA
that must be re-accepted). Build 7 notarized fine on 2026-06-11, so the
agreement lapsed between then and now.

Consequence: the build-8 packaging run's staging cleanup deleted the previous
`release/Dead-Air-4.0.1-7.dmg`, and no build-8 DMG was produced. There is
currently no notarized DMG on disk. Both are recoverable by re-running the
pipeline once the agreement is signed.

### To resume (user action required — account holder only)

1. Sign in to https://developer.apple.com/account (or App Store Connect) as
   the Account Holder for team `G82WS97Q35`.
2. Accept the pending Program License Agreement / any expired agreement
   (usually a banner on the account landing page, or App Store Connect →
   Business → Agreements).
3. Then re-run:
   ```sh
   DEAD_AIR_SIGN_IDENTITY="Developer ID Application: Sean Ashe (G82WS97Q35)" \
   DEAD_AIR_NOTARY_PROFILE="dead-air-notary" \
   ./Scripts/package_release_dmg.sh --notarize
   ```
4. Record the new DMG SHA-256, app + DMG submission IDs, stapler results, and
   Gatekeeper assessment here, then run the clean-profile install smoke.

## Release Verdict

Result: **Code is release-quality (build 8); notarized artifact BLOCKED on the
Apple Developer Program License Agreement.**

Every automated, hosted, and locally-verifiable gate is green on `4488b4d`,
and the Setup Assistant redesign is verified on-screen. The only thing
standing between here and a shippable DMG is the Apple account agreement,
which only the account holder can accept. After that: re-run the pipeline,
then the remaining physical-rig / clean-machine QA carried over from
`Distribution/QA_RESULTS_2026-06-11.md`.
