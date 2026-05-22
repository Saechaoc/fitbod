# Phase 3: Smart Prescription & Warm-ups - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning
**Mode:** Auto-generated via `/gsd-autonomous` smart-discuss (recommended options auto-selected based on PROJECT.md, REQUIREMENTS.md, ROADMAP Phase 3 success criteria, and Phases 1–2 CONTEXT/SUMMARY artifacts; user accepted all 4 area proposals)

<canonical_refs>
## Canonical References

MANDATORY reads for researcher and planner:
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md` (this phase covers PRES-01..04, PRES-07..10, WARM-01..03, SET-02..04, SET-07 — 15 requirements)
- `.planning/ROADMAP.md` (Phase 3 — 6 must-be-true success criteria)
- `.planning/phases/01-foundation-exercise-library/01-CONTEXT.md` (Phase 1 decisions; entity catalog, `ProgressionKind` enum, `UserSettings`, `Exercise.smallestIncrement` presence/absence)
- `.planning/phases/02-core-loop-routines-sessions/02-CONTEXT.md` (Phase 2 decisions — `SessionFactory.start(...)` snapshot pattern; `SessionExercise` carries prescription; `SetEntry.actualWeight/actualReps/actualRPE` are the source-of-truth for progression calculations)
- `.planning/phases/02-core-loop-routines-sessions/*-SUMMARY.md` (what exists: `SessionFactory`, `PreviousMatchingIntent` query, rest timer, intent-split history)
- Tuchscherer RPE table: at plan-phase, confirm exact percent values per rep × RPE cell from RTS reference material (Mike Tuchscherer, *Reactive Training Manual*, 2009 — values are well-documented across the strength community)
</canonical_refs>

<domain>
## Phase Boundary

This phase delivers **transparent smart prescription** — every working set in a session shows a recommended weight derived from a chosen progression model, with an inspectable "Why this weight?" disclosure; the first compound auto-generates a plate-rounded warm-up ramp; and the integrated plate calculator surfaces actual barbell loading.

1. **Progression strategies** — protocol-oriented `ProgressionStrategy` with two concrete implementations:
   - `RPEAutoregStrategy` — back-calculates target weight from prior RPE + reps using a hardcoded Tuchscherer table as the prior, then switches to per-exercise locally-weighted regression after ≥10 logged working sets; displays a "calibrating" badge + range prescription while warming up
   - `DoubleProgressionStrategy` — advances weight by the exercise's `smallestIncrement` when ALL working sets hit top of rep range; "You earned the weight bump" banner surfaces at the START of the next session; missed top holds weight indefinitely
2. **"Why this weight?" disclosure** — expandable row on each working exercise in the session logger showing: last session's data (weight × reps @ RPE), formula name, computed percent, raw target, rounded target, increment source
3. **Warm-up ramp generator** — `WarmupRamp.generate(top:bar:plates:)` produces a 4-set ramp (40% × 5, 60% × 3, 75% × 2, 90% × 1), each set rounded DOWN to loadable plates. Triggered for the first `SessionExercise` whose underlying `Exercise.mechanic == .compound` AND `Exercise.equipment ∈ {.barbell, .dumbbell}`. Skipped on deload weeks (deferred to Phase 4 — for now the flag is wired but always false), halved sets for unilateral lifts (dumbbells), skipped when top working weight < 1.5× bar weight, skipped for bodyweight, user-overridable per `RoutineExercise.warmupOverride: WarmupConfig?`.
4. **Plate calculator + inventory** — new `PlateInventory` entity keyed by `equipmentKind` (barbell, dumbbell, EZ-bar, trap-bar). Default barbell inventory seeded on first launch (per UnitSystem). Inline disclosure on each set row: tap weight cell → reveals plate stack visualization underneath. Per-exercise `barWeightOverride: Double?` for safety squat / Swiss / fat bars.
5. **Manual override flow** — user-typed `SetEntry.actualWeight` is the source of truth; `wasManualOverride: Bool` is auto-flagged when typed weight diverges from rounded prescription. Progression strategies ALWAYS read `actualWeight`, never prescribed.
6. **Settings surface** — per-equipment plate inventory editor, per-exercise unit override (kg/lb), RPE-calibration window (`minCalibrationSets`, default 10), all reachable from `SettingsView`.

In scope: PRES-01..04, PRES-07..10, WARM-01..03, SET-02..04, SET-07 (15 requirements).
Out of scope: block-periodized strategy (Phase 4), hybrid strategy (Phase 4), deload-week scaling of warm-up (Phase 4 — the conditional flag exists here but the source of truth lands in Phase 4), volume aggregation (Phase 5), charts (Phase 6).
</domain>

<decisions>
## Implementation Decisions

### Area 1 — RPE Autoreg Strategy

- **Tuchscherer table source**: hardcoded Swift `enum TuchschererTable` with `static let percentFor: [Int: [Double: Double]]` (`[reps: [rpe: percent]]`). Single file `fitbod/Prescription/TuchschererTable.swift`. No asset loading, fully testable, fully unit-test-snapshot-friendly. Range covered: reps 1–12 × RPE 6.0–10.0 in 0.5 increments.
- **Calibration algorithm**: locally-weighted linear regression (LOWESS-style) on `(actualReps, actualRPE) → estimated1RM` per `(exercise, intent)` pair. For each prediction point, weight historical sets by Gaussian kernel on time-distance (recent sets count more). Implemented as pure function `Calibration.predict(history:targetReps:targetRPE:) -> Double` — no SwiftData coupling.
- **Min-sets to switch from prior to calibrated**: 10 logged working sets (literal per ROADMAP success criterion #2). Configurable via `UserSettings.minCalibrationSets: Int` (default 10). Below threshold → Tuchscherer prior + "calibrating" badge + range prescription.
- **Calibrating-window range width**: ±5% of point estimate, rounded to plate-loadable increments on each side. Displayed in UI as `"95 – 105 kg"` rather than `"100 ±5%"`.

### Area 2 — Double Progression Strategy

- **Bump trigger**: ALL working sets must hit top of rep range (literal per ROADMAP success criterion #3). Partial reps and warmup sets do NOT count toward the trigger.
- **Increment source**: per-exercise `Exercise.smallestIncrement: Double?` (NEW field — kg in kg-mode, lb in lb-mode). Falls back to `UserSettings.defaultIncrementKg: Double` (default 2.5 kg / 5 lb) when nil. Editable per exercise from `ExerciseDetailView`.
- **"You earned the weight bump" banner timing**: at the START of the next session (when the upcoming prescription reflects the bump). Banner is a single-row pill at the top of the `SessionLoggerView` for that exercise, dismissed on first set tap. Reason: actionable in context — user sees the bumped target right above the banner.
- **Missed top behavior**: hold weight indefinitely. No auto-decrement. (User can manually edit prescription if a true stall persists; Phase 5 plateau detection will surface this signal.)

### Area 3 — Warm-up Ramp Generator

- **Set count + percentages**: 4-set ramp — 40% × 5, 60% × 3, 75% × 2, 90% × 1 of top working weight. Proven RTS/RP ramp shape, ~10 reps total volume, ramp top is one heavy single before working sets.
- **Plate-rounding direction**: round each ramp set DOWN to loadable plates (`PlateCalculator.roundDown(target:bar:plates:)`). Warm-up should under-load if forced to choose — never want a warmup to be heavier than intended.
- **First-compound detection**: first `SessionExercise` whose underlying `Exercise.mechanic == .compound` AND `Exercise.equipment ∈ {.barbell, .dumbbell}`. Pure function `WarmupRamp.shouldGenerate(for:in:) -> Bool` — testable in isolation. Machines, cables, bodyweight skipped.
- **User override scope**: `RoutineExercise.warmupOverride: WarmupConfig?` (NEW relationship — codable struct stored as JSON via `@Attribute(.transformable)` OR as a separate entity if SwiftData has trouble with codable; planner decides). When user edits the ramp mid-session, the edit promotes to the routine-level override on first save (with a small toast "Saved as default for this routine"). Per-session-only changes happen by tapping a "just this session" toggle in the edit sheet.
- **Halving for unilateral**: `equipment == .dumbbell` → halve the ramp set count (2 sets: 60% × 3, 90% × 1) since each side gets warmed independently.
- **Skip threshold**: top working weight < 1.5 × bar weight → no ramp. Just write a "warm up however you'd like" placeholder row.

### Area 4 — Plate Calculator & Inventory

- **Inventory model**: NEW `PlateInventory` entity, one row per `EquipmentKind` enum case (`.barbell`, `.dumbbell`, `.ezBar`, `.trapBar`). Each row holds:
  - `barWeight: Double` (default 20kg for barbell, 0kg for dumbbell — handle weight is already in plate logic)
  - `availablePlates: [PlateSpec]` (codable struct: `weight: Double, countPerSide: Int, color: String?`)
  - Defaults seeded on first app launch based on `UserSettings.unitSystem`:
    - kg barbell: 25×4, 20×2, 15×2, 10×2, 5×2, 2.5×2, 1.25×2
    - lb barbell: 45×4, 35×2, 25×2, 10×2, 5×2, 2.5×2, 1.25×2
- **Bar weight**: per `EquipmentKind` field on `PlateInventory` (the default). Plus per-exercise `Exercise.barWeightOverride: Double?` (NEW field) for safety squat (~32kg), Swiss bar (~22kg), fat bar (~25kg), women's bar (~15kg). When present, overrides the equipment-level bar weight.
- **Plate calculator surface**: inline disclosure on the set row in the session logger. Tap the weight cell → reveals a horizontal plate stack visualization (small colored bars per plate with weight labels) underneath the set row. Tap again or interact with another set → collapses. Same visualization is available in the `PlateCalculatorSheet` (reachable from settings) as a standalone tool with editable target weight slider.
- **Manual override capture**: always write `SetEntry.actualWeight` as-typed (existing field from Phase 2 — no schema change). NEW `SetEntry.wasManualOverride: Bool` (default false) is set to true when the diff between `actualWeight` and rounded-prescribed-weight exceeds the per-exercise `smallestIncrement`. All progression strategies read `actualWeight` only — never `prescribedWeight`. The override flag is informational only (could surface in history as a small "M" badge in Phase 6).

### Area 5 — "Why this weight?" Disclosure

- **Trigger**: small `info.circle` icon next to the prescribed-weight cell on every working set row in the session logger. Tap → opens a bottom sheet (or inline disclosure if space permits) with:
  - **Last session line**: "Last time: 100 kg × 8 @ 8.5 (May 15)"
  - **Formula**: "RPE autoreg" or "Double progression"
  - **Computed**: "Target e1RM: 122 kg → 88% × 8 → 107 kg"
  - **Rounded**: "→ 107.5 kg (rounded down to 1.25 kg plates × 2)"
  - **Status badge**: "calibrating (4 / 10 sets)" or "calibrated"
- **Wired to plan-phase**: this is a single `WhyThisWeightSheet` view that takes a `PrescriptionExplanation` value type emitted by the strategy.

### Area 6 — Settings surface

- **`PlateInventoryEditor`** view (reachable from `SettingsView`): tabbed by `EquipmentKind`, each tab edits bar weight + plate list. "Reset to defaults" button per tab.
- **Per-exercise unit override**: editable from `ExerciseDetailView` — a small picker `Unit: System / kg / lb`. Persists as `Exercise.unitOverride: UnitSystem?`. Affects display only; calculations remain canonical (planner choose canonical unit — recommend kg).
- **RPE calibration window**: editable in `SettingsView` → "Smart progression" section — `Stepper("Sets before calibrating", value: $minCalibrationSets, in: 5...30)`. Default 10.

### Claude's Discretion

- Exact bottom-sheet vs inline-disclosure form factor for "Why this weight?" — visual decision deferred to UI-SPEC for this phase
- Plate visualization styling (colored rectangles vs SF Symbols vs custom Canvas) — UI-SPEC decision
- Toast/banner copywriting micro-variations — match Phase 2's voice
- Whether `PlateInventory` is a SwiftData `@Model` or a single `UserSettings` codable field — pick whichever is simpler given current Phase 1 patterns
- Whether `WarmupConfig` is a separate entity vs a JSON-encoded transformable attribute — planner decides per SwiftData behavior

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phases 1 & 2)

- `Exercise` entity exists with `mechanic`, `equipment`, `primaryMuscles` — needs new fields: `smallestIncrement: Double?`, `barWeightOverride: Double?`, `unitOverride: UnitSystem?`
- `SetEntry` already has `actualWeight`, `actualReps`, `actualRPE` (snapshotted by `SessionFactory`) — needs new field: `wasManualOverride: Bool` (default false)
- `RoutineExercise` has `progressionKind` (enum `ProgressionKind` already includes `.rpeAutoreg`, `.doubleProgression`, `.blockPeriodized`, `.hybrid`) — needs new field: `warmupOverride: WarmupConfig?`
- `SessionExercise` snapshots prescription from `RoutineExercise` at session start — `SessionFactory.start(...)` needs to additionally invoke prescription strategy + warm-up generator at snapshot time
- `PreviousMatchingIntent` query (Phase 2) already returns the prior matching-intent `SetEntry` — perfect input for `RPEAutoregStrategy`
- `UserSettings` exists — needs new fields: `defaultIncrementKg: Double = 2.5`, `minCalibrationSets: Int = 10`, `unitSystem: UnitSystem`
- `RootView` has placeholder Settings tab; `SettingsView.swift` exists and can be extended

### Established Patterns

- Pure-function strategies (no SwiftData coupling) — testable in isolation
- `@Observable` for ephemeral UI state; never wrap `@Query`
- Enums persisted as `*Raw: String`
- `#Index` on hot query paths (progression strategies query `SetEntry` history — index `(exercise, intent, performedAt DESC)`)
- Atomic per-plan commits
- Swift Testing with `.serialized` trait for `UserDefaults`-touching suites
- UI-SPEC tokens carried forward: accent `#0E7C86`/`#3FBFC9`, 8pt spacing, semantic typography

### Integration Points

- `SessionFactory.start(...)` (Phase 2) — hook here to invoke `ProgressionStrategy.prescribe(...)` per `SessionExercise` and `WarmupRamp.generate(...)` for the first qualifying compound. Pre-populates `SetEntry.prescribedWeight` (existing field).
- `SessionLoggerView` (Phase 2) — add the "Why this weight?" `info.circle` icon, the inline plate disclosure, and the bump banner.
- `RoutineBuilderView` (Phase 2) — add the per-exercise warm-up override editor.
- `SettingsView` (Phase 1) — add `PlateInventoryEditor`, `defaultIncrementKg`, `minCalibrationSets`, `unitSystem`.
- `ExerciseDetailView` (Phase 1) — add `smallestIncrement`, `barWeightOverride`, `unitOverride` fields.

</code_context>

<specifics>
## Specific Ideas

- The Tuchscherer table is well-known — at plan-phase, source the exact values from a reliable cite (Tuchscherer, *Reactive Training Manual*, 2009) and include a unit test that snapshots the table.
- The plate calculator inline disclosure should feel snappy — animation under 200ms, no layout shift on adjacent rows.
- The "calibrating" badge should be subtle (muted text + small dot) — not alarming.
- The "You earned the weight bump" banner copy: match Phase 2 voice — direct, second-person, no exclamation points (e.g., "Bumping to 102.5 kg — you cleared the top of the range last time.").
- Per-exercise unit override should NOT change historical data display — only future entries (note this in copy).
- `PlateInventory` defaults can be defined in a single `PlateInventory+Defaults.swift` extension — easy to inspect and tweak.
- The "Why this weight?" sheet copy should be plain English; no jargon — phrases like "your last hard set" instead of "prior intent-matched logged set."

</specifics>

<deferred>
## Deferred Ideas

- Block-periodized strategy and hybrid strategy implementations — explicit Phase 4 scope (the `ProgressionStrategy` protocol designed here must accommodate them without refactoring; planner verify)
- Deload-week-aware warm-up scaling — Phase 4 owns the deload signal; this phase wires the conditional but leaves it always-false
- Plateau detection signal that auto-triggers a deload — Phase 5
- Plate calculator as a standalone tool reachable from anywhere — out of scope unless the inline disclosure leaves obvious gaps
- Custom progression strategies (user-defined) — out of v1 entirely
- Smart-rounding heuristics (e.g., "round to 5 kg for high-rep sets, 1.25 kg for singles") — defer until usage shows a need
- Velocity-based loading — explicit out-of-scope per PROJECT.md

</deferred>
