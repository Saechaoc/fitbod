# Phase 4: Periodization & Blocks - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning
**Mode:** `/gsd-discuss-phase 4 --power max` — 27 questions answered via JSON/HTML companion; all recommended (option `a`) selected.

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project / Requirements / State
- `.planning/PROJECT.md` — Core value, constraints (SwiftUI + SwiftData, iOS 18, local-only), key decisions
- `.planning/REQUIREMENTS.md` — Phase 4 covers BLOCK-01..08 + PRES-05 + PRES-06 (10 requirements)
- `.planning/ROADMAP.md` — Phase 4 "Periodization & Blocks" — 5 must-be-true success criteria
- `.planning/STATE.md` — Phase 2 complete (13/13 plans, 20/20 requirements); Phase 3 in flight

### Prior phase decisions
- `.planning/phases/01-foundation-exercise-library/01-CONTEXT.md` — Block/BlockPhase schema already shipped; ProgressionKind enum has `.block` and `.hybrid` cases
- `.planning/phases/02-core-loop-routines-sessions/02-CONTEXT.md` — SessionFactory.start snapshot pattern; @Observable draft + three-way merge save (RoutineBuilderView precedent); RoutinesListView sectioned-list pattern; ResumeWorkoutBanner on Today
- `.planning/phases/02-core-loop-routines-sessions/02-UI-SPEC.md` — Carry-forward design tokens (accent `#0E7C86` / `#3FBFC9`, 8pt spacing, semantic typography, copywriting voice)
- `.planning/phases/03-smart-prescription-warm-ups/03-CONTEXT.md` — `ProgressionStrategy` protocol design; `fitbod/Prescription/` directory; pure-function strategy + `PrescriptionExplanation` value type; `RoutineExercise.prescribedWeight` as user baseline
- `.planning/phases/03-smart-prescription-warm-ups/03-RESEARCH.md` — Tuchscherer table, e1RM helper plumbing, manual override flow (Phase 4 inherits the protocol)

### Research dossier
- `.planning/research/SUMMARY.md` §"Phase 4: Periodization" — block phase curve multipliers flagged as research-confirm item
- `.planning/research/ARCHITECTURE.md` — snapshot-at-session-start invariant (PITFALLS #1) extends to Session.block snapshot
- `.planning/research/PITFALLS.md` — #1 template/instance split (now extends to block context); deload conflict resolution model

### External (verify at plan-phase)
- Renaissance Periodization (RP) volume/intensity defaults per phase — researcher confirms exact multipliers from `Scientific Principles of Hypertrophy Training` (Israetel/Hoffmann) or equivalent
- Reactive Training Systems (RTS) — RPE-driven autoregulation (Phase 3 dependency) and hybrid combination patterns

</canonical_refs>

<domain>
## Phase Boundary

This phase delivers **defined mesocycles with deterministic phase progression and a transparent home-screen timeline** — the user constructs a multi-week training block as an ordered sequence of phases (accumulation / intensification / realization / deload), each carrying volume and intensity multipliers; the active block surfaces on Today with phase color coding and swipe-between-weeks navigation; scheduled deloads automatically cut volume; and the four-strategy `ProgressionStrategy` protocol gains its remaining two implementations (`BlockPeriodizedStrategy`, `HybridStrategy`).

1. **Block builder** — single-screen `BlockBuilderView` mirroring `RoutineBuilderView`: top-of-screen block name + start date, ordered phase list below with inline editors per phase (kind picker, weeks stepper, volume/intensity multipliers), drag-handle reorder, @Observable `BlockDraft` with three-way merge on save. Three stock templates (Generic Strength, Hypertrophy Meso, Powerlifting Peak) plus "Blank" available from "+ Block" menu.
2. **Routines tab integration** — `RoutinesListView` gets a new "Blocks" section above existing routine folders. Block rows show `Week N of M` inline. No 6th tab added.
3. **Today tab block card** — `BlockCard` renders above `ResumeWorkoutBanner` when a block is active. Shows: phase chip (heat-map color), linear `Week N of M`, days remaining, multipliers. Horizontal swipe on the card (TabView + PageTabViewStyle) navigates between weeks of the mesocycle.
4. **Single-active invariant** — at most one block has `isActive == true` at a time. Activating a new block deactivates any other active block transactionally.
5. **PeriodizationEngine** — static facade `PeriodizationEngine.phase(for: Block, on: Date) -> BlockPhase?` lives in `fitbod/Prescription/`. Pure function, no SwiftData coupling, testable in isolation. Strategies receive `Block` via dependency injection and call the engine.
6. **BlockPeriodizedStrategy + HybridStrategy** — both land in `fitbod/Prescription/` alongside Phase 3's `RPEAutoregStrategy` and `DoubleProgressionStrategy`. BlockPeriodized multiplies routine baseline (`RoutineExercise.targetSets` × `prescribedWeight`) by phase multipliers. Hybrid takes `min(blockTarget, rpeTarget)` — block defines the ceiling, RPE pulls down on bad days, never up.
7. **Scheduled deloads** — deload-week prescription halves working sets (3×8 @ 100kg → 2×8 @ 100kg) and applies intensity multiplier to weight. Today-tab banner + tinted block card background communicates the deload week visually. Warm-up generator (Phase 3) respects the deload flag (skips ramps on deload weeks; conditional already wired in Phase 3).
8. **Session-block snapshot** — `SessionFactory.start(...)` snapshots `routine.block` onto `Session.block` so historical sessions remember their block context even if the routine is later detached. Matches the snapshot pattern (PITFALLS #1).
9. **Phase-end review** — when `block.endDate` passes, a `BlockReviewView` surfaces as a modal on the next Today-tab open. Scaffolds four sections (total volume, e1RM deltas, PRs hit, recommended next phase) with placeholder copy for the Phase 5/6 deliverables; total tonnage and simple e1RM deltas computed inline from `SetEntry` history. Recommended next phase is static-rule driven (after deload → accumulation; after realization → deload).
10. **BLOCK-08 canonicality** — type-level enforcement: a forthcoming `FatigueAdvisory` protocol (signal stubbed in Phase 4, real signal lands Phase 5) returns only `Suggestion` values, never `DeloadMutation`. Only `PeriodizationEngine.advance(...)` can set deload state — single writer enforced by type.
11. **BLOCK-06 advisory scaffold** — `ConsiderDeloadBanner` view + dismiss state shipped in Phase 4. `FatigueAdvisory.shouldSuggest()` returns false for v1 (stub); Phase 5 fills the real signal without touching the UI.

In scope: BLOCK-01..08, PRES-05, PRES-06 (10 requirements).
Out of scope: real fatigue/plateau signal computation (Phase 5), volume bars / heatmap deload tinting (Phase 5 owns these visualizations), PR/e1RM/charting deliverables surfaced inside the phase-end review (Phase 6 fills the placeholders), per-day routine assignment within the mesocycle (defer to v1.x — week cards show 'scheduled routines' as a flat list).
</domain>

<decisions>
## Implementation Decisions

### Area 1 — Block builder UX (BLOCK-01)

- **D-01 (Q-01): Single-screen builder.** `BlockBuilderView` mirrors Phase 2's `RoutineBuilderView` 1:1: block name + start date at the top, ordered phase list below with inline editors per phase (kind picker, weeks stepper, volume/intensity multipliers). Drag-handle reorder via `EditMode + .onMove`. `@Observable BlockDraft` + three-way merge `save(into:context:)`. **Why:** Phase 2 set the precedent; reusing the idiom keeps the codebase coherent.
- **D-02 (Q-02): Blocks live on the Routines tab.** New "Blocks" section above routine folders inside `RoutinesListView`. Block rows show `Week N of M` inline. No 6th tab. **Why:** Adding a tab is heavier than this phase needs; blocks and routines are tightly coupled conceptually.
- **D-03 (Q-03): 2–3 stock templates + Blank.** Templates defined in `fitbod/Periodization/BlockTemplates.swift` as Swift literals. Initial set: "Generic Strength Meso" (4-week accum, 2-week intens, 1-week realization, 1-week deload), "Hypertrophy Meso" (5-week accum, 2-week intens, 1-week deload), "Powerlifting Peak" (3-week accum, 3-week intens, 1-week realization, 1-week deload). "+ Block" menu shows templates + "Blank". **Why:** Fastest path to a usable block; matches what serious lifters expect.
- **D-04 (Q-04): No hard ordering constraints.** User can sequence phases any way they want. No "deload must be last" enforcement. **Why:** Matches the "transparent over magic" stance — user is the discipline, not the app.
- **D-05 (Q-05): Single active block at a time.** `Block.isActive == true` invariant: activating block X transactionally deactivates any other active block. Single mesocycle = current. Routines linked to non-active blocks behave as if `block == nil` for that session. **Why:** Matches RP/RTS convention of running one meso at a time; avoids "which deload is this week" ambiguity.

### Area 2 — Block timeline & home screen (BLOCK-02, BLOCK-03)

- **D-06 (Q-06): BlockCard above ResumeWorkoutBanner.** Today tab stacking order when a block is active: `BlockCard → ResumeWorkoutBanner → empty/start CTA`. Block context is the primary "where am I in training" signal. **Why:** A live mesocycle outranks "resume in-progress session" as the framing for the day.
- **D-07 (Q-07): Heat-map phase colors.** Accumulation = accent teal (`#0E7C86`), intensification = amber (`#F59E0B`), realization = orange (`#EA580C`), deload = desaturated gray (`#94A3B8`). **Why:** Visual intensity matches training intensity. Deload reads as "rest" via desaturated gray. Accumulation reuses the existing accent token, no new color needed for the most common state.
- **D-08 (Q-08): Horizontal swipe on the block card.** `TabView` with `.tabViewStyle(.page(indexDisplayMode: .never))` inside the block card; each page = one week. Page shows: phase chip (heat-map color), `Week N of M`, days remaining, multipliers preview, scheduled routines list (flat list of routine names linked to the block; per-day assignment deferred). **Why:** Familiar iOS pattern; no extra tap to reach mesocycle context.
- **D-09 (Q-09): Linear block week ("Week 5 of 8").** Simple counter spanning the entire block, computed from `block.startDate` and total weeks across all `BlockPhase` rows. Phase chip carries the "which phase" signal, so a per-phase counter would be redundant. **Why:** Simpler mental model, fewer numbers competing on the same card.

### Area 3 — Phase multipliers & deload mechanics (BLOCK-04, BLOCK-05)

- **D-10 (Q-10): RP-style default multipliers** (researcher to confirm exact values at plan-phase from RP literature):
  - Accumulation: `volumeMultiplier = 1.0`, `intensityMultiplier = 0.75`
  - Intensification: `volumeMultiplier = 0.85`, `intensityMultiplier = 0.88`
  - Realization: `volumeMultiplier = 0.6`, `intensityMultiplier = 0.97`
  - Deload: `volumeMultiplier = 0.5`, `intensityMultiplier = 0.75`
  
  Applied to stock templates and the `BlockPhase.init` default for the matching `BlockPhaseKind`. User-editable per phase inside the builder. **Why:** RP-published values are the strongest published baseline; user can tune from there.
- **D-11 (Q-11): Multiplicative against routine baseline.** Strategies multiply `RoutineExercise.targetSets × prescribedWeight` by phase multipliers. No e1RM dependency in Phase 4. **Why:** Simplest composition, no new schema dependency on Phase 6 PR/e1RM data; phase 4 stays self-contained.
- **D-12 (Q-12): Deload halves working sets, keeps weight.** `3×8 @ 100kg → 2×8 @ 100kg` (volume reduction by set count, intensity preserved). Working-set count is the most visible "volume" lever and matches RP convention. **Why:** RP "load taper" deload pattern; user experiences the cut clearly without weight drop confusing the prescription.
- **D-13 (Q-13): Deload visual = banner on Today + tinted block card.** Top-of-Today banner copy (UI-SPEC will lock verbatim): "Deload week — recover, don't load." Block card background tints to deload color (desaturated gray from D-07) for that week. Mesocycle week strip highlights the deload week with the same tint. **Why:** Banner is unmissable; tint is ambient. Both honored by the user without modal interruption.

### Area 4 — PeriodizationEngine & strategies (PRES-05, PRES-06)

- **D-14 (Q-14): Static facade — `PeriodizationEngine.phase(for: Block, on: Date) -> BlockPhase?`.** Pure function. Strategies receive `Block` via dependency injection and call the engine. Testable without `ModelContainer`. **Why:** Matches Phase 3's pure-function strategy pattern (FOUND-07); the @Model stays a data structure.
- **D-15 (Q-15): Strategies live in `fitbod/Prescription/`.** New files: `fitbod/Prescription/BlockPeriodizedStrategy.swift`, `fitbod/Prescription/HybridStrategy.swift`, `fitbod/Prescription/PeriodizationEngine.swift`. **Why:** All 4 strategies in one directory is more discoverable than splitting algorithm from "block-aware code."
- **D-15a (Q-15 follow-up): Block UI lives in `fitbod/Periodization/`.** Engine + math stays in `fitbod/Prescription/`; block-feature surfaces live in `fitbod/Periodization/` — `BlockBuilderView.swift`, `BlockCard.swift`, `MesocycleNavigatorView.swift`, `BlockReviewView.swift`, `BlockTemplates.swift`, `BlockDraft.swift`. **Why:** Engine ≠ feature. Clean split.
- **D-16 (Q-16): Hybrid = `min(blockTarget, rpeTarget)`.** Block defines the theoretical max for the phase; RPE responds to fatigue. Conservative — Hybrid autoregulates ONLY downward. **Why:** Avoids the "RPE says I'm fresh, push past the planned phase intensity" failure mode. Block schedule remains canonical (BLOCK-08 spirit).
- **D-17 (Q-17): No-history baseline = `RoutineExercise.prescribedWeight`.** When a user starts a block on a new exercise with no logged history, `BlockPeriodizedStrategy` multiplies the routine's manually-entered prescribed weight by `intensityMultiplier`. **Why:** No Phase 6 e1RM dependency; user is expected to enter a realistic baseline at routine-creation time (already a Phase 2 capability).

### Area 5 — Routine ↔ block linkage

- **D-18 (Q-18): Assignment via `RoutineBuilderView` header.** Top of `RoutineBuilderView` gets a "Block" menu showing all defined blocks + "None". `RoutineDraft.blockID: UUID?` carries the selection through the @Observable draft and is materialized to `Routine.block` on save. **Why:** Discoverable; user sets block context while building the routine.
- **D-19 (Q-19): Disallow `.block` / `.hybrid` progression unless routine is in a block.** `PrescriptionEditorRow` progression picker hides the `.block` and `.hybrid` cases when `routine.block == nil`, with a tooltip: "Add routine to a block to use these." **Why:** Prevents a degenerate prescription state where a `.block` strategy is selected but no block context exists.
- **D-20 (Q-20): Snapshot `routine.block` onto `Session.block` at session start.** `SessionFactory.start(routine:on:context:)` extension copies `routine.block` to `Session.block` at snapshot time. Even if the user later detaches the routine from the block, historical sessions retain their block context. **Why:** Honors the snapshot pattern (PITFALLS #1); makes block-filtered history queries possible in Phase 6 without retroactive joins.

### Area 6 — Phase-end review (BLOCK-07)

- **D-21 (Q-21): Trigger at end of block only.** When `block.endDate < Date.now` AND `block.isActive == true`, surface `BlockReviewView` as a modal on the next Today-tab open. Subsequent opens don't re-surface (track via `block.reviewedAt: Date?` — see schema note in Area 7). Block transitions to `isActive = false` after review acknowledgment. **Why:** One comprehensive review per block; not interrupting every phase transition. Per-phase reviews were rejected as too noisy.
- **D-22 (Q-22): Scaffold all four sections with placeholders.** `BlockReviewView` lays out four sections: (1) Total volume (computed inline as Σ `setEntry.actualWeight × setEntry.actualReps` over the block date range — Phase 4 ships this), (2) e1RM deltas per exercise (Phase 4 ships using Phase 3's e1RM helper for start-of-block vs end-of-block deltas on the top working set per exercise), (3) PRs hit ("Coming in Phase 6" placeholder copy), (4) Recommended next phase (D-23). **Why:** Phase 4 honors BLOCK-07 with a real, useful review on the data it has; Phase 6 fills the PR slot in place without restructuring.
- **D-23 (Q-23): Recommended next phase via static rules.** Map: just-finished phase kind → recommended next-phase kind. `.deload → .accumulation` (start a new meso). `.realization → .deload` (recover from peak). `.accumulation → .intensification`. `.intensification → .realization`. Surface as a single CTA: "Start [Recommended] Block" → opens block builder seeded with the static template for that phase chain. **Why:** Deterministic, transparent, matches RP convention. No "smart" recommendation engine in v1.

### Area 7 — Fatigue-triggered deload advisory (BLOCK-06, BLOCK-08)

- **D-24 (Q-24): Phase 4 ships UI scaffold + stubbed signal.** New `ConsiderDeloadBanner` view in `fitbod/Periodization/`. New `FatigueAdvisory` protocol in `fitbod/Prescription/` (`shouldSuggest(context:) -> Bool`) plus a `StubFatigueAdvisory` impl returning `false`. Banner renders only when `advisory.shouldSuggest()` is true. **Why:** Phase 5 fills the real signal without touching UI. UI contract locks now.
- **D-25 (Q-25): Type-level canonicality enforcement.** `FatigueAdvisory` protocol returns only a `FatigueSuggestion` value type (carries reason copy + dismiss-state plumbing), never a `DeloadMutation`. The only writer of block deload state is `PeriodizationEngine.advance(block:on:)` (block scheduler). Single-writer enforced by type. **Why:** BLOCK-08 ("scheduled block deload is canonical") becomes impossible to violate accidentally — the compiler refuses.

### Area 8 — Schema evolution

- **D-26 (Q-26 + Q-27 reconciled): No new schema fields in Phase 4 — minor exception for `Block.reviewedAt`.** Q-26 selected "none — Phase 1 schema is sufficient" but D-21 introduces a single new field (`Block.reviewedAt: Date?`) to track whether the phase-end review has been shown. This is a default-valued optional (FOUND-02 safe) and fits a lightweight migration. **Conflict reconciled:** Q-27's "bundle into SchemaV3" is honored — `Block.reviewedAt` lands in **SchemaV3** (Phase 3's migration), not a new SchemaV4. **Why:** Phase 3 is the next migration anyway; adding one Date? field while SchemaV3 is being defined costs ~10 minutes and avoids a SchemaV4 round-trip. Planner verifies Phase 3 hasn't sealed SchemaV3 before relying on this; if Phase 3 has already shipped, fall back to SchemaV4 in Phase 4.

### Claude's Discretion

- Exact heat-map color hex values for intensification/realization (D-07) — UI-SPEC for this phase will lock; recommended `#F59E0B` / `#EA580C` from the iOS system-amber/system-orange family.
- Modal vs sheet form factor for `BlockReviewView` — UI-SPEC decides; recommended `.sheet(isPresented:)` with `.large` detent (matches `WhyThisWeightSheet` precedent from Phase 3).
- Block card swipe-pager dot indicators on/off — UI-SPEC decides; recommend off (the linear week badge inside each page is the canonical "which week" signal).
- Copy for the deload banner / canonicality contract / next-phase recommendation — UI-SPEC locks verbatim; match Phase 2/3 second-person direct voice.
- Whether `BlockTemplates.swift` is a static enum vs a `let` array vs a JSON resource — planner chooses (static Swift literal is the recommended path for inspection + diff-friendliness).
- Whether `BlockDraft.blockID: UUID?` for the routine-builder block picker is wired via `RoutineDraft` (Phase 2) extension or a new param on the picker — planner chooses.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phases 1, 2, 3)

- `Block` @Model (Phase 1) — id / name / startDate / endDate / notes / isActive; cascade phases; inverse routines + sessions. Schema in final shape, ready for builder consumption.
- `BlockPhase` @Model (Phase 1) — id / block / orderIndex / nameRaw / weeks / volumeMultiplier / intensityMultiplier / notes. All defaults in place; multiplier fields ready to receive D-10 RP values.
- `BlockPhaseKind` enum (Phase 1) — accumulation / intensification / realization / deload.
- `Routine.block: Block?` (Phase 1) — relationship already wired.
- `Session.block: Block?` (Phase 1) — relationship already wired.
- `ProgressionKind` enum (Phase 1) — already has `.block` and `.hybrid` cases; Phase 3 wires `.rpe` and `.double`, Phase 4 wires the remaining two.
- `SessionFactory.start(routine:on:context:)` (Phase 2) — extends to snapshot `routine.block → Session.block` (D-20). Single-line addition next to existing snapshot fields.
- `RoutineBuilderView` (Phase 2) — header gets a new "Block" menu (D-18). `RoutineDraft` (`@Observable`) gets a `blockID: UUID?` field.
- `RoutinesListView` (Phase 2) — sectioned list gets a "Blocks" section above existing folders (D-02).
- `ResumeWorkoutBanner` (Phase 2) — Today tab stacking order updated to put `BlockCard` above (D-06).
- `TodayView` (Phase 2, in `RootView.swift`) — adds `BlockCard` above the existing `ResumeWorkoutBanner` slot.
- `PreviousMatchingIntent` query (Phase 2) — feeds the e1RM-delta computation in `BlockReviewView` (D-22).
- `PrescriptionEditorRow` (Phase 2) — progression picker case set conditionally filters `.block`/`.hybrid` based on `routine.block != nil` (D-19).
- `ProgressionStrategy` protocol (Phase 3 — in flight) — `BlockPeriodizedStrategy` + `HybridStrategy` conform to it; Phase 4 adds 2 more conforming types alongside Phase 3's 2.
- `PrescriptionExplanation` value type (Phase 3 — in flight) — `BlockPeriodizedStrategy.explain(...)` and `HybridStrategy.explain(...)` emit instances of it for the "Why this weight?" disclosure surface.
- `WhyThisWeightSheet` (Phase 3 — in flight) — already renders any `PrescriptionExplanation`; no Phase 4 UI work for the disclosure surface itself, just new sentences in the explanation value.
- `UserSettings.deloadAlertEnabled: Bool` (Phase 1) — already exists; consumed by Phase 4 to gate the `ConsiderDeloadBanner` even when `FatigueAdvisory.shouldSuggest()` becomes truthy in Phase 5.

### Established Patterns

- MV-VM-lite: bind `@Query` directly to views; @Observable for ephemeral UI state only.
- Pure-function strategies behind protocols (FOUND-07) — Phase 4's `BlockPeriodizedStrategy` / `HybridStrategy` / `PeriodizationEngine` keep this shape.
- Snapshot at session start (PITFALLS #1) — extends to Session.block (D-20).
- Enums persisted as `*Raw: String` (FOUND-03) — no new enums in Phase 4; existing `BlockPhaseKind` already covers it.
- `#Index` on hot query paths (FOUND-04) — `Block.isActive` query (single-active invariant) and `Block.startDate` (week-counter math) are hot; planner verifies index presence (likely already there via Phase 1 schema).
- Atomic per-plan commits.
- Swift Testing with in-memory `ModelContainer` + `Schema(SchemaV2.models)` + `FitbodSchemaMigrationPlan` fixture pattern (per Phase 2 SUMMARY).
- Verbatim UI-SPEC copywriting.
- `.serialized` trait for UserDefaults-touching suites.
- Three-way merge save pattern (Phase 2's `RoutineDraft.save(into:context:)`) — `BlockDraft.save(into:context:)` follows the same shape.

### Integration Points

- `RootView.swift` → `TodayView` body: insert `BlockCard` above `ResumeWorkoutBanner`. One conditional render based on `@Query<Block>(filter: #Predicate { $0.isActive })`.
- `fitbod/Routines/RoutinesListView.swift` → new "Blocks" section above folders. `@Query<Block>` sorted by `isActive desc, startDate desc`.
- `fitbod/Routines/RoutineBuilderView.swift` (header area) → new "Block" picker menu.
- `fitbod/Routines/RoutineDraft.swift` → new `blockID: UUID?` field on the @Observable draft.
- `fitbod/Routines/PrescriptionEditorRow.swift` → conditional `.block` / `.hybrid` case filter on `routine.block != nil`.
- `fitbod/Sessions/SessionFactory.swift` → one-line snapshot copy `session.block = routine.block`.
- `fitbod/Prescription/` (Phase 3 — in flight) → add `BlockPeriodizedStrategy.swift`, `HybridStrategy.swift`, `PeriodizationEngine.swift`, `FatigueAdvisory.swift`, `StubFatigueAdvisory.swift`.
- `fitbod/Periodization/` (NEW directory) → `BlockBuilderView.swift`, `BlockDraft.swift`, `BlockTemplates.swift`, `BlockCard.swift`, `MesocycleNavigatorView.swift`, `BlockReviewView.swift`, `ConsiderDeloadBanner.swift`.
- `fitbod/Persistence/SchemaV3.swift` (Phase 3 — in flight) → add `Block.reviewedAt: Date?` field if SchemaV3 not yet sealed; otherwise SchemaV4 in Phase 4 (per D-26).
- `fitbodTests/` → new suites `BlockBuilderTests`, `PeriodizationEngineTests`, `BlockPeriodizedStrategyTests`, `HybridStrategyTests`, `BlockReviewMathTests`, `SingleActiveBlockInvariantTests`, `SessionBlockSnapshotTests`, `FatigueAdvisoryCanonicalityTests`.

</code_context>

<specifics>
## Specific Ideas

- Stock template names and structure (D-03) should feel domain-fluent: "Generic Strength Meso", "Hypertrophy Meso", "Powerlifting Peak" — not generic numbered templates. Defined as Swift literals in `BlockTemplates.swift` for diff-friendliness.
- Phase color palette (D-07): match iOS semantic colors where possible (`.orange`, `.gray`) but for accumulation use the existing app accent (`#0E7C86`) to keep the brand thread visible in the most common state. Intensification + realization can be `#F59E0B` / `#EA580C` from the system amber/orange family.
- Deload banner copy (D-13): match Phase 2/3 voice — direct, second-person, no exclamation. Example: "Deload week — recover, don't load." (Final wording locked by UI-SPEC.)
- Mesocycle swipe page transitions should feel snappy — match `.tabViewStyle(.page)` defaults, no custom timing. Page dots OFF — week badge inside each page is the canonical signal.
- Block card phase chip should reuse the existing `IntentFilterChipRow` chip styling from Phase 2 (44pt HIG, accent fill when current, `.systemGray5` when not) — different content (`BlockPhaseKind` instead of `Intent`) but identical shape so the visual language stays coherent.
- "Recommended next phase" CTA copy (D-23): "Start your next accumulation block" / "Start a deload" — proactive verb, no question marks. Tapping seeds the block builder with the stock template for that kind.
- The single-active invariant (D-05) should be enforced at the `BlockDraft.save(...)` boundary: a save that sets `isActive = true` must first set every other `Block.isActive` to false inside the same `modelContext` transaction (`try modelContext.transaction { ... }`). One write, one save.
- `Block.reviewedAt: Date?` (D-26) addition to SchemaV3: keep it Optional + nil-default to stay FOUND-02 safe. Setting it to `Date.now` on review acknowledgment + flipping `isActive = false` happens in the same transaction.
- Researcher at plan-phase should triple-check the RP multiplier defaults (D-10) against current literature — values published in `Scientific Principles of Hypertrophy Training` are the strongest cite. If RTS literature disagrees materially, surface the conflict; user accepts RP-aligned defaults.

</specifics>

<deferred>
## Deferred Ideas

- **Per-day routine assignment within the mesocycle** — Phase 4 week cards show a flat list of "routines linked to this block." Per-day scheduling (Mon = Push A, Tue = Pull A) is deferred to v1.x. Workaround: routines linked to a block all show on every week page; user runs them in the order they prefer.
- **Multiple concurrent active blocks** (rejected as Q-05 option B) — could be a future feature once single-active is proven. Would require per-routine block resolution at session start rather than the simpler "the one active block."
- **Real fatigue/plateau signal** (BLOCK-06 substance) — Phase 5 fills `FatigueAdvisory.shouldSuggest()` with the real signal. UI scaffold already locked here.
- **Block-aware progress charting** — intent-split charts with block phase shading is Phase 6. The block snapshot on Session (D-20) makes this trivially queryable.
- **PRs hit / volume aggregation surfaced in BlockReviewView** — Phase 5 (volume) + Phase 6 (PRs) fill the placeholders Phase 4 lays out in `BlockReviewView` (D-22).
- **Block templates marketplace / shareable mesos** — out of scope per PROJECT.md (no social features); personal app only.
- **"Smart" next-phase recommendation engine** — Phase 4 ships static rules (D-23). A historic-fatigue / e1RM-trend-aware recommendation is a future-version question.
- **Block carryover / "continue this block another N weeks"** — out of scope. Block ends, user starts another (potentially from the same template).
- **Per-phase-kind warm-up scaling beyond deload** — Phase 3 handles deload-skip; per-phase variants (e.g., realization = single-set warm-up only) deferred.
- **Block-aware intent overrides** — e.g., "intensification automatically biases all RoutineExercise.intent to strength." Out of scope; user manages intent at the routine level.
- **Tracking adherence (% of scheduled sessions completed)** — Phase 5 or 6.

</deferred>

---

*Phase: 4-periodization-blocks*
*Context gathered: 2026-05-22*
