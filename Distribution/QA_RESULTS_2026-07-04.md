# Dead Air Refinement Pass 2 — Settings, Help, Menu Bar, Terminology (4.0.1 Build 9)

Version: 4.0.1
Build: 9 (SHA `61a0006` on `main`)
Method: six-lens Sonnet 5 design audit (Settings structure, Settings visuals,
Settings/Help accessibility, main surface, menu bar + Help + app menus,
microcopy) orchestrated by a Fable 5 architect pass; 39 raw findings
synthesized, implemented, then independently adversarially verified by a
Sonnet 5 reviewer reading the full diff and post-change source.
Date: 2026-07-04

## What Changed

Settings information architecture:
- The Audio tab (SettingsPanel) previously duplicated four control groups
  owned by other tabs — Fade In/Out/Live Crossfade sliders, the Bed Mode
  picker, the inbound-OSC enable/port/retry block, and a second live
  MIDIMappingPanel. All four removed; each preference now lives in exactly
  one pane (Playback / Control), with a one-line cross-reference. This was
  the audit's sole blocker.
- Tab "MIDI/OSC" renamed "Control" (matching the Setup Assistant's
  vocabulary) with a distinct inbound icon; every pane now has a
  .title2 title plus a one-line direction subtitle ("Inbound MIDI and OSC
  into Dead Air" vs "Outbound show cues to lighting and show apps").
- Sidebar rows announce selection to VoiceOver (.isSelected), carry
  per-section automation identifiers, and the compact section picker has a
  stable identifier.

Menu bar extra:
- model.warning now surfaces in the menu bar (red, matching the main
  window), fixing silent failures when operating from the menu bar alone.
  Architect note: the audit suggested disabling unavailable transport
  actions instead; rejected as contrary to the app's show-safety stance
  (controls always live, guarded in the model with warnings).
- "Settings…" ellipsis, separated "Quit Dead Air", automation identifiers
  on Show Mode/Open/Settings/Quit.

Terminology (one vocabulary everywhere):
- "Bed Inspector" (was "Track Inspector"), "Add Bed Cue", bed-cue captions,
  Library help says beds; "Send Test Cue" standardized (was also "Test
  Connector"); "Copy MIDI/OSC Map" (inbound reference, 3 sites) vs "Copy
  Lighting Cues" (outbound list) disambiguated; "Keep in Menu Bar" menu item
  matches its feature name; "Enable inbound OSC"/"Retry OSC" unified;
  "Channel"/"Velocity"/"Any Channel" spelled out; fade-in-blocked warning
  reworded to name the fix location; "songs" removed from fade help copy.

Correctness/consistency sweep:
- Twelve remaining Int-interpolated Stepper labels wrapped in String()
  (connector port, dedupe window, lighting MIDI channel/velocity, cue
  channel/number/value, mapping number/min, energy, log retention days,
  heartbeat timeout ms) — completing the locale-grouping fix across the app.

Robustness and visual consistency:
- Long user-provided names truncate gracefully with full-text tooltips:
  bed titles (BedRow, + VoiceOver full title/artist), cue names
  (LightingCueEditor), device/output line (NowPlayingCard, middle
  truncation), event-log raw payloads (middle truncation + text selection);
  event messages bounded to 3 lines; readiness details wrap to 2 with
  tooltip; MIDI action labels scale instead of clipping.
- Main-window warning banner moved from a hand-rolled flat red fill to the
  house statusGlassTile(tint: .red) with combined VoiceOver announcement.
- Help Center: .largeTitle → .title2 (house scale), topic cards on
  liquidGlassTile with combined VoiceOver labels, search-field automation
  identifier, empty state for unmatched searches.
- Playlist drop zone sits on a real tile instead of floating text.
- SectionHeader joins the house card-title tier (.headline).
- ControlButton: Panic Mute's elevated styling is now a structural
  `emphasized:` parameter (was a fragile title string match); transport
  controls now also enlarge at system accessibility Dynamic Type sizes,
  not only via the in-app setting.
- Appearance picker falls back from segmented to menu at accessibility
  type sizes; automation-ID reference rows read as label/value pairs.

## Verification

| Gate | Result |
| --- | --- |
| swift run DeadAirChecks (debug + release) | Pass |
| Thread + Address sanitizers | Pass |
| swift build -c release -Xswiftc -warnings-as-errors | Pass |
| ./Scripts/build_app.sh --local (4.0.1 build 9) | Pass |
| Adversarial diff review (Sonnet 5, full source read) | No blockers; 4 minor findings, all fixed in the same commit (2 missed String() steppers, menu-bar/main warning color mismatch, SettingsPanel self-scroll asymmetry, allCritical scope documented) |
| CI / CodeQL on `61a0006` | Pass — both `success` |

Reviewer confirmations: every deleted Audio-tab control exists in exactly one
other reachable tab; all 9 SettingsSection cases route correctly with no
double-scroll; all renamed sites changed labels only (automation IDs and
model calls untouched); zero residual stale strings; only Panic Mute passes
emphasized: true; BedRow's optional-artist accessibility label type-checks
against BedItem.artist: String?; the red-on-red contrast concern was
adjudicated not-a-risk (full-saturation red text over a 12 % tint).

## Outstanding

- Live visual spot-check of the refined Settings/Help/menu bar surfaces —
  blocked this session because another Claude session held the computer;
  run on next availability or during rehearsal QA.
- Notarization remains blocked on the Apple Developer Program License
  Agreement (see QA_RESULTS_2026-07-03.md). Build 9 supersedes build 8 as
  the artifact to notarize once the agreement is accepted.
- Physical-rig and clean-machine QA carried over unchanged.
