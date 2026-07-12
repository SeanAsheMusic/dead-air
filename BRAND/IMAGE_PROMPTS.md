# Signal — image-generation prompts (ChatGPT / DALL·E ready)

Paste these into ChatGPT image generation. Every prompt is anchored to the Signal
identity: **dark charcoal (#0B0E10), glowing teal signal (#1CC7DB), red on-air
tally (#FF5447)**, machined/instrument aesthetic. Generate, then hand PNGs back to
Claude/Sol to wire into the app + DMG.

Palette to keep consistent across ALL assets:
`ground #0B0E10 · panel #161A1E · teal #1CC7DB · teal-bright #61EBFC · red #FF5447 · text #E9EEF0`

---

## HIGHEST IMPACT

### 1. Refined Dead Air app icon (macOS, 1024×1024 master)
> A premium macOS app icon, 1024×1024, rounded-square. Deep charcoal machined
> metal tile (#0B0E10 to #161A1E subtle top-lit gradient), soft inner bevel. A
> glowing horizontal teal signal line (#1CC7DB) runs left-to-right through the
> center and swells into a clean open circular node (a signal passing through a
> hub); the teal has a soft neon bloom. A small red-orange "live" dot (#FF5447)
> sits at the upper-right of the node like an on-air tally. Dark, cinematic,
> high-end audio-hardware feel, à la a boutique rack unit. No text. Crisp, centered,
> lots of contrast so it reads at small sizes. Flat modern icon, not skeuomorphic clutter.

### 2. Small-size icon variant (16/32 px legibility, 512×512 master)
> Same Dead Air icon concept — charcoal tile, teal signal line through a center
> node, red live dot — but SIMPLIFIED for tiny sizes: thicker teal line and ring,
> larger red dot, higher contrast, minimal bevel, no fine detail. Must stay legible
> when scaled to 16×16. 512×512, no text.

### 3. Flat in-app logo glyph (transparent PNG, 512×512)
> Just the signal mark, NO tile/background — transparent PNG. A glowing teal
> (#1CC7DB) horizontal signal line passing through an open circular node, with a
> small red (#FF5447) dot at the node's upper right. Soft neon glow. Centered,
> generous padding. For use as an in-app header logo on dark surfaces.

---

## DISTRIBUTION

### 4. DMG install-window background (1320×860, @2x of 660×430)
> A macOS DMG installer background, 1320×860, very dark charcoal (#0B0E10) with a
> faint teal signal line motif sweeping across the lower third and a subtle teal
> top glow. Leave the left-center and right-center clear for the app icon and an
> Applications-folder alias with a thin teal arrow suggestion between them. Minimal,
> premium, cinematic. Small "DEAD AIR" wordmark bottom-left in light gray, thin
> letter-spaced sans. Mostly empty negative space; do not fill it.

### 5. Menu-bar template icon (monochrome, 44×44, transparent)
> A single-color BLACK monochrome menu-bar glyph on transparent background, 44×44,
> simple flat shapes only (macOS template icon style): a short horizontal signal
> line passing through a small open circle node. No color, no gradient, no glow —
> pure silhouette that macOS will tint. Clean and minimal.

---

## ONBOARDING / EMPTY STATES

### 6. Empty playlist illustration (transparent, 480×360)
> A minimal line illustration on transparent background, thin teal (#1CC7DB)
> strokes on nothing, subtle glow: an empty audio waveform flatline running into a
> "+" node, suggesting "drop audio here." Dark-theme friendly, lots of negative
> space, no text, restrained and elegant — not cartoonish.

### 7. "No bed loaded" state (transparent, 360×360)
> A minimal teal line-art icon on transparent: a dormant signal node (open circle)
> with a faint flat signal line, one small red dot dim/unlit, conveying "ready but
> idle." Thin strokes, subtle glow, dark-friendly, no text.

---

## MARKETING / LANDING / STORE

### 8. Landing / App Store hero (2880×1620, 16:9)
> A cinematic hero image for a pro live-show audio app called Dead Air. Very dark
> charcoal stage environment, a single glowing teal signal line (#1CC7DB) arcing
> across the frame and pulsing through a bright node, tiny red on-air dot. Mood:
> a dark stage between songs, tension and control. Abstract, premium, moody,
> lots of empty dark space for headline text on the left. No literal UI, no text
> in the image.

### 9. Feature screenshot frame / device backdrop (2560×1600)
> A dark premium backdrop for placing a macOS app screenshot: charcoal-to-black
> gradient (#0B0E10) with a soft teal glow behind where a floating window would sit
> and a faint signal-line motif. Center area clear/neutral for compositing a
> screenshot on top. Subtle, high-end, no text.

### 10. Social / OG card (1200×630)
> A social share card, 1200×630, dark charcoal. Left: the Dead Air teal signal-node
> mark with red live dot. Right: bold light wordmark "DEAD AIR" and a thin teal
> tagline line "Never let the room go silent." Minimal, premium, teal + red on near
> black. Clean sans type, generous spacing.

### 11. Undeniable Spectacle suite lockup (1600×900)
> A dark charcoal brand lockup showing a family of six app icon tiles in a row,
> each a dark rounded square with a teal signal motif variation and a small red
> dot, connected by a single continuous glowing teal signal line threading through
> all six nodes left to right. Below, small light wordmark "UNDENIABLE SPECTACLE".
> Conveys a unified product line. Premium, cinematic, no other text.

---

## OPTIONAL

### 12. Demo GIF end-card (1280×720)
> A dark charcoal end-card for a product demo video: centered Dead Air teal
> signal-node mark, "DEAD AIR" wordmark, tiny "by Undeniable Spectacle", a teal
> "underline" signal line. Minimal, premium, near-black background.

---

**Wiring after generation:** app icon → `Assets/DeadAirLogoMark.png` (master) then
run `Scripts/generate_brand_assets.py`; flat glyph → in-app `LogoMarkView`; DMG bg
→ `Scripts/package_release_dmg.sh`; the rest live in `BRAND/marketing/`.
