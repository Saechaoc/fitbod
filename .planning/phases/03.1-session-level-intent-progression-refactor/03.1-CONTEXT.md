# Phase 3.1: Session-Level Intent & Progression Refactor - Context

**Gathered:** 2026-05-22
**Status:** Ready for planning
**Mode:** Smart-discuss (autonomous) — 4 areas × 4 questions accepted as recommended

<canonical_refs>
## Canonical References

MANDATORY reads for researcher and planner:
- `.planning/PROJECT.md`
- `.planning/REQUIREMENTS.md` — PIVOT-01..05 (new section appended 2026-05-22)
- `.planning/ROADMAP.md` — Phase 3.1 section (Goal + Success Criteria)
- `.planning/phases/03-smart-prescription-warm-ups/03-CONTEXT.md` — Phase 3 locked decisions (esp. CalibratingStatus / WhyThisWeightSheet status row)
- `.planning/phases/03-smart-prescription-warm-ups/03-RESEARCH.md` — SchemaV3 migration design; SwiftData related-entity-ID Pitfall 1
- `.planning/phases/02-core-loop-routines-sessions/02-CONTEXT.md` — SessionFactory snapshot pattern; @Observable RoutineDraft + three-way merge
- `.planning/phases/01-foundation-exercise-library/01-CONTEXT.md` — Schema versioning conventions; enum-as-String (FOUND-03)
- `.planning/phases/04-periodization-blocks/04-CONTEXT.md` — Phase 4 will inherit session-level intent/progression. Decision D-19 ("disallow .block/.hybrid unless routine is in a block") becomes obsolete after this refactor — Phase 4 re-plan needed afterward.
</canonical_refs>

<domain>
## Phase Boundary

This phase delivers **session-level intent + progression** — what was per-exercise becomes per-session. A `Routine` carries one Intent and one ProgressionKind that apply to the whole session. SchemaV4 migration moves the fields; UI strips per-exercise pickers; all Phase 3 read-sites + tests update to the new shape.

1. **Schema** — SchemaV4 versioned migration:
   - **Add** `Routine.intentRaw: String` (default `"strength"`), `Routine.progressionKindRaw: String` (default `"double"`)
   - **Add** `Session.intentRaw: String` (default `"strength"`), `Session.progressionKindRaw: String` (default `"double"`)
   - **Remove** `RoutineExercise.intentRaw`, `RoutineExercise.progressionKindRaw`
   - **Remove** `SessionExercise.intentRaw`
   - **Custom migration** (NOT lightweight): backfill Routine + Session from most-common per-exercise value; `.strength` fallback on ties / mixed sets
2. **Snapshot pattern** — `SessionFactory.start(routine:on:context:)` copies `routine.intentRaw` → `session.intentRaw` and `routine.progressionKindRaw` → `session.progressionKindRaw` at session start (PITFALLS #1). Editing the Routine later does not retroactively change logged Sessions.
3. **RoutineBuilderView** — Intent picker + Progression picker render at the top of the form, ABOVE the exercise list (order: Routine Name → Intent → Progression → Exercises section). Both use `LabeledContent` menu pickers matching the Phase-3-fix layout. `RoutineDraft` gains `intent` + `progressionKind` fields.
4. **PrescriptionEditorRow** — STRIP the Intent picker and Progression picker rows. Remaining rows: Sets / Reps range / Target RPE / Rest / Tempo (opt-in) / Track partial reps / Auto warm-up / Per-set overrides.
5. **SessionLoggerView header** — Renders an intent chip (15%-opacity accent capsule, reuses Phase 2's `intentChip` styling) next to the elapsed time and "1 of N" exercise counter. Read from `session.intentRaw`.
6. **WhyThisWeightSheet** — Status row reads from `session.intentRaw` (e.g., "Strength session — calibrating (4 / 10 sets)").
7. **PreviousMatchingIntent** — Predicate on `SessionExercise.exercise` only (the workaround already shipped for related-entity-ID Pitfall 1 stays); post-filter on `entry.sessionExercise?.session?.intentRaw == targetIntent` in Swift. Caller signature unchanged.
8. **ProgressionStrategyFactory** — Called once per session in `SessionFactory.start` using `session.progressionKindRaw`. Every SessionExercise in the same session gets the same strategy. `SessionExerciseCard.currentExplanation()` recompute path also reads from the session.
9. **History intent filter** — `ExerciseHistoryView` chip filter switches its predicate source from `SessionExercise.intentRaw` to `Session.intentRaw`. Same logical filter, new field source.
10. **Test rewiring** — All 12 Phase 3 test suites + Phase 2's `PreviousMatchingIntentTests` + `SessionFactoryTests` updated to set `session.intentRaw` / `session.progressionKindRaw` instead of per-exercise values. Two NEW suites: `SchemaV4MigrationTests`, `RoutineBuilderHeaderPickersTests`.

In scope: PIVOT-01..05 (5 requirements).
Out of scope: Block-level intent override (Phase 4 — block defaults inherit to Routine on assignment, but only after Phase 4 wires the block picker). Phase 4 re-plan to reflect the pivot (separate effort after this phase merges).
</domain>

<decisions>
## Implementation Decisions

### Area 1 — Field placement & defaults

- **D-01: Intent lives on Routine and Session** (snapshotted). `Routine.intentRaw: String`, `Session.intentRaw: String`. Persisted as `*Raw: String` per FOUND-03 with computed enum accessor in extension.
- **D-02: ProgressionKind lives on Routine and Session** (snapshotted). `Routine.progressionKindRaw: String`, `Session.progressionKindRaw: String`. Same persistence pattern.
- **D-03: Default intent = `.strength`** for new Routines. Matches developer's primary training style; user picks from header picker before save.
- **D-04: Default progressionKind = `.double`**. Most predictable strategy, works without prior history.

### Area 2 — SchemaV4 migration strategy

- **D-05: Custom (NOT lightweight) migration**. Single stage:
  - Add 4 new fields (`Routine.intentRaw`, `Routine.progressionKindRaw`, `Session.intentRaw`, `Session.progressionKindRaw`)
  - Backfill from most-common per-exercise value per Routine and per Session
  - Remove `RoutineExercise.intentRaw`, `RoutineExercise.progressionKindRaw`, `SessionExercise.intentRaw`
- **D-06: Routine backfill conflict resolution** — when ≥2 distinct intents in same Routine, use `.strength` as fallback. User can re-pick from header picker afterward. Same rule for progressionKind.
- **D-07: Session backfill** — same most-common-value logic per Session over its SessionExercises; `.strength` fallback on ties. Historical sessions remember their intent.
- **D-08: Keep all four ProgressionKind cases** (`.rpeAutoreg`, `.double`, `.block`, `.hybrid`). `.block` / `.hybrid` remain selectable from the header picker; the strategies route to DoubleProgression as a Phase 3 fallback (unchanged). Phase 4 replaces those fallbacks with real implementations.

### Area 3 — UI surfaces

- **D-09: RoutineBuilderView header order**: Routine Name → **Intent picker** → **Progression picker** → Exercises section. Both pickers rendered as `LabeledContent` with `.menu` style matching the Phase-3-fix layout. `RoutineDraft.intent: Intent` + `RoutineDraft.progressionKind: ProgressionKind` carry the selection through the @Observable draft.
- **D-10: PrescriptionEditorRow stripped of Intent + Progression rows**. Remaining order: Sets / Reps range / Target RPE / Rest / Tempo (opt-in) / Track partial reps / Auto warm-up / Per-set overrides.
- **D-11: SessionLoggerView header intent chip**. Render `intentChip` (extracted from Phase 2's `RoutineExerciseCard` private view into a shared `IntentChip` component) next to elapsed time + "1 of N". Reuses the 15%-opacity accent capsule + accent caption-label styling.
- **D-12: WhyThisWeightSheet status row** updates copy to read `"{Intent.capitalized} session — {status copy}"`. Example: "Strength session — calibrating (4 / 10 sets)" or "Hypertrophy session — calibrated".

### Area 4 — Read-sites + test rewiring

- **D-13: PreviousMatchingIntent rewrite**. Predicate on `SessionExercise.exercise == X` only (the Pitfall-1 workaround already shipped stays). Post-filter on `entry.sessionExercise?.session?.intentRaw == targetIntent` in Swift. Caller signature `fetchTopWorkingSet(exerciseID:intentRaw:context:)` is unchanged — the intent parameter now compares against the session-level value internally.
- **D-14: ProgressionStrategyFactory call site**. `SessionFactory.start` reads `session.progressionKindRaw` once per session and uses the same strategy for every SessionExercise in that session. `SessionExerciseCard.currentExplanation()` recompute reads from `session.progressionKindRaw` likewise.
- **D-15: ExerciseHistoryView intent split** keeps working — chip filter swaps its predicate source from `SessionExercise.intentRaw` to `Session.intentRaw` (also post-filter pattern). No UX change visible to user.
- **D-16: Test rewiring scope**:
  - Update all 12 Phase 3 test suites (TuchschererTableTests, PlateCalculatorTests, WarmupRampTests, RPEAutoregStrategyTests, DoubleProgressionStrategyTests, PrescriptionExplanationTests, ProgressionRoundingTests, ManualOverrideTests, SessionFactoryPhase3Tests, PlateInventoryTests, WarmupConfigTests, SchemaV3MigrationTests)
  - Update Phase 2's PreviousMatchingIntentTests + SessionFactoryTests
  - Add NEW: `SchemaV4MigrationTests` (mirrors SchemaV3MigrationTests structure; covers V3 → V4 custom migration with backfill cases), `RoutineBuilderHeaderPickersTests` (header pickers update RoutineDraft.intent / progressionKind correctly, snapshot to Session on save)

### Claude's Discretion

- Whether the intent chip in SessionLoggerView header is tap-interactive (e.g., to switch session intent mid-workout) — recommend NO for v1, the session's intent is locked at start
- Exact migration code shape (single MigrationStage.custom willMigrate vs split into two stages with intermediate) — planner picks the simpler one that the test suite can exercise cleanly
- Whether `IntentChip` extraction is a separate file or stays inline in a shared `Views/` location — planner picks; prefer separate file for reuse
- Whether the Phase 4 CONTEXT.md should be auto-edited to remove decision D-19 ("disallow .block/.hybrid unless in a block") — defer to Phase 4 re-plan; just flag it
- Whether `Routine.intent` and `Session.intent` get `#Index` declarations — recommend YES for `Session.intentRaw` (history queries hot) and NO for Routine (routine list is small)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets (from Phases 1-3)

- `Intent` enum already exists (Phase 1) with `.strength`, `.hypertrophy`, `.power`, `.endurance`, `.technique` cases
- `ProgressionKind` enum already exists (Phase 1) with `.rpe` (renamed to `.rpeAutoreg`?), `.double`, `.block`, `.hybrid`
- `FitbodSchemaMigrationPlan` already supports versioned migrations — V1→V2 + V2→V3 lightweight stages exist
- `RoutineDraft` (Phase 2) — @Observable, already snapshots from Routine on init; needs intent/progressionKind fields added
- `RoutineBuilderView` (Phase 2/3.1-fix) — recently refactored to use `LabeledContent`; new header pickers slot in cleanly above the Exercises section
- `SessionFactory.start(routine:on:context:)` — already does deep-copy snapshot; one-line additions for the two new fields
- `PrescriptionEditorRow` — needs two `private var intentPicker` / `progressionPicker` view functions removed; remaining rows already use `LabeledContent` and `rowLabel(_:)`
- `IntentFilterChipRow` (Phase 2) — exists in `Exercises/` for ExerciseHistoryView; the styling is reusable for the SessionLoggerView header chip
- All Phase 3 strategies + WarmupRamp are pure functions that take inputs explicitly — no internal SessionExercise/RoutineExercise field reads to refactor

### Established Patterns

- Versioned schema with computed enum accessors per FOUND-03
- @Observable draft + three-way merge save (Phase 2 RoutineDraft pattern)
- Snapshot at session start (PITFALLS #1) — extends to two new fields
- Pure-function strategies behind protocols (FOUND-07)
- Post-filter on related-entity-ID compares in Swift (Pitfall 1 workaround)
- #Index on hot query fields (SessionExercise.intentRaw was indexed; that index moves to Session.intentRaw)
- Swift Testing in-memory ModelContainer + `Schema(SchemaV4.models)` + FitbodSchemaMigrationPlan fixture pattern
- LabeledContent + .lineLimit(1) + .fixedSize(horizontal: true) for editor row layout (Phase 3 fix pattern)

### Integration Points

- `fitbod/Models/Routine.swift` → add `intentRaw: String = "strength"` + `progressionKindRaw: String = "double"` + computed accessors
- `fitbod/Models/Session.swift` → same two fields + accessors
- `fitbod/Models/RoutineExercise.swift` → REMOVE `intentRaw` and `progressionKindRaw` + accessors
- `fitbod/Models/SessionExercise.swift` → REMOVE `intentRaw` + accessor (and the index)
- `fitbod/Persistence/SchemaV4.swift` → NEW, mirrors SchemaV3
- `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` → add V3→V4 custom stage with backfill
- `fitbod/fitbodApp.swift` + `PreviewModelContainer.swift` → flip to `Schema(SchemaV4.models)`
- `fitbod/Routines/RoutineDraft.swift` → add `intent: Intent` + `progressionKind: ProgressionKind` fields + init from Routine + save back
- `fitbod/Routines/RoutineBuilderView.swift` → new header pickers (Intent + Progression) above Exercises section
- `fitbod/Routines/PrescriptionEditorRow.swift` → REMOVE `intentPicker` + `progressionPicker` view functions and their entries in `body`
- `fitbod/Routines/RoutineExerciseCard.swift` → REMOVE the `intentChip` reference in the header (intent is now session-level)
- `fitbod/Sessions/SessionFactory.swift` → snapshot the two new fields; ProgressionStrategyFactory call site reads from session
- `fitbod/Sessions/SessionLoggerView.swift` → header gains IntentChip
- `fitbod/Sessions/SessionExerciseCard.swift` → currentExplanation reads from session.progressionKindRaw
- `fitbod/Sessions/WhyThisWeightSheet.swift` → status row copy update
- `fitbod/Sessions/PreviousMatchingIntent.swift` → post-filter swap to `session?.intentRaw`
- `fitbod/Exercises/ExerciseHistoryView.swift` → chip filter swap
- `fitbod/Views/IntentChip.swift` → NEW, shared component extracted from Phase 2's RoutineExerciseCard
- `fitbodTests/SchemaV4MigrationTests.swift` → NEW
- `fitbodTests/RoutineBuilderHeaderPickersTests.swift` → NEW
- 12 Phase 3 test suites + 2 Phase 2 test suites → update

</code_context>

<specifics>
## Specific Ideas

- The migration's `willMigrate` closure should iterate `Routine`s first (computing each Routine's intent/progression from its RoutineExercises), then `Session`s (computing from SessionExercises). Use a deterministic tie-breaker (`Intent.strength` and `ProgressionKind.double`) so the migration is reproducible.
- The `IntentChip` extraction should be a single-file SwiftUI view with one initializer: `IntentChip(intent: Intent)`. Phase 2's inline chip in `RoutineExerciseCard` had been a `private var intentChip: some View` — promote it.
- The Phase 4 CONTEXT.md decision D-19 ("disallow .block/.hybrid unless in a block") becomes obsolete after this refactor (intent + progression are now session-level; no per-exercise picker to filter). Flag this in the plan's SUMMARY.md for the Phase 4 re-plan to consume.
- The on-disk store has a fresh SchemaV3 DB (user wiped + reseeded earlier today). The custom migration is exercised only in tests; production users won't have V3 data to migrate when this ships (because v1 hasn't shipped). Treat migration tests as the canonical correctness gate.
- Don't try to silently rename `ProgressionKind.rpe` to `.rpeAutoreg` in this phase — separate scope. Leave the enum cases as-is.

</specifics>

<deferred>
## Deferred Ideas

- **Block-level intent + progression defaults** — Phase 4 owns this. Block.intentRaw + Block.progressionKindRaw could exist as override defaults that auto-fill new Routines on block-assignment; but this requires the block-assignment UI from Phase 4. Defer.
- **Mid-session intent change** — UI to tap the SessionLoggerView intent chip and pick a different intent mid-workout. Out of scope; would require recomputing all prescriptions live.
- **Per-exercise intent OVERRIDE** — keep the field optional so a user can override the session intent for one specific exercise (e.g., "this isolation movement is for hypertrophy even on a strength day"). Rejected as v1 scope creep; user can re-tag a session if needed.
- **Phase 4 CONTEXT.md auto-edit** to remove D-19 — manual edit during Phase 4 re-plan; don't auto-modify upstream phase docs from this refactor.
- **Tag the SessionFactory snapshot with a `pivotSource: "v3-backfill"` flag** so analytics can distinguish pre-pivot Sessions — out of scope, single-user app, no analytics layer.

</deferred>
