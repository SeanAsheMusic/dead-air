# Dead Air Release-Level Audit Handoff

Date: 2026-06-04  
Repo: https://github.com/SeanAsheMusic/dead-air  
Product: Dead Air by Undeniable Spectacle  
Bundle ID: `com.undeniablespectacle.deadair`  
Current version/build: `4.0.0` / `4`

## Goal For The Next Chat

Bring Dead Air from public beta/source-ready to release-level by making GitHub CI and CodeQL green, completing the signed/notarized distribution path, hardening support-bundle privacy, adding real release QA coverage, and producing a verified beta/release artifact that can be shared without Gatekeeper workarounds.

Suggested first message for the next chat:

```text
We are working in /Users/ashemacstudio/Documents/Codex/2026-05-11/files-mentioned-by-the-user-dead. Continue from Distribution/RELEASE_LEVEL_AUDIT_HANDOFF.md. First verify GitHub CI/CodeQL after the latest workflow and FadeTimeSlider fixes, then work the P0/P1 release blockers in order until Dead Air is ready for signed beta/release distribution.
```

## Current State

- Public GitHub repo exists at `SeanAsheMusic/dead-air`.
- Local branch `main` tracks `origin/main`.
- App is native SwiftUI/AppKit with SwiftPM, targeting macOS 14+.
- No third-party Swift dependencies are declared in `Package.swift`.
- Source is about 8,921 Swift lines. The largest files are:
  - `Sources/DeadAirApp/DeadAirApp.swift`: 4,691 lines
  - `Sources/DeadAirCore/Models.swift`: 1,507 lines
  - `Sources/DeadAirCore/AudioEngineController.swift`: 437 lines
- Generated local artifacts are ignored: `.build/`, `dist/`, `dist-sandbox/`, `dmg-staging/`, `release/`, `*.dmg`, `*.pkg`, `*.zip`.
- No obvious committed secrets were found by a local regex scan for common token/private-key patterns.

## Audit Work Completed In This Pass

- Verified GitHub repo visibility and local remote state.
- Pulled GitHub Actions failure logs.
- Ran local checks.
- Scanned for production forced unwraps, `try!`, `as!`, TODO/FIXME markers, and common secret patterns.
- Reviewed the core release-critical paths:
  - audio engine and output routing
  - file import/reference/bookmark handling
  - persistence and corruption recovery
  - MIDI input/output
  - inbound/outbound OSC
  - diagnostics/support bundle export
  - signing/build scripts
  - entitlements
  - docs and release checklist
- Fixed a hosted build risk by splitting `FadeTimeSlider` into smaller SwiftUI expressions.
- Updated GitHub workflows from `actions/checkout@v4` to `actions/checkout@v6`.

## Verification Commands Run Locally

These passed after the `FadeTimeSlider` change:

```sh
swift run DeadAirChecks
swift build -c release -Xswiftc -warnings-as-errors
```

The clean local release build also passed before the patch:

```sh
swift package clean
swift build -c release -Xswiftc -warnings-as-errors
```

The hosted GitHub CI had failed before the patch at:

```text
Sources/DeadAirApp/DeadAirApp.swift:3667
error: the compiler is unable to type-check this expression in reasonable time
```

That failure was in `FadeTimeSlider.body`. The local patch breaks the body into `header`, `fadeSlider`, `secondsBinding`, and `secondsRange`.

## Release Readiness Verdict

Dead Air is a strong beta/prototype with unusually good show-safety intent, but it is not release-level yet.

Release-level blockers are mostly around hosted automation, signing/notarization, manual QA evidence, privacy hardening, and test coverage breadth rather than core feature absence.

## P0 Blockers

### P0.1 GitHub CI and CodeQL must be green

Evidence:

- GitHub CI and CodeQL failed on `main` before this audit patch due SwiftUI type-checking.
- Dependabot opened PR #1, `Bump actions/checkout from 4 to 6`, and it failed because the same release build failed.
- Workflows have now been updated to `actions/checkout@v6`; verify new hosted runs after pushing this handoff commit.

Next steps:

1. Push current local changes.
2. Wait for GitHub `CI` and `CodeQL`.
3. If CI still fails, inspect `gh run view --log-failed` and keep breaking large SwiftUI bodies into smaller subviews.
4. Close or merge Dependabot PR #1 after main already uses checkout v6.

### P0.2 Signed/notarized distribution is not complete

Current state:

- `Scripts/build_app.sh --local` creates a real `.app`, but it is ad-hoc signed.
- `--developer-id` exists, but requires an Apple Developer account/certificate.
- No notarization script exists yet.
- No stapled DMG/pkg release pipeline exists.

Release requirement:

- For direct distribution outside the Mac App Store, Apple expects Developer ID signing and notarization for default Gatekeeper trust.
- For App Store distribution, the app needs Xcode archive/export, App Store Connect metadata, sandbox entitlements, and App Review readiness.

Next steps:

1. Add `Scripts/notarize_dmg.sh` or `Scripts/package_release_dmg.sh`.
2. Support `xcrun notarytool submit --wait`.
3. Staple the notarization ticket.
4. Verify with `spctl --assess --type execute --verbose=4`.
5. Document required environment variables and Apple account prerequisites.

Official references:

- Apple notarization: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- Apple App Sandbox: https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox

### P0.3 No complete release QA evidence exists

The code and docs describe many professional workflows, but there is no saved QA report proving they work end-to-end on real rigs.

Must verify manually before release:

- first-run wizard
- Simple/Advanced mode
- Show Dark, Light, Dark, System appearance
- menu bar close/reopen operation
- drag/drop and folder import
- Copy and Reference imports
- stale bookmark refresh and Relink
- save playlist/load playlist/save default/restore default
- real audio playback, fade in, fade out, panic mute, crossfade
- 44.1/48/88.2/96 kHz routing
- output device and channel-pair routing
- virtual MIDI from Ableton/Logic/IAC
- inbound OSC on `127.0.0.1:38101`
- Lightkey OSC on `127.0.0.1:21600`
- Custom OSC to at least one generic local UDP receiver
- support-bundle redaction
- sandbox build launch
- signed Developer ID build once available

Next step:

- Create `Distribution/QA_RUNBOOK.md` and `Distribution/QA_RESULTS_TEMPLATE.md`.

## P1 High Priority Work

### P1.1 Support-bundle redaction needs hardening

Current behavior:

- `redactedSupportConfig()` redacts output UID, MIDI source names, and lighting MIDI destination.
- `redactedAudioDevices()` redacts device names and UIDs.
- `Diagnostics.redacted(_:)` only redacts raw values containing `/Users/`, `file://`, or `.app/`.

Risk:

- Paths under `/Volumes/...`, `/External...`, network shares, or other personal folders may appear in logs/support bundles.
- MIDI device names or venue/profile names could still be sensitive depending on the field.

Next steps:

1. Add a centralized redaction helper for local paths, volume paths, file URLs, home-relative paths, UUID-like device IDs, and known audio/MIDI device fields.
2. Add `DeadAirChecks` coverage for `/Volumes/...`, `~/...`, and cue-map/device-name redaction.
3. Make support bundle export show a clear redaction status.

### P1.2 Test suite is an executable check runner, not full test infrastructure

Current state:

- `DeadAirChecks` is useful and covers models, MIDI/OSC parsing, dedupe, persistence migration, diagnostics concurrency, fade math, and audio predecode refusal.
- There is no XCTest target.
- There are no UI automation tests.
- There are no fixture-based playlist/profile migration test folders.

Next steps:

1. Add a real XCTest target for core logic.
2. Keep `DeadAirChecks` as a smoke runner if desired.
3. Add fixture JSON files for old config/library/profile formats.
4. Add tests for support-bundle redaction and Lightkey/Custom OSC send-result behavior.

### P1.3 `DeadAirApp.swift` is too large for release maintenance

Current state:

- `DeadAirApp.swift` is 4,691 lines and owns app model, menus, setup wizard, settings tabs, transport UI, inspector, diagnostics, and helper views.

Risk:

- SwiftUI type-check failures are more likely.
- Release changes will be harder to review safely.

Next steps:

1. Split into files:
   - `DeadAirModel.swift`
   - `SetupWizardView.swift`
   - `SettingsViews.swift`
   - `TransportViews.swift`
   - `PlaylistViews.swift`
   - `InspectorViews.swift`
   - `HelpCenterView.swift`
   - `SharedControls.swift`
2. Keep behavior unchanged while moving code.
3. Run CI after each small move.

### P1.4 App Store/Xcode path is incomplete

Current state:

- SwiftPM app builds and `build_app.sh` creates a bundle.
- App Store docs exist.
- Entitlements exist.
- There is no Xcode project or documented App Store archive/export process.

Next steps:

1. Decide whether to generate/maintain an Xcode project.
2. Add asset catalog/Icon Composer path if App Store submission needs it.
3. Document App Store Connect screenshots, review notes, categories, privacy labels, and sandbox explanation.

### P1.5 Branch protection and release governance are not configured

Recommended GitHub settings:

- require CI before merge
- require CodeQL/code scanning before release branches
- protect `main`
- enable secret scanning and push protection where available
- keep Dependabot enabled
- add release tags and GitHub Releases once signed artifacts exist

## P2 Medium Priority Work

### P2.1 More production-facing docs

Add:

- `Distribution/QA_RUNBOOK.md`
- `Distribution/RELEASE_PROCESS.md`
- `Distribution/BETA_FEEDBACK_TEMPLATE.md`
- `Distribution/KNOWN_LIMITATIONS.md`

### P2.2 Visual QA needs screenshot evidence

Current UI work is substantial, but there is no saved visual QA artifact.

Next steps:

- Capture screenshots for first-run wizard, main show surface, settings tabs, help center, menu bar mode, and small-window layout.
- Add them to a QA report or App Store screenshot prep folder.

### P2.3 Release artifact automation needs cleanup

Current state:

- A beta DMG was previously created locally.
- `release/` is ignored and not committed.

Next steps:

- Create a repeatable signed DMG script.
- Include version/build in DMG name.
- Verify mount contents.
- Verify app signature.
- Verify notarization/stapling once Developer ID exists.

## Strengths Found

- No third-party Swift dependencies, which reduces supply-chain risk.
- Core models are `Codable` with backward-compatible decode defaults.
- Persistence uses backup-before-write and corrupt-file quarantine.
- Referenced files use security-scoped bookmarks.
- Audio is predecoded and memory-limited before playback.
- Fades and crossfades are in-app and independent of Ableton.
- MIDI source selection uses exact endpoint identity where available.
- OSC server uses a generation token to avoid stale receive loops after restart.
- Outbound lighting cues are non-blocking.
- Lighting supports Lightkey OSC, Custom OSC, and MIDI fallback.
- Menu bar mode keeps app active when the main window closes.
- Diagnostics are synchronized behind a queue.
- App has useful docs: README, Quick Start, User Guide, Technical README, Troubleshooting, Privacy, Release Notes, signing notes, App Store review notes.

## Risks Found

- Hosted CI/CodeQL failure must be verified fixed after push.
- Support-bundle redaction is incomplete for `/Volumes/...` and other non-home paths.
- No signed/notarized release pipeline yet.
- No real release QA report with hardware/DAW/lighting verification.
- No XCTest/UI test structure.
- `DeadAirApp.swift` is too large.
- CodeQL uses Swift extraction and can be slow on macOS runners; refactors should avoid very large SwiftUI bodies.
- Public repo means all source/docs/assets are visible; do not commit test audio, logs, customer show data, certificates, private keys, or beta support bundles.

## Immediate Execution Order For Next Chat

1. Check local status:

   ```sh
   git status --short --branch
   git log --oneline --decorate -5
   ```

2. Verify current local checks:

   ```sh
   swift run DeadAirChecks
   swift build -c release -Xswiftc -warnings-as-errors
   ./Scripts/build_app.sh --sandbox
   codesign --verify --deep --strict "dist-sandbox/Dead Air.app"
   ```

3. Push current audit/fix commit if not already pushed:

   ```sh
   git add .
   git commit -m "Add release-level audit handoff and CI fixes"
   git push origin main
   ```

4. Watch GitHub:

   ```sh
   gh run list --repo SeanAsheMusic/dead-air --limit 10
   gh run view <run-id> --log-failed
   gh pr list --repo SeanAsheMusic/dead-air
   ```

5. Make CI and CodeQL green.

6. Harden support-bundle redaction and add checks.

7. Add QA runbook/results template.

8. Build signed/notarized release pipeline once Apple Developer credentials exist.

9. Run full manual show rehearsal and record results.

10. Only then cut a release candidate tag.

## Release Candidate Exit Criteria

Dead Air can be called release-candidate only when all are true:

- GitHub `CI` is green on `main`.
- GitHub `CodeQL` is green on `main`.
- `swift run DeadAirChecks` passes locally.
- Release build passes with warnings as errors.
- Sandbox app bundle launches and passes smoke QA.
- Developer ID app is signed with hardened runtime.
- DMG is notarized and stapled.
- `spctl` accepts the final app/DMG.
- Support bundle redaction tests pass.
- QA runbook is completed on a real or representative show rig.
- README/User Guide/Troubleshooting reflect the final release behavior.

## Current Source References

- Main app/model/UI: `Sources/DeadAirApp/DeadAirApp.swift`
- Audio engine: `Sources/DeadAirCore/AudioEngineController.swift`
- File import/bookmarks: `Sources/DeadAirCore/LibraryManager.swift`
- Persistence: `Sources/DeadAirCore/Persistence.swift`
- MIDI input: `Sources/DeadAirCore/MIDIEndpointManager.swift`
- MIDI output: `Sources/DeadAirCore/MIDIOutputManager.swift`
- OSC input: `Sources/DeadAirCore/OSCServer.swift`
- OSC message support: `Sources/DeadAirCore/LightingCueSupport.swift`
- Diagnostics: `Sources/DeadAirCore/Diagnostics.swift`
- Checks: `Tests/DeadAirCoreChecks/main.swift`
- Build script: `Scripts/build_app.sh`
- Entitlements: `Entitlements/`
- Workflows: `.github/workflows/`

## External References Used

- Apple notarization docs: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- Apple App Sandbox docs: https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox
- CodeQL supported languages: https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/
- `actions/checkout` releases/runtime: https://github.com/actions/checkout
