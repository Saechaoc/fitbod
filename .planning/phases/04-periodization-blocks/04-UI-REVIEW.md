---
phase: 4
slug: periodization-blocks
status: complete
audited: 2026-05-23
baseline: 04-UI-SPEC.md v3 (approved 2026-05-23) + 02-UI-SPEC.md (locked BRU primitives)
screenshots: not captured — iOS SwiftUI native project; no dev server applicable
overall_score: 9
overall_max: 24
---

# Phase 4 — UI Review

**Audited:** 2026-05-23
**Baseline:** `04-UI-SPEC.md` v3 (approved 2026-05-23) + `02-UI-SPEC.md` (locked BRU primitives)
**Screenshots:** Not captured (iOS native SwiftUI; no Playwright path)
**Registry audit:** Skipped — no `components.json` (native SwiftUI; shadcn N/A)

> **Context for the score:** The UI-SPEC was approved retroactively after Phase 4 shipped. The Phase 4 code implements the pre-BRU `04-CONTEXT.md` D-07 heat-map palette (teal/amber/orange/gray) and Apple `Form`/`Section` layouts that predate the BRU contract. Drift is systematic and full-layer — BRU was not applied during execution. The code is internally consistent with the pre-spec intent.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 2/4 | Core strings correct; Blocks empty-state heading, `ConsiderDeloadBanner` header, several BRU-mandated copy treatments drifted |
| 2. Visuals | 1/4 | Full BRU visual layer absent — no ink hero bands, no timeline bar, no week-ticker strip, no phase-data grid, no signal-orange fills |
| 3. Color | 1/4 | BRU color tokens never registered; `AccentColor` is the old Phase 1 teal; `Color.red` / `Color.yellow` used directly |
| 4. Typography | 1/4 | BRU font system not implemented; Dynamic Type semantic styles (`.headline`/`.caption`/`.body`) used on every Phase 4 surface |
| 5. Spacing | 2/4 | Outer 16pt `lg` padding mostly correct; inner spacing uses non-spec values (6pt vertical, `spacing: 10`); BRU border constants absent |
| 6. Experience Design | 2/4 | State coverage solid; 5 SF Symbols violate BRU contract; accessibility spec partially met; reduced-motion gate missing |

**Overall: 9 / 24**

---

## Top 3 Priority Fixes

### 1. BRU color token registration (Pillar 3 — BLOCKER)

All Phase 4 surfaces use the pre-BRU `AccentColor` teal instead of `bruInk`/`bruPaper`/`bruSignal`. Every other color deficit flows from this absence.

**Fix:**
1. Register 8 BRU `Color` assets in `Assets.xcassets`:
   - `bruInk #0A0A0A`, `bruPaper #FAFAF7`, `bruSignal #FF5C1A`
   - `bruFaint #E8E5DD`, `bruHair #D4D0C5`, `bruMuted #6E6A60`
   - `bruBg #F2EFE7`, `bruBg2 #EDEAE0`
   - Add dark-mode variants per `02-UI-SPEC.md`.
2. Replace every `Color.accentColor`, `Color.red`, `Color.yellow`, `Color(.systemGray6)`, `Color(.secondarySystemGroupedBackground)` in `fitbod/Periodization/` with the BRU equivalent.

**User impact:** Current app looks identical to Phase 1/2 Apple HIG style — brutalist design contract is entirely invisible.

### 2. BRU typography implementation (Pillar 4 — BLOCKER)

No SpaceGrotesk or JetBrains Mono fonts are bundled; no `BRUFont` enum exists. Every surface uses Dynamic Type semantic styles instead of the locked explicit-point BRU type scale.

**Fix:**
1. Add font files under `fitbod/Resources/Fonts/`:
   - `SpaceGrotesk-Bold.otf`, `SpaceGrotesk-SemiBold.otf`
   - `JetBrainsMono-Regular.otf`, `JetBrainsMono-Bold.otf`
2. Declare in `Info.plist` `UIAppFonts`.
3. Create `BRUFont.swift` with the 7-role enum (`displayHero`, `displayLarge`, `displayMedium`, `bodyEmphasis`, `bodyDefault`, `labelSmall`, `labelMicro`) per `02-UI-SPEC.md` sizes.
4. Replace all Dynamic Type font calls in `fitbod/Periodization/` with explicit BRU roles.

**User impact:** All Phase 4 text renders in system-default Apple fonts instead of the brutalist display+mono pairing the mockups depend on.

### 3. Rebuild `BlockBuilderView` and `BlockReviewView` (Pillar 2 — BLOCKER)

Both primary Phase 4 surfaces render as `Form { Section { ... } }` Apple HIG inset-grouped forms. Spec mandates BRU-composed layouts.

**Fix — `BlockBuilderView`:**
- Full-bleed `bruPaper` background
- 2pt `bruInk` bottom border on header band
- 56pt TIMELINE visual with `Canvas`-drawn phase-proportional bars (ink-filled past, `bruSignal`-filled current, 25% opacity future, diagonal-stripe deload)
- `BlockPhaseEditorRow` with `labelMicro` 3-column data grids inside 1pt `bruInk` cell borders
- "Apply changes ▸" `BRUButton kind="primary"` (not toolbar "Save")

**Fix — `BlockReviewView`:**
- Full-bleed `bruInk` hero band with `displayLarge` 36pt block name in `bruPaper`
- Three `displayHero` 48pt stat columns: SESSIONS / TONNAGE / PRS
- `bruSignal` color on TONNAGE value
- e1RM list with `GeometryReader` progress bars (bruInk fill + bruSignal cursor mark)
- `bruBg2` recommended-next footer
- `BRUButton kind="signal"` "Start next ▸" CTA

Replace `Form`/`Section` structure entirely with `ScrollView` + `VStack` bodies.

---

## Detailed Findings

### Pillar 1 — Copywriting (2/4)

**Correct (spec-verbatim) strings shipped:**

| File | Line | String |
|------|------|--------|
| `DeloadWeekBanner.swift` | 19 | "Deload week — recover, don't load." |
| `DeloadWeekBanner.swift` | 21 | "Working sets cut by ~50%. Weights held to phase intensity." |
| `StartBlockCTA.swift` | 19, 21, 25 | "No active block." / "Define a training block…" / "Start a Block" |
| `BlockBuilderView.swift` | 35, 71, 172 | "Block name is required." / "Add at least one phase." / "Couldn't save block. Try again." |
| `BlockReviewView.swift` | 98 | "Not enough sessions logged to compute deltas." |
| `RoutinesListView.swift` | 201 | "Linked routines stay; sessions logged under this block keep their snapshot context." |

**Drifted strings (WARNING):**

**`RoutinesListView` Blocks empty-state:**
- `RoutinesListView.swift:288`: ships "No blocks yet." — spec: "No blocks defined."
- `RoutinesListView.swift:290-293`: ships "Define a training block to organize routines into a mesocycle." — spec: "Create a training block to track mesocycles, phases, and scheduled deloads."
- Missing "+ NEW BLOCK" signal text CTA; ships a `Menu { ... }` labeled "+ Block" instead.

**`ConsiderDeloadBanner`:**
- `ConsiderDeloadBanner.swift:29`: ships "Consider a deload this week." as primary — spec: "▲ FATIGUE ADVISORY" header (matching `DeloadWeekBanner`'s "▲ DELOAD WEEK" pattern), with body for the reason.
- Ships an "Adjust block" button (not in spec) and SF Symbol `xmark` dismiss instead of `BRUChip "DISMISS"`.

**`BlockBuilderView` CTA:**
- Toolbar button labeled "Save" — spec mandates "Apply changes ▸" as primary `BRUButton kind="primary"`.
- Section header right action: `Menu("+ Phase")` — spec mandates "+ ADD PHASE" as `BRUSectionHead` right action text.

**`BlockReviewView` section headers:**
- "Total volume" (not in spec — spec uses hero band stats pattern)
- "e1RM deltas" — spec uses "e1RM movement"
- "PRs hit" — spec uses "PRS" in hero band, not standalone section
- "Recommended next phase" — spec uses "RECOMMENDED NEXT BLOCK" with `displayLarge` "Strength · 4 weeks"

**Copy-case rendering:** Spec mandates `.textCase(.uppercase)` on all `labelSmall` elements. Not wired anywhere (inert without BRU type roles).

### Pillar 2 — Visuals (1/4)

BLOCKER — BRU visual contract entirely unimplemented.

**`BlockBuilderView`** — standard `Form` with `.insetGrouped`. Spec mandates: full-bleed `bruPaper` background, 2pt `bruInk` header band, 56pt TIMELINE visual with phase-proportional bars, week-column labels, `displayMedium` 26pt ordinals, `bruSignal` left-edge 4pt stripe on NOW row, 3-column data grid with 1pt `bruInk` cell borders. None present.

**`BlockPhaseEditorRow`** — `VStack` with `Stepper`/`LabeledContent`. Spec mandates: `displayMedium` 26pt ordinal, `bodyEmphasis` 14pt phase name, `⋮⋮` drag glyph (SF Symbol `line.3.horizontal` used instead), `labelMicro` 8pt WEEKS/VOL/INT labels inside 1pt-bordered cells.

**`BlockCard`** — `RoundedRectangle(cornerRadius: 12)` with `TabView` pages. Spec mandates: `bruPaper` fill, 2pt `bruInk` bottom border, `BRUChip "Block"` + `labelSmall` 11pt name + signal-fill phase chip in a row, 28pt week-ticker strip with `bruInk`-filled active cell, `bruFaint` past cells, `bruSignal` DL badge. Week-ticker strip absent.

**`BlockReviewView`** — `Form` with sections. Spec mandates: full-bleed `bruInk` hero band with `displayLarge` 36pt block name in `bruPaper`, three `displayHero` 48pt stat values, `bruSignal` on TONNAGE, scrollable e1RM list with `GeometryReader` progress bars, `bruBg2` footer. None of these hero-band elements exist.

**`DeloadWeekBanner`** — `RoundedRectangle(cornerRadius: 12)` + `BlockPhaseColors.tint(for: .deload)` background. Spec: sharp 0-radius corners, `bruBg2` background, 2pt `bruInk` top border. Rounded card shape directly contradicts the BRU "zero rounded corners" stance.

**`ConsiderDeloadBanner`** — `Color(.systemYellow).opacity(0.15)` background. Spec: `bruBg2` background, `bruSignal` "▲ FATIGUE ADVISORY" header in `labelSmall`. SF Symbol `exclamationmark.triangle` is explicitly prohibited (BRU uses typographic `▲` only).

**`BlockRow`** — `Circle()` active indicator. Spec mandates `Rectangle().fill(.bruSignal).frame(width: 6, height: 6)` (no circles in BRU). `Capsule()` for week badge — spec: rectangular `BRUChip` with 1pt `bruInk` border.

**`StartBlockCTA`** — `Color(.secondarySystemGroupedBackground)` + `RoundedRectangle(cornerRadius: 12)`. Spec: `bruPaper`, no rounded corners, specific BRU typography hierarchy.

### Pillar 3 — Color (1/4)

BLOCKER — Zero BRU color tokens registered or used.

**No BRU asset catalog entries.** `Assets.xcassets` contains only `AccentColor` (teal `#0E0D87`/`#3FBFC9` equivalent from component values `r=0.055, g=0.486, b=0.525`), plus Phase 5 volume colors. The 8 BRU tokens are completely absent.

**`BlockPhaseColors.swift` uses pre-BRU D-07 palette:**

| Line | Current | Spec |
|------|---------|------|
| 15 | `Color.accentColor` (accumulation) | `Color("bruInk")` |
| 17-18 | `Color(red: 0.96, green: 0.62, blue: 0.04)` amber (intensification) | `Color("bruSignal")` (#FF5C1A) |
| 19-20 | `Color(red: 0.92, green: 0.34, blue: 0.05)` orange (realization) | `Color("bruInk").opacity(0.25)` |
| 21-22 | `Color(red: 0.58, green: 0.64, blue: 0.72)` slate (deload) | Diagonal stripe `Canvas` pattern |

**Direct color literals violating BRU contract:**

| File | Line | Found | Required |
|------|------|-------|----------|
| `BlockBuilderView.swift` | 37, 73, 97 | `Color.red` | `Color("bruSignal")` (BRU has no destructive token) |
| `BlockBuilderView.swift` | 86, 119 | `Color.accentColor` | `Color("bruSignal")` |
| `BlockPickerMenu.swift` | 38, 51, 57 | `Color.accentColor` | `Color("bruSignal")` |
| `ConsiderDeloadBanner.swift` | 27 | `Color.yellow` on `Image` | typographic `▲` in `bruSignal` |
| `ConsiderDeloadBanner.swift` | 50 | `Color(.systemYellow).opacity(0.15)` | `Color("bruBg2")` |
| `MesocycleWeekPage.swift` | 35-36 | `Color(.systemGray6)` + `Capsule()` | `bruInk`-outlined rectangular chip |
| `StartBlockCTA.swift` | 31 | `Color(.secondarySystemGroupedBackground)` | `Color("bruPaper")` |
| `BlockRow.swift` | 48 | `Color(.systemGray6)` for week badge | `bruInk`-outlined chip |

**60/30/10 distribution** — Cannot be assessed because BRU base layer is absent. Current distribution: `systemBackground` 60%, teal `accentColor` accent, system grays — the inverse of the BRU contract.

### Pillar 4 — Typography (1/4)

BLOCKER — BRU font system not implemented.

- `fitbod/Resources/Fonts/` does not exist.
- No `.otf` files for SpaceGrotesk / JetBrains Mono.
- No `BRUFont` enum (grep confirmed: zero results for `BRUFont`, `SpaceGrotesk`, `JetBrains`).
- No `UIAppFonts` registration.

**Every Phase 4 view uses forbidden Dynamic Type semantic styles:**

| File | Found | Spec |
|------|-------|------|
| `BlockBuilderView.swift` | TextField + `.font(.caption)` | `displayLarge` 32pt name, `labelSmall` 9pt "BLOCK NAME" label |
| `BlockPhaseEditorRow.swift` | no explicit font | `displayMedium` 26pt ordinal, `bodyEmphasis` 14pt name, `labelMicro` 8pt grid labels, `displayMedium` 20pt grid values |
| `BlockCard.swift:70` | `.font(.headline)` | `labelSmall` 11pt; entire week-ticker absent |
| `MesocycleWeekPage.swift:23` | `.font(.caption)` | `labelSmall` chip label |
| `MesocycleWeekPage.swift:32` | `.font(.headline)` | `displayMedium` 16pt / `labelSmall` week labels |
| `BlockRow.swift:36` | `.font(.body)` | `bodyEmphasis` 13pt Bold |
| `BlockRow.swift:38` | `.font(.caption)` | `labelSmall` muted |
| `DeloadWeekBanner.swift:20` | `.font(.headline)` | `labelSmall` 10pt 1.5 letterspacing `bruSignal` |
| `DeloadWeekBanner.swift:22` | `.font(.caption)` | `bodyDefault` 11pt muted |
| `BlockReviewView.swift:81` | `.font(.headline)` (total kg) | `displayHero` 48pt `bruPaper` |
| `ConsiderDeloadBanner.swift:30` | `.font(.body)` | `labelSmall` 10pt 1.5 letterspacing `bruSignal` |
| `StartBlockCTA.swift:20` | `.font(.headline)` | `displayLarge` 28pt `bruInk` |

**SF Symbol icon substitutes (BRU prohibits SF Symbols on Phase 4 surfaces):**

- `BlockPhaseEditorRow.swift:24` — `Image(systemName: "line.3.horizontal")` → `⋮⋮` glyph in `BRUMono` 12pt `bruMuted`
- `BlockCard.swift:113` — `Image(systemName: "ellipsis.circle")` → `•••` typographic glyph

### Pillar 5 — Spacing (2/4)

Outer 16pt `lg` horizontal inset is consistently correct. Inner spacing has several deviations.

**Correct:**
- `BlockCard.swift:74, 88`: `.padding(.horizontal, 16)` + `.padding(.vertical, 8)`
- `DeloadWeekBanner.swift:26`: `.padding(16)` + outer 16pt/8pt
- `ConsiderDeloadBanner.swift:49, 52, 53`: 16pt horizontal / 8pt vertical
- `StartBlockCTA.swift:30, 33, 34`: `.padding(16)` interior, 16pt outer
- `MesocycleWeekPage.swift:68`: `.padding(16)` interior

**Drifted:**
- `BlockPhaseEditorRow.swift:50`: `.padding(.vertical, 6)` — spec: `md=12pt` (JSX uses `padding: '12px 16px'`; pre-spec 6pt is wrong).
- `BlockPhaseEditorRow.swift:64-65`: `.padding(.horizontal, 12).padding(.vertical, 6)` on kind chip — spec: `4pt vertical / 8pt horizontal` per phase-data grid cell rule. 12pt horizontal too wide.
- `BlockRow.swift:46-47`: `.padding(.horizontal, 8).padding(.vertical, 4)` for week badge — at xs/sm range; outer row uses no explicit padding (relies on List default insets).
- **Missing border constants:** No `Rectangle().fill(.bruInk).frame(height: 2)` or `frame(height: 1)` border rules. `DeloadWeekBanner` no top 2pt rule. `BlockCard` no bottom 2pt border. All BRU section-level 2pt ink rules absent.

**Arbitrary value:** `BlockPhaseEditorRow.swift:20`: `spacing: 10` in `VStack` — 10pt is not in BRU set `{4, 8, 12, 16, 24, 32, 48, 64}`.

### Pillar 6 — Experience Design (2/4)

**State coverage (PASS):**
- Loading: `RootView` splash + per-component empty states.
- Empty: `BlockBuilderView` "Add a phase…", `BlockReviewView` e1RM empty string, `MesocycleWeekPage` "No routines linked to this block.", `StartBlockCTA` no-active-block — all present.
- Error: Inline validation + save-failure strings.
- Destructive: Delete block + End block + Discard alerts with `.destructive` role.
- Single-active invariant: Overlay warning copy correct.

**SF Symbol violations (WARNING — BRU prohibits SF Symbols on Phase 4 surfaces):**

| File | Line | Found | Required |
|------|------|-------|----------|
| `BlockPhaseEditorRow.swift` | 24 | `line.3.horizontal` | `⋮⋮` typographic |
| `BlockCard.swift` | 113 | `ellipsis.circle` | `•••` typographic |
| `ConsiderDeloadBanner.swift` | 26 | `exclamationmark.triangle` | `▲` typographic |
| `ConsiderDeloadBanner.swift` | 43 | `xmark` | `×` typographic or `BRUChip "DISMISS"` |
| `MesocycleWeekPage.swift` | 58 | `chevron.right` | `›` typographic |
| `BlockRow.swift` | 57 | `trash` swipe action | acceptable (system alert chrome) |

**Accessibility spec gaps:**
- `BlockCard.swift:91`: `accessibilityHint` only; missing `accessibilityLabel = "Active block: {name}, {phaseKind} phase, week {N} of {M}."`
- `BlockPhaseEditorRow.swift:51`: row hint "Delete" is misleading; missing `accessibilityLabel = "Phase {ordinal}: {kind}"`
- `BlockOverviewScreen` not implemented at all — entire spec view absent

**Reduced-motion gate (WARNING):**
- `BlockCard.swift`: `TabView(.page(indexDisplayMode: .never))` for week pager — no `@Environment(\.accessibilityReduceMotion)` check. Spec mandates snap-without-slide when `reduceMotion` is true.

**Missing `BlockOverviewScreen`:** Spec defines a separate full-screen view (reachable by tapping `BlockCard`). Does not exist. Tapping `BlockCard` opens `BlockBuilderView` edit mode instead. The week carousel, phase progression list, and fatigue advisory strip that compose `BlockOverviewScreen` are entirely absent.

---

## Registry Safety

Not applicable — no `components.json` (native SwiftUI; shadcn N/A).

---

## Files Audited

- `fitbod/Periodization/BlockBuilderView.swift`
- `fitbod/Periodization/BlockPhaseEditorRow.swift`
- `fitbod/Periodization/BlockPhaseColors.swift`
- `fitbod/Periodization/BlockCard.swift`
- `fitbod/Periodization/BlockReviewView.swift`
- `fitbod/Periodization/DeloadWeekBanner.swift`
- `fitbod/Periodization/ConsiderDeloadBanner.swift`
- `fitbod/Periodization/BlockRow.swift`
- `fitbod/Periodization/StartBlockCTA.swift`
- `fitbod/Periodization/BlockPickerMenu.swift`
- `fitbod/Periodization/MesocycleWeekPage.swift`
- `fitbod/App/RootView.swift` (TodayView private struct)
- `fitbod/Routines/RoutinesListView.swift` (blocksSection)
- `fitbod/Assets.xcassets/` (all colorsets)
- `fitbod/Resources/Fonts/` (absent — confirmed)
- `bru-screens/block-builder.jsx`, `block-overview.jsx`, `block-review.jsx`, `today.jsx`
- `.planning/phases/04-periodization-blocks/04-UI-SPEC.md` (v3)
- `.planning/phases/02-core-loop-routines-sessions/02-UI-SPEC.md` (locked)

---

## Verdict

**Severity:** 3 BLOCKERs (Pillars 2/3/4 at score 1), 10+ WARNINGs, several minor recommendations.

**Recommended path forward:**

The drift is systematic (entire BRU layer missing), not incremental. Two options:

1. **Project-wide BRU implementation phase** — create a new Phase that registers BRU color tokens + fonts + primitive views + `BRUFont` enum once, then retroactively migrates Phase 2, 3, 4, and 6 surfaces in waves. This is the right answer for a personal app where visual consistency matters.
2. **Accept current Phase 4 visual layer as tech debt** — mark this UI-REVIEW as documented drift, defer BRU migration to a v1.1+ "visual polish" milestone. Acceptable if you want to keep shipping function over form for v1.

Either is defensible. The audit's job is to make the gap visible — the path is your call.
