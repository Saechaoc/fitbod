# Phase 4: Periodization & Blocks — Research

**Researched:** 2026-05-22
**Domain:** Block periodization (RP/RTS/Issurin model) on top of an existing `ProgressionStrategy` protocol; SwiftData mesocycle navigation; pure-function periodization math
**Confidence:** HIGH on architecture/SwiftData, HIGH on Issurin canonical model, MEDIUM on the specific multiplier values

---

## Executive Summary

Phase 4 wraps a deterministic, transparent mesocycle around the four-strategy `ProgressionStrategy` protocol shipped in Phase 3. Every architectural and SwiftData pattern needed already exists in the codebase — `Block` / `BlockPhase` models (Phase 1), `BlockPhaseKind` enum, snapshot pattern (`SessionFactory.start` from Phase 2), `@Observable` draft + three-way merge (`RoutineDraft` precedent), pure-function strategies behind a protocol (Phase 3 `ProgressionStrategyFactory` already has stub-fallbacks for `.block` and `.hybrid`). Adding `PeriodizationEngine` + two concrete strategies + the `BlockBuilderView`/`BlockCard` UI is a vertical-slice composition over existing primitives.

The single load-bearing research question — "are the locked Tactical 8 multipliers defensible against current RP/RTS literature?" — resolves favorably for the **CONTEXT.md D-10 values** (1.0/0.85/0.6/0.5 volume; 0.75/0.88/0.97/0.75 intensity), which sit squarely inside published RP/Issurin/Issrurin-derived ranges. The **task-brief alternative values** (1.0/0.85/0.55/0.50 and 0.70/0.825/0.925/0.65) are also defensible but slightly more aggressive on the realization end and slightly conservative on accumulation; both sets are inside the published evidence envelope. **Recommendation: ship CONTEXT.md D-10 verbatim** — they match the most-cited published values, the user-edit affordance in the builder makes the choice non-permanent, and the `BlockTemplates` factory makes alternative templates a one-file diff.

**Biggest open risk:** `RoutineExercise.prescribedWeight` is referenced as the no-history baseline in CONTEXT.md D-17, but **does not exist on the `RoutineExercise` @Model** (verified by reading `fitbod/Models/RoutineExercise.swift`). Phase 3's prescription system lives entirely on `SessionExercise.prescribedWeight`. The planner must either (a) add `RoutineExercise.prescribedWeight: Double?` to SchemaV3/SchemaV4 in Phase 4 Wave 0, or (b) source the baseline from the most recent `SetEntry.weight` for the exercise (which has its own coupling problems). Without resolving this, `BlockPeriodizedStrategy` and `HybridStrategy` cannot compute a prescribed weight for the first session in a block on a new exercise.

---

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area 1 — Block builder UX**
- **D-01:** Single-screen `BlockBuilderView` mirroring `RoutineBuilderView`; name + start date at top; ordered phase list below with inline editors per phase; drag-handle reorder via `EditMode + .onMove`; `@Observable BlockDraft` + three-way merge `save(into:context:)`.
- **D-02:** Blocks live on the Routines tab — new "Blocks" section above routine folders inside `RoutinesListView`. Block rows show `Week N of M` inline. No 6th tab.
- **D-03:** Three stock templates + Blank — "Generic Strength Meso" (4/2/1/1), "Hypertrophy Meso" (5/2/1), "Powerlifting Peak" (3/3/1/1). Defined in `fitbod/Periodization/BlockTemplates.swift` as Swift literals.
- **D-04:** No hard ordering constraints — user can sequence phases any way they want.
- **D-05:** Single active block at a time — activating block X transactionally deactivates any other active block.

**Area 2 — Block timeline & home screen**
- **D-06:** `BlockCard` above `ResumeWorkoutBanner` on Today tab when a block is active.
- **D-07:** Heat-map phase colors — accumulation = accent teal (`#0E7C86`), intensification = amber (`#F59E0B`), realization = orange (`#EA580C`), deload = desaturated gray (`#94A3B8`).
- **D-08:** Horizontal swipe on the block card — `TabView` with `.tabViewStyle(.page(indexDisplayMode: .never))`; each page = one week.
- **D-09:** Linear block week ("Week 5 of 8") — counter spanning the entire block, computed from `block.startDate` and total weeks across all `BlockPhase` rows.

**Area 3 — Phase multipliers & deload mechanics**
- **D-10:** RP-style default multipliers (the "Tactical 8" defaults):
  - Accumulation: `volumeMultiplier = 1.0`, `intensityMultiplier = 0.75`
  - Intensification: `volumeMultiplier = 0.85`, `intensityMultiplier = 0.88`
  - Realization: `volumeMultiplier = 0.6`, `intensityMultiplier = 0.97`
  - Deload: `volumeMultiplier = 0.5`, `intensityMultiplier = 0.75`
- **D-11:** Multiplicative against routine baseline. Strategies multiply `RoutineExercise.targetSets × prescribedWeight` by phase multipliers. No e1RM dependency in Phase 4.
- **D-12:** Deload halves working sets, keeps weight (`3×8 @ 100kg → 2×8 @ 100kg`).
- **D-13:** Deload visual = banner on Today + tinted block card.

**Area 4 — PeriodizationEngine & strategies**
- **D-14:** Static facade `PeriodizationEngine.phase(for: Block, on: Date) -> BlockPhase?`. Pure function. No SwiftData coupling.
- **D-15:** Strategies live in `fitbod/Prescription/`. New files: `BlockPeriodizedStrategy.swift`, `HybridStrategy.swift`, `PeriodizationEngine.swift`.
- **D-15a:** Block UI lives in `fitbod/Periodization/` — `BlockBuilderView.swift`, `BlockCard.swift`, `MesocycleNavigatorView.swift`, `BlockReviewView.swift`, `BlockTemplates.swift`, `BlockDraft.swift`.
- **D-16:** Hybrid = `min(blockTarget, rpeTarget)`. Block defines the theoretical max for the phase; RPE responds to fatigue. Hybrid autoregulates ONLY downward.
- **D-17:** No-history baseline = `RoutineExercise.prescribedWeight`. [**RISK: field does not yet exist — see Open Questions**]

**Area 5 — Routine ↔ block linkage**
- **D-18:** Assignment via `RoutineBuilderView` header — "Block" menu showing all defined blocks + "None".
- **D-19:** Disallow `.block` / `.hybrid` progression unless routine is in a block.
- **D-20:** Snapshot `routine.block` onto `Session.block` at session start.

**Area 6 — Phase-end review**
- **D-21:** Trigger at end of block only. `BlockReviewView` as modal on next Today-tab open when `block.endDate < Date.now AND block.isActive == true AND block.reviewedAt == nil`. Subsequent opens don't re-surface (track via `block.reviewedAt: Date?`).
- **D-22:** Scaffold all four sections — Total volume (Phase 4 ships), e1RM deltas (Phase 4 ships using Phase 3's e1RM helper), PRs hit ("Coming in Phase 6" placeholder), Recommended next phase (static rule).
- **D-23:** Static next-phase rules — `.deload → .accumulation`, `.realization → .deload`, `.accumulation → .intensification`, `.intensification → .realization`.

**Area 7 — Fatigue-triggered deload advisory**
- **D-24:** Phase 4 ships UI scaffold + stubbed signal. `FatigueAdvisory` protocol in `fitbod/Prescription/`. `StubFatigueAdvisory` returns `false`.
- **D-25:** Type-level canonicality enforcement. `FatigueAdvisory` returns only `FatigueSuggestion` values, never `DeloadMutation`. Single-writer enforced by type.

**Area 8 — Schema evolution**
- **D-26:** `Block.reviewedAt: Date?` lands in SchemaV3 (Phase 3's migration) if not yet sealed; otherwise SchemaV4 in Phase 4. Default-valued optional, FOUND-02 safe.

### Claude's Discretion

- Exact heat-map color hex values for intensification/realization — UI-SPEC locked.
- Modal vs sheet form factor for `BlockReviewView` — UI-SPEC chose `.sheet` with `.large` detent.
- Block card swipe-pager dot indicators on/off — UI-SPEC chose off.
- Copy for the deload banner / canonicality contract / next-phase recommendation — UI-SPEC locked verbatim.
- Whether `BlockTemplates.swift` is a static enum vs a `let` array vs a JSON resource — planner chooses (static Swift literal recommended).
- Whether `BlockDraft.blockID: UUID?` for the routine-builder block picker is wired via `RoutineDraft` (Phase 2) extension or a new param on the picker — planner chooses.

### Deferred Ideas (OUT OF SCOPE)

- **Per-day routine assignment within the mesocycle** — Phase 4 week cards show a flat list of "routines linked to this block." Deferred to v1.x.
- **Multiple concurrent active blocks** (rejected as Q-05 option B).
- **Real fatigue/plateau signal** (BLOCK-06 substance) — Phase 5 fills `FatigueAdvisory.shouldSuggest()` with the real signal. UI scaffold locked here.
- **Block-aware progress charting** — Phase 6.
- **PRs hit / volume aggregation surfaced in BlockReviewView** — Phase 5 (volume) + Phase 6 (PRs) fill the placeholders.
- **Block templates marketplace / shareable mesos** — out of scope per PROJECT.md.
- **"Smart" next-phase recommendation engine** — Phase 4 ships static rules; smart engine is a future-version question.
- **Block carryover / "continue this block another N weeks"** — out of scope.
- **Per-phase-kind warm-up scaling beyond deload** — Phase 3 handles deload-skip; per-phase variants deferred.
- **Block-aware intent overrides** — out of scope.
- **Tracking adherence (% of scheduled sessions completed)** — Phase 5 or 6.

---

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BLOCK-01 | User can define training blocks with phase sequence and week length per phase | §SwiftData Model Sketch + §Files to Create/Modify (BlockBuilderView, BlockDraft, BlockPhaseEditorRow); CONTEXT D-01..D-04 |
| BLOCK-02 | Active block visible on home screen with phase chip, "Week N of M", days remaining, phase color-coded | §Week Navigation State + §Files (BlockCard, MesocycleWeekPage); CONTEXT D-06..D-09 |
| BLOCK-03 | User can navigate weeks within a block (swipe between weeks) | §Week Navigation State (TabView paging with derived currentWeekIndex); CONTEXT D-08 |
| BLOCK-04 | Scheduled deload weeks auto-reduce prescribed volume (~50%) and adjust intensity per the deload phase definition | §Deload Mechanics (working-set halving + intensity multiplier application); §Periodization Theory Validation (50% volume cut is RP-canonical); CONTEXT D-10/D-12 |
| BLOCK-05 | Deload weeks are visually distinct (banner / calendar tint / volume targets cut on bars) | §Files (DeloadWeekBanner, BlockCard tint via BlockPhaseColors); CONTEXT D-13 |
| BLOCK-06 | App surfaces a "consider deload" alert when fatigue/performance signals spike | §Files (ConsiderDeloadBanner, FatigueAdvisory protocol, StubFatigueAdvisory); CONTEXT D-24 (scaffold only in Phase 4; Phase 5 fills signal) |
| BLOCK-07 | End-of-block produces a phase-end review | §Phase-End Review (4-section scaffold; total volume + e1RM deltas inline; PRs placeholder); CONTEXT D-21..D-23 |
| BLOCK-08 | Scheduled block deload is canonical; fatigue-triggered alerts are advisory and never override the block schedule | §Algorithm Patterns (type-level enforcement: FatigueAdvisory returns only FatigueSuggestion, never DeloadMutation; only PeriodizationEngine.advance sets deload state); CONTEXT D-25 |
| PRES-05 | BlockPeriodizedStrategy resolves weight from the active block phase's intensity curve | §Algorithm Patterns (BlockPeriodizedStrategy pseudocode); §Periodization Theory Validation (multipliers verified); CONTEXT D-10/D-11/D-17 |
| PRES-06 | HybridStrategy combines block phase context with RPE-driven daily adjustment | §Algorithm Patterns (HybridStrategy pseudocode: min(blockTarget, rpeTarget)); CONTEXT D-16 |

---

## Architectural Responsibility Map

Single-tier iOS app (no client/server split). Capabilities map to module boundaries within the iOS target.

| Capability | Primary Module | Secondary Module | Rationale |
|------------|-------------|----------------|-----------|
| Block schema + cascade rules | SwiftData @Model (Models/) | — | Already shipped Phase 1; only one new optional field (`Block.reviewedAt`) in Phase 4 |
| Block / phase advancement math | `fitbod/Prescription/PeriodizationEngine.swift` (pure-function namespace enum) | — | Pure function; no SwiftData coupling; matches Phase 3 `WarmupRamp` / `Calibration` pattern |
| BlockPeriodized + Hybrid prescription | `fitbod/Prescription/*Strategy.swift` (value types conforming to `ProgressionStrategy`) | `PeriodizationEngine` (DI) | Strategies stay in `Prescription/` alongside the four-protocol family; engine injected so strategies remain SwiftData-free |
| Block builder UI | `fitbod/Periodization/BlockBuilderView.swift` | `BlockDraft` (`@Observable`) | Mirrors Phase 2 `RoutineBuilderView` + `RoutineDraft` pattern verbatim |
| Active-block card on Today | `fitbod/Periodization/BlockCard.swift` | `@Query<Block>(filter:#Predicate{$0.isActive})` directly in view | MV-VM-lite — query in view per FOUND-06; ephemeral selected-week state owned by `@State` |
| Phase-end review | `fitbod/Periodization/BlockReviewView.swift` | `@Query<SetEntry>` filtered to block date range | Single-block aggregation, scoped to one render, no aggregation service needed |
| Fatigue advisory canonicality | `fitbod/Prescription/FatigueAdvisory.swift` (protocol) + `StubFatigueAdvisory.swift` (impl) | `ConsiderDeloadBanner` (UI) | Type-level enforcement of BLOCK-08; protocol returns only `FatigueSuggestion`, never `DeloadMutation` |
| Snapshot extension (session-block link) | `fitbod/Sessions/SessionFactory.swift` (one-line addition) | — | Existing snapshot site, single-line patch |
| Routine ↔ block linkage | `fitbod/Routines/RoutineBuilderView.swift` (header picker) + `fitbod/Routines/RoutineDraft.swift` (new `blockID: UUID?` field) + `fitbod/Routines/PrescriptionEditorRow.swift` (conditional case filter) | — | Header picker matches Phase 2 folder picker pattern; case filter prevents degenerate state per D-19 |

---

## Periodization Theory Validation

**Question:** Are the locked default multipliers defensible against current RP/RTS literature?

### Canonical model — published evidence

Block periodization as a sequence of accumulation → intensification (transmutation) → realization mesocycles is the **Issurin model** [CITED: Sportlyzer / TrainingPeaks / Track & Field News], adapted by RP and applied to hypertrophy/strength contexts. The published intensity bands are consistent across multiple independent sources:

| Phase | Volume (RP literature) | Intensity (% 1RM, Issurin/HPRC bands) | Duration |
|-------|------------------------|----------------------------------------|----------|
| Accumulation | High (climb from MEV → MAV/MRV over weeks) | **50–75% 1RM** [CITED: HPRC/CoachMePlus] | 3–6 weeks typical; up to 12 for beginners [CITED: Arvo / RP] |
| Intensification (transmutation) | Moderate, reduced from accumulation peak | **75–90% 1RM** [CITED: HPRC/CoachMePlus] | 2–4 weeks [CITED: Arvo / BodySpec] |
| Realization (peak/taper) | Low | **≥90% 1RM** [CITED: HPRC] up to maximal | 1–3 weeks [CITED: TrainingPeaks] |
| Deload | **Reduced 40–60% from accumulation peak**, most commonly cited at 50% volume [CITED: PMC review of deload practices] | Typically held or modestly reduced; some protocols cut both [CITED: RP help center "if too beaten up, cut both"] | ~7 days [CITED: PMC Delphi consensus] |

### Validation of CONTEXT.md D-10 multipliers

**Locked CONTEXT.md values** (assumed expressed as fraction of training max / e1RM):

| Phase | D-10 Volume | D-10 Intensity | Maps to literature? |
|-------|------------|----------------|--------------------|
| Accumulation | 1.0 (baseline) | 0.75 | **Match.** Top of accumulation 1RM band (50–75%) — verifiable HPRC citation [CITED: HPRC]. Sets baseline = "weeks where the user works at full volume at moderate intensity." |
| Intensification | 0.85 | 0.88 | **Match.** Middle of intensification 1RM band (75–90%) [CITED: HPRC]. 0.85 volume = ~15% reduction, consistent with RP's "moderate volume, high intensity" descriptor. |
| Realization | 0.6 | 0.97 | **Match (slightly aggressive on intensity).** 0.97 is at the top of realization (≥90% [CITED: HPRC]). 0.6 volume aligns with the "low volume" descriptor for peak/taper [CITED: BodySpec / Arvo]. |
| Deload | 0.5 | 0.75 | **Match.** 50% volume cut is the most-cited deload prescription [CITED: PMC review — 41–60% reduction "most effective"]. Holding intensity at accumulation level (0.75) matches RP's primary deload protocol [CITED: RP help center]. |

**Verdict: CONTEXT.md D-10 values are defensible against canonical literature.** They sit in the middle of published evidence envelopes for every phase. The user can edit any value in the builder; this is "good starting point," not "scientific lock."

### Task brief alternative values (not adopted)

The task brief mentioned alternative values: vol 1.0/0.85/0.55/0.50 and intensity 0.70/0.825/0.925/0.65. These are also defensible:
- Volume 0.55 (vs 0.6) realization — slightly more aggressive taper, consistent with "low volume" peak phase.
- Intensity 0.70 (vs 0.75) accumulation — toward the lower end of the published 50–75% band.
- Intensity 0.65 (vs 0.75) deload — drops both vol and intensity per the "if too beaten up" alternative RP protocol [CITED: RP help center "drop both volume and intensity"].

**Both sets are inside the published evidence envelope.** Recommendation: ship CONTEXT.md D-10 verbatim because (a) they match the most-cited single-protocol values, (b) the user can edit each multiplier per phase in the builder, and (c) `BlockTemplates.swift` makes alternative templates a one-file diff for the user (or for a future v1.x update if a research-driven re-tune is warranted).

### Confidence

[VERIFIED] — Issurin canonical model and the three-phase structure [HIGH confidence; multiple independent sources agree].

[VERIFIED] — Specific intensity bands per phase (50–75% / 75–90% / ≥90%) [HIGH confidence; HPRC / CoachMePlus / Hevy Coach concur].

[VERIFIED] — Deload at 50% volume as mainstream [HIGH confidence; PMC systematic literature review confirms 41–60% range with 50% as median practice].

[ASSUMED] — That CONTEXT.md's `intensityMultiplier` values are expressed as fraction of training max / 1RM and applied multiplicatively to `prescribedWeight`. CONTEXT.md D-11 confirms "multiplicative against routine baseline." This interpretation is the only one that lines up with published 1RM percentages.

[ASSUMED] — That the user's `RoutineExercise.prescribedWeight` (whenever it materializes — see Open Questions) represents the user's working weight at ~100% of their accumulation-phase target, NOT their 1RM. Under this assumption, a 0.97 intensity multiplier means "work at 97% of your normal working weight," not "work at 97% 1RM." This matches CONTEXT.md D-11 ("multiplicative against routine baseline. No e1RM dependency in Phase 4.").

---

## Algorithm Patterns

### `PeriodizationEngine` (pure-function namespace enum)

**Lives in:** `fitbod/Prescription/PeriodizationEngine.swift`
**Pattern:** Same as Phase 3 `WarmupRamp` and `Calibration` — `public enum` with static funcs, no instance state, no SwiftData calls.

```
PeriodizationEngine.phase(for block: Block, on date: Date) -> BlockPhase?

  1. Let phases = block.phases ?? [], sorted by orderIndex ascending
  2. If phases.isEmpty → return nil
  3. Compute daysSinceStart = floor((date - block.startDate) / 86400)
  4. If daysSinceStart < 0 → return phases.first (block hasn't started yet; show first phase as preview)
  5. Walk phases:
       cumulativeDays = 0
       for each phase in phases:
         phaseDays = phase.weeks * 7
         if daysSinceStart < cumulativeDays + phaseDays:
           return phase
         cumulativeDays += phaseDays
  6. Past end of block → return nil (caller handles end-of-block; D-21)


PeriodizationEngine.weekIndex(for block: Block, on date: Date) -> Int?
  1. daysSinceStart = floor((date - block.startDate) / 86400)
  2. If daysSinceStart < 0 OR daysSinceStart >= totalDays(block) → return nil
  3. Return floor(daysSinceStart / 7)  // 0-based; UI renders as N+1


PeriodizationEngine.weekContext(for block: Block, weekIndex: Int) -> MesocycleWeekContext?
  Returns the rendering bundle for one TabView page on BlockCard.
  - phase (which BlockPhase this week falls in)
  - weekStartDate / weekEndDate (week range)
  - daysRemaining (only meaningful for currentWeek)
  - isCurrentWeek (bool — based on Date.now)
  - isDeloadWeek (bool — based on phase.kind == .deload)


PeriodizationEngine.recommendedNextKind(after kind: BlockPhaseKind) -> BlockPhaseKind
  Pure static map per CONTEXT D-23:
    .accumulation → .intensification
    .intensification → .realization
    .realization → .deload
    .deload → .accumulation
```

### `BlockPeriodizedStrategy`

**Conforms to:** `ProgressionStrategy` (Phase 3 protocol)
**Inputs:** Phase 3's `prescribe(history:targetRepsLow:targetRepsHigh:targetRPE:smallestIncrement:plates:barWeight:minCalibrationSets:lastSessionWeight:lastSessionReps:lastSessionRPE:lastSessionDate:lastSessionRepsArray:)` — Phase 4 must extend this with `block: Block?` and `today: Date` via DI through the factory.

```
BlockPeriodizedStrategy.prescribe(...) -> (weight: Double, explanation: PrescriptionExplanation)

  1. Resolve baseline:
     - baseline = caller-supplied lastSessionWeight ?? routineExercise.prescribedWeight  // <-- D-17; see Open Questions
     - If baseline is nil/0 → return (0, explanation = "No baseline weight set. Edit this exercise to enter a starting weight.")

  2. Resolve phase context:
     - currentPhase = PeriodizationEngine.phase(for: block, on: today)
     - If currentPhase == nil → fall through to caller-defined no-block behavior (factory should never route here without a block, but defensive)

  3. Apply intensity multiplier:
     - rawTarget = baseline * currentPhase.intensityMultiplier

  4. Round to plates:
     - rounded = PlateCalculator.roundDown(target: rawTarget, barWeight: barWeight, plates: plates)

  5. Build explanation:
     - formulaName = "Block periodized"
     - computedLine = "Phase {phase.kind}: baseline {baseline} kg × ×{intensityMultiplier} → {rawTarget} kg"
     - roundedLine = "→ {rounded} kg (rounded down to {smallestIncrement} kg plates)"
     - status = .notApplicable  // calibration is not a block-periodized concept

  6. Return (rounded, explanation)
```

**Working-set count adjustment:** `BlockPeriodizedStrategy.prescribe` returns only weight. Volume cut (deload halving) is enforced by `SessionFactory.start` reading `currentPhase.volumeMultiplier` and creating `floor(routineExercise.targetSets * volumeMultiplier)` SetEntry rows instead of `targetSets`. **The set-count cut is a SessionFactory concern, not a strategy concern.** This split keeps strategies pure-function on weight only.

### `HybridStrategy`

**Conforms to:** `ProgressionStrategy`. Receives both `Block` and `today` via DI. Combines `BlockPeriodizedStrategy` + `RPEAutoregStrategy` outputs.

```
HybridStrategy.prescribe(...) -> (weight: Double, explanation: PrescriptionExplanation)

  1. Compute block branch:
     - blockResult = BlockPeriodizedStrategy().prescribe(...)
     - blockTarget = blockResult.weight

  2. Compute RPE branch:
     - rpeResult = RPEAutoregStrategy().prescribe(...)
     - rpeTarget = rpeResult.weight

  3. Take minimum (block defines the CEILING; RPE pulls down on bad days, never up):
     - chosen = min(blockTarget, rpeTarget)
     - sourceLabel = chosen == blockTarget ? "block ceiling" : "rpe-driven"

  4. Build explanation:
     - formulaName = "Hybrid (block + RPE)"
     - computedLine = "Block ceiling: {blockTarget} kg · RPE target: {rpeTarget} kg · Using: min → {chosen} kg"
     - status = rpeResult.status  // forward RPE calibration status if applicable
     - range = nil  // hybrid does not display a range; the single chosen value is the prescription

  5. Return (chosen, explanation)
```

**Why `min(...)` is conservative and correct per BLOCK-08 spirit:** If RPE-autoreg says "you're fresh, push 110 kg" but block intensification cap says "this week is 100 kg," HybridStrategy picks 100 kg. RPE never pulls the prescription past the block ceiling. If block says "intensification, 100 kg" but RPE says "you're cooked, 95 kg," Hybrid picks 95 kg — block schedule is honored as a maximum, not a floor.

### `FatigueAdvisory` protocol (BLOCK-08 type-level canonicality)

**Lives in:** `fitbod/Prescription/FatigueAdvisory.swift`

```
protocol FatigueAdvisory: Sendable {
    func shouldSuggest(context: SessionContext) -> Bool
    func suggestion(context: SessionContext) -> FatigueSuggestion
    // CRITICAL: protocol returns ONLY FatigueSuggestion values.
    // It cannot return a DeloadMutation, BlockState change, or any
    // type that could mutate the scheduled block. Single-writer
    // enforced at the type level.
}

struct FatigueSuggestion {
    let reason: String  // surfaces as the ConsiderDeloadBanner secondary line
    // NO mutation power. The advisory can only suggest text.
}

struct StubFatigueAdvisory: FatigueAdvisory {
    func shouldSuggest(context: SessionContext) -> Bool { false }
    func suggestion(context: SessionContext) -> FatigueSuggestion {
        FatigueSuggestion(reason: "")
    }
}
```

The only writer of `Block` deload state is `PeriodizationEngine.advance(block:on:)` (or `BlockDraft.save(...)` for builder edits). The advisory has no compile-time path to mutate a `Block`. This satisfies BLOCK-08 by construction.

---

## Deload Mechanics

### Scheduled-only model (matches mainstream practice)

Deloads in Phase 4 are **scheduled** — they're a `BlockPhase` with `kind == .deload` that the user defines in the builder. They auto-apply when the calendar week falls within that phase. There is no reactive/automatic deload trigger; the user's only "reactive" surface is the `ConsiderDeloadBanner` advisory (which never mutates the schedule).

This matches mainstream block-periodization practice [CITED: Issurin / RP / Arvo] and avoids the conflict-resolution rabbit hole between two competing deload triggers.

### How multipliers apply at the week boundary

When `PeriodizationEngine.phase(for: block, on: Date.now).kind == .deload` is true for the current session:

1. **Working-set count cut** (CONTEXT.md D-12 — "halve working sets, keep weight"):
   - `SessionFactory.start(routine:on:context:)` reads `currentPhase.volumeMultiplier` from the resolved phase
   - For each `RoutineExercise`, creates `max(1, floor(re.targetSets * currentPhase.volumeMultiplier))` SetEntry rows instead of `re.targetSets`
   - Example: `targetSets = 3, volumeMultiplier = 0.5 → 2 sets logged` (floor(1.5) clamped to ≥1)
   - **D-12 special case:** the locked "halve sets, keep weight" decision means deload deliberately does NOT apply intensity multiplier to weight; the multiplier value (0.75) is informational/displayed but the weight is held at the prior session's actual. This is RP's "primary deload" pattern (volume cut, intensity held) [CITED: RP help center].
   - **Important:** for accumulation/intensification/realization phases, `intensityMultiplier` IS applied to weight by the strategy. Deload week is the exception where weight is HELD per D-12.

2. **Weight held at prior** (D-12):
   - On deload weeks, `BlockPeriodizedStrategy.prescribe` returns the **prior session's actualWeight** (or `routineExercise.prescribedWeight` for no-history cases), NOT `prior * deload.intensityMultiplier`.
   - The `intensityMultiplier` field on the deload phase row is kept around for display ("×0.75 int" in the BlockCard preview) but is not actually multiplied into the deload week's weight prescription.
   - This is a Phase 4 deliberate choice (D-12) that diverges from a "pure" multiplier model. The planner should call this out in a comment.

3. **Warm-up generator skip** (Phase 3 already wired):
   - `WarmupRamp.shouldGenerate(for:deloadActive:topWorkingWeight:barWeight:warmupConfig:)` returns false when `deloadActive == true`
   - The deload flag is passed by `SessionFactory.start` reading `currentPhase.kind == .deload` and forwarding to `WarmupRamp.shouldGenerate(deloadActive:)`

4. **Visual signals** (BLOCK-05 / D-13):
   - `DeloadWeekBanner` renders at top of Today scroll when `currentWeek.isDeloadWeek`
   - `BlockCard` background tints to deload color (`Color(red: 0.58, green: 0.64, blue: 0.72).opacity(0.15)`) for the deload week page
   - `MesocycleNavigatorView` highlights the deload week with the same tint

### Edge cases

- **First day of deload (transition):** the calendar boundary moment when `Date.now` first falls inside the deload phase. The strategy/factory correctly resolves the new phase at session start; no state needs explicit "advance" handling. Sessions started on day N of week M correctly resolve to the right phase via `PeriodizationEngine.phase(for:on:)`.
- **Multi-phase blocks where deload is not the last phase** (D-04 allows arbitrary ordering): the calendar walk in `PeriodizationEngine.phase(for:on:)` is order-agnostic — it walks `orderIndex` ascending and stops at the first phase containing the date. Mid-block deloads are handled correctly.
- **Block ends mid-deload-week:** Deload behavior persists until `Date.now > block.endDate`, at which point `BlockReviewView` triggers per D-21. The day after `endDate`, `PeriodizationEngine.phase(for:on:)` returns nil and the strategy falls back to its no-block path.

---

## SwiftData Model Sketch

### Existing models (already shipped in Phase 1) — NO new fields needed except D-26

```swift
@Model
public final class Block {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var startDate: Date = Date.now
    public var endDate: Date? = nil          // computed at save: startDate + sum(phase.weeks)*7
    public var notes: String? = nil
    public var isActive: Bool = false        // single-active invariant enforced in BlockDraft.save
    public var reviewedAt: Date? = nil       // *** NEW in SchemaV3 (or V4 if V3 sealed) per D-26 ***

    @Relationship(deleteRule: .cascade, inverse: \BlockPhase.block)
    public var phases: [BlockPhase]? = []

    @Relationship(inverse: \Routine.block)
    public var routines: [Routine]? = []     // nullify: deleting block sets routine.block = nil

    @Relationship(inverse: \Session.block)
    public var sessions: [Session]? = []     // nullify: deleting block preserves history; sessions retain snapshot
}

@Model
public final class BlockPhase {
    @Attribute(.unique) public var id: UUID = UUID()
    public var block: Block? = nil
    public var orderIndex: Int = 0
    public var nameRaw: String = "accumulation"  // BlockPhaseKind via .kind extension
    public var weeks: Int = 4
    public var volumeMultiplier: Double = 1.0
    public var intensityMultiplier: Double = 1.0
    public var notes: String? = nil
}
```

### One new field — Block.reviewedAt (SchemaV3 or V4 per D-26)

```swift
// Add to Block:
public var reviewedAt: Date? = nil
```

**Migration path (D-26 resolved):** Phase 3 is currently in flight defining SchemaV3 (per plan 03-01). The planner MUST check whether plan 03-01 has shipped its SchemaV3 commit:
- **If SchemaV3 not yet committed:** add `Block.reviewedAt: Date?` to SchemaV3 alongside Phase 3's additive fields. Lightweight migration. Phase 4 ships zero new schema versions.
- **If SchemaV3 has shipped and is sealed:** define SchemaV4 in Phase 4. Lightweight migration (V3 → V4) for the single optional field. Schema lineage becomes [V1, V2, V3, V4].

This is checkable via: `find fitbod/Persistence -name "SchemaV3.swift"` — if present and contains a Block entry, see whether it already declares `reviewedAt`.

### Cascade rules (already shipped — no changes)

| Relationship | Rule | Why |
|--------------|------|-----|
| `Block → BlockPhase` | `.cascade` | Phases are owned by the block. Deleting the block deletes its phases. |
| `Block → Routine` (inverse) | `.nullify` (SwiftData default for non-cascade inverse) | Deleting a block detaches routines without deleting them. |
| `Block → Session` (inverse) | `.nullify` | Snapshot pattern: deleting the block preserves session history; sessions retain `Session.block = nil` after, but the prior snapshot data on `SessionExercise` is intact. |
| `Routine → Session` | NO SwiftData relationship; soft `Session.sourceRoutineID: UUID?` | Already established Phase 2 pattern (PITFALLS #1). |

### Why no schema migration beyond `reviewedAt`

Every other Phase 4 capability is achievable with the existing Phase 1 schema:
- `BlockPhaseKind` enum already exists with all 4 cases (`accumulation` / `intensification` / `realization` / `deload`)
- `BlockPhase.volumeMultiplier` and `intensityMultiplier` already exist as `Double` with sane defaults (1.0)
- `Routine.block: Block?` already wired
- `Session.block: Block?` already wired (and inverse declared on `Block.sessions`)
- `ProgressionKind` enum already has `.block` and `.hybrid` cases (Phase 3 has them stub-fallback to DoubleProgression; Phase 4 swaps in the real strategies)
- `UserSettings.deloadAlertEnabled: Bool` already exists for gating `ConsiderDeloadBanner`

The schema work in Phase 4 is exactly one optional `Date?` field. Everything else is code-only.

---

## Week Navigation State

### Source of truth: calendar math, not stored state

The "current week" is **derived** from `block.startDate` + `Date.now`, NOT stored on `Block`. This avoids drift, midnight-boundary bugs, and the need to "advance" the block on a timer.

```
currentWeekIndex = PeriodizationEngine.weekIndex(for: activeBlock, on: Date.now) ?? 0
totalWeeks = activeBlock.phases.reduce(0) { $0 + $1.weeks }

UI display: "Week \(currentWeekIndex + 1) of \(totalWeeks)"
```

### Where the swipe-pager selection lives

`BlockCard` owns ephemeral `@State var selectedWeekIndex: Int`, initialized to `currentWeekIndex` on first appearance:

```swift
struct BlockCard: View {
    let block: Block
    @State private var selectedWeekIndex: Int

    init(block: Block) {
        self.block = block
        let current = PeriodizationEngine.weekIndex(for: block, on: Date.now) ?? 0
        _selectedWeekIndex = State(initialValue: current)
    }

    var body: some View {
        TabView(selection: $selectedWeekIndex) {
            ForEach(0..<totalWeeks(for: block), id: \.self) { weekIdx in
                MesocycleWeekPage(block: block, weekIndex: weekIdx)
                    .tag(weekIdx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}
```

### Days-remaining calculation

For the currently-selected week page, `MesocycleWeekContext.daysRemaining` is computed as:
- For current week (`selectedWeekIndex == currentWeekIndex`): `daysRemaining = ((weekIndex + 1) * 7) - daysSinceBlockStart`, clamped to 0...7
- For past weeks: not shown (caption renders "Completed" instead — UI-SPEC)
- For future weeks: shows "Starts in {N} days" where N = `weekStartDate - Date.now`

### Edge cases

- **Block hasn't started yet** (`Date.now < block.startDate`): `currentWeekIndex = 0`; days-remaining for week 0 shows "Starts in {N} days." `BlockCard` still renders.
- **Block has ended** (`Date.now > block.endDate`): `weekIndex(for:on:)` returns nil. `BlockCard` falls back to "Block ended — review pending." caption per UI-SPEC defensive copy.
- **Single-phase block, single week** (`weeks = 1, phases.count = 1`): `totalWeeks = 1`, pager has one page, swipe gesture is a no-op. Fine.

---

## Phase-End Review

### Trigger condition (D-21)

On `TodayView.task` (every Today-tab appearance):

```
Query: blocks where endDate < Date.now AND isActive == true AND reviewedAt == nil
Expected count: 0 or 1 (the single-active invariant prevents >1).

If count == 1 → present BlockReviewView(block: matched) as .sheet(.large).
Tap "Done" in sheet:
  modelContext.transaction {
    block.reviewedAt = Date.now
    block.isActive = false
  }
  // After this transaction, the query above returns 0 — sheet never re-surfaces.
```

### Section 1: Total volume (Phase 4 ships)

Computed inline via `@Query<SetEntry>` filtered to the block date range:

```
@Query(filter: #Predicate<SetEntry> { setEntry in
    let session = setEntry.sessionExercise?.session
    return session?.startedAt >= blockStartDate
        && session?.startedAt <= blockEndDate
        && setEntry.isComplete == true
        && setEntry.isWarmup == false
}) var setsInBlock: [SetEntry]

totalVolume = setsInBlock.reduce(0) { acc, set in
    acc + (set.weight * Double(set.reps))
}
workingSetCount = setsInBlock.count
sessionCount = Set(setsInBlock.compactMap { $0.sessionExercise?.session?.id }).count
```

**Local-let predicate workaround** (Phase 2 RESEARCH §6 Pitfall 1): capture `blockStartDate` and `blockEndDate` into local lets BEFORE the `#Predicate` body to avoid SwiftData's related-entity-date-compare footgun. Same pattern as `ExerciseHistoryView`.

**Display:**
- Primary: "{N} kg total" (where N is sum from above, formatted with thousands separator)
- Secondary: "{workingSetCount} working sets across {sessionCount} sessions"

### Section 2: e1RM deltas (Phase 4 ships, uses Phase 3 helper)

Per top-set per exercise within the block:

```
For each Exercise that has ≥2 sessions in the block date range:
  startSets = top working set from first session in block (by startedAt asc)
  endSets = top working set from last session in block (by startedAt desc)
  startE1RM = E1RMCalculator.e1rm(weight: startSets.weight, reps: startSets.reps)
  endE1RM   = E1RMCalculator.e1rm(weight: endSets.weight,   reps: endSets.reps)
  delta = endE1RM - startE1RM

Display per row: "{exercise.name}: {sign}{delta} kg"
  Positive → .systemGreen
  Negative → .systemRed
  Zero → .primary
```

**Empty state** (no exercises with ≥2 sessions): "Not enough sessions logged to compute deltas." (`.caption .secondaryLabel`)

**E1RM formula:** Phase 3 ships an e1RM helper (per ROADMAP Phase 3 references "Phase 3's e1RM helper for start-of-block vs end-of-block deltas"). Phase 4 must verify what file/function name Phase 3 actually shipped — likely `E1RMCalculator` or similar. If Phase 3 has not yet shipped the helper (in-flight per STATE.md), Phase 4 may need to inline a minimal Epley formula: `weight * (1 + reps / 30.0)` for reps ≤10.

### Section 3: PRs hit (PLACEHOLDER — Phase 6 fills)

UI-SPEC copy verbatim: "Coming in Phase 6. Full PR detection ships with the progress views update." (`.caption .secondaryLabel`). No computation. Section header still renders so the layout slot exists.

### Section 4: Recommended next phase (Phase 4 ships, static rule)

```
let justFinishedPhase = block.phases.sorted(by: orderIndex).last
let recommendedKind = PeriodizationEngine.recommendedNextKind(after: justFinishedPhase.kind)

Display:
  Body: "Start {recommendedKind.title} next." (e.g. "Start accumulation next.")
  CTA button: "Start {recommendedKind.title} Block" (e.g. "Start Accumulation Block")
    Tapping → opens BlockBuilderView pre-seeded with BlockTemplates.template(for: recommendedKind)
    Does NOT auto-activate the new block — user must toggle "Active block" in builder.
  Secondary button: "Not now" — dismisses sheet without seeding.
```

### Why no aggregation service (just inline @Query)

The aggregation queries above each scope to a single block's date range. No cross-block analytics in Phase 4. Phase 5/6 will need cross-block analytics (intent-split charts with phase shading) and will likely extract a `BlockAggregator` service then. For Phase 4, inline `@Query` in the view is sufficient and matches FOUND-06 (MV-VM-lite, no parallel view-model layer).

---

## Files to Create/Modify

### New files in `fitbod/Prescription/` (engine + strategies + advisory protocol)

| File | Role |
|------|------|
| `fitbod/Prescription/PeriodizationEngine.swift` | Pure-function namespace enum. `phase(for:on:)`, `weekIndex(for:on:)`, `weekContext(for:weekIndex:)`, `recommendedNextKind(after:)`. No SwiftData calls. |
| `fitbod/Prescription/BlockPeriodizedStrategy.swift` | `struct BlockPeriodizedStrategy: ProgressionStrategy`. Calls PeriodizationEngine, multiplies baseline by intensityMultiplier, rounds via PlateCalculator. |
| `fitbod/Prescription/HybridStrategy.swift` | `struct HybridStrategy: ProgressionStrategy`. Composes BlockPeriodizedStrategy + RPEAutoregStrategy; `min(blockTarget, rpeTarget)`. |
| `fitbod/Prescription/FatigueAdvisory.swift` | Protocol + `FatigueSuggestion` value type. No-mutation-power contract for BLOCK-08 type-level enforcement. |
| `fitbod/Prescription/StubFatigueAdvisory.swift` | Phase 4 impl returning `false` from `shouldSuggest`. Phase 5 swaps to real signal without UI changes. |

### New files in `fitbod/Periodization/` (UI feature directory — NEW)

| File | Role |
|------|------|
| `fitbod/Periodization/BlockBuilderView.swift` | Single-screen builder (mirror RoutineBuilderView). Name + start-date + active-toggle + ordered phase list. Toolbar Save/Cancel. |
| `fitbod/Periodization/BlockDraft.swift` | `@Observable` ephemeral draft (`name: String`, `startDate: Date`, `isActive: Bool`, `phases: [BlockPhaseDraft]`, `reviewedAt: Date?`). Three-way merge `save(into:context:)` with active-block transaction. |
| `fitbod/Periodization/BlockPhaseDraft.swift` | `@Observable` per-phase draft state (`kind: BlockPhaseKind`, `weeks: Int`, `volumeMultiplier: Double`, `intensityMultiplier: Double`). |
| `fitbod/Periodization/BlockPhaseEditorRow.swift` | One row of the phases list inside the builder. Phase-kind Menu chip + weeks Stepper + volume Stepper + intensity Stepper + drag handle. |
| `fitbod/Periodization/BlockTemplates.swift` | Static enum: `generic`, `hypertrophy`, `powerliftingPeak` returning seeded `BlockTemplate` structs. Plus `template(for: BlockPhaseKind)` for the BlockReviewView CTA seeding. |
| `fitbod/Periodization/BlockTemplate.swift` (or inline in BlockTemplates) | Value type for a template — `name: String, phases: [BlockPhaseDraft]`. |
| `fitbod/Periodization/BlockPhaseColors.swift` | Static enum: `color(for: BlockPhaseKind) -> Color` (full) + `tint(for: BlockPhaseKind) -> Color` (15% opacity). Inline hex values per UI-SPEC. |
| `fitbod/Periodization/BlockCard.swift` | Today-tab card. Internal `TabView(.page)` paging over `MesocycleWeekPage` views. Overflow menu (Edit/End). |
| `fitbod/Periodization/MesocycleWeekPage.swift` | One swipe-pager page: phase chip + week badge + days-remaining + multipliers preview + scheduled-routines list. |
| `fitbod/Periodization/MesocycleWeekContext.swift` (or inline) | Value type carrying `(phase, weekStartDate, weekEndDate, daysRemaining, isCurrentWeek, isDeloadWeek)` — output of `PeriodizationEngine.weekContext`. |
| `fitbod/Periodization/DeloadWeekBanner.swift` | Top-of-Today pinned banner during deload weeks. Non-dismissible. Deload-color tint background. |
| `fitbod/Periodization/ConsiderDeloadBanner.swift` | Advisory banner above BlockCard. Phase 4 ships scaffold; stub returns false so view never renders in Phase 4. |
| `fitbod/Periodization/BlockReviewView.swift` | `.sheet(.large)` modal triggered at end-of-block. 4 sections (Total volume / e1RM deltas / PRs hit placeholder / Recommended next phase). |
| `fitbod/Periodization/BlockRow.swift` | One row inside RoutinesListView "Blocks" section. Active-indicator dot + name + start-date caption + week badge. |
| `fitbod/Periodization/StartBlockCTA.swift` | "No active block" placeholder on Today when no active block exists. |
| `fitbod/Periodization/BlockPickerMenu.swift` | "Block: {name}" Menu added to RoutineBuilderView header. |

### Schema additions (one optional field)

| File | Modification |
|------|--------------|
| `fitbod/Persistence/SchemaV3.swift` (Phase 3) OR `fitbod/Persistence/SchemaV4.swift` (NEW if V3 sealed) | Add `Block.reviewedAt: Date?` per D-26. Lightweight migration. |
| `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` | Add `migrateV3toV4` stage if SchemaV4 path taken. No-op otherwise. |
| `fitbod/Models/Block.swift` | Add one line: `public var reviewedAt: Date? = nil`. |

### Modifications to existing Phase 2 / Phase 3 surfaces

| File | Modification |
|------|--------------|
| `fitbod/Routines/RoutinesListView.swift` | Add `Section("Blocks")` above existing folder sections. Custom header with "+ Block" Menu trigger. `@Query<Block>` sorted `isActive desc, startDate desc`. Empty-state inline. |
| `fitbod/Routines/RoutineBuilderView.swift` | Add `BlockPickerMenu` row in header section, beneath the existing folder picker. |
| `fitbod/Routines/RoutineDraft.swift` | Add `blockID: UUID?` field. Three-way merge `save(into:context:)` materializes `Routine.block` from a `Block` fetch-by-id. |
| `fitbod/Routines/PrescriptionEditorRow.swift` | Filter the progression Picker cases conditionally on `routine.block != nil`. Remove the Phase 3 "Block / Hybrid models activate in Phase 4" footnote (Phase 4 ships them). |
| `fitbod/Sessions/SessionFactory.swift` | Add one line: `session.block = routine.block`. Also: read `currentPhase` via PeriodizationEngine and apply `volumeMultiplier` to working set count when phase is deload. |
| `fitbod/App/RootView.swift` (TodayView slot) | Insert stack: `(1) DeloadWeekBanner` (conditional), `(2) ConsiderDeloadBanner` (conditional — Phase 4 stub never), `(3) BlockCard`, `(4) ResumeWorkoutBanner`. Or `(1) StartBlockCTA` if no active block. |
| `fitbod/Prescription/ProgressionStrategyFactory.swift` (Phase 3) | Replace `.block` and `.hybrid` fallbacks (currently route to DoubleProgressionStrategy per Phase 3) with the real strategies. Pass `Block` + `today` via DI. |
| `fitbod/Prescription/ProgressionStrategy.swift` (Phase 3) | EITHER extend `prescribe(...)` signature with `block: Block?, today: Date` (default `nil` / `Date.now`) so block-aware strategies can access context, OR define a parallel `BlockAwareStrategy` sub-protocol. The planner picks; extending the existing signature is the lower-friction path. |
| `fitbod/Prescription/PrescriptionExplanation` (Phase 3 value type) | Add two formula-name string variants for "Block periodized" / "Hybrid (block + RPE)" plus conditional rows for "Phase context" and "Deload note" per UI-SPEC. |

### New test suites in `fitbodTests/`

| Suite | Coverage |
|-------|----------|
| `PeriodizationEngineTests` | Phase resolution: walks phases by orderIndex, handles before-start / past-end / mid-block. Week index math. `recommendedNextKind` static map. |
| `BlockPeriodizedStrategyTests` | Multiplier application (accumulation/intensification/realization phases). Deload week weight-held behavior. No-baseline fallback. PlateCalculator integration. |
| `HybridStrategyTests` | `min(blockTarget, rpeTarget)` selection. Block-ceiling-enforced (RPE can pull down, not up). Source-label correctness. |
| `BlockDraftTests` | Three-way merge save. Active-block transactional invariant (saving as active deactivates other). Validation (empty name / no phases). |
| `BlockBuilderViewCopyTests` | UI-SPEC verbatim copy across all surfaces. |
| `BlockReviewMathTests` | Total volume sum. e1RM delta computation. Block date-range predicate. Empty-state for insufficient sessions. |
| `SingleActiveBlockInvariantTests` | Saving `isActive=true` on block X transactionally sets every other `isActive=false`. No orphan state. |
| `SessionBlockSnapshotTests` | `SessionFactory.start` copies `routine.block` to `session.block`. Detaching routine.block later does not mutate session.block. |
| `FatigueAdvisoryCanonicalityTests` | Type-level enforcement test: `FatigueAdvisory` protocol cannot return `DeloadMutation` (compile-time check; assert protocol surface). |
| `DeloadVolumeApplicationTests` | `SessionFactory.start` on deload week creates `floor(targetSets * 0.5)` SetEntry rows (clamped ≥1). Weight is held (not multiplied). |
| `BlockTemplatesTests` | Stock templates (Generic / Hypertrophy / PowerliftingPeak) produce valid drafts. Each phase has expected weeks count. |
| `PeriodizationEngineWeekIndexTests` | weekIndex math for typical block (8-week 3+2+2+1). Edge cases: day-0, day-N, day-after-end. |

**All test suites use `@MainActor + .serialized` over in-memory `ModelContainer` with `Schema(SchemaV3.models)` (or V4) + `FitbodSchemaMigrationPlan` matching the `SchemaV2MigrationTests` fixture pattern.**

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Suite`, `@Test`, `#expect`) — unit/model tests; XCTest retained for `fitbodUITests` |
| Config file | none — Xcode test scheme `fitbod` |
| Quick run command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing fitbodTests/<SuiteName> 2>&1 \| grep -E 'PASS\|FAIL\|error'` |
| Full suite command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Estimated runtime | ~60s quick, ~3-4 min full |

### Contract Surfaces (what gets tested)

| Surface | What | Why |
|---------|------|-----|
| `PeriodizationEngine.phase(for:on:)` | Phase resolution from `block` + `date` | Pure function; the heart of Phase 4 calendar math. Testable in isolation, no `ModelContainer`. |
| `PeriodizationEngine.weekIndex(for:on:)` | Week index math (0-based) | Pure function. Edge cases: before-start, mid-block, past-end. |
| `PeriodizationEngine.recommendedNextKind(after:)` | Static phase-to-next map | Pure function. Deterministic mapping per D-23. |
| `BlockPeriodizedStrategy.prescribe(...)` | Multiplier application per phase | Pure function. Property-based: result weight == baseline × intensityMultiplier (rounded down). Deload week → weight held. |
| `HybridStrategy.prescribe(...)` | `min(blockTarget, rpeTarget)` | Pure function. Property-based: result ≤ blockTarget AND result ≤ rpeTarget. |
| `BlockDraft.save(into:context:)` | Three-way merge save + active-block transaction | SwiftData touch. Must use in-memory `ModelContainer` per Phase 2 fixture pattern. |
| `SessionFactory.start(...)` extension | Snapshot `routine.block → session.block` + deload set-count cut | SwiftData touch. Must use in-memory `ModelContainer`. |
| `BlockReviewView` math (volume sum, e1RM deltas, recommended next) | View-internal computations | SwiftData touch (`@Query` over block date range). |
| `FatigueAdvisory` protocol shape | Type-level: returns only `FatigueSuggestion`, never `DeloadMutation` | Static type assertion. No runtime needed; compiles or doesn't. |

### Test Bench (fixture setup)

```swift
@MainActor
@Suite("PeriodizationEngine", .serialized)
struct PeriodizationEngineTests {
    // PURE FUNCTION — no ModelContainer needed.
    // Construct in-memory Block + BlockPhase via .init() and assign properties directly.
    // Test phase resolution against synthetic dates.

    @Test func phaseOneInAccumulationOnDayZero() {
        let block = makeBlock(phases: [
            (kind: .accumulation, weeks: 3),
            (kind: .intensification, weeks: 2),
            (kind: .deload, weeks: 1)
        ])
        let phase = PeriodizationEngine.phase(for: block, on: block.startDate)
        #expect(phase?.kind == .accumulation)
    }
}

@MainActor
@Suite("BlockDraftSave", .serialized)
struct BlockDraftSaveTests {
    // SwiftData touch — uses in-memory ModelContainer.
    // Same fixture pattern as SchemaV2MigrationTests.
    func makeContext() -> ModelContext {
        let schema = Schema(SchemaV3.models)  // or V4
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, migrationPlan: FitbodSchemaMigrationPlan.self, configurations: [config])
        return ModelContext(container)
    }

    @Test func savingAsActiveDeactivatesOthers() async throws {
        let ctx = makeContext()
        let existing = Block()
        existing.name = "Previous"
        existing.isActive = true
        ctx.insert(existing)
        try ctx.save()

        var draft = BlockDraft.template(BlockTemplates.generic)
        draft.isActive = true
        try draft.save(into: ctx)

        let blocks = try ctx.fetch(FetchDescriptor<Block>())
        let activeCount = blocks.filter(\.isActive).count
        #expect(activeCount == 1)
    }
}
```

### Property-Based Invariants

| Invariant | Test |
|-----------|------|
| **Deload week always cuts volume** | For any block with a deload phase, `SessionFactory.start` on a date inside the deload week creates fewer SetEntry rows than `routineExercise.targetSets`. Specifically `floor(targetSets * 0.5)` clamped ≥1. |
| **Block week count = sum of phase weeks** | For any block, `weekIndex(for: block, on: block.endDate)` returns `totalWeeks - 1`. `weekIndex(for: block, on: block.endDate + 1.day)` returns nil. |
| **Hybrid never exceeds block ceiling** | For any inputs, `HybridStrategy.prescribe(...).weight <= BlockPeriodizedStrategy.prescribe(...).weight`. |
| **Phase-end review always has 4 sections** | `BlockReviewView` body always renders 4 section headers regardless of data state (PRs section uses placeholder copy when no data). |
| **Single active block** | After any `BlockDraft.save(isActive: true)`, `fetch(Block where isActive == true).count == 1`. |
| **FatigueAdvisory cannot mutate** | Type-level: `FatigueAdvisory` protocol returns `Bool` and `FatigueSuggestion`; neither type has a `Block` mutation method. (Verified by inspecting `FatigueSuggestion` struct definition — no `func` referencing `Block`.) |
| **Recommended next is deterministic** | `recommendedNextKind(after: .deload) == .accumulation` (and the other 3 cases) — pure-function property test across all 4 inputs. |
| **e1RM delta sign matches direction** | For synthetic SetEntry history where end weight > start weight, BlockReviewView computes delta > 0. Inverse for weight loss. Zero for unchanged. |

### Sampling Rate

- **Per task commit:** `xcodebuild test -only-testing fitbodTests/<relevant suite>` (~30s for pure-function suites; ~60s for SwiftData suites)
- **Per wave merge:** Full `fitbodTests` (~3-4 min)
- **Phase gate:** Full suite green before `/gsd-verify-work`
- **Max feedback latency:** ~60s

### Wave 0 Gaps

These test files don't exist yet and must be scaffolded before downstream plans wire production code:

- [ ] `fitbodTests/PeriodizationEngineTests.swift` — covers `phase(for:on:)`, `weekIndex(for:on:)`, `recommendedNextKind(after:)`
- [ ] `fitbodTests/BlockPeriodizedStrategyTests.swift` — covers PRES-05
- [ ] `fitbodTests/HybridStrategyTests.swift` — covers PRES-06
- [ ] `fitbodTests/BlockDraftSaveTests.swift` — covers BLOCK-01 + single-active invariant
- [ ] `fitbodTests/SingleActiveBlockInvariantTests.swift` — covers D-05 transactional invariant
- [ ] `fitbodTests/SessionBlockSnapshotTests.swift` — covers D-20 snapshot extension
- [ ] `fitbodTests/DeloadVolumeApplicationTests.swift` — covers BLOCK-04 + D-12
- [ ] `fitbodTests/BlockReviewMathTests.swift` — covers BLOCK-07 + D-22 totals/deltas
- [ ] `fitbodTests/FatigueAdvisoryCanonicalityTests.swift` — covers BLOCK-08 + D-25 type-level enforcement
- [ ] `fitbodTests/BlockTemplatesTests.swift` — covers D-03 stock templates
- [ ] `fitbodTests/SchemaV4MigrationTests.swift` (only if SchemaV4 path taken per D-26) — covers `Block.reviewedAt` migration
- [ ] `fitbodTests/BlockBuilderViewCopyTests.swift` — UI-SPEC verbatim copy anchors

### What should NOT be tested

- **UI animations** — `.tabViewStyle(.page)` slide animation, banner appearance — visual judgment.
- **Color hex picks** — `BlockPhaseColors` hex values are UI-SPEC tokens, not behavior.
- **TabView swipe gesture mechanics** — system-provided; testing it tests SwiftUI, not Phase 4.
- **Modal sheet detent behavior** — `.large` detent is SwiftUI built-in.
- **Settings.deloadAlertEnabled toggle UI** — bound to existing `UserSettings.deloadAlertEnabled`; tested via `UserSettings` round-trip in Phase 1.
- **Block builder drag-handle reorder animation** — `EditMode + .onMove` is SwiftUI built-in.
- **Voice Control / Voice Over** — manual verification per UI-SPEC accessibility contract.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `intensityMultiplier` is expressed as fraction of training max / 1RM, applied multiplicatively to `prescribedWeight` (NOT to e1RM) | Periodization Theory Validation; Algorithm Patterns | Wrong → strategies compute weights at wrong absolute load. Mitigation: CONTEXT.md D-11 explicitly says "multiplicative against routine baseline" and "no e1RM dependency in Phase 4" — this assumption is confirmed by CONTEXT. |
| A2 | The `RoutineExercise.prescribedWeight` field referenced in CONTEXT.md D-17 will exist by Phase 4 plan time | Algorithm Patterns; Open Questions | **HIGH RISK.** Field does not exist on `RoutineExercise` as of 2026-05-22 (verified by reading `fitbod/Models/RoutineExercise.swift`). Phase 3 adds `SessionExercise.prescribedWeight` but not `RoutineExercise.prescribedWeight`. See Open Questions #1. |
| A3 | Phase 3's `ProgressionStrategy.prescribe(...)` signature can be extended with `block: Block?` and `today: Date` parameters via default values without breaking Phase 3 test green-state | Files to Create/Modify | Medium. Adding default-valued params to a protocol method requirement is non-trivial in Swift — Phase 3's strategies are structs that implement the protocol; adding optional protocol params requires updating every conforming type. Mitigation: introduce a parallel `BlockAwareStrategy` sub-protocol if extension is too invasive. |
| A4 | Phase 3 ships an e1RM helper (Epley / Brzycki) before Phase 4 starts | Phase-End Review | Medium. Phase 3 is in flight per STATE.md. The 03-RESEARCH.md references e1RM math for the "Why this weight?" RPE strategy. If not yet shipped, Phase 4 inlines Epley formula `weight * (1 + reps / 30.0)`. |
| A5 | The `BlockPhase.weeks` field can be safely treated as a literal 7-day chunk; no calendar-week alignment to Monday/Sunday | Week Navigation State | Low. Calendar-week alignment would force "week starts Monday" UX but block week 0 starts on `block.startDate` (any day of week). Treating weeks as 7-day blocks is the simpler model and matches every reviewed periodization tool. CONTEXT.md does not require calendar alignment. |
| A6 | SchemaV3 status (Phase 3 in-flight) determines whether `Block.reviewedAt` lands in V3 or V4 | SwiftData Model Sketch | Low. CONTEXT.md D-26 explicitly handles both branches. Planner verifies at plan time. |
| A7 | The 8-week default block (3 accum + 2 intens + 2 realiz + 1 deload) mentioned in the task brief differs slightly from the CONTEXT.md D-03 templates (4/2/1/1 generic, 5/2/1 hypertrophy, 3/3/1/1 powerlifting) | Algorithm Patterns + Files | Low. The 8-week "Tactical 8" is an alternative template the user could add; current D-03 templates total 8 / 8 / 8 weeks anyway. Stock templates ship per D-03; user can build any custom block. |

---

## Open Questions / Risks

### 1. `RoutineExercise.prescribedWeight` does not exist on the @Model — D-17 baseline unresolvable as-is

**What's verified:**
- CONTEXT.md D-17: "No-history baseline = `RoutineExercise.prescribedWeight`"
- `fitbod/Models/RoutineExercise.swift` has these fields: `id, routine, exercise, orderIndex, intentRaw, targetSets, targetRepsLow, targetRepsHigh, targetRPE, targetRIR, prescribedRestSeconds, tempo, notes, progressionKindRaw, generateWarmups, supersetGroupID, tracksTempo, tracksPartialReps`. **No `prescribedWeight` field.**
- Phase 3's prescribed weight lives on `SessionExercise.prescribedWeight` (populated by `SessionFactory.start` calling the strategy).
- Phase 3's plans (03-08) say: "SessionFactory ONLY needs to set SessionExercise.prescribedWeight; everything else (the explanation displayed in WhyThisWeightSheet, the bumpOccurred flag, the calibrating status) is recomputed at render time."

**What's unclear:**
- How `BlockPeriodizedStrategy.prescribe(...)` and `HybridStrategy.prescribe(...)` get a starting baseline for a new exercise in a new block with zero logged sessions. The current Phase 3 strategies handle "no history" by returning weight 0 + a "no prior data" explanation; this is acceptable for RPE-autoreg (user enters weight on first set) but is a problem for block-periodized strategies that need to know the user's working weight to apply the intensity multiplier.

**Recommendation for planner:**
- Option A (preferred): Add `RoutineExercise.prescribedWeight: Double?` (default nil) to SchemaV3 or SchemaV4 in Phase 4 Wave 0. This is a minor schema addition (one optional Double field, FOUND-02 safe). Update `RoutineBuilderView` to expose a "starting weight" field per exercise. CONTEXT.md D-17 then becomes implementable.
- Option B (lower-friction but worse UX): Source the baseline from `PreviousMatchingIntent.fetchTopWorkingSet(...)` — the most recent matching-intent set's actual weight. If none exists, prompt the user to log a baseline session before block-periodized prescription works. This delays "start using block" until at least one session exists per exercise.
- Option C (defer): Phase 4 ships block math but `BlockPeriodizedStrategy` falls back to `lastSessionWeight` only (same as RPE-autoreg). Document that block prescription "warms up" after the first session in a block. Lowest schema impact, mildly worse UX.

**Risk if unresolved:** Block-periodized and Hybrid strategies cannot prescribe weights for first sessions on new exercises — the entire PRES-05 / PRES-06 success criterion partially breaks. Planner MUST resolve this before plan-writing.

### 2. Phase 3 ProgressionStrategy signature extension vs sub-protocol

**What's verified:**
- Phase 3's `ProgressionStrategy.prescribe(...)` signature has 12 named parameters (per 03-05-PLAN.md), all primitives + arrays. No `Block` parameter.
- Phase 3's factory routes `.block` / `.hybrid` to `DoubleProgressionStrategy` as a temporary stub.

**What's unclear:**
- Whether to extend `ProgressionStrategy.prescribe(...)` with `block: Block? = nil, today: Date = Date.now` (default-valued, preserving Phase 3 test green-state) OR define a new `BlockAwareStrategy` sub-protocol.

**Recommendation:** Extend the existing signature. Adding two default-valued parameters preserves Phase 3 call-site compatibility. Phase 3's `RPEAutoregStrategy` and `DoubleProgressionStrategy` simply ignore the new params.

### 3. Where does deload working-set-count cut happen — strategy or factory?

**What's verified:**
- D-12 says "deload halves working sets, keeps weight" (3×8 @ 100kg → 2×8 @ 100kg).
- Phase 3's strategies return only weight, not set count.

**Decision documented in §Deload Mechanics:** Set-count cut is a `SessionFactory.start` concern, not a strategy concern. Strategy returns the weight (held at baseline for deload). Factory reads `currentPhase.volumeMultiplier` and creates `max(1, floor(re.targetSets * volumeMultiplier))` SetEntry rows. The planner should confirm this split is acceptable — it deliberately puts deload volume logic in two places (SessionFactory for set-count; UI for visual cue), but the alternative (a separate "volume strategy" type) would over-engineer for one concern.

### 4. Phase 3 in-flight status — coordination with the e1RM helper and PrescriptionExplanation

**What's verified:**
- STATE.md: "Phase 3: Smart Prescription & Warm-ups: Not started" (last-updated 2026-05-11) — BUT the 03-CONTEXT.md, 03-RESEARCH.md, 03-PATTERNS.md, 03-VALIDATION.md, and 8 plan files all exist (per directory listing 2026-05-22).
- Phase 3 plans reference an e1RM helper but the implementation file name is not explicitly listed in 03-05-PLAN.md.

**What's unclear:**
- Whether Phase 3 will have shipped its complete implementation (including e1RM helper, SchemaV3, and ProgressionStrategy + 2 strategies) before Phase 4 plan-execution starts.

**Recommendation for planner:** Treat Phase 3 deliverables as prerequisites. If Phase 4 plan execution would land before Phase 3 completes, either (a) wait, or (b) inline the Phase 3 deliverables Phase 4 needs (e1RM helper, ProgressionStrategy protocol if extending signature, factory routing). Optionally check Phase 3 progress via: `find fitbod/Prescription -name "*.swift" -newer .planning/phases/04-periodization-blocks/04-CONTEXT.md`.

### 5. Single-active invariant — what if user has 0 active blocks?

**What's verified:**
- D-05 says "single active block at a time"
- D-21 phase-end review sets `isActive = false` on review-acknowledge
- After a block ends and is reviewed, the user has 0 active blocks until they create/activate a new one.

**Resolution:** "Single active" means "at most one," not "exactly one." Zero active is a valid state — `BlockCard` renders the `StartBlockCTA` empty-state. `RoutinesListView` Blocks section shows no leading-dot indicator. No bug.

### 6. Block templates: enum vs JSON vs static array

**Marked as Claude's discretion in CONTEXT.md.** Recommendation: static Swift enum/struct literals in `BlockTemplates.swift` per CONTEXT.md "Specifics" note. Easier to inspect, diff-friendly, no resource-bundle parsing. Three templates × ~5 phases × 5 fields = ~75 literal values; fits comfortably in one file.

---

## Code Examples

### PeriodizationEngine.phase(for:on:) reference implementation

```swift
// Source: Phase 4 pattern, mirrors Phase 3 WarmupRamp / Calibration namespace-enum pattern
public enum PeriodizationEngine {

    public static func phase(for block: Block, on date: Date) -> BlockPhase? {
        let phases = (block.phases ?? []).sorted { $0.orderIndex < $1.orderIndex }
        guard !phases.isEmpty else { return nil }

        let daysSinceStart = Int(floor(date.timeIntervalSince(block.startDate) / 86400))
        if daysSinceStart < 0 { return phases.first }

        var cumulativeDays = 0
        for phase in phases {
            let phaseDays = phase.weeks * 7
            if daysSinceStart < cumulativeDays + phaseDays {
                return phase
            }
            cumulativeDays += phaseDays
        }
        return nil  // past end of block; caller handles end-of-block review trigger
    }

    public static func weekIndex(for block: Block, on date: Date) -> Int? {
        let daysSinceStart = Int(floor(date.timeIntervalSince(block.startDate) / 86400))
        let totalDays = (block.phases ?? []).reduce(0) { $0 + ($1.weeks * 7) }
        if daysSinceStart < 0 || daysSinceStart >= totalDays { return nil }
        return daysSinceStart / 7
    }

    public static func recommendedNextKind(after kind: BlockPhaseKind) -> BlockPhaseKind {
        switch kind {
        case .accumulation:    return .intensification
        case .intensification: return .realization
        case .realization:     return .deload
        case .deload:          return .accumulation
        }
    }
}
```

### BlockDraft.save with active-block transaction (single-active invariant)

```swift
// Source: D-05 transactional invariant; mirrors Phase 2 RoutineDraft.save pattern
extension BlockDraft {
    func save(into context: ModelContext) throws {
        try context.transaction {
            // D-05: if saving as active, deactivate all other blocks first.
            if isActive {
                let descriptor = FetchDescriptor<Block>(predicate: #Predicate<Block> { other in
                    other.isActive == true
                })
                let others = try context.fetch(descriptor)
                for other in others where other.id != self.id {
                    other.isActive = false
                }
            }

            // Materialize Block from draft (three-way merge).
            let block = try fetchOrCreate(in: context)
            block.name = self.name
            block.startDate = self.startDate
            block.isActive = self.isActive
            block.endDate = computedEndDate()  // startDate + sum(phase.weeks)*7

            // Materialize phases (cascade-managed; just replace the array).
            block.phases?.forEach { context.delete($0) }
            block.phases = self.phases.enumerated().map { idx, draftPhase in
                let phase = BlockPhase()
                phase.orderIndex = idx
                phase.nameRaw = draftPhase.kind.rawValue
                phase.weeks = draftPhase.weeks
                phase.volumeMultiplier = draftPhase.volumeMultiplier
                phase.intensityMultiplier = draftPhase.intensityMultiplier
                return phase
            }

            try context.save()
        }
    }
}
```

### HybridStrategy composition pattern

```swift
public struct HybridStrategy: ProgressionStrategy {
    public init() {}

    public func prescribe(
        history: [HistoryPoint],
        targetRepsLow: Int,
        targetRepsHigh: Int,
        targetRPE: Double?,
        smallestIncrement: Double,
        plates: [(weight: Double, countPerSide: Int)],
        barWeight: Double,
        minCalibrationSets: Int,
        lastSessionWeight: Double?,
        lastSessionReps: Int?,
        lastSessionRPE: Double?,
        lastSessionDate: Date?,
        lastSessionRepsArray: [Int]? = nil,
        block: Block? = nil,            // NEW Phase 4 param
        today: Date = Date.now           // NEW Phase 4 param
    ) -> (weight: Double, explanation: PrescriptionExplanation) {

        let blockResult = BlockPeriodizedStrategy().prescribe(
            history: history, targetRepsLow: targetRepsLow, targetRepsHigh: targetRepsHigh,
            targetRPE: targetRPE, smallestIncrement: smallestIncrement, plates: plates,
            barWeight: barWeight, minCalibrationSets: minCalibrationSets,
            lastSessionWeight: lastSessionWeight, lastSessionReps: lastSessionReps,
            lastSessionRPE: lastSessionRPE, lastSessionDate: lastSessionDate,
            lastSessionRepsArray: lastSessionRepsArray, block: block, today: today
        )

        let rpeResult = RPEAutoregStrategy().prescribe(
            history: history, targetRepsLow: targetRepsLow, targetRepsHigh: targetRepsHigh,
            targetRPE: targetRPE, smallestIncrement: smallestIncrement, plates: plates,
            barWeight: barWeight, minCalibrationSets: minCalibrationSets,
            lastSessionWeight: lastSessionWeight, lastSessionReps: lastSessionReps,
            lastSessionRPE: lastSessionRPE, lastSessionDate: lastSessionDate,
            lastSessionRepsArray: lastSessionRepsArray
        )

        let chosen = min(blockResult.weight, rpeResult.weight)
        let source = chosen == blockResult.weight ? "block ceiling" : "rpe-driven"

        let explanation = PrescriptionExplanation(
            lastSessionLine: rpeResult.explanation.lastSessionLine,
            formulaName: "Hybrid (block + RPE)",
            computedLine: "Block ceiling: \(blockResult.weight) kg · RPE target: \(rpeResult.weight) kg · Using: \(source) → \(chosen) kg",
            roundedWeight: chosen,
            roundedLine: "→ \(chosen) kg (chose lower of block / RPE)",
            status: rpeResult.explanation.status,
            bumpOccurred: false,
            range: nil
        )
        return (chosen, explanation)
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single mesocycle (no phases) | Multi-phase block with explicit kind/weeks/multipliers | RP popularized circa 2014–2018 | Phase 4 ships the modern model directly; no legacy migration needed. |
| RPE OR percentage-based (binary choice) | Hybrid model: block percentages with RPE downward adjustment | Tuchscherer + Helms research, 2015–2020 | Phase 4's HybridStrategy implements the mainstream synthesis. |
| Hand-rolled volume calendars | Calendar-derived from block start + phase weeks | Modern fitness apps (Strong, Hevy, Beyond) | Phase 4 derives current week from `Date.now - block.startDate`; no stored "current week" field. |

**Deprecated / outdated:**
- **Linear periodization** (load increases monotonically each week with no deload) — superseded by block periodization for serious lifters. CONTEXT.md treats blocks as the primary model; linear is implicitly available by setting all phases to `accumulation`.
- **DUP** (Daily Undulating Periodization) — different model that varies intensity within the week rather than across weeks. Out of scope for Phase 4; not in any requirements.

---

## Common Pitfalls

### Pitfall 1: Storing "current week" as a Block field

**What goes wrong:** Future-you forgets to increment the field, or increments it twice across midnight, or the device clock changes and stored week disagrees with calendar.

**Why it happens:** Tempting to "advance" the block on a timer or app-launch.

**How to avoid:** Derive current week from `Date.now - block.startDate`. No stored state. `PeriodizationEngine.weekIndex(for:on:)` is the single source.

**Warning signs:** Any function named `Block.advance()` or `Block.tickWeek()` should raise a flag.

### Pitfall 2: SwiftData @Query predicate referencing a relationship property and a non-local variable

**What goes wrong:** SwiftData predicate fails to translate, or returns wrong results, when the predicate references `block.startDate` directly inside a `#Predicate<SetEntry>` body that also walks a relationship (e.g., `setEntry.sessionExercise?.session?.startedAt`).

**Why it happens:** SwiftData's `#Predicate` expression translation has known limitations with related-entity property access combined with captured outer variables (Phase 2 PITFALLS #1 documented this — the "local-let workaround").

**How to avoid:** Capture the date bounds into local `let` constants BEFORE the `#Predicate` body. Example:
```swift
let blockStart = block.startDate
let blockEnd = block.endDate ?? Date.now
let descriptor = FetchDescriptor<SetEntry>(predicate: #Predicate { entry in
    let session = entry.sessionExercise?.session
    return session?.startedAt >= blockStart && session?.startedAt <= blockEnd
})
```

**Warning signs:** "Predicate failed to evaluate" in console, or query returns 0 rows when data exists.

### Pitfall 3: Active-block invariant violated across non-transactional saves

**What goes wrong:** Save Path A sets block X active; concurrent or subsequent save Path B sets block Y active without first reading the current active state — both X and Y end up `isActive == true`.

**Why it happens:** Two separate `modelContext.save()` calls instead of one `modelContext.transaction { ... }`.

**How to avoid:** Always wrap "set as active" in a single transaction that first fetches all `isActive == true` rows and zeros them, then sets the target row. Per `BlockDraft.save(into:context:)` example above.

**Warning signs:** UI shows two active-dot indicators in `RoutinesListView` Blocks section.

### Pitfall 4: Snapshot-pattern violation — strategy reads `Routine.block` at session time instead of `Session.block` at prescription time

**What goes wrong:** User detaches a routine from a block AFTER starting a session; the strategy on the in-flight session now sees `routine.block = nil` and switches behavior mid-session.

**Why it happens:** Forgetting that `Session.block` is the snapshot per D-20, not `Routine.block`.

**How to avoid:** All Phase 4 code that needs "what block is this session in?" reads `session.block`, never `routine.block`. `SessionFactory.start` copies once at start; strategies/views read from `session` thereafter.

**Warning signs:** Mid-session prescription changes when user detaches the routine from the block.

### Pitfall 5: Calendar-week vs 7-day-from-start ambiguity

**What goes wrong:** UI shows "Week 5" but calendar Monday-Sunday says it's "Week 6 of the year."

**Why it happens:** Conflating "block-relative week" with "calendar week."

**How to avoid:** Phase 4's "week" is always block-relative: floor((today - startDate) / 7). Never use `Calendar.current.dateComponents([.weekOfYear], ...)` for block math. The user's `weekStartsMonday: Bool` in `UserSettings` affects weekly recap UI in Phase 5/6 only, never block math.

**Warning signs:** Block week shown disagrees with day-count-from-start.

### Pitfall 6: Deload week starts on a Wednesday (or any non-Monday) and UI looks broken

**What goes wrong:** User's `block.startDate` is a Wednesday; week 4 of the block (deload) starts on a Wednesday but Today tab shows "Deload week" on the prior Sunday because user expects "weeks start on Monday."

**Why it happens:** Confusing block-relative weeks with calendar-week-anchored display.

**How to avoid:** UI-SPEC defines "Week N of M" as block-relative; UI never claims a deload week starts on Monday unless `block.startDate` was a Monday. The day-of-week display ("Tuesday, May 22") tells the user where they are.

**Warning signs:** User complaint "the deload week is on the wrong day."

### Pitfall 7: Floor-div clamp on deload set count causes 0 sets

**What goes wrong:** `targetSets = 1, volumeMultiplier = 0.5 → floor(0.5) = 0 sets logged for that exercise on deload week.`

**Why it happens:** Naive integer arithmetic.

**How to avoid:** `let count = max(1, Int(floor(Double(targetSets) * volumeMultiplier)))` — clamp to ≥1.

**Warning signs:** Exercise shows 0 sets to log on deload week.

### Pitfall 8: e1RM delta computed against the wrong session (first vs last in block)

**What goes wrong:** `BlockReviewView` computes "+5 kg" delta but uses the wrong session pair (e.g., compares week 4 to week 6 instead of week 0 to week-final).

**Why it happens:** Off-by-one or wrong sort direction in the `@Query` for block-range sessions.

**How to avoid:** Sort sessions by `startedAt` ASC. First session in block = `sessions.first`. Last session in block = `sessions.last`. Compute e1RM from each session's top working set.

**Warning signs:** Delta sign matches the trend but magnitude is wrong; spot-check against raw `SetEntry` weights.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Mesocycle swipe pager | Custom HStack with drag-gesture math | `TabView` + `.tabViewStyle(.page(indexDisplayMode: .never))` | iOS built-in, handles RTL, accessibility, reduced-motion automatically. UI-SPEC explicitly picks this. |
| Block multiplier persistence | Custom JSON-encoded blob on Block | Native `BlockPhase` rows (one per phase, ordered) — already shipped | Phase 1 schema already models this correctly; using native @Model gets cascade rules and queryability for free. |
| Phase color palette | Asset catalog entries per phase | Static `BlockPhaseColors` enum returning `Color(red:green:blue:)` inline | UI-SPEC explicitly chooses inline values to keep asset catalog free of feature-specific tokens. Dark-mode handled by `.opacity()` adjustments. |
| Schema migration for `Block.reviewedAt` | Brand new SchemaV4 even when SchemaV3 unsealed | Inline addition to SchemaV3 if possible (D-26 explicit) | Avoiding unnecessary schema versions; SchemaV3 is being defined right now in Phase 3. |
| Active-block invariant enforcement | Application-level "before-save" hook | `try modelContext.transaction { ... }` wrapping fetch-deactivate-save | Transactional rollback on any failure — no partial state where two blocks are active. |
| Phase-end review math (volume sum, e1RM delta) | Service object or background actor | Inline `@Query` in `BlockReviewView` body | One-screen aggregation; MV-VM-lite (FOUND-06). Phase 5/6 will extract aggregators when cross-block analytics is needed. |
| RPE table for HybridStrategy | Re-implementing Tuchscherer cells | Reuse Phase 3's `TuchschererTable` | Already shipped; HybridStrategy just composes existing strategies. |
| e1RM formula | Custom rep-to-1RM helper | Reuse Phase 3's e1RM helper (or inline Epley `weight * (1 + reps/30)` for reps ≤10 if Phase 3 helper not yet shipped) | Phase 3 owns this concern; Phase 4 consumes it. |
| `FatigueAdvisory` real signal | Phase 4 inferring the signal from set RPEs | `StubFatigueAdvisory` returning false; let Phase 5 fill the protocol with real signal | Phase 4's UI scaffold + protocol contract is the deliverable; signal is Phase 5 scope. |
| Block week navigation state | Stored "current week" on Block | Derive via `PeriodizationEngine.weekIndex(for:on:)` | Calendar math is reliable; stored state drifts. |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16.x | Build / test / sign | ✓ | (developer machine) | — |
| iOS Simulator (iPhone 16) | Test runner | ✓ | iOS 18 | iPhone 15 simulator if 16 unavailable |
| Swift 6 toolchain | Strict concurrency | ✓ | bundled with Xcode 16 | — |
| Swift Testing | Test suites | ✓ | bundled with Xcode 16 | XCTest if Swift Testing unavailable (would break Phase 1/2/3 pattern) |
| SwiftData iOS 18 SDK | All @Model entities | ✓ | bundled iOS 18 | — |
| `#Index` macro (iOS 18) | `Session.startedAt`, `SessionExercise.intentRaw` indexes (Phase 1) | ✓ | iOS 18 | Drop indexes if forced to iOS 17 |
| `.tabViewStyle(.page)` | BlockCard swipe pager | ✓ | iOS 17+ baseline | — |
| `@Observable` macro | BlockDraft / BlockPhaseDraft | ✓ | iOS 17+ baseline | — |

**Missing dependencies with no fallback:** None — all dependencies are already in use by Phases 1/2/3.

**Missing dependencies with fallback:** None — every required capability is available in the current Xcode/iOS toolchain.

---

## Sources

### Primary (HIGH confidence)
- `fitbod/Models/Block.swift`, `fitbod/Models/BlockPhase.swift`, `fitbod/Models/Enums/BlockPhaseKind.swift` — verified current schema
- `fitbod/Models/Routine.swift`, `fitbod/Models/RoutineExercise.swift`, `fitbod/Models/Session.swift`, `fitbod/Models/SessionExercise.swift`, `fitbod/Models/SetEntry.swift` — verified existing fields and relationships
- `fitbod/Models/UserSettings.swift` — verified `deloadAlertEnabled` already exists
- `.planning/phases/04-periodization-blocks/04-CONTEXT.md` — locked decisions D-01 through D-26
- `.planning/phases/04-periodization-blocks/04-UI-SPEC.md` — visual / interaction contract (approved)
- `.planning/phases/03-smart-prescription-warm-ups/03-CONTEXT.md` — Phase 3 protocol design (Phase 4 builds on)
- `.planning/phases/03-smart-prescription-warm-ups/03-05-PLAN.md` — Phase 3 ProgressionStrategy + Factory plan (Phase 4 consumes)
- `.planning/phases/03-smart-prescription-warm-ups/03-08-PLAN.md` — SessionFactory integration plan (Phase 4 extends)
- `.planning/REQUIREMENTS.md` — BLOCK-01..08, PRES-05, PRES-06
- `.planning/ROADMAP.md` — Phase 4 success criteria
- `CLAUDE.md` — SwiftData iOS 18 + Swift Charts + @Observable + MV-VM-lite constraints

### Secondary (MEDIUM-HIGH confidence — multi-source citations on periodization theory)
- [HPRC: Plan your workouts with block periodization](https://www.hprc-online.org/physical-fitness/training-performance/plan-your-workouts-block-periodization) — accumulation/transmutation/realization 1RM bands (50-75% / 75-90% / ≥90%)
- [CoachMePlus: Basics of Block Periodization](https://coachmeplus.com/the-basics-of-block-periodization/) — Issurin model overview
- [Arvo: Periodization for Hypertrophy & Strength Complete Guide 2026](https://arvo.guru/resources/periodization) — block periodization phase durations and RP overview
- [Arvo: RP Training — Volume Landmarks & Mesocycles Guide](https://arvo.guru/resources/methods/rp-training) — MEV/MAV/MRV climb, accumulation length 3-12 weeks
- [BodySpec: Renaissance Periodization Principles and Guide](https://www.bodyspec.com/blog/post/renaissance_periodization_principles_and_guide) — RP mesocycle structure, accumulation/transmutation/realization
- [RP Strength: In Defense of Set Increases](https://rpstrength.com/blogs/articles/in-defense-of-set-increases-within-the-hypertrophy-mesocycle) — RP volume climb across mesocycle
- [RP Help Center: Why did my training get so much easier? (deload)](https://help.rpstrength.com/hc/en-us/articles/31639551676439-Why-did-my-training-get-so-much-easier-deload) — RP deload mechanics: hold weights at week-1 then cut to ~50%
- [PMC: A Practical Approach to Deloading (review)](https://pmc.ncbi.nlm.nih.gov/articles/PMC9811819/) — coaches' perceptions of deload practice; 41–60% volume reduction range
- [PMC: Integrating Deloading into Strength and Physique Sports — International Delphi Consensus](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10511399/) — typical deload duration 6.4±1.7 days every 5.6±2.3 weeks
- [PubMed: Gaining more from doing less? (Coleman et al. 2024)](https://pubmed.ncbi.nlm.nih.gov/38274324/) — supervised deload effects, 50% reductions
- [Reactive Training Systems: Emerging Strategies (Tuchscherer interview)](https://store.reactivetrainingsystems.com/blogs/default-blog-1/powerlifting-emerging-strategies-an-interview-with-mike-tuchscherer) — RPE autoregulation philosophy
- [SimpliFaster: Principles for Periodization of Volume and Intensity with Autoregulation](https://simplifaster.com/articles/periodization-volume-intensity-autoregulation/) — autoregulation within periodization
- [Sportlyzer Academy: Block Periodization](https://academy.sportlyzer.com/wiki/block-periodization/) — Issurin three-mesocycle structure
- [TrainingPeaks: Implementing Block Periodization in Endurance Training](https://www.trainingpeaks.com/blog/implementing-block-periodization/) — phase durations, taper length
- [Track & Field News: Running Periodization Part 3 — Block and Undulating Periodization](https://trackandfieldnews.com/track-coach/running-periodization-part-3-block-and-undulating-periodization/) — Issurin block model overview

### Tertiary (LOW-MEDIUM confidence — informational, single-source)
- [Hevy Coach: Block Periodization glossary](https://hevycoach.com/glossary/block-periodization/) — informational
- [Dr. Bunsen: Block Periodization](https://www.drbunsen.org/block-periodization/) — informational
- [BarBend: 3 Types of Training Periodization](https://barbend.com/different-types-of-training-periodization/) — overview
- [Levels: Deload Week: Why Even the Best Need to Rest](https://levelsprotein.com/blogs/training/deload-week) — popular-press

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — locked by PROJECT.md / CLAUDE.md; iOS 18 + SwiftData + SwiftUI + Swift Charts + Swift Testing; zero third-party SPM dependencies
- Architecture: HIGH — every pattern (snapshot, @Observable draft + three-way merge, pure-function strategies, namespace-enum engines, MV-VM-lite @Query) already shipped in Phases 1/2/3; Phase 4 is composition over existing primitives
- Periodization theory: MEDIUM-HIGH — Issurin canonical model verified across 4+ independent sources; specific multiplier values per phase verified against RP/HPRC/CoachMePlus citations; CONTEXT.md D-10 values sit squarely in published evidence envelopes
- Pitfalls: HIGH — six of eight pitfalls inherit from Phase 1/2/3 documented patterns (local-let predicate workaround, snapshot-not-template, transactional invariants); two new pitfalls (calendar-week confusion, floor-div clamp) are mechanical

**Research date:** 2026-05-22
**Valid until:** 2026-06-22 (30 days — periodization literature is stable; iOS 18 SwiftData semantics stable)
