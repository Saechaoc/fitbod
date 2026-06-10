# Phase 7: BRU Visual Rewrite (Final — Library + Prescription + Fatigue + Progress) - Context

**Gathered:** 2026-05-23
**Status:** Ready for planning — with prerequisites (see Canonical References)
**Mode:** Interactive discuss-phase (default mode, 4 initial gray areas + 3 follow-ups, no scope creep)

<domain>
## Phase Boundary

Phase 7 is the **final BRU Visual Rewrite** — it ports the remaining four phases of user-facing surfaces (Phase 1 Library, Phase 3 Smart Prescription & Warm-ups, Phase 5 Fatigue Model & Plateau Detection, Phase 6 Progress Views & Export) from Apple HIG defaults to the BRU brutalist design system locked in their respective `*-UI-SPEC.md` v2 contracts.

This phase closes the systematic BRU gap captured in memory ("BRU is locked in 02-UI-SPEC.md but never shipped; phases 2-6 use Apple HIG defaults"). After Phase 02.1 (Phase 2 surfaces) + Phase 04.1 (Phase 4 surfaces) + Phase 7 (Phase 1, 3, 5, 6 surfaces) all complete, every user-facing surface in the app renders against the BRU design contract — zero `Color.accentColor`, zero `.font(.body/.headline/.title*)`, zero `Image(systemName:)` outside the documented exception list, zero `RoundedRectangle(cornerRadius:)`, zero `Capsule()` clips remain across the codebase.

**Per-phase surfaces in scope:**

1. **Phase 1 — Library:**
   - `ExerciseLibraryView` (browse + filter + search at 1000+ items)
   - `ExerciseDetailView` (single-exercise destination)
   - `CustomExerciseForm` (create + edit; save-blocking primary-muscle requirement preserved)
   - bru-screens reference: `library.jsx`, `exercise-detail.jsx`, `custom-exercise.jsx`

2. **Phase 3 — Smart Prescription & Warm-ups:**
   - `WhyThisWeightSheet` (the ink hero slab — primary v2 destination)
   - `PlateStackViz` / `PlateStackDisclosure` (replace v1 color-coded plates with `bruInk` fill + rotated `bruPaper` labels)
   - `PlateCalcSheet` (ink-outlined target display band + `displayHero` 96pt weight + `bruBg2` plate-stack zone)
   - `PlateInventoryEditor` (`PlateTallyRow` 4-tally visual — replace `Stepper`)
   - `CalibratingProgressMeter` / `CalibratingBadge` (flat `bruInk` rectangle, NOT capsule)
   - `BumpBanner` → `BumpBannerSlab` (flat 52pt `bruInk` rectangle, NOT pill, NOT green tint)
   - `WarmupRampRows` (`displayMedium` 18pt `bruSignal` `W{N}` index; drop systemBlue chip + add mini `PlateStackViz`)
   - `PrescriptionWeightCell` (remove `info.circle` SF Symbol; disclosure triggered by cell tap)
   - `WarmupConfigSheet` (UPPERCASE BRU header bar)
   - bru-screens reference: `why-weight.jsx`, `plate-calc.jsx`

3. **Phase 5 — Fatigue Model & Plateau Detection:**
   - `FatigueSurfaceView` (Today-tab volume + heatmap section host)
   - `MuscleVolumeBar` (BRU two-tone bars with verbatim D-06 verb labels — already lockedcopy)
   - `BodySilhouetteView` + `MuscleRegionPaths` (heatmap — keep `Canvas` + bezier paths; recolor to 4 new `bruZone*` colorsets)
   - `PerMuscleDetailView` (4-section drill-down — This Week / Contributing Exercises / Frequency / Adjust Targets)
   - `MuscleVolumeTargetEditor` + `MuscleVolumeTargetStepper` (Settings + inline editors)
   - `StallBadge` + `SuggestedActionChip` (currently rounded capsule + `Color(.systemOrange)` — Phase 7: flat `bruInk` with `bruSignal` accent)
   - `TryVariationSheet` (BRU header + list shell)
   - `DeloadAdvisoryBanner` + `DeloadSignalDetailSheet` (currently amber-tinted; Phase 7: ink slab + signal accent)
   - `WeeklyRecapSheet` (4-section auto-presented sheet)
   - bru-screens reference: `heatmap.jsx`, `volume.jsx`, `plateau.jsx`, `weekly-recap.jsx`

4. **Phase 6 — Progress Views, Export & Polish:**
   - `ProgressHomeView` (Progress tab root — Recent / Trends / Compare sections)
   - `ExerciseProgressView` (Swift Charts intent-split line chart + series toggle chips; BRU-skinned `LineMark`/`PointMark`)
   - `WeeklyTonnageView` + `WeekDetailView` (`BarMark` + 3 chip filter rows + `RuleMark` previous-best)
   - `ExercisePRsView` (4×3 PR layout — Weight / Reps / Volume / e1RM × intent toggle)
   - `SessionComparisonView` (3-column Δ diff with U+2212 minus + verbatim sign formatting)
   - `InSessionPRBanner` (currently capsule via `.safeAreaInset(edge: .top)` — Phase 7: flat `bruInk` slab, preserve mount)
   - `SettingsView` Data section (4 rows: Export CSV / Export JSON / Create Backup / Restore from Backup)
   - bru-screens reference: `progress-chart.jsx`, `settings.jsx`, `weekly-recap.jsx` (Phase 5 cross-ref)

**Behavioral preservation contract.** All Phase 1/3/5/6 functional behavior (library filters + search; snapshot pattern; progression strategies; plate calculator; warm-up generator; fatigue computation; stimulus-weighted volume; plateau detector; deload advisory; weekly recap trigger; chart math; PR detection; export DTOs; backup round-trip) is preserved verbatim. This is a pure visual rewrite — the engine, persistence layer, services, and tests stay intact. Existing functional unit tests MUST remain GREEN throughout Phase 7 execution per the Hard regression bar (D-13).

**Out of scope.** Phase 2 surfaces (owned by 02.1). Phase 4 surfaces (owned by 04.1). Launch screen, app icon, marketing screens, onboarding overlays, Watch app, widgets BRU restyling, HealthKit integration, iCloud/CloudKit sync — none of which exist in v1 or are deferred to v2.

</domain>

<decisions>
## Implementation Decisions

### Area 1 — Scope (multi-select)

- **D-01:** Phase 7 covers Phase 1 + Phase 3 + Phase 5 + Phase 6 surfaces. All four source phases lack BRU implementation. Phase 2 BRU work stays in 02.1; Phase 4 BRU work stays in 04.1. Phase 7 does NOT absorb those siblings; dependency relationship only.

### Area 2 — UI-REVIEW prerequisite

- **D-02:** Run `/gsd-ui-review 1`, `/gsd-ui-review 5`, `/gsd-ui-review 6` BEFORE `/gsd-plan-phase 7`. Each produces a `{N}-UI-REVIEW.md` audit with per-pillar scores (Copywriting / Visuals / Color / Typography / Spacing / Experience Design) + concrete `file:line` gap inventory + Wave A-G migration backlog. Phase 3 already has `03-UI-REVIEW.md` (committed c025996, 10/24 baseline) — reused as-is.
- **D-03:** UI-REVIEWs are MANDATORY plan-phase inputs. Planner reads all 4 UI-REVIEW.md files (01 + 03 + 05 + 06) and all 4 UI-SPEC.md files plus the 12 in-scope bru-screens/*.jsx mockups to derive the per-surface migration backlog. Planner refuses to plan a block without its audit.

### Area 3 — Foundation dependency

- **D-04:** Phase 7 hard-depends on Phase 02.1. The BRU foundation (8 `bru*.colorset` assets, 4 OFL `.otf` font files, `Color+BRU.swift`, `BRUFont.swift`, `Info.plist` UIAppFonts entry) is shipped by `02.1-01-PLAN.md` Wave A. Phase 7 plans ASSUME `Color.bruInk` / `BRUFont.displayHero` / etc. exist and bind directly. ROADMAP Phase 7 entry must declare `Depends on: Phase 02.1, Phase 04.1, Phase 6`.
- **D-05:** Phase 7 also depends on the 02.1 plan(s) that ship the 15+ BRU primitive components (`BRUHeaderBar`, `BRUTabBar`, `BRUChip`, `BRUDisplay`, `BRUReadout`, `BRUSectionHead`, `BRUButton`, `BRUSpark`, `BRUDivider`, `BRUDashedSlot`, `BRUPillButton`, `BRUSupersetBracket`, `BRUCornerBadge`, `SetCompletionGlyph`, `RestTimerProgressArc`). These compose every Phase 7 surface — they MUST exist before any Phase 7 surface plan executes. Currently only `02.1-01-PLAN.md` is written; additional 02.1 plans for the primitive library must land first.
- **D-06:** **New primitive discovery during Phase 7.** If a Phase 7 surface needs a primitive not in the 02.1 inventory (e.g., a chart-axis label helper for Swift Charts, a Canvas zone-tint helper, a flat PR-banner slab), the new primitive lands in `fitbod/Design/` as a Phase 7 contribution — it does NOT retroactively get pushed back into 02.1. Phase 7 owns its incremental primitive additions; 02.1 owns the foundational set.

### Area 4 — Fidelity bar to bru-screens

- **D-07:** Token-strict + layout-faithful. Every surface MUST use BRU tokens (colors, fonts, spacing, no rounding, no SF Symbols outside the exception list, UPPERCASE label-class strings) AND reproduce the bru-screens composition (header bands, grids, tick rows, hero slabs). Swift Charts and Canvas internals use native chart marks / paths but with BRU stroke + fill tokens — NO JSX-emulated divs replacing `BarMark` / `LineMark` / `PointMark`.
- **D-08:** **Chart skinning discipline.** `ExerciseProgressView` Swift Charts `LineMark`/`PointMark` use `bruInk` for top-set series, `bruSignal` for all-set-avg series; hypertrophy sessions use `StrokeStyle(lineWidth: 1.5, dash: [4, 3])`, strength uses `StrokeStyle(lineWidth: 2)`. `WeeklyTonnageView` `BarMark` uses `bruInk` fill; `RuleMark` "previous best" overlay uses `bruHair` 1pt stroke. `chartXAxis` and `chartYAxis` are rebuilt with `BRUFont.labelMicro` tick labels and 1pt `bruInk` axis lines. NO `Color.accentColor`, NO `Color.blue`, NO `.foregroundStyle(by:)` palette-generated colors.
- **D-09:** **Heatmap skinning.** `BodySilhouetteView` keeps `Canvas` + existing `MuscleRegionPaths` bezier/ellipse/rounded-rect geometry (anatomically-informed approximations already shipped in plan 05-05). Recolor: zone fills map to 4 new BRU semantic colorsets that REPLACE the current `VolumeBelowMEVGray` / `VolumeProductiveGreen` / `VolumeNearMRVAmber` / `VolumeOverMRVRed` assets:
  - `bruZoneBelow` ← derived from `bruMuted`
  - `bruZoneProductive` ← derived from `bruInk` at lower opacity
  - `bruZoneNear` ← derived from `bruSignal` at 50%
  - `bruZoneOver` ← derived from `bruSignal` 100%
  The 4 old `Volume*` colorsets are deleted in Block C Wave Z grep gate. Heatmap remains custom Canvas (not Swift Charts) per PROJECT.md "Charting Decision" table.

### Area 5 — Plan/wave structure

- **D-10:** **Per-phase blocks.** Phase 7 is organized as 4 sequential plan blocks, one per source phase:
  - **Block A — Phase 1 surfaces** (3 surfaces) — depends on `01-UI-REVIEW.md` being generated first.
  - **Block B — Phase 3 surfaces** (~9 surfaces) — depends on existing `03-UI-REVIEW.md`.
  - **Block C — Phase 5 surfaces** (~12 surfaces) — depends on `05-UI-REVIEW.md`.
  - **Block D — Phase 6 surfaces** (~7 surfaces) — depends on `06-UI-REVIEW.md`. ALSO blocked on `06-10-PLAN.md` (backup/restore) executing first, because Block D Settings Data section rewrite must cover the backup/restore rows which 06-10 introduces in HIG form.
- **D-11:** **Within each block:** mirror the 02.1 wave pattern.
  - **Wave A:** grep audit purge — enumerate `Color.accentColor` / `.font(.body|.headline|.title*|.caption)` / `Image(systemName:)` / `RoundedRectangle(cornerRadius:)` / `Capsule()` / `.buttonStyle(.bordered|.borderedProminent)` references in that block's surfaces; write the per-block checklist; identify allowed exceptions inline.
  - **Wave B:** per-surface rewrites — one atomic plan per surface (or tight pair of cohesive surfaces). Each plan replaces Apple HIG with BRU primitives + adds the new BRU contract tests + updates any UI tests that bind to old HIG component trees.
  - **Wave C:** regression sweep — grep gate (zero residual references), all prior tests GREEN, new BRU contract tests GREEN, snapshot in CONTEXT-style "must_haves.truths".
- **D-12:** **Block ordering.** Default order: Phase 1 → 3 → 5 → 6 (functional-dependency order, also surface-complexity ramp). Planner may reorder surfaces within a block. Cross-block ordering is sequential — no parallelization across blocks because all 4 blocks share the 02.1 foundation, risk of test-suite churn, and the regression bar requires a stable baseline per plan.

### Area 6 — Regression bar

- **D-13:** **Hard regression bar.** Every Phase 7 plan MUST keep ALL existing Phase 1-6 functional unit + integration tests GREEN. The plan-level acceptance checklist is:
  1. `xcodebuild test` for relevant phase test target passes BEFORE plan starts (baseline snapshot).
  2. Plan implements the BRU rewrite.
  3. `xcodebuild test` passes AFTER the plan — same suite + new BRU contract tests added by this plan.
  4. Wave C grep gate passes for the block scope after the plan.
- **D-14:** **New BRU contract tests per plan.** Each surface rewrite plan ships at least one Swift Testing `@Test` that asserts the BRU contract holds. Examples:
  - **BRU primitive resolution** — `Font.custom("SpaceGrotesk-Bold", size: 48)` resolves at runtime via `UIFont(name:size:)` (registration smoke test pattern from 02.1-01).
  - **Token presence** — view body source contains `Color.bruInk` / `Color.bruSignal` references (verified via source-string assertions against `String(reflecting: view.body)` or grep-as-test pattern).
  - **Composition** — `WhyThisWeightSheet` renders an ink hero slab structure (asserted via property-reflection on the underlying `ZStack` + child `Color.bruInk` background + 128pt numeral text).
  - **Verbatim copy preservation** — Phase 5 D-06 verb copy ("Below MEV — add volume." etc.) appears character-for-character in the rewritten `MuscleVolumeBar`.
  Snapshot tests (image-pixel bitmaps) are LOW priority for v1 — they're brittle vs simulator versions and don't materially aid a single-developer review loop. Prefer structural / token / copy contract assertions.
- **D-15:** **UI tests acknowledgment.** XCUITest suites (`fitbodUITests/`) that bind to current Apple HIG component trees (e.g., `app.cells.staticTexts["Routines"]`) may need to be updated to match new BRU `BRUHeaderBar` / `BRUTabBar` / `BRUSectionHead` accessibility identifiers. UI test updates are part of each surface plan's acceptance criteria — NOT deferred to a follow-up. Each BRU primitive must expose stable `accessibilityIdentifier` strings so UI tests can rebind cleanly.

### Area 7 — Grep audit purge gates (mirror ROADMAP 02.1 success criterion #7)

- **D-16:** Phase 7 final gate (Wave Z, after all 4 blocks complete) is a grep audit across the in-scope directories (`fitbod/ExerciseLibrary/`, `fitbod/Prescription/`, `fitbod/Sessions/` overlays from Phase 3 & 5 & 6, `fitbod/Fatigue/`, `fitbod/Progress/`, `fitbod/Settings/` Data section) confirming:
  - Zero references to `Color.accentColor`, `Color.primary`, `Color(.system*)` outside the documented exception list.
  - Zero references to `.font(.body)`, `.font(.headline)`, `.font(.title)`, `.font(.title2)`, `.font(.title3)`, `.font(.caption)`, `.font(.callout)`, `.font(.footnote)`, `.font(.subheadline)` (all replaced with `BRUFont.{role}`).
  - Zero references to `Image(systemName:)` outside the per-block exception list.
  - Zero references to `RoundedRectangle(cornerRadius:)` and `.clipShape(RoundedRectangle(...))` and `.clipShape(Capsule())`.
  - Zero references to `.buttonStyle(.bordered)`, `.buttonStyle(.borderedProminent)` (replaced with `BRUButton kind="primary|secondary|signal"`).
  - Zero references to `VolumeProductiveGreen` / `VolumeNearMRVAmber` / `VolumeOverMRVRed` / `VolumeBelowMEVGray` (replaced by `bruZone*` colorsets in Block C).
- **D-17:** **Allowed exception list** is documented inline in each Wave A plan's "exception list" section with rationale (e.g., "the iOS share sheet's UTI icon is intentionally Apple-rendered; not in our control"; "`Color.accentColor` retained only in the iOS share sheet UTI"; "system tab bar a11y icons exempt per BRU primitive contract"). Exception list is finite and reviewed at plan-checker gate.

### Claude's Discretion

- Within each block, the exact split of plans (one per surface vs grouping cohesive pairs like `MuscleVolumeTargetEditor` + `MuscleVolumeTargetStepper`) — planner decides based on dependency + cohesion. Per-plan task budget ~3-8 tasks per 02.1-01-PLAN.md precedent.
- Within each plan, the wave-internal ordering (audit grep then implement vs implement then verify) — planner choice.
- Snapshot test framework decision — `swift-snapshot-testing` SPM dep vs `ViewInspector` vs source-string assertions. Recommendation: structural / token assertions; defer `swift-snapshot-testing` to v2.
- Whether to extract a shared "BRU chart skinning helpers" module (`BRUChartStyle.swift`, `BRUAxisLabels.swift`) in Block D Wave A or inline per chart view — planner decision.
- Whether `MuscleVolumeTargetEditor` and `MuscleVolumeTargetStepper` ship in one plan or split — cohesion call.
- Wave Z grep-audit allowed-exception list specifics — planner enumerates with rationale per exception; user reviews at plan-checker phase.
- Order of Phase 5 surfaces within Block C (heatmap first? volume bars first? plateau badges first?) — planner picks based on dependency graph (likely: zone colorsets first, then `MuscleVolumeBar`, then `FatigueSurfaceView` host, then heatmap, then drill-down surfaces, then badges/sheets).
- Whether `BodySilhouetteView` refactor introduces a `BRUCanvasStyle` helper for the zone-tint mapping — planner choice.
- Whether `InSessionPRBanner` and `WhyThisWeightSheet` need a shared "BRU hero slab" primitive — discovered during planning; per D-06 lives in Phase 7's `fitbod/Design/` additions.
- Exact `accessibilityIdentifier` naming convention for BRU primitives (e.g., `bru-chip-set-type-warmup` vs `BRUChip.SetType.warmup`) — planner picks and documents at first usage; consistent across blocks.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project + scope
- `.planning/PROJECT.md` — locked tech stack (SwiftUI + SwiftData, iOS 18+, zero third-party deps), charting decision (Swift Charts + custom Canvas for heatmap), what NOT to use, state management, persistence stance.
- `.planning/ROADMAP.md` § Phase 7 — phase scope anchor (currently stub — Phase 7's goal is now captured in this CONTEXT's `<domain>` section).
- `.planning/ROADMAP.md` § Phase 02.1 — 7 success criteria for the BRU foundation contract that Phase 7 depends on.
- `.planning/STATE.md` — current ship state for Phases 1-6 + plan-level closure summaries (Phase 5 + Phase 6 plan-by-plan detail for the regression-bar baseline).

### BRU design contract — UI-SPECs (4 in scope + 2 sibling)
- `.planning/phases/01-foundation-exercise-library/01-UI-SPEC.md` — Library / ExerciseDetail / CustomExercise BRU spec.
- `.planning/phases/02-core-loop-routines-sessions/02-UI-SPEC.md` — **FOUNDATION BRU PRIMITIVE CONTRACT** (color hex table, font role inventory, 15+ primitive component inventory) — Phase 7's primitives all derive from this spec via 02.1.
- `.planning/phases/03-smart-prescription-warm-ups/03-UI-SPEC.md` — Phase 3 BRU spec (ink hero slab, `PlateStackViz`, `BumpBannerSlab`, `PlateTallyRow`).
- `.planning/phases/05-fatigue-model-plateau-detection/05-UI-SPEC.md` — Phase 5 BRU spec (volume bars, heatmap palette, plateau badges, deload banner, weekly recap).
- `.planning/phases/06-progress-views-export-polish/06-UI-SPEC.md` — Phase 6 BRU spec (progress home composition, chart skinning, PR layout, Settings Data section).

### UI-REVIEW audits — migration backlog source (per-pillar scored gap lists)
- `.planning/phases/02-core-loop-routines-sessions/02-UI-REVIEW.md` — Phase 2 audit (existing, 12/24 — TEMPLATE FORMAT for the 01/05/06 audits + 02.1 backlog source).
- `.planning/phases/03-smart-prescription-warm-ups/03-UI-REVIEW.md` — Phase 3 audit (existing, 10/24 baseline; commit c025996) — Block B input.
- `.planning/phases/04-periodization-blocks/04-UI-REVIEW.md` — Phase 4 audit (existing, 9/24; commit 58d5ea3) — sibling reference (Phase 7 does NOT consume; 04.1 owns).
- **TO BE GENERATED BEFORE `/gsd-plan-phase 7`:**
  - `.planning/phases/01-foundation-exercise-library/01-UI-REVIEW.md` (run `/gsd-ui-review 1`) — Block A input.
  - `.planning/phases/05-fatigue-model-plateau-detection/05-UI-REVIEW.md` (run `/gsd-ui-review 5`) — Block C input.
  - `.planning/phases/06-progress-views-export-polish/06-UI-REVIEW.md` (run `/gsd-ui-review 6`) — Block D input.

### BRU foundation source (hard dep — must execute before Phase 7)
- `.planning/phases/02.1-bru-visual-rewrite/02.1-01-PLAN.md` — Wave A foundation plan: 8 colorsets + 4 OFL .otf font files + Info.plist UIAppFonts + `Color+BRU.swift` + `BRUFont.swift` + OFL license attribution.
- **Pending 02.1 plans (must land before Phase 7):**
  - The 02.1 plan(s) that ship the 15+ BRU primitive components (`BRUHeaderBar`, `BRUTabBar`, `BRUChip`, `BRUDisplay`, `BRUReadout`, `BRUSectionHead`, `BRUButton`, `BRUSpark`, `BRUDivider`, `BRUDashedSlot`, `BRUPillButton`, `BRUSupersetBracket`, `BRUCornerBadge`, `SetCompletionGlyph`, `RestTimerProgressArc`). Plan-checker for Phase 7 hard-blocks if these don't exist on disk.

### Phase 6 prerequisite (Block D blocker)
- `.planning/phases/06-progress-views-export-polish/06-10-PLAN.md` — backup/restore plan (per ROADMAP Phase 6 plan list, 1 of 11 still incomplete). Block D Settings Data section rewrite must cover the backup/restore rows that 06-10 introduces in HIG form. 06-10 must execute before Block D Wave B Settings plan.

### bru-screens mockups (visual contract source — in scope, located at repo root)
- `bru-screens/library.jsx` (120 LOC) — Phase 1 Library
- `bru-screens/exercise-detail.jsx` (134 LOC) — Phase 1 ExerciseDetail
- `bru-screens/custom-exercise.jsx` (132 LOC) — Phase 1 CustomExerciseForm
- `bru-screens/why-weight.jsx` (150 LOC) — Phase 3 WhyThisWeightSheet (the ink hero slab demo)
- `bru-screens/plate-calc.jsx` (141 LOC) — Phase 3 PlateCalcSheet
- `bru-screens/heatmap.jsx` (172 LOC) — Phase 5 BodySilhouetteView heatmap
- `bru-screens/volume.jsx` (133 LOC) — Phase 5 FatigueSurfaceView + MuscleVolumeBar
- `bru-screens/plateau.jsx` (104 LOC) — Phase 5 plateau-detection chip surface
- `bru-screens/weekly-recap.jsx` (114 LOC) — Phase 5 WeeklyRecapSheet (+ Phase 6 cross-ref)
- `bru-screens/progress-chart.jsx` (144 LOC) — Phase 6 ExerciseProgressView + WeeklyTonnageView reference
- `bru-screens/settings.jsx` (119 LOC) — Phase 6 SettingsView Data section

### Out-of-scope bru-screens (covered by 02.1 / 04.1 — DO NOT touch in Phase 7)
- `bru-screens/today.jsx` — 02.1 Phase 2 TodayView
- `bru-screens/routine-builder.jsx` — 02.1 Phase 2
- `bru-screens/session-history.jsx` — 02.1 Phase 2
- `bru-screens/block-builder.jsx` — 04.1 Phase 4
- `bru-screens/block-overview.jsx` — 04.1 Phase 4
- `bru-screens/block-review.jsx` — 04.1 Phase 4

### Prior phase contexts (locked behavioral decisions to preserve verbatim)
- `.planning/phases/01-foundation-exercise-library/01-CONTEXT.md` — Library entity catalog + filter pattern + custom-exercise primary-muscle save-gate.
- `.planning/phases/03-smart-prescription-warm-ups/03-CONTEXT.md` — `ProgressionStrategy` protocol + plate calc + warm-up generator + `wasManualOverride` informational badge contract.
- `.planning/phases/05-fatigue-model-plateau-detection/05-CONTEXT.md` — `VolumeZone` enum + D-06 VERBATIM verb copy (lock these character-for-character through the rewrite) + heatmap palette + 4 zone colorsets + `MuscleVolumeTarget` editor surface + D-13 suggested-action 4-branch decision tree + D-14/D-15/D-17 deload-advisory semantics.
- `.planning/phases/06-progress-views-export-polish/06-CONTEXT.md` — e1RM formulas + intent-split chart series + PR layout + export DTO shape + backup/restore round-trip contract.

### Prior phase summaries (what's actually shipped — Phase 7 regression bar reference)
- `.planning/STATE.md` (loaded above) — current ship state for all 6 phases including per-plan closure detail.
- `.planning/phases/05-fatigue-model-plateau-detection/05-*-SUMMARY.md` (per-plan) — Phase 5 plan closure detail; Phase 7 Block C must not regress any of these behaviors.
- `.planning/phases/06-progress-views-export-polish/06-*-SUMMARY.md` (per-plan) — Phase 6 plan closure detail; Phase 7 Block D regression baseline.

### Audit format reference (for the 3 UI-REVIEWs being generated)
- `.planning/phases/02-core-loop-routines-sessions/02-UI-REVIEW.md` § Pillar Scores + § Top 3 Priority Fixes + § Detailed Findings — canonical audit shape; `/gsd-ui-review` follows this format.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Phase 1 surfaces** live in `fitbod/ExerciseLibrary/` (`ExerciseLibraryView`, `ExerciseDetailView`, `CustomExerciseForm`). Filter chips + search bar are Apple HIG `Picker` / `.searchable(text:)` today. BRU contract: filter chips become `BRUChip`, search bar uses BRU primitives, list rows use `BRUSectionHead` + `BRUDivider`.
- **Phase 3 surfaces** live in `fitbod/Prescription/` and `fitbod/Sessions/` (`WhyThisWeightSheet`, `PlateStackDisclosure`, `PlateCalcSheet`, `PlateInventoryEditor`, `CalibratingBadge`, `BumpBanner`, `WarmupRampRows`, `PrescriptionWeightCell`, `WarmupConfigSheet`). Many compose into `SessionLoggerView` (owned by 02.1) — Phase 7 owns only the Prescription/* surfaces; the SessionLoggerView hosting structure stays in 02.1. Mount points must be stable.
- **Phase 5 surfaces** live in `fitbod/Fatigue/` (`FatigueSurfaceView`, `MuscleVolumeBar`, `BodySilhouetteView`, `MuscleRegionPaths`, `PerMuscleDetailView`, `MuscleVolumeTargetEditor`, `MuscleVolumeTargetStepper`, `StallBadge`, `SuggestedActionChip`, `TryVariationSheet`, `DeloadAdvisoryBanner`, `DeloadSignalDetailSheet`, `WeeklyRecapSheet`). Plus `fitbod/Sessions/SessionExerciseCard` extension points (StallBadge mount).
- **Phase 6 surfaces** live in `fitbod/Progress/` and `fitbod/Settings/` and `fitbod/Sessions/` (`ProgressHomeView`, `ExerciseProgressView`, `WeeklyTonnageView`, `WeekDetailView`, `ExercisePRsView`, `SessionComparisonView`, `InSessionPRBanner`, `SettingsView` Data section). `InSessionPRBanner` mounts via `.safeAreaInset(edge: .top)` on `SessionLoggerView` (02.1 owns the host; Phase 7 owns the banner content).
- **Phase 6 backup surfaces** live in `fitbod/Backup/` (per 06-10 plan when it executes) and `fitbod/Export/` (per 06-09b — already shipped). Block D Settings rewrite hosts both.
- **Existing zone colorsets** in `fitbod/Assets.xcassets/`: `AccentColor`, `VolumeProductiveGreen`, `VolumeNearMRVAmber`, `VolumeOverMRVRed`, `VolumeBelowMEVGray`, `AppIcon`. Block C Wave A introduces 4 new `bruZone*.colorset` assets; Wave Z grep gate deletes the 4 old `Volume*` colorsets after migration confirms zero remaining references.
- **02.1-01-PLAN.md must_haves pattern** — `truths` (factual statements) + `artifacts` (path + provides + contains + min_lines) + `key_links` (from + to + via + pattern). Phase 7 plans inherit this exact pattern.

### Established Patterns

- **02.1 Wave A-G migration pattern** — per `02-UI-REVIEW.md` Wave breakdown: A foundation → B primitives → C-F per-surface rewrites → G grep audit. Phase 7 replicates this per-block (A-C internal to each block; Z final cross-block).
- **`@Query` directly in views** (FOUND-06 / 02.1 / Phase 6) — Phase 7 rewrites are visual-only; preserve every `@Query` declaration verbatim.
- **`@Observable` for ephemeral state** — preserve `ChartFilterState`, `InSessionPRState`, `PRDetectorState`, all `MuscleVolumeTargetStepper` bindings, `ProgressColors`, etc.
- **Pure-function services** (FOUND-07) — `FatigueModel`, `PlateauDetector`, `DeloadAdvisor`, `OneRepMaxEstimator`, `PRDetector`, `WeeklyTonnageAggregator`, `SessionComparator`, `ExportService`, `BackupArchiver`, `BackupRestorer` are all preserved as-is. Phase 7 does NOT touch service code.
- **Atomic per-plan commits** — match 02.1-01-PLAN.md commit-discipline pattern. One feature per commit; commit message form `feat(07): {block}-{plan_id} — {surface name(s)}` mirroring Phase 5/6 style.
- **Swift Testing + XCTest split** — Swift Testing for math/contract/registration smoke; XCTest for UI binding via XCUIApplication. Phase 7 adds Swift Testing contract tests + updates existing XCTest UI tests for new BRU component a11y identifiers.
- **Verbatim copy preservation** — Phase 5 D-06 verb copy ("Below MEV — add volume." / "Productive range — hold/progress" / "Near MRV — deload soon if performance or recovery drops." / "Over MRV — deload recommended."), Phase 6 PR banner copy ("Weight PR · Volume PR · e1RM PR"), all UI-SPEC § Copywriting Contract strings are LOCKED. Phase 7 rewrites cannot drift copy.

### Integration Points

- **SessionLoggerView host (owned by 02.1)** — Phase 7's `InSessionPRBanner` (Block D) and Phase 5's `StallBadge` + `SuggestedActionChip` mount points (Block C) overlay on `SessionLoggerView`. 02.1 must finalize its `SessionLoggerView` BRU rewrite first, OR define stable mount-point contracts (named `accessibilityIdentifier` slots) that Phase 7 surfaces bind to. Plan-checker enforces this dependency.
- **TodayView host (owned by 02.1)** — Phase 7's `FatigueSurfaceView` mount (Block C) overlays inside TodayView. Same contract as SessionLoggerView — 02.1 finalizes host first; mount-point contract documented.
- **RootView TabView (owned by 02.1)** — `ProgressTabHost` and the Progress tab icon already exist (06-08 shipped with `chart.line.uptrend.xyaxis` SF Symbol). Block D Wave A's Phase 7 grep purge swaps the SF Symbol to a BRU-compliant alternative per the BRU primitive contract (likely a typographic glyph or a `BRUSpark` icon).
- **SettingsView host** — Phase 7's Data section rewrite (Block D) lands inside Settings. Settings shell itself is shared across Phase 1 / 3 / 5 / 6 sections; Phase 7 rewrites each section in its respective block, leaving Settings coherent throughout the rewrite (no half-styled Settings — Block A handles ExerciseLibrary settings if any; Block B handles `PlateInventoryEditor` settings entry; Block C handles `MuscleVolumeTargetEditor` settings entry; Block D handles Data section).
- **Asset Catalog migration** — Block C Wave A creates 4 `bruZone*.colorset` files. All call sites that currently read `Color("VolumeBelowMEVGray")` etc. update to read `Color("bruZoneBelow")` etc. Wave Z grep gate confirms zero remaining `Volume*` color references, then the 4 old colorsets are deleted.

</code_context>

<specifics>
## Specific Ideas

- **Per the user's strong preference** ("Visual contract — token-strict, layout-faithful"): match bru-screens/*.jsx pixel-near on tokens (colors, fonts, spacing, no rounding, no SF Symbols, UPPERCASE labels) AND on composition (header bands, hero slabs, grid structures), but allow Swift Charts and Canvas to use their native marks/paths rather than emulating JSX divs.
- **The 03-UI-REVIEW.md verdict is harsh on purpose** (audit baseline 10/24). The audit shape is: per-pillar score table + Top 3 Priority Fixes + per-pillar detailed findings with `file:line` citations + Wave A-G migration backlog. Planner should mirror this structure when generating 01 / 05 / 06 UI-REVIEWs and when consuming all 4.
- **The 02-UI-REVIEW migration backlog is ~72 tasks across 7 waves** — Phase 7 across 4 blocks will likely produce 80-120 tasks across ~15-25 plans. Per-plan task sizing targets ~3-8 tasks per plan to stay within executor context budgets (per 02.1-01-PLAN.md sizing).
- **Color hex values are LOCKED in 02-UI-SPEC.md** — `bruInk #0A0A0A` (light) / `#FAFAF7` (dark); `bruPaper #FAFAF7` / `#0A0A0A`; `bruSignal #FF5C1A` / `#FF7A3D`; `bruFaint #E8E5DD` / `#1F1D17`; `bruHair #D4D0C5` / `#2C2A22`; `bruMuted #6E6A60` / `#A8A399`; `bruBg #F2EFE7` / `#141310`; `bruBg2 #EDEAE0` / `#1A1814`. Phase 7 NEVER redefines these; consumes via `Color.bruInk` etc.
- **Font pairing is LOCKED to Pairing A** — Space Grotesk Bold/SemiBold (display) + JetBrains Mono Regular/Bold (mono/data) per 02.1-01-PLAN.md and 02-UI-SPEC.md commit 4c1674b.
- **BRU type role inventory (7 roles, locked)**: `displayHero` (96-128pt) / `displayLarge` (32-48pt) / `displayMedium` (18-22pt) / `bodyEmphasis` (12-14pt) / `bodyDefault` (14-16pt) / `labelSmall` (10-12pt) / `labelMicro` (8-10pt). Phase 7 NEVER introduces new roles; consumes via `BRUFont.{role}`.
- **Heatmap zone palette migration is the only NEW Asset Catalog work** — 4 new `bruZone*.colorset` files (semantic mappings to the 8 base BRU tokens, light + dark variants). All other Phase 7 surfaces reuse the 8 base tokens directly.
- **InSessionPRBanner becomes a flat BRU slab** — currently a capsule via `.safeAreaInset(edge: .top)`. Phase 7: `bruInk` rectangle, `bruPaper` text, no clip, `labelSmall` UPPERCASE chips ("WEIGHT PR · VOLUME PR · E1RM PR"). Preserve `.safeAreaInset` mount.
- **Settings/Data section** must include the 4 export/backup rows (06-09b + 06-10) — Phase 6's 06-10 ships them in Apple HIG; Phase 7 Block D re-skins them as BRU rows. Block D Settings plan cannot start until 06-10 executes.
- **Tests stance** — snapshot tests are deferred; structural/contract tests preferred (token presence, primitive composition, copy verbatim, registration smoke). UI tests updated per surface plan, NOT deferred.
- **UI-REVIEW generation IS the audit-first prerequisite** — Phase 7 plan-phase will hard-block on `01-UI-REVIEW.md` / `05-UI-REVIEW.md` / `06-UI-REVIEW.md` missing. Planner refuses to plan Block A / C / D respectively without its audit.
- **Sub-Block X.Y plan ID convention** — plan IDs follow `07-{block-letter}{plan-number}-PLAN.md` (e.g., `07-A1-PLAN.md`, `07-A2-PLAN.md`, `07-B1-PLAN.md`, ..., `07-D7-PLAN.md`, `07-Z-PLAN.md` for the final cross-block grep gate). Mirrors 02.1's existing convention.
- **No half-styled surfaces shipped mid-block.** Each plan must produce a complete, internally-consistent BRU rewrite of its surface(s). No "75% rewritten, ship later" — either the plan ships fully BRU or it does not commit.
- **Existing accessibility behavior must be preserved or improved.** All `accessibilityLabel` / `accessibilityHint` / `accessibilityIdentifier` strings preserved verbatim where possible. BRU primitives that replace HIG components must expose equivalent or richer a11y metadata.
- **Documentation update at end of Phase 7** — add a "BRU Migration Complete" entry to `.planning/STATE.md` and a "shipped" mark on Phase 7 ROADMAP entry. The audit milestone (4 UI-REVIEWs scored at >= 22/24 across all pillars per surface) is the close criterion.

</specifics>

<deferred>
## Deferred Ideas

- **Phase 2 surfaces** (TodayView, RoutineBuilderView, SessionLoggerView, SessionHistoryView, RestTimerOverlay, IntentChip, SetTypeChip, PinnedNoteCapsule) — owned by Phase 02.1. Not in Phase 7 scope.
- **Phase 4 surfaces** (BlockBuilderView, BlockReviewView, BlockCard, RoutinesListView Blocks section, DeloadWeekBanner, MesocycleWeekPage) — owned by Phase 04.1. Not in Phase 7 scope.
- **Launch screen redesign** — not in any bru-screens; no UI-SPEC entry. v2.
- **App icon redesign** — out of scope for v1 (PROJECT.md "distribution: personal install via Xcode" — no App Store presence to justify icon investment). v2.
- **Marketing screens / onboarding tour** — none exist in v1; not in any bru-screens. v2.
- **Watch app + widgets BRU** — out per PROJECT.md (no Apple Watch in v1; widgets via Live Activities are partially auto-styled by iOS template, not custom BRU). v2.
- **Live Activity BRU restyling** — RestTimer Live Activity is constrained by iOS Activity templating; not in any UI-SPEC. v2 if Apple opens Activity styling further.
- **Tab bar BRU rewrite** — `BRUTabBar` is owned by 02.1 (since TabView is rooted there). Phase 7 consumes the BRU-styled TabBar transparently.
- **Snapshot-test framework adoption** — `swift-snapshot-testing` SPM dep is brittle vs simulator versions. Defer; use structural assertions instead. Reconsider v2 if a CI environment + dedicated maintenance budget exists.
- **iCloud / CloudKit sync** — out per PROJECT.md (every property would need to be optional or defaulted — architectural cost not worth paying for personal app). v2+.
- **Apple HIG fallback toggle / theme switcher** — NO. The BRU rewrite is a one-way migration; no `UserDefaults` flag to switch back to HIG. Maintaining two visual systems contradicts PROJECT.md "Don't add features beyond what the task requires".
- **Library grid layout alternative** — bru-screens/library.jsx shows a list. Grid alternative is a separate feature, not a BRU rewrite concern. v2 if requested.
- **Cross-block parallelization** — Blocks A / B / C / D run sequentially per D-12. Parallel execution is deferred indefinitely (foundation churn risk + test-suite contention).
- **Automatic dark-mode preview screenshots** — manual review on device is the v1 stance. v2.
- **A new BRU primitive that ships under 02.1 retroactively** — Per D-06, Phase 7 owns its new primitive additions. NOT deferred — explicitly assigned to Phase 7.
- **Reverting Phase 7 if the BRU aesthetic doesn't land at use time** — the user is the only user; if BRU does not work after living with it, a v2 visual redesign would be a fresh phase. No rollback hatch in Phase 7.

</deferred>

---

*Phase: 07-bru-visual-rewrite*
*Context gathered: 2026-05-23 via interactive discuss-phase*
