# Phase 03 — UI Review

**Audited:** 2026-05-23
**Baseline:** 03-UI-SPEC.md v2 (BRU brutalist design system — 2026-05-23 revision)
**Screenshots:** Not captured (iOS native app — no dev server; code-only audit)

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 2/4 | Hero slab copy contract replaced by generic List rows; step labels, UPPERCASE treatment, and hero sub-band copy absent |
| 2. Visuals | 1/4 | Zero BRU primitives exist; no ink hero slab, no PlateStackViz Canvas, no CalibratingProgressMeter, no BumpBannerSlab — all v1 HIG components delivered instead |
| 3. Color | 1/4 | Entire BRU 8-token palette is absent from the codebase; Color.accentColor (teal) and system semantic colors used throughout all Phase 03 surfaces |
| 4. Typography | 1/4 | Space Grotesk Bold and JetBrains Mono not bundled; all text uses Apple Dynamic Type semantic styles (Font.headline, Font.body, Font.caption) — zero BRUFont enum usage |
| 5. Spacing | 2/4 | Spacing values are ad-hoc multiples with some 4pt-grid alignment; no BRU named spacing scale tokens; arbitrary values present |
| 6. Experience Design | 3/4 | State coverage is solid — loading, empty, error, and no-solution states all handled; disabled states present; destructive confirmation implemented |

**Overall: 10/24**

---

## Top 3 Priority Fixes

1. **Entire BRU design system is absent from the codebase** — The Phase 03 UI was implemented against the v1 UI-SPEC (Apple HIG), not the BRU v2 contract. No BRU color tokens (`bruInk`, `bruPaper`, `bruSignal`, etc.), no BRU font faces (Space Grotesk Bold, JetBrains Mono), and no BRU primitive components (`BRUChip`, `BRUButton`, `BRUSectionHead`, `BRUHeaderBar`, `BRUFont`) exist anywhere in the codebase. Assets.xcassets contains only `AccentColor` (teal: R 0.055, G 0.486, B 0.525) and `Volume*` palette colors — no BRU color assets. Every Phase 03 surface must be re-skinned to use BRU tokens before the visual layer can be considered compliant.

2. **`WhyThisWeightSheet` delivers a generic `List` instead of the ink hero slab architecture** — The spec mandates a full-bleed `bruInk` hero slab at the top displaying the recommended weight at 128pt `displayHero`, with reps/RPE in `displayLarge` 32pt and a `bruSignal` RPE numeric. The implementation delivers a plain `List { Section { row(label:value:) ... } }` with `Font.headline` / `Font.body` labels in a standard iOS grouped-list layout. There is no ink slab, no 128pt weight number, no signal-colored RPE value, no `●` status indicator, and no `BRUSectionHead("Why this weight", right: "−")`. The entire visual contract for the primary new surface in this phase is absent.

3. **`PlateStackViz` uses color-coded plates (`Color(.systemRed)`, `Color(.systemBlue)`, `Color(.systemYellow)`, `Color(.systemGreen)`) — explicitly deprecated in BRU v2** — Both `PlateStackDisclosure.swift` and `PlateCalculatorSheet.swift` implement the v1 color tier scheme. The BRU v2 contract mandates all plate rectangles use `bruInk` fill with `bruPaper` rotated weight labels. The v1 color scheme has zero-redundancy (plate weight is conveyed by both color AND the numeral printed on the plate), making the color information inaccessible to color-blind users without the BRU fallback. Fix: replace the `plateColor(weight:)` function in both files with `Color.bruInk`, and add rotated `bruPaper` weight labels.

---

## Detailed Findings

### Pillar 1: Copywriting (2/4)

**WARNING** — The copywriting contract text strings themselves are largely verbatim from the v1 spec, but the v2 visual container strips out nearly all the structural copy by replacing the hero slab with a plain `List`. The actual content of rendered string literals is correct where it exists; the failures are structural.

**BLOCKER: Hero slab copy absent entirely**
The v2 spec defines 8 distinct hero slab elements with specific copy, roles, and visual weights:
- `"● RECOMMENDED · RPE AUTOREG"` in `labelSmall` 11pt `bruSignal` — NOT rendered
- `"{SET TYPE}"` trailing in `labelSmall` `bruPaper` 50% opacity — NOT rendered
- `"REPS"` / `"RPE"` sub-band labels in `labelSmall` 9pt `bruPaper` 60% opacity — NOT rendered
- `"LB"` / `"KG"` unit suffix in `displayLarge` 22pt — NOT rendered
- Hero weight number 128pt — NOT rendered

Instead, the sheet title is `"Why this weight?"` (acceptable) and the first row label is `"Last session"` (acceptable as a field label but is not a hero slab status line).

**BLOCKER: Step labels lack UPPERCASE + letterspacing treatment**
The spec mandates step labels ("Last session", "Target @ RPE {rpe}", "Rounded to plate {increment} {unit}") use `bodyEmphasis` 12pt UPPERCASE with 0.8 letterspacing. The implementation renders `Text(label).font(.headline).foregroundStyle(.secondary)` — no `.textCase(.uppercase)`, no explicit letterspacing, using Dynamic Type `.headline` (not `BRUMono` 13pt bold).

**WARNING: Step label copy deviates from v2 spec**
The v2 step labels are "Last session" / "Target @ RPE {rpe}" or "Double progression" / "Rounded to plate {increment} {unit}". The implementation uses "Last session" / "Formula" / "Computed" / "Rounded" / "Status" — "Formula" and "Computed" are not in the BRU v2 copywriting contract. The v2 spec defines exactly 3 numbered steps (01/02/03); the implementation has 5 rows without step indices.

**WARNING: `WarmupRampRows` "W{N}" labels render lowercase "warmup" chip**
The BRU spec mandates `W1`/`W2`/`W3`/`W4` in `displayMedium` 18pt `bruSignal`. The implementation wraps each row with a `Text("warmup")` capsule in `Color(.systemBlue)` — a Phase 02 set-type chip carried forward into a warmup context, never specified by the BRU v2 contract, and explicitly replaced by the signal-colored `W{N}` index in the spec.

**WARNING: `BumpBanner` title casing differs from spec**
Spec: `"BUMPING TO {weight} {unit} — YOU CLEARED THE TOP OF THE RANGE LAST TIME."` (all-caps, `labelSmall` 11pt). Implementation: `"Bumping to {weight} kg \u{2014} you cleared the top of the range last time."` (sentence case, `Font.headline`).

**WARNING: `PlateInventoryEditor` tab labels use title case, not all-caps**
Spec mandates `"BARBELL"`, `"DUMBBELLS"`, `"EZ-BAR"`, `"TRAP BAR"` (UPPERCASE via `labelSmall` or `.textCase(.uppercase)`). Implementation uses `"Barbell"`, `"Dumbbells"`, `"EZ-Bar"`, `"Trap Bar"` — no uppercase treatment.

**WARNING: `WarmupConfigSheet` title renders as "Warm-up Settings" not "WARM-UP SETTINGS"**
The spec mandates `BRUHeaderBar` center — uppercase treatment via `BRUSectionHead` pattern. The actual title string "Warm-up Settings" is in title case, not the all-caps BRU style.

**PASSING: Core copywriting strings are verbatim**
"No prior data — starting fresh.", "No prior data — starting at prescribed weight.", "Skip warm-ups", "Warm up however you'd like.", "Add Plate", "Reset plate inventory?", "No plates configured", "Add plates to use the plate calculator." — all match the spec verbatim. U+2013 en-dash in range display confirmed at `PrescriptionWeightCell.swift:70`. U+2014 em-dash in BumpBanner confirmed at `BumpBanner.swift:44`. Accessibility labels match the spec.

---

### Pillar 2: Visuals (1/4)

**BLOCKER: Zero BRU primitive components exist**
None of the following mandated Phase 03 BRU primitive components were built:
- `CalibratingProgressMeter` (`fitbod/Design/CalibratingProgressMeter.swift`) — NOT FOUND
- `PlateStackViz` (`fitbod/Design/PlateStackViz.swift`) — NOT FOUND; `PlateStackDisclosure` is a partial substitute but uses v1 color scheme
- `PlateTallyRow` (`fitbod/Design/PlateTallyRow.swift`) — NOT FOUND; `PlateInventoryEditor` uses `Stepper` instead of the tally-mark visual affordance
- `BumpBannerSlab` (`fitbod/Sessions/BumpBannerSlab.swift`) — NOT FOUND; `BumpBanner.swift` exists but is a pill-shaped capsule, not a flat ink rectangle

**BLOCKER: `BumpBanner` is a rounded pill, not a flat `bruInk` rectangle**
The spec is explicit: "NOT a capsule, NOT rounded — a flat `bruInk` rectangle (BRU has no rounded shapes)." The implementation uses `.clipShape(RoundedRectangle(cornerRadius: 12))` with a green tint background (`Color(.systemGreen).opacity(0.15)`) instead of a flat 52pt `bruInk` rectangle.

**BLOCKER: `CalibratingBadge` uses a rounded capsule shape**
Spec mandates a `BRUCornerBadge`-style inline element. The implementation uses `.clipShape(Capsule())`. BRU has no rounded capsule shapes — all shapes are flat rectangles.

**BLOCKER: `WhyThisWeightSheet` has no visual hierarchy**
The spec's ink hero slab creates a strong focal point (paper text on ink background, 128pt numeral). The implementation is a uniform `List` with no focal hierarchy differentiation — every row uses the same `headline` + `body` treatment. There is no distinguishable primary information.

**BLOCKER: `PlateInventoryEditor` uses `Stepper` instead of tally-mark visual input**
The spec mandates `PlateTallyRow` with 4 tally-mark boxes as the visual input affordance. "A `Stepper` is NOT used on-card." The implementation uses SwiftUI `Stepper` directly (`PlateInventoryEditor.swift:181`). This is an explicitly called-out v1 regression.

**WARNING: `WarmupRampRows` inline "warmup" chip uses systemBlue capsule**
The 4-column `WarmupRampRow` grid from the spec is not rendered. Instead, each row includes an off-spec systemBlue capsule chip labeled "warmup" — a Phase 02 set-type chip pattern carried forward. The mini `PlateStackViz` in the trailing column is absent (the spec shows it at 18pt height).

**WARNING: `PlateCalculatorSheet` uses a standard `Form` instead of the target-display band architecture**
The spec mandates an ink-outlined target display band with `displayHero` 96pt weight number, `±` adjustment chips, and a `PLATE STACK` zone (bruBg2 fill, 2pt rules). The implementation uses a standard iOS `Form` with `TextField` inputs and an `HStack` plate visualization inside a `Section`.

**WARNING: `PlateStackDisclosure` lacks `bruBg2` fill and 2pt `bruInk` bottom rule**
The spec mandates: "bare disclosure panel with `bruBg2` fill + 2pt `bruInk` bottom rule." The implementation renders against the default grouped background with no rule.

**WARNING: No `info.circle` removal — icon still present in `PrescriptionWeightCell`**
The v2 spec explicitly states: "The `info.circle` SF Symbol from v1 is REMOVED — the disclosure is triggered by tapping the weight cell area, not a separate icon button." The implementation retains `Image(systemName: "info.circle")` at `PrescriptionWeightCell.swift:105`. The entire affordance model is v1.

---

### Pillar 3: Color (1/4)

**BLOCKER: BRU 8-token color palette does not exist in the codebase**
`find` and `grep` across all Swift files in the project reveals zero references to `bruInk`, `bruPaper`, `bruSignal`, `bruFaint`, `bruHair`, `bruMuted`, `bruBg`, or `bruBg2`. The `Assets.xcassets` directory contains only 5 color assets: `AccentColor` (teal), `VolumeProductiveGreen`, `VolumeNearMRVAmber`, `VolumeOverMRVRed`, `VolumeBelowMEVGray`. No BRU color assets have been added.

**BLOCKER: `Color.accentColor` (teal) used on Phase 03 surfaces — deprecated by v2 spec**
The v2 spec states: "`AccentColor` (teal `#0E7C86` / `#3FBFC9`) is DEPRECATED for Phase 03 surfaces. Any Phase 03 view referencing `Color.accentColor` is a regression." Confirmed usages in Phase 03 files:
- `WhyThisWeightSheet.swift:91` — `.tint(.accentColor)` on "Use Suggested Weight" button
- `WhyThisWeightSheet.swift:167` — `.foregroundStyle(Color.accentColor)` on "Calibrated" status capsule
- `WhyThisWeightSheet.swift:170` — `Color.accentColor.opacity(0.15)` background on "Calibrated" capsule
- `PrescriptionWeightCell.swift:106` — `Color.accentColor` on `info.circle` button
- `PlateInventoryEditor.swift:162`, `203`, `257` — `Color.accentColor` on action buttons

**BLOCKER: Plate rectangles use multi-color tier scheme — explicitly deprecated**
The v2 spec states: "The v1 color-coded plate tier scheme (`Color(.systemRed)` for ≥25 kg, `Color(.systemBlue)` for 20 kg, etc.) is DEPRECATED. All plates are `bruInk` in BRU." Both `PlateStackDisclosure.swift:143–156` and `PlateCalculatorSheet.swift:201–218` implement the v1 color tiers using `Color(.systemRed)`, `Color(.systemBlue)`, `Color(.systemYellow)`, `Color(.systemGreen)`, `Color(.systemGray3/4/5/6)`.

**BLOCKER: `BumpBanner` uses `Color(.systemGreen).opacity(0.15)` — off-spec**
The v2 spec mandates `bruInk` fill with `bruPaper` text. The implementation uses the green success tint.

**BLOCKER: `CalibratingBadge` uses `Color(.systemGray5)` not `bruMuted` fill**
The spec mandates a `BRUCornerBadge`-style element with `bruMuted` fill and `bruPaper` text (7pt UPPERCASE). The implementation uses system gray semantics.

**WARNING: `WarmupRampRows` "warmup" chip uses `Color(.systemBlue)`**
Not part of any BRU reserved-for list. Not `bruSignal`. Not `bruInk`. Unspecified system semantic color.

**WARNING: 60/30/10 split completely inverted**
The spec mandates `bruPaper` as 60% dominant surface. With no BRU tokens applied, all surfaces default to iOS `systemGroupedBackground` (light gray / dark gray) — which does not map to `bruPaper` (#FAFAF7) and completely breaks the intended paper-ink-signal hierarchy.

---

### Pillar 4: Typography (1/4)

**BLOCKER: Space Grotesk Bold not bundled — `displayHero`, `displayLarge`, `displayMedium` roles missing**
`find` across the entire project finds no `.otf` or `.ttf` font files. No `SpaceGrotesk-Bold.otf` exists. The `BRUFont` enum (mandated in the spec: "All sizes via `BRUFont` enum — never raw `Font.custom(...)` calls in feature code") does not exist. All display-role text throughout Phase 03 surfaces renders using the system font (SF Pro).

**BLOCKER: JetBrains Mono not bundled — `bodyEmphasis`, `bodyDefault`, `labelSmall`, `labelMicro` roles missing**
No `JetBrainsMono-Regular.otf` or `JetBrainsMono-Bold.otf` found. All monospaced numeric rendering falls back to SF Mono or the system font, losing the BRU typeface identity.

**BLOCKER: All Phase 03 views use Apple Dynamic Type semantic styles**
Full inventory of font usage across Phase 03 UI files:
- `Font.headline` — used in `WhyThisWeightSheet.swift:109,125`, `BumpBanner.swift:45`
- `Font.body` — used in `PrescriptionWeightCell.swift:71`, `WarmupRampRows.swift:113,117`, `WhyThisWeightSheet.swift:113,180,184`
- `Font.caption` — used in `PlateStackDisclosure.swift:57,67,86,132`, `WarmupRampRows.swift:53,68,90,96,106,132`, `CalibratingBadge.swift:38`, `WhyThisWeightSheet.swift:150,166`

None of these map to BRU's 6-role type system with explicit pt sizes. The spec requires exactly 6 roles: `displayHero` (56–128pt), `displayLarge` (28–36pt), `displayMedium` (18–22pt), `bodyEmphasis` (13–15pt Mono bold), `bodyDefault` (11–13pt Mono regular), `labelSmall` (9–11pt Mono bold UPPERCASE).

**BLOCKER: No `.textCase(.uppercase)` applied anywhere in Phase 03 views**
The spec mandates UPPERCASE treatment for all label-class strings via `.textCase(.uppercase)` at the view layer. Zero occurrences found in Phase 03 files.

**WARNING: `WarmupRampRows` "W{N}" uses `Font.caption .foregroundStyle(.secondary)`**
The spec mandates `displayMedium` 18pt `bruSignal`. The implementation uses the smallest semantic font size in a secondary foreground color.

---

### Pillar 5: Spacing (2/4)

**WARNING: No BRU named spacing scale tokens are used**
The spec defines xs=4pt, sm=8pt, md=12pt, lg=16pt, xl=24pt, 2xl=32pt, 3xl=48pt as named design tokens. The implementation uses raw integers throughout: `.padding(.vertical, 4)`, `.padding(.horizontal, 8)`, `.padding(.vertical, 12)`, `.padding(.horizontal, 16)`, `HStack(spacing: 12)`, etc. While several values happen to be on the 4pt grid, they are not expressed through the token system.

**WARNING: Spacing values are reasonably aligned to 4pt grid in most cases**
Most padding values in Phase 03 files are multiples of 4: 4, 8, 12, 16. These are consistent with the scale without using named tokens. Not a hard blocker but reinforces the v1/ad-hoc implementation stance.

**BLOCKER: `BumpBanner` uses non-spec outer padding (`.padding(.horizontal, 16).padding(.vertical, 8)` applied twice — inner and outer)**
The spec mandates 52pt height with sm (8pt) internal content padding. The implementation has both an inner content padding and an outer padding on the containing element, adding up to 16pt vertical padding outside the banner — not matching the spec's flat-ink-slab-with-sm-internal-padding model.

**WARNING: `PlateStackDisclosure` plate rectangles are 24pt tall, not the spec's proportional formula**
The spec defines `height = 40pt + plateWeight × 0.8pt` for full-size visualization. The implementation uses a fixed `height: 24` for all plates — a uniform height that does not reflect plate weight dimensionally.

**WARNING: `PlateStackDisclosure` plate widths use `CGFloat(max(8, min(32, weight)))` — off-spec**
The spec formula is `width = max(8pt, plateWeight × 0.4pt)`. The implementation uses `min(32, weight)` as a direct pixel mapping, capping much lower than the spec's proportional formula for heavy plates.

**PASSING: 44pt touch target on `PrescriptionWeightCell` info.circle confirmed**
`.frame(minWidth: 44, minHeight: 44)` at `PrescriptionWeightCell.swift:108` — compliant with the 44pt touch target requirement even though the icon itself is deprecated in v2.

---

### Pillar 6: Experience Design (3/4)

**PASSING: Loading and empty states are well-handled**

State coverage analysis:
- `PlateInventoryEditor` no-plates state: `ContentUnavailableView` with verbatim copy — PRESENT
- `PlateStackDisclosure` below-bar state: informational caption — PRESENT
- `PlateStackDisclosure` no-solution state: error caption with `systemRed` foreground — PRESENT
- `PlateCalculatorSheet` no-combination state: "No combination found" + footer — PRESENT (duplicated in section body and footer; minor redundancy)
- `WhyThisWeightSheet` no-prior-data state: "No prior data — starting fresh." in last session row — PRESENT
- `WarmupRampRows` empty/lightweight state: "Warm up however you'd like." placeholder — PRESENT

**PASSING: Destructive actions confirmed**
- Plate row swipe-to-delete: `.swipeActions(edge: .trailing, allowsFullSwipe: false)` with `Button("Delete", role: .destructive)` — PRESENT
- "Reset to Defaults": `.alert("Reset plate inventory?", ...)` with "Reset" destructive role and "Cancel" — PRESENT and verbatim
- Cancel confirmation model for WarmupConfigSheet: dismisses without writing state — PRESENT

**PASSING: Disabled states confirmed**
- "Add" button in add-plate sheet is disabled when input is empty or non-numeric: `.disabled(Double(newPlateWeightText) == nil || newPlateWeightText.isEmpty)` at `PlateInventoryEditor.swift:241` — PRESENT

**PASSING: Manual override flag tracking confirmed**
`wasManualOverride` written by `PrescriptionWeightCell.onChange` when user weight diverges from prescribed weight — functional and tested (ManualOverrideTests: 4/4 GREEN).

**WARNING: `PlateCalculatorSheet` "No combination found" is duplicated in two places**
Section body `Text("No combination found")` at line 96 and section footer at line 104 render the same content. The footer should be the sole location per the spec.

**WARNING: `WhyThisWeightSheet` interaction model differs from spec**
The spec mandates opening via long-press on the weight cell (or a trailing action — "implementation-time TBD"). The implementation opens the sheet via the `info.circle` SF Symbol button, which is the v1 model. This affects interaction flow discoverability.

**WARNING: `BumpBanner` dismissal is correct (delegated to parent card) but the banner text uses `Font.headline` rather than the spec's `labelSmall` 11pt 1.2 letterspacing**
The dismissal model is correctly implemented in `SessionExerciseCard` using `.onTapGesture { bannerDismissed = true }`. The visual rendering of the text is the defect.

**WARNING: Reduced-motion animation in `PlateStackDisclosure` is applied to `value: targetWeight` rather than the expand/collapse animation**
The spec mandates the reduced-motion gate on the slide-in animation of the disclosure panel. The implementation applies `.animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: targetWeight)` — this gates on weight changes, not the expand/collapse transition. The expand/collapse is managed by the parent `SessionExerciseCard` via conditional rendering and is not gated at all.

---

## Files Audited

**Planning documents:**
- `.planning/phases/03-smart-prescription-warm-ups/03-UI-SPEC.md` (v2 BRU contract — primary baseline)
- `.planning/phases/03-smart-prescription-warm-ups/03-01-SUMMARY.md` through `03-08-SUMMARY.md`
- `.planning/phases/03-smart-prescription-warm-ups/03-01-PLAN.md` (schema)

**Swift source (Phase 03 UI files):**
- `fitbod/Sessions/WhyThisWeightSheet.swift`
- `fitbod/Sessions/PrescriptionWeightCell.swift`
- `fitbod/Sessions/PlateStackDisclosure.swift`
- `fitbod/Sessions/BumpBanner.swift`
- `fitbod/Sessions/CalibratingBadge.swift`
- `fitbod/Sessions/WarmupRampRows.swift`
- `fitbod/Sessions/SessionExerciseCard.swift` (integration wiring)
- `fitbod/Settings/PlateInventoryEditor.swift`
- `fitbod/Settings/PlateCalculatorSheet.swift`
- `fitbod/Settings/SettingsView.swift` (Smart Progression section)
- `fitbod/Routines/WarmupConfigSheet.swift`
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (Prescription Settings section)

**Asset files:**
- `fitbod/Assets.xcassets/AccentColor.colorset/Contents.json`
- `fitbod/Assets.xcassets/*.colorset` (full catalog enumerated)

---

## Summary of Defects by Category

| Category | Count | Severity |
|----------|-------|----------|
| BRU primitives not built | 4 components | BLOCKER |
| BRU color palette absent | 8 tokens | BLOCKER |
| BRU font faces not bundled | 2 faces | BLOCKER |
| AccentColor regression | 5 sites | BLOCKER |
| v1 plate color scheme | 2 files | BLOCKER |
| Capsule/rounded shapes | 3 views | BLOCKER |
| SF Symbol info.circle retained | 1 site | BLOCKER |
| Stepper used instead of PlateTallyRow | 1 view | BLOCKER |
| Dynamic Type semantic styles | All Phase 03 views | BLOCKER |
| No UPPERCASE/letterspacing | All label strings | BLOCKER |
| Copy structural deviations | 4 surfaces | WARNING |
| Spacing non-tokenized | All Phase 03 views | WARNING |
| Interaction model v1 (long-press vs. icon) | 1 surface | WARNING |

**Root cause:** Phase 03 was executed under the v1 UI-SPEC (Apple HIG stance) before the BRU v2 rewrite. The execution plans (03-06, 03-07, 03-08 PLANs) reference Phase 02 color conventions which were themselves written to the v1 spec. None of the Phase 02 BRU primitives (`BRUFont`, `BRUChip`, `BRUButton`, `BRUSectionHead`, `BRUHeaderBar`, `BRUDivider`) appear to have been built in Phase 02 either — the entire BRU design system layer is missing from the codebase, not just Phase 03.
