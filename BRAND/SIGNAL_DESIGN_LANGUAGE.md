# Signal — the Undeniable Spectacle design language

Version 1.0 · established in Dead Air 4.0.1 build 11 · SwiftUI / macOS 14+

Signal is the shared house look for every Undeniable Spectacle app — Dead Air,
Show Off, Luminescence, Tonograph, NoCab, Board, and whatever comes next. It is
implemented and proven in Dead Air; this document is the portable spec so the
rest of the line can adopt it exactly.

**One sentence:** native macOS bones (real controls, keyboard, accessibility)
under a machined charcoal skin, threaded by a glowing teal *signal* and a red
*on-air* tally — road-ready stage instruments, not stock chrome.

A live, interactive reference of this system is published as the "Signal"
Artifact (dark charcoal page with the animated signal motif, the token swatches,
and a faithful Dead Air mock). Keep this Markdown as the source of truth for
values; keep the Artifact for showing people.

---

## 1. Principles

1. **Native bones, custom skin.** Standard AppKit/SwiftUI controls, keyboard, and
   accessibility underneath. A bespoke charcoal-and-glow surface on top. You get
   macOS familiarity and brand ownership at once. Never fight the platform's
   interaction model to get the look.
2. **Every number is an instrument.** Levels, ports, timecode, counts, dB — set
   in a monospaced face with tabular figures. Precision reads as engineering.
3. **The signal is the throughline.** A glowing teal line seams surfaces and
   pulses through the icon's node. It is the single element every app shares.
4. **Dark stage first.** Deep cool charcoal is the ground. Teal = active/live-ready.
   Red = on air / armed / panic. Nothing glows that isn't telling you something.
5. **Honor accessibility.** Reduce Transparency and the app's own "reduce glass
   effects" collapse glows/materials to solids; "increase contrast" strengthens
   fills and strokes. Every surface primitive already branches on these.

---

## 2. Color tokens

All values live in one place in code: `enum Brand` in `DeadAirApp.swift`.
Dark is the hero; Light is a clean premium counterpart. Resolve per `ColorScheme`.

### Surface elevation ladder
| Token | Role | Dark | Light |
|---|---|---|---|
| `surface(0)` | App ground | `#0B0E10` | `#E8EBEF` |
| `surface(1)` | Panel | `#161A1E` | `#F4F5F8` |
| `surface(2)` | Tile / card / readout | `#1C2125` | `#FFFFFF` |
| `surface(3)` | Raised control (buttons) | `#262D32` | `#FFFFFF` |

### Brand + semantic
| Token | Hex | Use |
|---|---|---|
| `accent` (Signal teal) | `#1CC7DB` | active, selected, accent, links, fade-in |
| `accentBright` | `#61EBFC` | glow highlights, focus ring |
| `live` (On-Air red) | `#FF5447` | live, armed, panic, danger, warnings |
| `ok` | `#3DCC9E` | healthy, pass, "good" status |
| `warn` | `#FAB347` | waiting, attention, "caution" status |
| Fade Out blue | `#4C93E6` | fade-out transport only |
| Next Bed amber | `#F29E42` | next-bed transport only |
| Text primary | `#E9EEF0` (dark) / `#10151A` (light) | body/titles |
| Text dim | `#93A0A6` | secondary |
| Text faint | `#5C666C` | captions, mono micro-labels |

### Seams & depth (functions of `ColorScheme`)
- **Hairline** — dark: `accent @ 16%` (teal-tinted, so the signal reads on every
  seam), strong `32%`. Light: `black @ 10%`, strong `20%`.
- **Top bevel** (inner top-edge highlight) — dark: `white @ 6%`, light: `white @ 90%`.
- **Drop shadow** — dark: `black @ 45%`, light: `black @ 10%`.

---

## 3. Geometry & typography

**Radii** (continuous rounded rectangles everywhere): panel `12`, tile `10`,
control `7`. **Spacing** 4-pt grid: `8 / 16 / 24`, `12` as the grid gutter.

**Type roles:**
| Role | Face | Notes |
|---|---|---|
| Surface title | SF Pro `.title2` bold | no `.largeTitle`, no size jumps across breakpoints |
| Card title | SF Pro `.headline` | |
| Body | SF Pro `.body` / `.callout` | |
| **Readout** | **SF Mono + `.monospacedDigit()` / tabular** | every number: dB, ports, times, counts, kHz |
| **Micro-label** | **SF Mono `.caption2` semibold, `tracking 0.8`, UPPERCASE** | the "instrument label" idiom (status pills, section eyebrows) |

Never locale-group integers in `LocalizedStringKey` contexts — wrap in
`String(…)` (ports/notes/IDs otherwise render "38,101").

---

## 4. Components (SwiftUI primitives, all in `DeadAirApp.swift`)

These are the reusable modifiers. Copy the `Brand` enum + these into any US app.

- **`StageGlassBackgroundView` / `.stageGlassBackground()`** — app ground:
  `surface(0)` + a teal top-glow radial + a soft bottom vignette (dark);
  clean neutral (light). Solids under Reduce Transparency.
- **`.liquidGlassPanel()`** — section container: `surface(1)`, radius 12, top
  bevel, teal hairline, drop shadow.
- **`.liquidGlassTile()`** — card/cell: `surface(2)`, radius 10, top bevel,
  hairline, light shadow. Selection = additive `accent` fill + `accent` stroke.
- **`.statusGlassTile(tint:)`** — status/readout strip: `surface(2)` + a `tint`
  wash, `tint` stroke, and a soft `tint` glow (dark). Use `ok` / `warn` / `live`.
- **`.glassHeader()`** — top bar: `surface(1)` + **the signature signal line**:
  a horizontal teal rule with a soft glow and faded ends, along the bottom edge.
  This motif is the single most recognizable Signal element — put it on the
  header of every app.
- **`ControlButton(emphasized:)`** — the transport "hardware key": raised
  `surface(3)` + per-action tint wash, top bevel, tint-lit rim, coloured glow,
  and an icon glow. `emphasized: true` (Panic only) = stronger red wash + rim +
  glow. Pass the action color as `tint` (fade-in=`accent`, fade-out=blue,
  next=amber, panic=`live`).
- **`StatusPill(tone:)`** — instrument readout: mono uppercase tracked label +
  mono tabular value, tone-tinted (`good`→`ok`, `neutral`→`accent`, `bad`→`live`)
  over `surface(2)` with a tint rim.

**The signal-line motif** (portable recipe): a `ZStack` of a blurred teal
`Rectangle` (glow) under a crisp teal `Rectangle` filled with a horizontal
`LinearGradient(accent→0 at the ends)`. Height ~1.5–2 pt. Use it on headers,
section dividers, and as the "active rail" on selected/armed elements.

---

## 5. Motion

Restrained. A single ambient signal pulse (the icon's node) is the only
persistent motion; everything else is a fast state transition (~120 ms).
Respect `prefers-reduced-motion` / Reduce Motion — no travelling pulses,
no looping glows.

---

## 6. Iconography

SF Symbols only in-chrome (no emoji). The **app icon** per product is a dark
charcoal rounded tile carrying the teal signal path + node + red tally, themed
per app (Dead Air = signal through a hub). See `IMAGE_PROMPTS.md` for the
per-size icon and asset generation briefs.

---

## 7. Adoption checklist (for Show Off, Luminescence, Tonograph, NoCab, Board)

1. Copy `enum Brand` + the six surface modifiers + `.tint(Brand.accent)` at every
   scene root.
2. Replace ad-hoc backgrounds with `.liquidGlassPanel()` / `.liquidGlassTile()` /
   `.statusGlassTile(tint:)`; put `.glassHeader()` (with the signal line) on the
   top bar.
3. Route every numeric readout through SF Mono + tabular; every status label
   through the mono uppercase tracked micro-label.
4. Give each app's primary action the `ControlButton` hardware treatment with an
   app-appropriate `tint`; reserve `live` red for the genuine emergency/armed control.
5. Keep the four appearances working (System/Light/Dark/"Show Dark" dim-stage),
   and keep the Reduce Transparency / increase-contrast branches intact.
6. Verify natively in Dark and Light before shipping — Signal is dark-first but
   Light must stay premium, not an afterthought.

---

*Signal v1 is realized in Dead Air. Treat Dead Air's `DeadAirApp.swift`
`Brand` enum + surface modifiers as the reference implementation; this document
is the contract every other app in the line conforms to.*
