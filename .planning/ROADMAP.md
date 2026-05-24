# Roadmap: Fitbod

**Created:** 2007-05-10
**Granularity:** standard (5–8 phases)
**Mode:** MVP (each phase delivers an end-to-end vertical slice)
**Total v1 requirements:** 80 (per category enumeration; covers all 11 categories)
**Coverage:** 80 / 80 mapped

---

## Core Value

Granular, prescriptive workout sessions — every set in a session is intentionally specified (intent, target reps, target RPE, smart-progressed weight), and progress is visible at the resolution serious lifters actually train at.

---

## Phases

- [x] **Phase 1: Foundation & Exercise Library** — Versioned SwiftData schema, full entity set, library seed pipeline, browse/filter/custom-creation UI **(complete: 12/12 plans, 14/14 requirements — 2007-05-11)**
- [x] **Phase 2: Core Loop (Routines + Sessions)** — Single-screen routine builder, snapshot session logger, accurate rest timer, intent-split history lists **(complete: 13/13 plans, 20/20 requirements — 2007-05-11)**
- [ ] **Phase 2.1: BRU Visual Rewrite (Core Loop)** — Rewrite TodayView / RoutineBuilder / SessionLogger / SessionHistory to BRU brutalist UI-SPEC v2: 8 BRU color tokens, Space Grotesk + JetBrains Mono fonts, 15+ BRU primitive components, no rounded corners, no Apple HIG defaults
- [x] **Phase 3: Smart Prescription & Warm-ups** — Two progression strategies (RPE autoreg, double progression), warm-up generator, plate calculator, "why this weight?" UI (completed 2007-05-23)
- [x] **Phase 3.1: Session-Level Intent & Progression Refactor** — Move intent + progressionKind from per-exercise to Routine/Session; strip per-exercise pickers from PrescriptionEditorRow; SchemaV4 migration; rewire 25 test suites to the new model contract (completed 2007-05-23; PIVOT-01..05 satisfied)
- [x] **Phase 4: Periodization & Blocks** — Block builder, scheduled deloads, block timeline on home, remaining two progression strategies (block-periodized, hybrid)
- [x] **Phase 5: Fatigue Model & Plateau Detection** — Stimulus-weighted weekly volume, MEV/MAV/MRV bars with verbs, muscle heatmap, plateau detector, fatigue-triggered deload advisory (completed 2007-05-23)
- [ ] **Phase 6: Progress Views, Export & Polish** — Intent-split charts, PRs, weekly tonnage, session comparison, weekly recap, CSV/JSON export, backup/restore

---

## Phase Details

### Phase 1: Foundation & Exercise Library
**Goal:** Schema, persistence, and the keystone exercise library are in place so every downstream phase composes on a stable foundation.
**Mode:** mvp
**Depends on:** Nothing (first phase)
**Requirements:** FOUND-01, FOUND-02, FOUND-03, FOUND-04, FOUND-05, FOUND-06, FOUND-07, LIB-01, LIB-02, LIB-03, LIB-04, LIB-05, LIB-06, SET-01
**Success Criteria** (what must be TRUE):
  1. On a fresh install, the app seeds ~800 exercises from the bundled JSON in under 2 seconds on a background `@ModelActor` — no UI freeze, library queryable immediately on second launch
  2. User can browse the bundled library and multi-facet filter by muscle group, equipment, mechanic, and movement pattern simultaneously with sub-100ms response (backed by `#Index` on hot fields)
  3. User can search exercises by name with type-ahead at 1000+ entries with no perceptible keystroke lag (debounced + indexed `canonicalName`)
  4. User can create a custom exercise — the form blocks save until at least one primary muscle is mapped with a stimulus weight (default 1.0 primary / 0.5 secondary)
  5. The full entity set (Exercise, MuscleGroup, ExerciseMuscleStimulus, Routine, RoutineExercise, Session, SessionExercise, SetEntry, Block, BlockPhase, UserSettings, MuscleVolumeTarget) is wrapped in `SchemaV1: VersionedSchema` with an empty `SchemaMigrationPlan` in place — every property optional or default-valued, every enum persisted as `*Raw: String`
  6. Global units toggle (lb / kg) is settable and affects library display
**Plans:** 12/12 plans executed (complete)
**UI hint:** yes
**Research flag:** None — patterns are standard SwiftData / SwiftUI

### Phase 2: Core Loop (Routines + Sessions)
**Goal:** User can build a routine with full prescription, start a session that snapshots the template, log every set with an accurate rest timer that survives lock-screen, and see per-exercise history split by intent.
**Mode:** mvp
**Depends on:** Phase 1
**Requirements:** ROUTINE-01, ROUTINE-02, ROUTINE-03, ROUTINE-04, ROUTINE-05, ROUTINE-06, ROUTINE-07, ROUTINE-08, ROUTINE-09, SESS-01, SESS-02, SESS-03, SESS-04, SESS-05, SESS-06, SESS-07, SESS-08, SESS-09, SESS-10, SESS-11
**Success Criteria** (what must be TRUE):
  1. User can build a 6-exercise routine on a single screen — inline exercise search-and-add, drag-handle reorder, per-exercise prescription (intent / rep range / target RPE / progression kind / rest), supersets and giant sets, per-set prescription overrides — with no modal exercise picker
  2. Starting a session calls `SessionFactory.start(...)` which snapshots every prescription field onto `SessionExercise` rows — editing the routine template afterwards leaves the logged session unchanged (snapshot pattern verified end-to-end)
  3. User can log per set: weight, reps, RPE (decimal RPE supported), set type (warmup / working / drop / failure / rest-pause), per-set form notes, optional 4-field tempo, partial reps, and cluster/rest-pause sub-reps; bodyweight and weighted-bodyweight exercises accept signed added weight
  4. Rest timer is `Date`-based (not foreground `Timer`), auto-starts on set completion, exposes ±15s buttons, fires a `UNUserNotification` at exactly the right wall-clock moment when phone is locked for 3+ minutes, displays as a Live Activity / Dynamic Island while running, and auto-stops on next set entry
  5. The same routine logged on Monday with strength intent and Thursday with hypertrophy intent produces two distinct per-exercise history streams; the inline "previous" column on each set shows the prior weight × reps × RPE from the matching-intent prior session
  6. Mid-session, user can swap or add unplanned exercises without mutating the routine template; workout-level notes and pinned per-exercise notes are visible inline
**Plans:** 13/13 plans complete
**UI hint:** yes
**Research flag:** None — `Date` + `UNUserNotification` rest timer pattern is well-documented; care required but no open question

### Phase 2.1: BRU Visual Rewrite (Core Loop)
**Goal:** All Phase 2 user-facing surfaces (TodayView, RoutineBuilderView, SessionLoggerView, SessionHistoryView, RestTimerOverlay, IntentChip, SetTypeChip, PinnedNoteCapsule) render in the BRU brutalist design system per `02-UI-SPEC.md` v2 — ink/paper/signal palette, Space Grotesk + JetBrains Mono fonts, sharp borders, no rounded corners, no Apple HIG defaults. Zero references to `Color.accentColor`, `Color.primary`, `Color(.system*)`, `.font(.body/.headline/.title*)`, `Image(systemName:)`, `RoundedRectangle(cornerRadius:)`, `Capsule()` clips, or `.buttonStyle(.bordered)` remain in Phase 2 surfaces.
**Mode:** refactor
**Depends on:** Phase 2 (rewrites its surfaces), Phase 3, Phase 3.1, Phase 4, Phase 5 (must not regress already-shipped behavior layered on Phase 2 views)
**Requirements:** None (visual refactor — no new functional requirements; preserves all existing Phase 2 requirements ROUTINE-01..09, SESS-01..11)
**Success Criteria** (what must be TRUE):
  1. 8 BRU color assets (`bruInk`, `bruPaper`, `bruSignal`, `bruFaint`, `bruHair`, `bruMuted`, `bruBg`, `bruBg2`) ship as `.colorset` entries in `Assets.xcassets` with dark-mode inversion; `Color+BRU.swift` extension exposes them as typed `Color` properties
  2. Space Grotesk Bold + SemiBold + JetBrains Mono Regular + Bold (OFL-licensed) ship as `.otf` files under `fitbod/Resources/Fonts/`; `Info.plist` declares `UIAppFonts`; `BRUFont.swift` exposes 7 type roles (`displayHero`, `displayLarge`, `displayMedium`, `bodyEmphasis`, `bodyDefault`, `labelSmall`, `labelMicro`) with explicit sizes and line heights
  3. 15+ BRU primitive components live under `fitbod/Design/` (`BRUHeaderBar`, `BRUTabBar`, `BRUChip`, `BRUDisplay`, `BRUReadout`, `BRUSectionHead`, `BRUButton`, `BRUSpark`, `BRUDivider`, `BRUDashedSlot`, `BRUPillButton`, `BRUSupersetBracket`, `BRUCornerBadge`, `SetCompletionGlyph`, `RestTimerProgressArc`) — each with SwiftUI previews and unit-test coverage for their visual contracts
  4. `TodayView` lives in `fitbod/Views/TodayView.swift` (not inlined in `RootView.swift`) and renders the BRU mockup layout: `BRUHeaderBar` → `TodayStatStrip` → `BlockContextBand` → `WeekTickerCells` (W1-W5 with DL badge) → `BlackSlabCTA` → `LiftListSection`. Match `bru-screens/today.jsx` line-for-line
  5. `RoutineBuilderView`, `SessionLoggerView`, `SessionHistoryView` rewritten to match their corresponding `bru-screens/*.jsx` mockups using BRU primitives only — no Apple HIG fallbacks
  6. `RestTimerOverlay` is a full-bleed slab (NOT a capsule); `SetTypeChip` drops `Color(.systemBlue|Orange|Red|Purple)` and uses BRU palette only; `PinnedNoteCapsule` drops `Color(.systemYellow)` and uses `bruSignal` or `bruInk`; `IntentChip` rebuilt as `BRUChip` instance
  7. Grep audit (Wave G) confirms zero residual references to deprecated tokens across all Phase 2 surface files; existing Phase 2 functional tests still pass; UI snapshot tests added for each rewritten screen
**Plans:** 4/11 plans executed

**Plan list:**
- [x] 02.1-01-PLAN.md — Wave 1: BRU color tokens (8 colorsets) + OFL fonts + Color+BRU.swift + Info.plist UIAppFonts + BRUFont.swift
- [x] 02.1-02-PLAN.md — Wave 2: 6 core BRU primitives (BRUDivider, BRUChip, BRUDisplay, BRUReadout, BRUSectionHead, BRUButton)
- [x] 02.1-03-PLAN.md — Wave 2: 9 composite BRU primitives (BRUHeaderBar, BRUTabBar, BRUSpark, BRUDashedSlot, BRUPillButton, BRUSupersetBracket, BRUCornerBadge, SetCompletionGlyph, BRUPhoneFrame)
- [ ] 02.1-04-PLAN.md — Wave 3: TodayView extraction + 8 BRU TodayView components (TodayStatStrip / BlockContextBand / WeekTickerCells / BlackSlabCTA / ResumeWorkoutSlab / LiftListSection / LiftListRow)
- [ ] 02.1-05-PLAN.md — Wave 3: RoutineBuilderView reskin + RoutineExerciseCard + PrescriptionEditorRow + SetRowsContainer + 4 supporting Routines files
- [ ] 02.1-06-PLAN.md — Wave 3: RoutinesListView + RoutineRow + NewFolderSheet + MoveRoutineSheet
- [ ] 02.1-07-PLAN.md — Wave 3: SessionLoggerView core + SessionExerciseCard + SetRow + SetTypeChip + IntentChip + InlineRPEChipRow + DecimalRPEPickerSheet
- [ ] 02.1-08-PLAN.md — Wave 3: 11 SessionLogger widgets (PinnedNoteCapsule yellow ban + WorkoutHeaderToolbar extraction + AddUnplannedExerciseButton BRUDashedSlot + ResumeWorkoutBanner + 7 others)
- [x] 02.1-09-PLAN.md — Wave 3: RestTimer Overlay (full-bleed slab) + RestTimerProgressArc (rename ProgressRing) + RestTimerLiveActivity + Lock Screen + 2 new Dynamic Island views
- [ ] 02.1-10-PLAN.md — Wave 3: ExerciseHistoryView reskin + IntentFilterChipRow + PRStripFooter (NEW) + SessionHistoryView (NEW) + SessionHistoryStatStrip + WeeklyTonnageSparkCard + SessionHistoryRow
- [ ] 02.1-11-PLAN.md — Wave 4: Wave G cleanup — delete PlaceholderTabView + close deferred Step-E from 02.1-08 + Step-A from 02.1-10 + BRUGrepAuditTests guardrail + 3 UI smoke test files
**UI hint:** yes (visual rewrite IS the phase)
**Research flag:** None — design system already locked in `02-UI-SPEC.md` v2 (commit 4c1674b); audit gap list already produced in `02-UI-REVIEW.md` (commit 7a1f142)

### Phase 3: Smart Prescription & Warm-ups
**Goal:** Each working exercise displays a transparent recommended weight from its chosen progression model (RPE autoreg or double progression), the first compound auto-generates a plate-rounded warm-up ramp, and the integrated plate calculator surfaces actual loading.
**Mode:** mvp
**Depends on:** Phase 2 (needs real logged sessions to compute prescriptions against)
**Requirements:** PRES-01, PRES-02, PRES-03, PRES-04, PRES-07, PRES-08, PRES-09, PRES-10, WARM-01, WARM-02, WARM-03, SET-02, SET-03, SET-04, SET-07
**Success Criteria** (what must be TRUE):
  1. At session start, each working exercise displays a recommended weight computed by its selected progression model (`RPEAutoregStrategy` or `DoubleProgressionStrategy`), with an expandable "Why this weight?" disclosure showing last session's data, formula, percent, and rounding
  2. `RPEAutoregStrategy` back-calculates target weight from prior RPE + reps using the Tuchscherer table as a prior, then switches to per-exercise per-lifter calibration after ≥10 logged sets — a "calibrating" badge is shown until then, and prescriptions display as a range while calibrating
  3. `DoubleProgressionStrategy` advances weight by the exercise's smallest-increment when all working sets hit the top of the rep range; "You earned the weight bump" banner surfaces at the trigger; missed top-of-range holds weight
  4. The first compound exercise of a session auto-generates a 3–5 set warm-up ramp plate-rounded to the user's per-equipment plate inventory; edge cases handled correctly — skipped on deload weeks, halved for unilateral lifts, skipped when working weight < 1.5× bar, skipped for bodyweight, user-overridable per exercise
  5. Plate calculator displays the loadable plate stack for a given target weight and bar weight respecting the user's plate inventory; per-exercise smallest weight increment is honored by every progression rounding decision; manual weight overrides are recorded as actual performance and feed into the next session's calculation (never ignored)
  6. Per-equipment plate inventory and smallest-increment settings, per-exercise unit override, and RPE-calibration window settings are user-configurable
**Plans:** 8/8 plans complete

**Plan list:**
- [x] 03-01-PLAN.md — SchemaV3 + additive fields + PlateInventory entity + lightweight migration
- [x] 03-02-PLAN.md — Wave 0 test scaffolding (12 suites: 3 GREEN, 9 RED for downstream plans)
- [x] 03-03-PLAN.md — TuchschererTable + PlateCalculator + Calibration pure functions
- [x] 03-04-PLAN.md — PlateInventory defaults + seeder + PlateInventoryEditor + Settings extensions
- [x] 03-05-PLAN.md — ProgressionStrategy protocol + RPEAutoreg + DoubleProgression + WarmupRamp + Factory
- [x] 03-06-PLAN.md — Session logger UI components (WhyThisWeightSheet, PrescriptionWeightCell, PlateStackDisclosure, BumpBanner, CalibratingBadge, WarmupRampRows)
- [x] 03-07-PLAN.md — Routine builder warm-up override + ExerciseDetailView prescription settings
- [x] 03-08-PLAN.md — SessionFactory integration + SessionExerciseCard/SetRow wiring + manual-override capture
**UI hint:** yes
**Research flag:** Yes — at plan-phase time, confirm Tuchscherer RPE table numbers (exact percent values per rep × RPE cell) and choose per-exercise per-lifter calibration algorithm (linear vs locally-weighted regression; min-points threshold)

### Phase 03.2: BRU Visual Rewrite (Prescription & Warm-ups) — reskin Phase 3 surfaces (PrescriptionWeightCell, WhyThisWeightSheet, PlateStackViz, PlateCalculatorSheet, PlateInventoryEditor, BumpBanner, CalibratingBadge, WarmupRampRows) to BRU brutalist per 03-UI-SPEC v2; depends on Phase 02.1 primitives (INSERTED)

**Goal:** [Urgent work - to be planned]
**Requirements**: TBD
**Depends on:** Phase 3
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 03.2 to break down)

### Phase 3.1: Session-Level Intent & Progression Refactor
**Goal:** Move `intent` and `progressionKind` from per-exercise (RoutineExercise / SessionExercise) to session-level (Routine / Session). Real programs are organized at session/block level — a session has a goal (strength, hypertrophy) and a progression style; the same exercise rarely flips intent within a session. Per-exercise prescription stays detail-rich but stops being prescriptive about *why* the set is being done.
**Mode:** refactor
**Depends on:** Phase 3 (consumes ProgressionStrategy protocol and SessionFactory snapshot pattern)
**Requirements:** PIVOT-01, PIVOT-02, PIVOT-03, PIVOT-04, PIVOT-05
**Success Criteria** (what must be TRUE):
  1. `Routine` and `Session` carry `intent: Intent` and `progressionKind: ProgressionKind` fields; `RoutineExercise.intentRaw` and `RoutineExercise.progressionKindRaw` removed (or kept as `nil`-only override paths); `SessionExercise.intentRaw` removed (snapshotted from `Session.intentRaw` instead)
  2. SchemaV4 migration ships — additive Routine/Session fields land lightweight; per-exercise fields removed via a versioned migration step that backfills session-level values from the most common per-exercise value at migration time
  3. RoutineBuilderView gains a session-level Intent picker + Progression picker at the top (above the exercise list); PrescriptionEditorRow drops its per-exercise Intent and Progression rows entirely
  4. PreviousMatchingIntent + ProgressionStrategyFactory + SessionFactory + all 12 Phase 3 test suites updated to read intent/progression from Session/Routine (not SessionExercise/RoutineExercise)
  5. Block-level intent + progression default is *not* in scope (Phase 4 owns that wiring) — but the new fields' default values (`intent = .strength`, `progressionKind = .double`) are placed so a future Phase 4 block-default override is a one-line addition
**Plans:** 8 plans (5 waves)

**Plan list:**
- [x] 03.1-01-PLAN.md — SchemaV4 + V3→V4 custom migration scaffold + SchemaV4MigrationTests wiring + tie-break helper tests
- [x] 03.1-02-PLAN.md — Add Routine/Session.intentRaw+progressionKindRaw fields + remove from RoutineExercise/SessionExercise + flip app+preview to SchemaV4 + activate migration backfill + extend SchemaV4MigrationTests end-to-end
- [x] 03.1-03-PLAN.md — SessionFactory session-level snapshot + hoist ProgressionStrategyFactory (D-14 one strategy per session) + RoutineDuplicator + AddUnplannedExerciseButton + SwapExerciseSheet
- [x] 03.1-04-PLAN.md — RoutineDraft.intent/progressionKind fields + RoutineBuilderView header pickers (Intent + Progression) + RoutineBuilderHeaderPickersTests
- [x] 03.1-05-PLAN.md — PrescriptionEditorRow strip Intent + Progression rows + RoutineExerciseCard intentChip removal
- [x] 03.1-06-PLAN.md — IntentChip shared SwiftUI component + SessionLoggerView header IntentChip integration (3-line principal toolbar)
- [x] 03.1-07-PLAN.md — PreviousMatchingIntent + ExerciseHistoryView/Row + SessionExerciseCard.currentExplanation + SetRow + WhyThisWeightSheet status row + PrescriptionExplanation.sessionIntent field
- [x] 03.1-08-PLAN.md — Rewire 14 existing test suites (12 Phase 3 + 2 Phase 2) + flip Schema(SchemaV3.models) → SchemaV4 across tests; rewire RoutineBuilderCopyTests + SessionLoggerCopyTests; +5 Rule 3 deviation fixes
**UI hint:** yes
**Research flag:** No — the refactor pattern is well-understood (mirrors Phase 1's enum-as-String + snapshot conventions)

### Phase 4: Periodization & Blocks
**Goal:** User can define training blocks with phased mesocycles, see the active block on the home screen, navigate weeks, get scheduled deloads that automatically cut volume/intensity, and pick block-periodized or hybrid progression for relevant exercises.
**Mode:** mvp
**Depends on:** Phase 3 (block-periodized and hybrid strategies need the `ProgressionStrategy` protocol and warm-up scaling already in place)
**Requirements:** BLOCK-01, BLOCK-02, BLOCK-03, BLOCK-04, BLOCK-05, BLOCK-06a, BLOCK-07, BLOCK-08, PRES-05, PRES-06
**Success Criteria** (what must be TRUE):
  1. User can define a training block with an ordered phase sequence (accumulation, intensification, realization, deload), per-phase week length, and per-phase volume/intensity multipliers; routines link to a block
  2. Home screen surfaces the active block with phase chip, "Week N of M", days remaining, and phase color coding; user can swipe between weeks to navigate the mesocycle
  3. `BlockPeriodizedStrategy` and `HybridStrategy` are live as the third and fourth progression options — switching the progression kind on a `RoutineExercise` changes the prescribed weight predictably across all four algorithms; hybrid combines block phase macro context with RPE-driven daily adjustment
  4. Scheduled deload weeks auto-reduce prescribed volume (~50%) and adjust intensity per the deload phase definition, are visually distinct (banner / calendar tint / volume targets cut on bars), and warm-up generation respects them (no ramps on deload weeks)
  5. Block schedule is canonical — fatigue-triggered "consider deload" advisories from Phase 5 will never auto-apply; end-of-block produces a phase-end review (total volume, e1RM deltas, PRs hit, recommended next phase)
**Plans:** 9 atomic plans (5 waves; 04-04 split into 04-04a + 04-04b per checker warning #7)

**Plan list:**
- [x] 04-01-PLAN.md — Wave 0 pure foundation: PeriodizationEngine + MesocycleWeekContext + BlockTemplates + BlockPhaseColors + FatigueAdvisory protocol + StubFatigueAdvisory + 3 GREEN test suites (SchemaV4 work deferred to 04-08; landed as SchemaV5 with Block.reviewedAt)
- [x] 04-02-PLAN.md — BlockBuilderView single-screen builder + BlockDraft / BlockPhaseDraft @Observable + BlockPhaseEditorRow + transactional single-active save
- [x] 04-03-PLAN.md — RoutinesListView "Blocks" section + BlockRow + +Block Menu + delete confirmation
- [x] 04-04a-PLAN.md — Today-tab BlockCard (value-driven init) + MesocycleWeekPage swipe pager + TodayView active-block @Query hoist (split per checker warning #7)
- [x] 04-04b-PLAN.md — DeloadWeekBanner + ConsiderDeloadBanner scaffold + StartBlockCTA + TodayView full banner-stack rewire (split per checker warning #7)
- [x] 04-05-PLAN.md — RoutineDraft.blockID + BlockPickerMenu in RoutineBuilderView header + PrescriptionEditorRow conditional .block/.hybrid case filter (RECONCILED post-Phase 3.1: D-19 filter relocated to RoutineBuilderView's session-level Progression header picker via RoutineDraft.availableProgressionKinds(hasBlock:) + guardedProgressionSelection save-path guard)
- [x] 04-06-PLAN.md — ProgressionStrategy protocol extension (defaults at impl site per Swift contract) + BlockPeriodizedStrategy (D-17 baseline chain) + HybridStrategy + Factory swap + PrescriptionExplanation phase-context / deload-note fields
- [x] 04-07-PLAN.md — SessionFactory deload set-count cut (D-12 / Pitfall 7 clamp) + Session.block snapshot pinning + WarmupDeloadIntegrationTests (warning #10)
- [x] 04-08-PLAN.md — BlockReviewView 4-section sheet (total volume + e1RM deltas + PRs placeholder + recommended next) + TodayView trigger + E1RMHelper.epley fallback + acknowledge transaction + SchemaV5 (Block.reviewedAt; D-26 lands here instead of SchemaV3 because Phase 3 sealed before Phase 4 could ship the field)
**UI hint:** yes
**Research flag:** Yes — at plan-phase time, confirm default volume/intensity multipliers per phase against current RP/RTS literature (accumulation, intensification, realization, deload baselines)

### Phase 04.1: BRU Visual Rewrite (Periodization & Blocks) (INSERTED)

**Goal:** Re-skin all Phase 4 (Periodization & Blocks) user-facing surfaces from Apple HIG defaults to the BRU brutalist design system defined in `04-UI-SPEC.md` v3, atop the locked BRU primitives from `02-UI-SPEC.md`. Closes the systematic full-layer drift documented in `04-UI-REVIEW.md` (overall 9/24, 3 BLOCKERs). Scope: the 12 audited Phase-4 files + 1 net-new BlockOverviewScreen + audit-flagged accessibility and reduced-motion fixes. Preserves all Phase 4 functional behavior.
**Mode:** refactor
**Depends on:** Phase 4, Phase 2.1 (specifically 02.1-01-PLAN.md foundation)
**Requirements:** None (visual refactor — no new functional requirements; preserves all existing Phase 4 BLOCK-01..08 + PRES-05 + PRES-06 requirements)
**Plans:** 8 plans (8 waves)

**Plan list:**
- [ ] 04.1-01-PLAN.md — Wave 0: Foundation precondition guard + 10 BRU primitive components (BRUChip / BRUHeaderBar / BRUSectionHead / BRUButton / BRUDivider / BRUDashedSlot / BRUPillButton / BRUDisplay / BRUReadout / BRUCornerBadge)
- [ ] 04.1-02-PLAN.md — Wave 1: BlockPhaseColors palette flip (ink/signal/quiet/Canvas-stripe) + drawDeloadStripes helper + rowTint helper
- [ ] 04.1-03-PLAN.md — Wave 2: Small re-skins (BlockRow + BlockPickerMenu + StartBlockCTA + DeloadWeekBanner + ConsiderDeloadBanner with D-16 + D-17)
- [ ] 04.1-04-PLAN.md — Wave 3: Medium re-skins (BlockCard with D-14 + D-15 + week ticker + MesocycleWeekPage + BlockPhaseEditorRow with D-15 + 3-column data grid + RoutinesListView.blocksSection with D-09 copy fix)
- [ ] 04.1-05-PLAN.md — Wave 4: BlockBuilderView rebuild (Form → ScrollView+VStack + 56pt Canvas TIMELINE + BRUSectionHead "+ ADD PHASE" + BRUButton "Apply changes ▸")
- [ ] 04.1-06-PLAN.md — Wave 5: BlockReviewView rebuild (Form → ScrollView+VStack + full-bleed bruInk hero band + three displayHero stat columns + GeometryReader e1RM progress bars + bruBg2 recommended-next footer + bottom action bar with ghost+signal BRUButtons)
- [ ] 04.1-07-PLAN.md — Wave 6: Net-new BlockOverviewScreen (D-10) + BlockCard tap-routing rewire (D-11) + ROADMAP Depends on update (D-02)
- [ ] 04.1-08-PLAN.md — Wave 7: Snapshot/regression tests + 25-forbidden-pattern audit re-run + Phase 04.1 completion verification


### Phase 5: Fatigue Model & Plateau Detection
**Goal:** Weekly volume per muscle is computed with stimulus-weighted aggregation, surfaced as MEV/MAV/MRV bars with verb labels and a muscle heatmap, plateau detection flags stalled exercises, and a fatigue-triggered deload alert surfaces as an advisory (block schedule remains canonical).
**Mode:** mvp
**Depends on:** Phase 4 (deload-conflict resolution model defined; sessions exist in volume to aggregate)
**Requirements:** VOL-01, VOL-02, VOL-03, VOL-04, VOL-05, VOL-06, VOL-07, PROG-06, SET-05, SET-06, BLOCK-06b
**Success Criteria** (what must be TRUE):
  1. Per-muscle weekly volume is computed as the stimulus-weighted sum of working sets via `ExerciseMuscleStimulus.weight` — a barbell row contributes 1.0 to lats and 0.5 to biceps rather than double-counting; the top ~50 lifts have hand-curated weights, all others fall back to 1.0/0.5 defaults
  2. Volume bars per muscle display current weekly sets within MEV/MAV/MRV color zones AND surface a verb label ("add a set" / "hold" / "near MRV — deload soon" / "over MRV — deload") so every number drives a decision
  3. Front and back body silhouette heatmap shows weekly volume per muscle as color intensity; muscle regions are tappable to drill into the per-muscle detail view; per-muscle frequency tracking (sessions per week meeting a minimum stimulus threshold) is visible
  4. Plateau detector flags stalled exercises (e1RM flat ±X% over N sessions, configurable per exercise or global) with a visual stall flag on the exercise card and a suggested action (drop intensity, add volume, deload, try variation)
  5. "Consider deload" alert surfaces when fatigue/performance signals spike (e1RM drop > X% over N sessions, RPE creep at same load, missed rep targets across multiple sessions) — always as an advisory the user explicitly accepts or dismisses; scheduled block deloads are never overridden
  6. MEV / MAV / MRV thresholds per muscle and plateau detection thresholds per exercise are user-tunable; weekly recap auto-surfaces at the week boundary (muscles hit, muscles under-trained, e1RM movement, sessions logged)
**Plans:** 6/6 plans complete
**Research flag:** Yes — at plan-phase time, curate the stimulus-weighting table for the ~50 main compound lifts (per-muscle weights beyond the 1.0/0.5 defaults) and confirm seeded RP-published MEV/MAV/MRV values per muscle

### Phase 05.1: BRU Visual Rewrite (Fatigue & Volume) — reskin Phase 5 surfaces (volume bars MEV/MAV/MRV, muscle heatmap, plateau detection, weekly recap, fatigue advisory banner) to BRU brutalist per 05-UI-SPEC; depends on Phase 02.1 primitives (INSERTED)

**Goal:** [Urgent work - to be planned]
**Requirements**: TBD
**Depends on:** Phase 5
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 05.1 to break down)

### Phase 6: Progress Views, Export & Polish
**Goal:** Per-exercise intent-split charts, PR detection, weekly tonnage, session comparison, and weekly recap surface the resolution serious lifters train at — and the user can export everything as CSV or JSON and back up / restore the database.
**Mode:** mvp
**Depends on:** Phase 5 (final aggregates and plateau signals exist; backend is stable so the polish phase is pure presentation work)
**Requirements:** PROG-01, PROG-02, PROG-03, PROG-04, PROG-05, PROG-07, PROG-08, EXP-01, EXP-02, EXP-03, EXP-04
**Success Criteria** (what must be TRUE):
  1. Per-exercise time-series chart renders intent-split as distinct strength and hypertrophy series on the same axes (Swift Charts), with top-set vs all-set-average e1RM as toggleable series; rep-range-aware e1RM (Brzycki ≤6 reps, Epley 6–10 reps, suppressed >10 reps from PR detection)
  2. PRs view per exercise shows weight PRs, rep PRs, volume PRs, and e1RM PRs — intent-matched and rep-range aware so a strength PR is compared only against strength sessions; live PR detection at set save surfaces an in-session banner ("weight PR" / "volume PR" / "e1RM PR")
  3. Weekly tonnage chart (total weight × reps) is sliceable by week / block phase / muscle group; session comparison view shows this week's session vs last week's same-routine session, side-by-side per-exercise diff
  4. User can export all data as CSV (one row per set: sessions → exercises → sets) and as version-stamped JSON (full schema preserved); user can create a full database backup file shareable via AirDrop / Files / iCloud Drive
  5. User can restore from a backup file with explicit data-loss confirmation; round-trip (export → wipe install → import) produces an identical app state
**Plans:** 10/11 plans executed

**Plan list:**
- [x] 06-01-PLAN.md — OneRepMax kernel + tests (PROG-02)
- [x] 06-02-PLAN.md — PRDetector + PRKind + RepBucket + #Index<SetEntry>([\.completedAt]) + Wave-0 fixtures + InMemoryContainer (PROG-05, PROG-08)
- [x] 06-03-PLAN.md — WeeklyTonnageAggregator + MuscleVolumeProvider protocol + UnweightedMuscleVolumeProvider + TonnageSliceMode/TimeRangeChoice (PROG-04 algorithm side)
- [x] 06-04-PLAN.md — SessionComparator (corrected D-22 per-exercise match rule) + SessionComparisonRow (PROG-07 algorithm side)
- [x] 06-05-PLAN.md — ExerciseProgressView + ProgressColors + ProgressFilterChip sibling + SeriesToggleChipRow + SeriesBuilder + deep links (ExerciseDetailView + ExerciseHistoryView) (PROG-01, PROG-03)
- [x] 06-06-PLAN.md — WeeklyTonnageView + WeekDetailView + WeeklyTonnageFilterChips + ChartFilterState (PROG-04 UI side)
- [x] 06-07-PLAN.md — ExercisePRsView + SessionComparisonView + InSessionPRBanner + InSessionPRState + SessionFactory.seedPRTable + SessionLoggerView mount via .safeAreaInset (PROG-05, PROG-07, PROG-08)
- [x] 06-08-PLAN.md — ProgressHomeView (tab root) + RootView TabView wiring + tab icon chart.line.uptrend.xyaxis (PROG-01/04/05/07 integration)
- [x] 06-09-PLAN.md — ExportDocument envelope + 17 Codable DTOs covering SchemaV6 + canonicalSchemaVersion = "v6" + JSONEncoder.exportConfigured() shared encoder (EXP-02 envelope half)
- [x] 06-09b-PLAN.md — CSVExporter + JSONExporter + CSVFile/JSONFile Transferable + ExportService @ModelActor + Settings Data section export rows (EXP-01 + EXP-02 user-facing half)
- [x] 06-10-PLAN.md — BackupArchiver (PKWARE ZIP) + BackupRestorer + BackupManifest + UTType.fitbodBackup + Info.plist UTI declarations + Settings Data section backup/restore rows + BackupRoundTripTests (D-33 canary) (EXP-03, EXP-04)
**UI hint:** yes
**Research flag:** None — Swift Charts, `ShareLink`, and `Transferable` patterns are standard

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Exercise Library | 12/12 | Complete | 2007-05-11 |
| 2. Core Loop (Routines + Sessions) | 13/13 | Complete   | 2026-05-24 |
| 3. Smart Prescription & Warm-ups | 8/8 | Complete   | 2007-05-23 |
| 4. Periodization & Blocks | 0/8 | Not started | - |
| 5. Fatigue Model & Plateau Detection | 6/6 | Complete   | 2007-05-23 |
| 6. Progress Views, Export & Polish | 10/11 | In Progress|  |

---

## Phase Dependency Graph

```
Phase 1 (Foundation + Library)
    ↓
Phase 2 (Core Loop — proves snapshot pattern with real logged data)
    ↓
Phase 3 (Smart Prescription — needs real history to back-calculate from)
    ↓
Phase 4 (Periodization — block-periodized and hybrid strategies depend on Phase 3 protocol)
    ↓
Phase 5 (Fatigue Model — needs sessions to aggregate from; deload conflict model from Phase 4)
    ↓
Phase 6 (Progress Views & Export — pure presentation polish on a stable backend)
```

This ordering is dependency-driven and pitfall-aware (per research/SUMMARY.md and research/PITFALLS.md). Earlier phases never assume later phases; later phases compose on stable foundations.

### Phase 06.1: BRU Visual Rewrite (Progress & Export) — reskin Phase 6 surfaces (progress chart, settings, session history, export sheet) to BRU brutalist per 06-UI-SPEC; depends on Phase 02.1 primitives (INSERTED)

**Goal:** [Urgent work - to be planned]
**Requirements**: TBD
**Depends on:** Phase 6
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 06.1 to break down)
