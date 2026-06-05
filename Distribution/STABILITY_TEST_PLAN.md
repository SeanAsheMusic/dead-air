# Dead Air Stability Test Plan

Dead Air is a live-show macOS utility, so stability testing needs to cover more than a normal settings app. The goal is to prove that bad input, large show data, external-control bursts, clean installs, and release packaging fail safely.

## Research Basis

- Apple XCTest documentation: use automated tests for repeatable correctness and regression coverage.
- Apple Xcode diagnostics guidance: catch memory, thread, and crash issues early with sanitizer and diagnostics tools.
- Apple Instruments guidance: use runtime profiling for leaks, hangs, memory growth, and CPU pressure.
- Apple notarization guidance: Developer ID signing, notarization, stapling, and Gatekeeper assessment are required for direct Mac distribution without workarounds.

References:

- https://developer.apple.com/documentation/xctest
- https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early
- https://developer.apple.com/documentation/xcode/gathering-information-about-memory-use
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution

## Automated Gates

Run these before every release candidate:

```bash
swift run DeadAirChecks
swift run -c release DeadAirChecks
swift run --sanitize thread DeadAirChecks
swift run --sanitize address DeadAirChecks
swift build -c release -Xswiftc -warnings-as-errors
./Scripts/build_app.sh --local
```

The sanitizer gates are slower, but they catch classes of races and memory errors that normal unit tests can miss.

## Stress Coverage

`DeadAirChecks` now includes:

- MIDI parser stress across every status byte and malformed packet lengths.
- OSC parser stress for empty, binary, malformed, huge, clamped, and plain-text packets.
- Diagnostics stress with 1,000 concurrent log events, retention cap checks, and privacy redaction checks.
- Large playlist encode/decode stress with 2,000 beds and connector cues.
- Support-bundle redaction stress for private MIDI source names and lighting cue details.
- Audio decode stress across generated tones, multiple output sample rates, oversize predecode refusal, and unsupported files.

## Runtime Smoke

For a clean-profile launch smoke test:

```bash
tmp_home="$(mktemp -d)"
HOME="$tmp_home" "./dist/Dead Air.app/Contents/MacOS/DeadAir"
```

Let the app run long enough to build the audio graph, load clean defaults, start MIDI/OSC ingress, and render the main window. Then terminate it and check:

- No `DeadAir` process remains.
- No `DeadAir` crash report appears in `~/Library/Logs/DiagnosticReports`.
- The app did not create audio playback from a clean profile.

## Manual Release QA

Automation cannot prove every live-show condition. Before public release, still run:

- Clean-machine install from the notarized DMG without right-click Open.
- Real audio interface routing on the final output pair.
- Real fade in, fade out, panic mute, and crossfade through the final show rig.
- Ableton/AbleSet or final DAW MIDI/OSC command bursts.
- Lightkey, Luminescence, Show Off, and custom OSC connector checks.
- Long idle soak with Show Mode armed and disarmed.
- Window resizing across compact, mid-size, wide, external-display, and minimum window sizes.
- Exported support-bundle privacy inspection from a real show setup.

## Release Rule

Do not call a build public-release ready unless automated gates pass, CI and CodeQL are green on the pushed SHA, the DMG is notarized/stapled/Gatekeeper accepted, and real-rig QA is recorded.
