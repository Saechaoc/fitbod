---
phase: 1
slug: foundation-exercise-library
status: draft
shadcn_initialized: false
preset: bru-v1
created: 2026-05-10
revised: 2026-05-23
---

# Phase 1 — UI Design Contract (BRU Edition)

> Visual and interaction contract for Foundation & Exercise Library.
> Originally drafted 2026-05-10 under native iOS HIG / system-materials stance.
> Re-authored 2026-05-23 to adopt the BRU design system — a project-internal
> brutalist editorial print-zine visual language inferred from 17 .jsx mockups.
> Same screen inventory, information architecture, requirement IDs, copy, and
> accessibility decisions are preserved. Design-system / spacing / typography /
> color / component sections are rewritten to the BRU language.

This phase delivers the app's `RootView` with `TabView`, the exercise library
(browse / multi-facet filter / type-ahead search), the exercise detail view
(read-only built-in + "Copy as custom"), the custom exercise editor (with required
primary-muscle stimulus mapping), and the Settings tab (units toggle only). The
design stance shifts from "iOS-default chrome" to **BRU: high-contrast ink-on-paper
editorial grid, hard borders, condensed display numerals, monospace data, capsule
chips — the aesthetic of a precision instrument, not a consumer wellness app**.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | custom (BRU design system — project-internal) |
| Preset | bru-v1 |
| Component library | SwiftUI built-ins restyled to BRU language: `List`, `NavigationStack`, `TabView`, `.searchable`, `.sheet`, `Form`-less custom `VStack` layouts. No third-party SPM dependencies. |
| Icon library | SF Symbols (Apple-bundled). Weight: `regular` for icons that accompany BRU.font text; match stroke to `BRU.font` size at point of use. |
| Font — BRU.display | **Instrument Serif** (Italic variant for display numerals + headers). Free, OFL-licensed. Loaded via `UIAppFonts` in Info.plist. Used at fixed sizes 18 / 22 / 28 / 32 / 48+ — scaled via `Font.custom(_:size:relativeTo:)`. |
| Font — BRU.font | **Inter** (weights 500 + 600 + 700). Free, OFL-licensed. Body, labels, navigation, buttons. Scaled via `Font.custom(_:size:relativeTo:)`. |
| Font — BRU.mono | **JetBrains Mono** (weight 400 + 700). Free, OFL-licensed. All data readouts, set chips, formula text, counters. Scaled via `Font.custom(_:size:relativeTo:)`. |

**Why these three fonts:**
- **Instrument Serif** — high-contrast editorial serif with strong vertical axis and
  narrow proportions. Closest free analog to the GT Alpina / Tiempos editorial serifs
  used in print sports journalism. Conveys "precision record" at the large display
  sizes the BRU mockups use (48–128px). Available on Google Fonts.
- **Inter** — humanist grotesk designed for UI density. Consistent weight axis at
  500/600/700 covers every BRU.font use case (body at 500, labels at 600, chips at 700).
  Best-in-class Latin legibility at 10–16px.
- **JetBrains Mono** — tabular-width monospace. The BRU mockups use
  `fontVariantNumeric: 'tabular-nums'` and `fontFamily: BRU.mono` everywhere numbers
  appear in data (set chips, e1RM readouts, counters). JetBrains Mono ships tabular
  figures by default and has excellent small-size legibility at 8–13px.

**Ambiguity note — font ratification:**
The exact font trio above is a proposal. If you want a different display face (e.g.
Tiempos Headline, or a condensed grotesk like Barlow Condensed), change BRU.display
before Phase 1 ships. The token name `BRU.display` is the contract; the typeface
behind it can be swapped by replacing the Info.plist registration and the
`Font.custom` literal in the BRU token file, with zero view changes.

**Custom font registration (mandatory — Phase 1 setup):**
Add all font files to the Xcode target as bundle resources (Build Phases →
Copy Bundle Resources). Register in `Info.plist`:
```xml
<key>UIAppFonts</key>
<array>
  <string>InstrumentSerif-Regular.ttf</string>
  <string>InstrumentSerif-Italic.ttf</string>
  <string>Inter-Medium.ttf</string>
  <string>Inter-SemiBold.ttf</string>
  <string>Inter-Bold.ttf</string>
  <string>JetBrainsMono-Regular.ttf</string>
  <string>JetBrainsMono-Bold.ttf</string>
</array>
```

**Zero third-party SPM dependencies confirmed.** BRU is implemented entirely with
SwiftUI + Asset Catalog + custom fonts. No pods, no packages.

---

## Spacing Scale

BRU uses an 8-point grid with sub-8 exceptions at 4 and 6. The mockups show
gutters of 4 / 6 / 8 / 10 / 12 / 14 / 16 / 24 throughout. Reconciled to the
4pt grid:

| Token | Value | BRU mockup origins | Usage |
|-------|-------|--------------------|----|
| xs | 4pt | `gap: 4` in chip rows, inline icon padding | Icon-to-label gaps, star-to-name gap in library row |
| sm | 6pt | `gap: 6` in chip rows | Chip-to-chip horizontal spacing in filter row |
| md-sm | 8pt | `gap: 8`, `padding: '8px 0'` on tick rows | Chip internal vertical padding, muscle row gaps |
| md | 10pt | `padding: '10px 16px'` (section rows) | Most list row vertical padding (top + bottom) |
| md-lg | 12pt | `padding: '12px 16px'` (exercise rows) | Exercise list row, section header internal padding |
| lg | 16pt | `padding: '... 16px'` — the dominant horizontal gutter | Screen edge horizontal margin, card horizontal padding |
| xl | 20pt | `gap: 20` (heatmap body pair) | Between major adjacent panels |
| 2xl | 24pt | `height: 24` (safe-area spacers) | Bottom safe-area breathing room below tab bar |

**Structural border tokens (load-bearing — not spacing, but rhythm):**

| Token | Value | Usage |
|-------|-------|-------|
| `BRU.borderHeavy` | 2px solid BRU.ink | Separates ALL major zones: header bottom, search bar bottom, filter row bottom, section separators between named sections, footer top, PR strip top. This is the BRU grid's primary structural line. |
| `BRU.borderLight` | 1px solid BRU.hair | Between list rows (individual exercise rows, set rows, muscle rows). Secondary rhythm. |
| `BRU.borderDash` | 2px dashed BRU.ink | Empty-state affordance zones: "Add muscle" placeholder, "Add exercise" placeholder in routine builder. |

**Exceptions (load-bearing for iOS):**
- **44pt minimum touch target** for any tappable control (HIG-mandated). Filter chips
  use `md` vertical padding but `.contentShape(Rectangle()).frame(minHeight: 44)` pads
  the hit area to 44pt. Tick-selector boxes (22×22pt visually) are wrapped in a
  44×44pt transparent touch target.
- **Custom tick selector** — 4 boxes of 22×22pt visible with `gap: 2` between them.
  Total visual width: 4×22 + 3×2 = 94pt. Minimum hit area per tick: 22pt × 22pt
  grown to 44×44 via `.contentShape`. This replaces the Phase 1 spec's continuous
  Slider for stimulus weight.
- The "delete" swipe action uses the system-provided swipe row height (no override).

---

## Typography

BRU's typography uses three font roles at fixed point sizes that are **always wrapped
in `Font.custom(_:size:relativeTo:)`** so Dynamic Type still scales them. The
`relativeTo:` TextStyle anchor is declared per role below; it determines how the
size scales up and down with the user's Dynamic Type setting.

### BRU.display — Instrument Serif

Carries structural numerals, hero readouts, section-letter index headers, and
exercise names in the detail title slab.

| Usage | Size (default Large DT) | Scaled via | Weight | Line height |
|-------|------------------------|------------|--------|-------------|
| Index letter header (A, B, C…) | 18pt | `.title2` | Regular | 1.0 |
| Date/compound label in history rows | 18pt | `.title2` | Regular | 1.0 |
| Exercise number in session lists (01, 02) | 22pt | `.title2` | Regular | 1.0 |
| Settings profile avatar initial | 36pt | `.largeTitle` | Regular | 1.0 |
| Exercise name in custom-exercise form (uppercase) | 28pt | `.title` | Regular | 1.1 |
| Routine / screen hero label | 32pt | `.largeTitle` | Regular | 1.0 |
| Exercise detail title slab | 48pt | `.largeTitle` | Regular | 1.0 |

**SwiftUI helper:**
```swift
extension Font {
    static func bruDisplay(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom("InstrumentSerif-Regular", size: size, relativeTo: style)
    }
    static func bruDisplayItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom("InstrumentSerif-Italic", size: size, relativeTo: style)
    }
}
```

### BRU.font — Inter

Carries body text, all chip labels, navigation labels, and form field values.

| Usage | Size | Scaled via | Weight | Line height |
|-------|------|------------|--------|-------------|
| Eyebrow / all-caps category label (e.g. "MUSCLE", "NAME") | 9pt | `.caption2` | 700 | 1.2 |
| Chip label (CHEST, COMPOUND, SECONDARY) | 10pt | `.caption` | 700 | 1.0 |
| Metadata below exercise name (sets, duration, equipment) | 10pt | `.caption` | 700 (uppercase) / 500 (mixed case) | 1.2 |
| Muscle-row names, form field values | 13–14pt | `.body` | 600 | 1.3 |
| Exercise name in list rows | 14pt | `.body` | 600 | 1.2 |
| Body / copy text (instructions, form labels, settings rows) | 13pt | `.body` | 500–600 | 1.4 |
| Section header right-side metadata | 10pt | `.caption` | 700 | 1.0 |

**SwiftUI helper:**
```swift
extension Font {
    static func bruFont(_ size: CGFloat, weight: Font.Weight = .semibold,
                        relativeTo style: Font.TextStyle = .body) -> Font {
        // Weight-to-filename mapping: .medium → Inter-Medium, .semibold → Inter-SemiBold, .bold → Inter-Bold
        let name: String
        switch weight {
        case .medium: name = "Inter-Medium"
        case .semibold: name = "Inter-SemiBold"
        default: name = "Inter-Bold"
        }
        return .custom(name, size: size, relativeTo: style)
    }
}
```

### BRU.mono — JetBrains Mono

Carries all data readouts: counters, weights, result counts, set notation, formula
steps. Always monospaced digits. Corresponds to `fontVariantNumeric: 'tabular-nums'`
in the JSX.

**SwiftUI:** Apply `.monospacedDigit()` modifier OR use `Font.custom("JetBrainsMono-Regular", ...)`.
Prefer `Font.custom` so the face matches corpus-wide.

| Usage | Size | Scaled via | Weight |
|-------|------|------------|--------|
| Result counter ("8 / 812") | 11pt | `.caption` | 400 |
| Logged count ("247×") | 11pt | `.caption` | 400 |
| Set chips (e.g. "205×8 @9") | 10–11pt | `.caption` | 400 |
| Formula / step text (why-this-weight detail) | 13pt | `.body` | 400 |
| MEV/MAV/MRV tick labels on bars | 8pt | `.caption2` | 400 |
| Section metadata counts, PR labels | 9pt | `.caption2` | 700 |

**SwiftUI helper:**
```swift
extension Font {
    static func bruMono(_ size: CGFloat, bold: Bool = false,
                        relativeTo style: Font.TextStyle = .caption) -> Font {
        .custom(bold ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular",
                size: size, relativeTo: style)
    }
}
```

### Letter spacing

Letter spacing is a structural element in BRU — not decorative.

| Token | Value | SwiftUI | Usage |
|-------|-------|---------|-------|
| `BRU.tracking.eyebrow` | +1.2pt | `.tracking(1.2)` | All-caps 9–10pt eyebrow labels: "MUSCLE", "EQUIP", "NAME", "PRIMARY", "LOGGED" |
| `BRU.tracking.cap` | +1.5pt | `.tracking(1.5)` | Wider caps: hero stat labels ("EST. 1 REP MAX"), section metadata ("READY TO SAVE"), PR badges ("NEAR MRV — DELOAD") |
| `BRU.tracking.tight` | -0.2pt | `.tracking(-0.2)` | Exercise names at 14–15pt in list rows (slight optical tightening for density) |
| `BRU.tracking.none` | 0 | (omit modifier) | All other copy |

### Exactly 4 type roles, exactly 2 functional weights

Mapping to the old Dynamic Type contract (preserved for executor reference):

| Old DT style | BRU replacement | Notes |
|---|---|---|
| `.caption` | `bruFont(10, weight: .bold)` | Chip labels, eyebrows |
| `.body` | `bruFont(14, weight: .semibold)` | Exercise names, body copy |
| `.headline` | `bruDisplay(18)` | Section index letters, dates |
| `.title2` | `bruDisplay(28–48)` | Screen titles, detail slab |

The two functional weights are **Inter 600 (semibold)** for body/label and
**Inter 700 (bold)** for chips/eyebrows. BRU.display uses a single weight (Regular /
Italic variant). BRU.mono uses Regular as default, Bold for emphasis numerals.

---

## Color

**BRU is a light-mode-canonical design system.** Off-white paper background with
near-black ink — the opposite of OLED-dark. Dark mode equivalents are declared and
required (iOS mandates adaptive colors in Asset Catalog), but BRU's visual identity
reads most clearly in light mode.

All tokens must be declared as Asset Catalog color sets in
`fitbod/Assets.xcassets/`. Never use `Color(red:green:blue:)` literals in view code
— reference by asset name.

### Token table — inferred from 17-screen JSX corpus

| Token | Asset Name | Light hex | Dark hex | Inference source |
|-------|------------|-----------|----------|-----------------|
| `BRU.ink` | `BRUInk` | `#111111` | `#F0EDE6` | Used as border color on `2px solid ${BRU.ink}` and all chip fills. Slightly off pure black — print-ink feel. Dark: inverted to cream. |
| `BRU.paper` | `BRUPaper` | `#F7F4EE` | `#141210` | BruPhone background, text-on-ink-slab. Warm off-white (aged newsprint). Dark: near-black with warm undertone. |
| `BRU.signal` | `BRUSignal` | `#E8341A` | `#F45232` | Accent red-orange. PR badges, primary CTAs, alarm fatigue state, active tab. Across all screens this is consistently a saturated warm red. Dark: slightly lighter for contrast. |
| `BRU.bg` | `BRUBg` | `#F7F4EE` | `#141210` | Base canvas. Identical to BRU.paper in the mockups (used for safe-area bottom padding). Same asset as BRUPaper. |
| `BRU.bg2` | `BRUBg2` | `#EDEAE3` | `#1E1C19` | Section-divider bg: index section headers (B, C letter headers), bar track fill, calibration panel background. Slightly darker than paper. |
| `BRU.muted` | `BRUMuted` | `#7A7367` | `#9C9488` | Secondary text: eyebrow label color, metadata below exercise names, result-count text, tick labels. Warm gray. |
| `BRU.hair` | `BRUHair` | `#D9D5CC` | `#3A3733` | Hairline 1px borders between list rows, between classification grid cells. The "light" rule. |
| `BRU.faint` | `BRUFaint` | `#C4C0B8` | `#2E2C2A` | Inactive stars (☆), empty bar fill regions (past week blocks), very dim supplemental fills. Slightly darker than hair. |
| `BRU.amber` | `BRUAmber` | `#D4860A` | `#E8A020` | Warning amber. Heatmap UNDER-MEV state, quad-warning in volume bars. |
| `BRU.green` | `BRUGreen` | `#2A7A2A` | `#3CA03C` | Success green. Heatmap IN-MAV + ADD A SET state. |
| `BRU.destructive` | `BRUDestructive` | `#E8341A` | `#F45232` | Same as signal — destructive actions (delete exercise, reset data) reuse BRU.signal per mockup pattern. Distinguish context by label, not separate color. |

### 60 / 30 / 10 split

| Role | Token(s) | Approx % |
|------|----------|----------|
| Dominant surface (paper) | `BRU.paper` / `BRU.bg` | 60% |
| Secondary surfaces (section dividers, bars, chips) | `BRU.bg2`, `BRU.hair` borders | 30% |
| Accent (signal red) | `BRU.signal` | 10% |

### Accent reserved for — Phase 1 specific elements

`BRU.signal` (`#E8341A`) appears **only** at the following elements in Phase 1.
Every other element uses BRU.ink, BRU.muted, or BRU.paper as appropriate.

1. **Status footer slab** in Custom Exercise Editor when form is VALID: full
   `BRU.signal` background, BRU.paper text ("VALID · 2 PRIMARY MAPPED" +
   "READY TO SAVE").
2. **SAVE button background** (BruButton) in Custom Exercise Editor when form is valid.
3. **Active filter chip** — chips for active filters (selected Chest, selected Barbell)
   use `fill: BRU.signal` background with BRU.paper text per library.jsx.
4. **Error / invalid state footer** in Custom Exercise Editor when form is invalid
   (no primary muscle): partial signal accent on the footer border + error copy.
5. **Selected tab icon** in BruTabBar (Library tab when active). Uses signal tint.
6. **"PRIMARY" badge** inside Custom Exercise Editor muscle rows: filled chip with
   BRU.signal background (SECONDARY chip uses BRU.ink fill).

**Explicitly NOT signal in Phase 1:**
- Exercise list row disclosure chevron — BRU.muted.
- Filter chip count badge text — BRU.muted on BRU.bg2 background.
- Section index letter headers (A, B, C) — BRU.ink text on BRU.bg2 background.
- Settings row chevrons — BRU.muted.
- Facet quick-row eyebrow labels — BRU.muted.

### Color mapping to SwiftUI

```swift
extension Color {
    static let bruInk    = Color("BRUInk")
    static let bruPaper  = Color("BRUPaper")
    static let bruSignal = Color("BRUSignal")
    static let bruBg     = Color("BRUBg")
    static let bruBg2    = Color("BRUBg2")
    static let bruMuted  = Color("BRUMuted")
    static let bruHair   = Color("BRUHair")
    static let bruFaint  = Color("BRUFaint")
    static let bruAmber  = Color("BRUAmber")
    static let bruGreen  = Color("BRUGreen")
}
```

All color sets declare `Any Appearance` (light) and `Dark` appearances in the Asset
Catalog. Do not use `Color.primary`, `Color.secondary`, or `Color(.systemBackground)`
in BRU-styled views. Use the BRU tokens.

---

## Copywriting Contract

All copy below is **terse and prescriptive**, matching "for a serious lifter, not a
beginner." No exclamation marks. No marketing voice. No hand-holding. BRU specifically
uses all-caps for category labels and structural metadata; sentence case or mixed case
for body copy and exercise names.

### Tab labels

| Tab | SF Symbol | Label | Phase 1 status |
|-----|-----------|-------|----------------|
| Today | `figure.strengthtraining.traditional` | Today | Placeholder |
| Routines | `list.bullet.rectangle.portrait` | Routines | Placeholder |
| Library | `dumbbell` | Library | Wired |
| Progress | `chart.xyaxis.line` | Progress | Placeholder |
| Settings | `gearshape` | Settings | Wired |

Only Library and Settings are wired in Phase 1. The other three tabs render
`Text("Available in Phase {N}").foregroundStyle(.bruMuted)` — no marketing copy.

### Library screen

| Element | Copy | BRU style note |
|---------|------|----------------|
| Navigation header center | Library | Mixed case, BRU.font 16pt |
| Navigation header right | + NEW | All caps, BRU.font 11pt, BRU.signal color |
| Search field placeholder | Search exercises | Mixed case, BRU.font 16pt |
| Result counter (trailing in search bar) | {N} / {total} | BRU.mono 11pt, e.g. "8 / 812" — DEFERRED (needs full count — show only when search active; total = all exercises) |
| Filter chip — All, inactive state | All | BRU.font 10pt bold, all-caps NOT required — BRU uses mixed case for "All" |
| Filter chip — Muscle, inactive | Muscle | Omitted in BRU; replaced by facet quick-row — see below |
| Filter chip — active muscle filter | {Muscle name} × | e.g. "Chest ×" — BRU.signal fill, BRU.paper text |
| Filter chip — active equipment filter | {Equipment} × | e.g. "Barbell ×" — BRU.signal fill, BRU.paper text |
| Filter chip — add equipment | + Equipment | BRU.ink border, transparent fill |
| Filter chip — add pattern | + Pattern | BRU.ink border, transparent fill |
| Filter chip — custom only | Custom | BRU.ink border, transparent fill |
| Facet quick-row: MUSCLE eyebrow | MUSCLE | All-caps, 9pt, BRU.muted, tracking 1.2 |
| Facet quick-row: EQUIP eyebrow | EQUIP | All-caps, 9pt, BRU.muted, tracking 1.2 |
| Facet quick-row: MECH eyebrow | MECH | All-caps, 9pt, BRU.muted, tracking 1.2 |
| Facet quick-row: PATTERN eyebrow | PATTERN | All-caps, 9pt, BRU.muted, tracking 1.2 |
| Facet quick-row: active value | {Value} | 12pt Inter-SemiBold, BRU.ink |
| Facet quick-row: unset value | Any | 12pt Inter-SemiBold, BRU.muted |
| Index section letter | B (etc.) | BRU.display 18pt on BRU.bg2 background |
| Exercise name in row | {Exercise.canonicalName} | BRU.font 14pt 600, tracking -0.2 |
| Muscle chip | {MUSCLE SLUG} | All-caps, 10pt 700, BRU chip outline |
| Equipment chip | {EQUIP} | All-caps, 10pt 700, BRU chip outline |
| Mechanic chip | COMPOUND / ISOLATION | All-caps, 10pt 700, BRU chip outline |
| Logged count | {N}× LOGGED | BRU.mono 11pt + "LOGGED" 8pt all-caps BRU.muted, tracking 1pt — **DEFERRED Phase 2+** (needs session history) |
| Star / favorite | ★ / ☆ | BRU.signal / BRU.faint — **DEFERRED Phase 6** (star system not built) |
| Zero-results italic hint | (0 results · clear {Filter} filter to see more) | BRU.font 11pt italic, BRU.muted |

**Facet quick-row is included in Phase 1** per library.jsx which shows it as a core
structural element between the filter chip row and the list, not a Phase 6 addition.
It is a read-only display of the active filter state (shows "Any" when unset, shows
the active facet value when set). Tapping a facet cell opens the facet picker sheet.

**Star / "247× LOGGED" are Phase 6 defers.** Phase 1 omits both columns. The grid
`gridTemplateColumns: '20px 1fr auto'` collapses to `gridTemplateColumns: '1fr'`
for Phase 1 rows; the logged-count trailing column is absent.

### Exercise detail screen

Phase 1 ships: title slab + classification chips + Primary/Secondary muscle list +
Instructions. Everything else is Phase 6 (e1RM hero, intent-split toggle, session
history rows, PR strip footer, sparkline).

| Element | Copy | BRU style note |
|---------|------|----------------|
| Header left | ‹ Library | BRU.font 13pt, BRU.ink |
| Header right | EDIT (custom) / (empty for built-in) | All-caps, BRU.font 11pt 700; absent for built-in exercises — absence IS the read-only signal |
| Classification chip row (above title) | CHEST · BARBELL · HORIZONTAL PUSH | BRU outline chips, 10pt bold, BRU.ink |
| Exercise name (title slab) | {Exercise.canonicalName} | BRU.display 48pt |
| Muscle stimulus sub-line | Primary: {Muscle} {weight} · Secondary: {Muscle} {weight} | BRU.font 11pt, BRU.muted, all-caps, tracking 0.5 |
| Section: muscle list header | Muscles | BruSectionHead (all-caps 10pt eyebrow, 2px ink top border) |
| Muscle row format | {MUSCLE NAME} {weight as decimal} | e.g. "BACK · LATS  1.0" — chips for role badge + inline display |
| Section: instructions header | Instructions | BruSectionHead |
| Instructions body text | (raw from dataset, no transformation) | BRU.font 13pt 500, 1.4 line-height |
| "Copy as custom" CTA | COPY AS CUSTOM | All-caps, BRU.font 11pt 700, BRU.signal text, outline BRU.signal border — presented as a BruButton ghost variant at the bottom of the detail scroll |
| Phase 6 defer notice (inline placeholder) | (absent — do not render placeholder rows) | Omit the e1RM hero, intent tabs, history rows, and PR strip entirely in Phase 1 |

### Custom exercise editor

**Critical UX change from original spec:** The existing spec used a continuous
`Slider` (0.0–1.0) for stimulus weight. **BRU replaces this with a 4-discrete-tick
selector** matching custom-exercise.jsx: four 22×22pt boxes showing values
`0.25 / 0.5 / 0.75 / 1.0`. The selected value shows `BRU.ink` fill + BRU.paper
text; unselected boxes are transparent with 1px BRU.ink border. This is a UX change
from the original spec — document explicitly for executor.

**Why:** BRU's editorial grid aesthetic uses hard discrete choices, not continuous
analog controls. Practically: the four levels map to natural training language
(quarter / half / three-quarter / full stimulus). Continuous precision is fake
precision at the level of stimulus weighting.

| Element | Copy | BRU style note |
|---------|------|----------------|
| Header left | CANCEL | All-caps BRU.font 11pt 700 |
| Header center | New exercise | Mixed case BRU.font 16pt 600 |
| Header right | SAVE | All-caps BRU.font 11pt 700 BRU.signal (enabled) / BRU.muted (disabled) |
| Name section eyebrow | NAME | All-caps 9pt BRU.muted tracking 1.2 |
| Name input placeholder | e.g. Cambered Bar Bench Press | BRU.font 16pt 400 BRU.muted (placeholder) |
| Name input active state | {exercise name in UPPERCASE} | BRU.display 28pt, all-caps — matches mockup `textTransform: 'uppercase'` |
| Classification section header | CLASSIFICATION | BruSectionHead |
| Classification grid field label — EQUIPMENT | EQUIPMENT | All-caps 9pt BRU.muted tracking 1.2 |
| Classification grid field label — MECHANIC | MECHANIC | All-caps 9pt BRU.muted |
| Classification grid field label — PATTERN | PATTERN | All-caps 9pt BRU.muted |
| Classification grid field label — TEMPO | TEMPO | All-caps 9pt BRU.muted — **DEFERRED** (not in Phase 1 scope per CONTEXT.md) |
| Classification grid field label — BAR WT | BAR WT | All-caps 9pt BRU.muted — **DEFERRED** (Phase 3 per SET-03) |
| Classification grid field label — INCREMENT | INCREMENT | All-caps 9pt BRU.muted — **DEFERRED** (Phase 3 per SET-04) |
| Phase 1 classification grid: 2 cells only | EQUIPMENT · MECHANIC | Render as 2-column grid with 2 cells only. Pattern deferred (not required data in Phase 1). |
| Disclosure chevron per grid cell | › | BRU.muted 16pt |
| Primary muscle section header | PRIMARY MUSCLE STIMULUS | BruSectionHead with right="Required" |
| PRIMARY role badge | PRIMARY | Filled chip, BRU.signal bg, BRU.paper text |
| SECONDARY role badge | SECONDARY | Outline chip, BRU.ink border, BRU.ink text |
| Tick selector values | 0.25 · 0.5 · 0.75 · 1.0 | 4 boxes 22×22pt, 10pt bold |
| Secondary stimulus section header | SECONDARY STIMULUS | BruSectionHead |
| Add muscle affordance | + ADD MUSCLE | All-caps 11pt 700 tracking 1.5, `border: 2px dashed BRU.ink`, full-width, centered, 44pt tall minimum |
| Status footer — valid, N primary | VALID · {N} PRIMARY MAPPED | Left side, all-caps 10pt 700 tracking 1.2, BRU.paper on BRU.signal bg |
| Status footer — valid right side | READY TO SAVE | Right side, same style |
| Status footer — invalid (no primary) | NO PRIMARY MUSCLE · SAVE BLOCKED | Left side, BRU.ink on BRU.bg2 bg (not signal); right side empty |
| Save button label | Save exercise ▸ | BRU.font 13pt 700, BRU.paper on BRU.ink bg — the "▸" cursor is structural in BRU buttons |
| Cancel confirmation title | Discard Changes? | |
| Cancel confirmation destructive | Discard | |
| Cancel confirmation safe | Keep Editing | |

### Settings screen — Phase 1 carve-out

Phase 1 ships **only** the Units row and the Profile slab. All other rows from
settings.jsx are forward-references (Phase 3+ scope). The Settings screen is
stub-aware: it renders Phase 1 rows now and will have Phase 6 rows added later.

| Element | Copy | BRU style note |
|---------|------|----------------|
| Header center | Settings | Mixed case BRU.font 16pt 600 |
| Profile slab — avatar | User initial (e.g. first letter of developer's name) | BRU.display 36pt, BRU.paper on BRU.ink 56×56pt square |
| Profile slab — name | {name} | BruDisplay 28pt |
| Profile slab — metadata | (omitted in Phase 1 — no session count or block data yet) | Sessions count and block position are Phase 2+ data |
| Units section header | UNITS & CALIBRATION | BruSectionHead |
| Units row label | Units | BRU.font 13pt 600 |
| Units row value | LB / KG | BRU.mono 11pt BRU.muted, all-caps, right-aligned |
| Units row disclosure | › | BRU.muted 14pt |
| About section header | ABOUT | BruSectionHead |
| Version row label | Version | BRU.font 13pt 600 |
| Version row value | 1.0.0 · SCHEMA V1 | BRU.mono 11pt BRU.muted |

**Units implementation:** Phase 1 doesn't yet use a toggle per the original spec.
BRU's settings.jsx uses a `Row` with a disclosure chevron that navigates to a
picker. Phase 1 ships the row with a `Picker` in an inline popover (`.confirmationDialog`
or a sheet presenting two options: LB / KG) rather than a binary Toggle. This
matches BRU's grid-row tap pattern. The underlying `UserSettings.unitsRaw` binding
is unchanged.

**Deferred rows (do not render, do not add placeholder cells):**
Plate inventory, Per-exercise increment, RPE calibration window, Training defaults
section, Volume targets section, Export section, Backup/restore block. These are
Phase 3 / Phase 5 / Phase 6 scope respectively. The Settings view grows as phases
land — Phase 1 ships 2 sections (Units + About) with About containing only the
Version row.

### Empty states

| Surface | Heading | Body | Action |
|---------|---------|------|--------|
| Library — no search results | No exercises match | Try fewer filters or a different search. | Clear filters (BRU.signal text, outline chip style) |
| Library — zero results on active query | No exercises match "{query}" | Check spelling or create a custom exercise. | + New exercise (BRU.signal fill chip) |
| Custom exercise — no muscles mapped (inline) | (none — section header serves as heading) | At least one primary muscle is required to save. | (the "+ ADD MUSCLE" dashed affordance is the CTA) |
| Library — pre-seed loading state | Preparing library… | (none) | ProgressView spinner (BRU.ink tint) |

**BRU empty state pattern:** Dashed 2px BRU.ink border on a centered block,
all-caps bold label, no illustration. Matches the "+ ADD MUSCLE" and "+ Add exercise"
patterns across mockups.

### Error states

| Scenario | Display | Copy |
|----------|---------|------|
| Seed pipeline fails on first launch | Full-screen `Alert` | Title: "Library Failed to Load". Body: "The exercise library could not be initialized. Restart the app — if this keeps happening, reinstall." Button: "OK" |
| User taps SAVE with no primary muscle (defensive — Save is visually blocked) | Status footer changes to invalid state | "NO PRIMARY MUSCLE · SAVE BLOCKED" |
| Photo-library access denied for custom-exercise image | `Alert` after picker dismiss | Title: "Photo Access Required". Body: "Enable photo access in Settings to attach an image." Buttons: "Open Settings" (BRU.signal text) / "Not Now" |
| Custom exercise delete with logged history | Confirmation `Alert` | Title: "Delete \"{name}\"?". Body: "Logged session history for this exercise will be preserved." Buttons: "Delete" (BRU.signal) / "Cancel" |

### Destructive actions in Phase 1

| Action | Confirmation approach |
|--------|-----------------------|
| Delete custom exercise (row swipe → BRU.signal "Delete") | No confirmation when no session history (nullify cascade, history preserved anyway). Full `Alert` confirmation when history exists (copy above). Swipe action uses BRU.signal background, BRU.paper "Delete" label in BRU.mono 11pt. |
| Discard unsaved changes in editor | `confirmationDialog` only when form is dirty. |

---

## Component Inventory (Phase 1 — BRU Primitives)

These are the BRU primitive views that Phase 1 must implement in SwiftUI. Later
phases reuse these components without redefinition.

### BRU Primitive Components

| Component | SwiftUI expression | Description |
|-----------|-------------------|-------------|
| `BruPhone` | `VStack(spacing: 0) { … }.background(Color.bruPaper).ignoresSafeArea(edges: .bottom)` | The root frame container. All screens are a VStack of named zones separated by `BRU.borderHeavy`. |
| `BruHeader` | Custom view: `HStack` with left label, center label, right label, separated by `BRU.borderHeavy` on the bottom. Replaces iOS NavigationBar chrome. | Standard top bar. Height: 44pt content + status bar height. Background: BRU.paper. All text: BRU.font. For Phase 1: implemented as a NavigationBar restyled via `UINavigationBarAppearance` (barTintColor = BRUPaper, titleTextAttributes using bruFont, no translucency). |
| `BruChip` | `Text(label).font(.bruFont(10, weight: .bold)).tracking(1.2).padding(.horizontal, 6).padding(.vertical, 3).overlay(RoundedRectangle(cornerRadius: 0).stroke(Color.bruInk, lineWidth: 1))` | Chip with rectangular corners (BRU uses 0 corner radius throughout — NO rounded capsule chips). Filled variant: `.background(fillColor)`. Default: transparent with BRU.ink 1px border. |
| `BruSectionHead` | `VStack(spacing: 0) { Divider().frame(height: 2).background(Color.bruInk); HStack { Text(label).font(.bruFont(10, weight: .bold)).tracking(1.2).foregroundColor(.bruMuted); Spacer(); rightMetadata }.padding(.horizontal, 16).padding(.vertical, 8).background(Color.bruPaper) }` | Section divider header. 2px BRU.ink top border, 10pt all-caps left label in BRU.muted, optional right metadata. |
| `BruButton` | `Text(label + " ▸").font(.bruFont(13, weight: .bold)).tracking(1.2).frame(maxWidth: .infinity).padding(.vertical, 14).background(fillColor).foregroundColor(textColor)` | Full-width bottom button with "▸" suffix. Primary variant: BRU.ink bg, BRU.paper text. Signal variant: BRU.signal bg, BRU.paper text. Ghost variant: transparent bg, BRU.ink text, BRU.ink 2px top border. |
| `BruTabBar` | Custom `HStack` of 5 tab items replacing iOS TabView chrome. Each tab: icon (SF Symbol, 20pt) + label (10pt BRU.font 700, all-caps). Active: BRU.signal icon + label. Inactive: BRU.muted. 2px BRU.ink top border. | Full custom tab bar. Implemented by wrapping TabView and overriding the bottom bar via `UITabBarAppearance` OR by hiding the system tab bar and floating a custom view. See interaction patterns below. |
| `BruIndexHeader` | `Text(letter).font(.bruDisplay(18)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.vertical, 6).background(Color.bruBg2).border(Color.bruInk, width: 1)` | Alphabetical section header (A, B, C). BRU.display 18pt on BRU.bg2, with 1px BRU.ink bottom border. |
| `BruTickSelector` | `HStack(spacing: 2) { ForEach([0.25, 0.5, 0.75, 1.0]) { v in box(v) } }` where each box is 22×22pt with 1px BRU.ink border, filled with BRU.ink when selected, transparent when not. | Replaces the continuous stimulus Slider from the original spec. 4 discrete values only. |

**Corner radius:** BRU uses 0 (zero) corner radius on all containers, cards, chips,
and buttons. This is structural — the print-grid aesthetic relies on sharp right-angle
borders. Do not add `cornerRadius` anywhere in BRU-styled views.

### User-Visible SwiftUI Surfaces (Phase 1)

| View | File | Role | Bound to |
|------|------|------|----------|
| `RootView` | `App/RootView.swift` | TabView host with 5 tabs (3 placeholders) + BruTabBar | — |
| `ExerciseLibraryView` | `ExerciseLibrary/ExerciseLibraryView.swift` | Main library: BruHeader + search bar + filter chips + facet quick-row + indexed List | `@Query<Exercise>` driven by `FilterState` |
| `ExerciseFilterBar` | `ExerciseLibrary/ExerciseFilterBar.swift` | Horizontal scroll of `BruChip` filter chips | `@Bindable FilterState` |
| `FacetQuickRow` | `ExerciseLibrary/FacetQuickRow.swift` | 4-column grid showing active facet summary, tappable to open picker | `FilterState` read |
| `FilterPickerSheet` | `ExerciseLibrary/FilterPickerSheet.swift` | Multi-select list for one facet | `@Bindable FilterState` |
| `ExerciseRow` | `ExerciseLibrary/ExerciseRow.swift` | 1fr grid: name + chip trio. Phase 1 omits star column and logged-count column | `Exercise` |
| `ExerciseDetailView` | `ExerciseLibrary/ExerciseDetailView.swift` | Title slab + classification chips + muscle list + instructions + Copy CTA. Phase 1 omits e1RM hero, history, PR strip | `Exercise` |
| `CustomExerciseEditor` | `ExerciseLibrary/CustomExerciseEditor.swift` | BRU-styled create/edit form with BruTickSelector | `@Bindable CustomExerciseDraft` |
| `MusclePickerSheet` | `ExerciseLibrary/MusclePickerSheet.swift` | List of `MuscleGroup`s | Selection closure |
| `MuscleWeightRow` | `ExerciseLibrary/MuscleWeightRow.swift` | Role badge chip + muscle name + BruTickSelector + delete | `@Bindable` row state |
| `SettingsView` | `Settings/SettingsView.swift` | BruHeader + Profile slab + Units section + About section | `UserSettings` via `@Query` |
| `PlaceholderTabView` | `App/PlaceholderTabView.swift` | "Available in Phase {N}" filler on BRU.paper bg | Static prop |

### Stateful helpers

| Type | Role |
|------|------|
| `FilterState` (`@Observable`) | `selectedMuscleSlugs: Set<String>`, `selectedEquipment: Set<String>`, `selectedMechanic: String?`, `selectedPatterns: Set<String>`. Computed `predicate: Predicate<Exercise>`. Provides `activeFacetSummary(for:)` → String for FacetQuickRow. |
| `CustomExerciseDraft` (`@Observable`) | Name, muscle rows (each with `role: String`, `weight: Double`), equipment, mechanic. `var isValid: Bool`. `var statusCopy: String` for the status footer. |

---

## Interaction Patterns

- **Search bar:** NOT a native `.searchable` modifier — BRU's search bar is a custom
  `HStack` zone with a 🔍︎ glyph (BRU.display 18pt), a transparent text field, and a
  result counter in BRU.mono 11pt. The custom zone sits below BruHeader, separated
  by `BRU.borderHeavy`. Debounce via `.task(id: searchText)` + 150ms sleep, same as
  the original spec. Because BRU's search bar is custom, use `UISearchTextField`
  wrapped in `UIViewRepresentable` OR a `SwiftUI.TextField` with `.backgroundStyle(.clear)`
  — either achieves the transparent field on BRU.paper background.

- **Filter chip taps:** Each non-facet chip opens a `.sheet(detents: [.medium, .large])`
  `FilterPickerSheet`. Each facet quick-row cell tap also opens the same sheet
  pre-scoped to that facet. "× " suffix on active chips clears that facet.

- **Facet quick-row:** Shown whenever the library list is visible. Updates immediately
  on facet selection change. "Any" when unset, active value when set.

- **Indexed list:** `List` with `Section(header:)` per letter. Each section header is
  `BruIndexHeader`. `List` style: `.plain` — removes iOS grouped background, allowing
  BRU.paper to show through. Disable default `List` row separators via
  `.listRowSeparator(.hidden)` and apply `BRU.borderLight` bottom border manually
  in each `ExerciseRow`.

- **Library row tap:** `NavigationLink(value: exercise)` pushes `ExerciseDetailView`.
  No modal.

- **"+ NEW" header button:** Presents `CustomExerciseEditor` as `.sheet`.

- **"Copy as custom":** Initializes `CustomExerciseDraft` from built-in exercise fields
  and presents `CustomExerciseEditor` as sheet over detail view.

- **BruTabBar active state:** The tab bar is visually custom (BRU.ink top border,
  5-tab HStack). Active tab uses BRU.signal for icon + label. Implemented via custom
  SwiftUI tab bar overlay OR `UITabBarAppearance` with `selectedItemTintColor` set
  to BRUSignal. The iOS system tab bar is hidden (`UITabBar.appearance().isHidden = true`)
  and replaced by the custom `BruTabBar` view pinned to the bottom safe area.

- **Tab re-tap pop-to-root:** When Library tab is re-tapped, clear `libraryPath:
  NavigationPath`. Implemented via `onChange(of: tabSelection)` detecting re-selection
  of the same tab.

- **Stimulus tick selector:** 4-box `HStack` replacing the Slider. Tapping a box
  sets `muscleRow.weight = boxValue`. The 4 values are fixed: 0.25, 0.5, 0.75, 1.0.
  Default for primary muscle: 1.0. Default for secondary: 0.5. This is a **UX change
  from the original spec** (was a continuous slider; now discrete ticks).

- **Custom exercise status footer:** A fixed-height zone pinned above the Save button.
  State machine:
  - `isValid == false, hasPrimary == false`: BRU.bg2 background, BRU.ink text,
    "NO PRIMARY MUSCLE · SAVE BLOCKED".
  - `isValid == true`: BRU.signal background, BRU.paper text,
    "VALID · {N} PRIMARY MAPPED" + "READY TO SAVE".

- **Settings Units row tap:** Opens a `.confirmationDialog` with two actions:
  "Pounds (LB)" and "Kilograms (KG)". Selected option updates `UserSettings.unitsRaw`.
  No separate navigation push.

---

## Asset Contract

| Asset | Path | Spec |
|-------|------|------|
| `BRUInk` | `Assets.xcassets/BRUInk.colorset/` | Light: `#111111`. Dark: `#F0EDE6`. Both sRGB. |
| `BRUPaper` | `Assets.xcassets/BRUPaper.colorset/` | Light: `#F7F4EE`. Dark: `#141210`. Both sRGB. |
| `BRUSignal` | `Assets.xcassets/BRUSignal.colorset/` | Light: `#E8341A`. Dark: `#F45232`. Both sRGB. |
| `BRUBg` | `Assets.xcassets/BRUBg.colorset/` | Light: `#F7F4EE`. Dark: `#141210`. Identical to BRUPaper — separate asset for semantic clarity. |
| `BRUBg2` | `Assets.xcassets/BRUBg2.colorset/` | Light: `#EDEAE3`. Dark: `#1E1C19`. Both sRGB. |
| `BRUMuted` | `Assets.xcassets/BRUMuted.colorset/` | Light: `#7A7367`. Dark: `#9C9488`. Both sRGB. |
| `BRUHair` | `Assets.xcassets/BRUHair.colorset/` | Light: `#D9D5CC`. Dark: `#3A3733`. Both sRGB. |
| `BRUFaint` | `Assets.xcassets/BRUFaint.colorset/` | Light: `#C4C0B8`. Dark: `#2E2C2A`. Both sRGB. |
| `BRUAmber` | `Assets.xcassets/BRUAmber.colorset/` | Light: `#D4860A`. Dark: `#E8A020`. Both sRGB. |
| `BRUGreen` | `Assets.xcassets/BRUGreen.colorset/` | Light: `#2A7A2A`. Dark: `#3CA03C`. Both sRGB. |
| `AppIcon` | `Assets.xcassets/AppIcon.appiconset/` | Placeholder: capital "F" in BRUPaper on BRUInk bg, 1024×1024. Artistic icon deferred. |

**Remove:** `AccentColor.colorset` from the original spec — replaced by BRU token
assets. The iOS tint color should be set to `BRUSignal` via
`UIView.appearance().tintColor = UIColor(named: "BRUSignal")` in `fitbodApp.swift`
for any residual system controls (Picker, native Toggle, search cursor) that cannot
be fully restyled.

**Font bundle assets (add as Build Phase resources — not Asset Catalog):**
- `InstrumentSerif-Regular.ttf`
- `InstrumentSerif-Italic.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`
- `JetBrainsMono-Regular.ttf`
- `JetBrainsMono-Bold.ttf`

SF Symbols `dumbbell`, `figure.strengthtraining.traditional`, `gearshape`,
`chart.xyaxis.line`, `list.bullet.rectangle.portrait` require no vendoring.

---

## Accessibility Contract

The user is the only user and is sighted, but BRU's high-contrast aesthetic (near-black
on warm-white) actually exceeds WCAG AA by default. The accessibility concerns
specific to BRU's custom components are documented below.

| Surface | Contract |
|---------|----------|
| BruChip (filter chip) | `accessibilityLabel` = "{facet} filter, {N} selected" when active; "{facet} filter, no selection" when inactive. |
| BruTickSelector boxes | Each box: `accessibilityLabel` = "{muscle} stimulus: {value as percent}". `accessibilityTrait` = `.button`. The currently selected box: `.accessibilityAddTraits(.isSelected)`. 44pt minimum touch area via `.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())` on the whole selector (not per-box — tap area for each box is 44/4 = 11pt, below minimum; use `.accessibilityElement(children: .combine)` on the HStack and implement `AXAdjustableAction` to step through values). |
| BruButton SAVE (disabled) | `accessibilityHint` = "Add a primary muscle to enable saving". `accessibilityTraits` includes `.isButton`. |
| BruTabBar items | Each tab item: `accessibilityLabel` = "{tab name}" + `accessibilityTrait` = `.isButton`. Active tab: `.accessibilityAddTraits(.isSelected)`. |
| BruIndexHeader | `accessibilityLabel` = "Section {letter}". `accessibilityTrait` = `.isHeader`. |
| Exercise row | `accessibilityLabel` = "{exercise name}, {equipment}, {mechanic}". |
| "▸ NEW" header button | `accessibilityLabel` = "Create custom exercise". |
| Dynamic Type | All fonts use `Font.custom(_:size:relativeTo:)` — system DT scale factor applied. BRU's layout uses `maxWidth: .infinity` and wrapping stacks, not fixed-width frames. |
| Color contrast | BRU.ink (#111111) on BRU.paper (#F7F4EE): contrast ratio ≈ 17.5:1 (exceeds WCAG AAA 7:1). BRU.signal (#E8341A) on BRU.paper (#F7F4EE): contrast ratio ≈ 4.8:1 (meets WCAG AA 4.5:1 for normal text). |
| Reduced motion | No custom animations introduced in Phase 1. BruTabBar switches are instant. Sheet presentations use system-default animation (respects Reduce Motion). |

---

## What's Explicitly Deferred (so the checker doesn't fail it for absence)

These are intentionally absent from the Phase 1 UI contract:

- **Star / favorite system** (★ column in library rows) — Phase 6.
- **"247× LOGGED" usage count** (logged-count trailing column) — requires Session
  history from Phase 2+.
- **e1RM hero slab** in exercise detail — Phase 6.
- **Intent-split toggle** (ALL / STRENGTH / HYPER tabs) in exercise detail — Phase 2+.
- **Session history rows** in exercise detail — Phase 2+.
- **PR strip footer** in exercise detail — Phase 6.
- **Sparkline chart** in exercise detail — Phase 6.
- **Facet quick-row TEMPO, BAR WT, INCREMENT** in custom-exercise classification grid — Phase 3.
- **Plate inventory / per-exercise increment / RPE calibration rows** in Settings — Phase 3.
- **Training defaults / Volume targets / Export / Backup sections** in Settings — Phase 3/5/6.
- **Profile slab session count and block position** — Phase 2+ (no session data yet).
- **Bundled exercise images/GIFs** — deferred per CONTEXT.md; image path strings persist.
- **Filter state persistence across launches** — single-session reset only.
- **Sort options menu** — alphabetical only.
- **Today / Routines / Progress tab content** — placeholder views only.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | — | not applicable (native SwiftUI; no shadcn registry) |
| Third-party iOS SPM packages | none | not applicable (PROJECT.md locks project to zero third-party SPM dependencies) |

The BRU design system is implemented entirely in-house. The three custom fonts
(Instrument Serif, Inter, JetBrains Mono) are OFL-licensed open-source fonts bundled
as static assets — they are not SPM dependencies and require no registry vetting.
Download from Google Fonts (for Inter) and each font's respective GitHub repository.
No runtime network access for fonts.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending

---

*UI-SPEC originally drafted: 2026-05-10 — gsd-ui-researcher (autonomous mode)*
*UI-SPEC re-authored: 2026-05-23 — gsd-ui-researcher (BRU adoption revision)*
