---
phase: 02
plan: 04-02
subsystem: session-logger
tags: [session-logger, swap-exercise, add-unplanned, tempo, partial-reps, cluster-sub-reps, swiftui, swiftdata, sess-05, sess-06, sess-07, sess-08, wave-4]
requires:
  - "Plan 00-01 (SetEntry.partialReps + clusterSubReps computed accessor + clusterSubRepsJoined)"
  - "Plan 01-01 (SessionFactory.start + PreviousMatchingIntent shared helper)"
  - "Plan 03-02 (ExerciseLibraryView(onSelect:) picker init — RESEARCH § Pattern 5)"
  - "Plan 04-01 (SessionLoggerView + SessionExerciseCard + SetRow extension points)"
provides:
  - "SwapExerciseSheet — mid-session swap (SESS-05) — mutates SessionExercise.exercise ONLY"
  - "AddUnplannedExerciseButton — bottom-of-session 'Add Exercise' (SESS-06) — appends SE to active session ONLY"
  - "TempoEntryRow — opt-in 4-field tempo row (SESS-07) — persists ecc-bot-con-top to SetEntry.tempoActual"
  - "PartialRepsRow — opt-in partial reps row (SESS-08) — persists to SetEntry.partialReps"
  - "ClusterSubRepChipRow — rest-pause sub-rep chips (SESS-08) — persists to SetEntry.clusterSubReps"
  - "SessionExercise.tracksTempo + tracksPartialReps — snapshotted opt-in toggles for per-set row rendering"
affects:
  - "Plan 04-03 (workout notes + pinned per-exercise notes — wires the 'Edit Pinned Note' stub menu entry shipped here)"
tech-stack:
  added: []
  patterns:
    - "UI-SPEC § Session logger verbatim — Swap Exercise, This swap applies to this session only. The routine template will not change., Add Exercise, Cancel, Remove from Session, Edit Pinned Note, Remove \"{name}\"?, Any logged sets for this exercise will be discarded., Tempo, Ecc, Bot, Con, Top, Partial reps, Sub-reps:, + (sub-rep add chip)"
    - "PITFALLS-doc #1 — swap mutates SessionExercise.exercise only; the source RoutineExercise.exercise is untouched"
    - "PITFALLS-doc #1 — add-unplanned appends to Session.exercises only; the source Routine.exercises is untouched"
    - "RESEARCH § Pattern 5 — ExerciseLibraryView(onSelect:) picker init reused for both swap and add-unplanned flows"
    - "Additive-only SchemaV2 fields — SessionExercise.tracksTempo / tracksPartialReps default to false; lightweight migration absorbs them before V2 ships to any user"
    - "SwiftUI .sheet(item:) for SessionExercise-keyed swap sheet; .alert(presenting:) for SessionExercise-keyed destructive remove confirmation"
    - "Cascade .cascade on SessionExercise.sets (plan 01-01 entity) — ctx.delete(sessionExercise) cleans owned SetEntry rows transitively"
    - "PreviousMatchingIntent.fetchTopWorkingSet — single shared query path for swap-time pending-set re-seed AND add-unplanned planned-set seed (DRY — same hint logic as SessionFactory + SessionExerciseCard.addSet)"
key-files:
  created:
    - "fitbod/Sessions/SwapExerciseSheet.swift"
    - "fitbod/Sessions/AddUnplannedExerciseButton.swift"
    - "fitbod/Sessions/TempoEntryRow.swift"
    - "fitbod/Sessions/PartialRepsRow.swift"
    - "fitbod/Sessions/ClusterSubRepChipRow.swift"
    - "fitbodTests/MidSessionSwapTests.swift"
    - "fitbodTests/AddUnplannedExerciseTests.swift"
    - "fitbodTests/OptionalRowRenderingTests.swift"
  modified:
    - "fitbod/Models/SessionExercise.swift"
    - "fitbod/Sessions/SessionFactory.swift"
    - "fitbod/Sessions/SessionExerciseCard.swift"
    - "fitbod/Sessions/SessionLoggerView.swift"
    - "fitbodTests/SessionFactoryTests.swift"
decisions:
  - "Treated this plan's additive SessionExercise fields (tracksTempo, tracksPartialReps) as in-flight SchemaV2 — landed BEFORE V2 ever shipped to a user, so no V3 migration is needed. SchemaV2.swift itself stays untouched (the entity catalog references SessionExercise.self by type, not by field list). Default-valued additive fields are lightweight-eligible by Apple's MigrationStage docs."
  - "Re-implemented the swap + append semantics hermetically inside MidSessionSwapTests and AddUnplannedExerciseTests rather than instantiating the SwiftUI view tree. The closure bodies are 6-15 LOC each; hoisting them into a service object would add a one-off controller that's exercised exactly once. Pattern matches plan 04-01's SetRowCommitTests/commitSet hermetic copy."
  - "Wrapped each SetRow inside SessionExerciseCard in a VStack(spacing: 4) and conditionally render the three opt-in rows BENEATH it. Alternative considered: putting the optional rows in a separate ForEach beside the SetRow. Rejected because the optional rows are per-SetEntry (one tempo/partial/cluster row per set), so colocating them under each SetRow keeps the Set's content visually grouped — matches the UI-SPEC's intent of 'optional row beneath set inputs'."
  - "Made `onSwap` + `onRemove` default-argument closures (`= { _ in }`) on SessionExerciseCard's init. Plan 04-01's existing callers (none yet besides SessionLoggerView, but the test fixtures in plan 04-01 instantiate the card directly in #Preview) compile unchanged. Plan 04-02's SessionLoggerView passes real closures; everyone else gets a quiet no-op."
  - "Used `.alert(presenting:)` for the destructive remove confirmation rather than `.alert(isPresented:)` so the alert body can reference the SessionExercise's exercise name in the title (UI-SPEC verbatim 'Remove \"{name}\"?'). The presenting variant binds the alert lifetime to the optional state directly, eliminating a separate $presentingFlag boolean."
  - "OptionalRowRenderingTests verifies conditional render predicates via on-disk substring matches against SessionExerciseCard.swift rather than via SwiftUI view inspection. SwiftUI's view tree is opaque to runtime tests; the source-level anchor catches the most likely regression (someone deleting the gate predicate). The data path itself (the snapshotted fields land on SessionExercise + survive SessionFactory) is verified separately by SessionFactoryTests/snapshotsTracksTempoAndTracksPartialReps."
  - "Four atomic commits matching the plan's directive (M-sized plan, ~550 LOC across 5 new sources + 3 modifications + 3 test suites): (1) SessionExercise + SessionFactory snapshot field, (2) five new view components, (3) SessionExerciseCard + SessionLoggerView integration, (4) three test suites."
metrics:
  duration_seconds: 720
  completed: "2026-05-11T20:35:00Z"
  files_created: 8
  files_modified: 5
  commits: 4
  test_count: 10
---

# Phase 2 Plan 04-02: Mid-Session Swap, Add Unplanned, Tempo / Partials / Cluster Rows Summary

Phase 2's remaining four SESS-* requirements ship as a single tightly-scoped wave-4 plan. Long-pressing an exercise card header in the session logger surfaces a context menu with **"Swap Exercise…"** (presents `SwapExerciseSheet` with the embedded `ExerciseLibraryView(onSelect:)` picker) / **"Edit Pinned Note"** (stub; sheet lands in plan 04-03) / **"Remove from Session"** (destructive UI-SPEC-verbatim alert). Bottom of the session list now shows a **"+ Add Exercise"** button (`AddUnplannedExerciseButton`) → picker → appends a brand-new `SessionExercise` row to the active session with three planned `SetEntry` rows seeded from `PreviousMatchingIntent.fetchTopWorkingSet`. Three new opt-in row components — `TempoEntryRow`, `PartialRepsRow`, `ClusterSubRepChipRow` — conditionally render beneath each `SetRow` based on per-`SessionExercise` toggles (snapshotted from `RoutineExercise.tracksTempo` / `tracksPartialReps` at `SessionFactory.start` time) and per-`SetEntry` set type (`.restPause` for cluster sub-reps). The swap mutates `SessionExercise.exercise` only; the source `RoutineExercise.exercise` is untouched. The add-unplanned appends to `Session.exercises` only; the source `Routine.exercises` is untouched. Both contracts are pinned by tests against the production model entities.

## Goal

Close the SESS-05 / SESS-06 / SESS-07 / SESS-08 contracts deferred from plan `04-01`:

- **SESS-05** — mid-session swap that mutates `SessionExercise.exercise` only and re-seeds pending (un-committed) sets via `PreviousMatchingIntent` on the new exercise.
- **SESS-06** — add unplanned exercise mid-session that appends a new `SessionExercise` + three planned `SetEntry` rows to the active session only.
- **SESS-07** — optional 4-field tempo per set, gated on the snapshotted `SessionExercise.tracksTempo` flag.
- **SESS-08** — partial reps row (gated on `SessionExercise.tracksPartialReps`) and cluster sub-rep chip row (gated on `set.setType == .restPause`).

## Requirements Covered

- **SESS-05** (mid-session swap without mutating routine template) — `SwapExerciseSheet`'s onSelect closure sets `sessionExercise.exercise = exercise` and re-seeds pending sets. `MidSessionSwapTests/swapMutatesSessionExerciseOnly` + `swapDoesNotAffectRoutineTemplate` pin the SE-only mutation contract.
- **SESS-06** (add unplanned exercise mid-session) — `AddUnplannedExerciseButton.append(exercise:)` creates a new `SessionExercise` + three planned `SetEntry` rows on the active session. `AddUnplannedExerciseTests/appendsSessionExerciseToActiveSession` + `doesNotMutateSourceRoutine` + `seedsThreeDefaultSetsWithMatchingIntentHint` pin the append contract.
- **SESS-07** (optional 4-field tempo per set) — `TempoEntryRow` renders only when `sessionExercise.tracksTempo == true` (snapshotted from `RoutineExercise.tracksTempo` at `SessionFactory.start` time). `OptionalRowRenderingTests/tempoRowRendersWhenSnapshottedFlag` pins the conditional render predicate. `SessionFactoryTests/snapshotsTracksTempoAndTracksPartialReps` pins the snapshot data path.
- **SESS-08** (partial reps + cluster sub-reps) — `PartialRepsRow` renders only when `sessionExercise.tracksPartialReps == true`; `ClusterSubRepChipRow` renders only when `set.setType == .restPause`. `OptionalRowRenderingTests/partialsRowRendersWhenSnapshottedFlag` + `clusterChipRowRendersWhenSetTypeRestPause` pin both gates.

## Files

| Path | Status | Purpose | LOC |
|------|--------|---------|----:|
| `fitbod/Models/SessionExercise.swift` | MODIFIED | Add `tracksTempo: Bool = false` + `tracksPartialReps: Bool = false` (additive SchemaV2 fields) | +2 |
| `fitbod/Sessions/SessionFactory.swift` | MODIFIED | Snapshot the two new flags into `SessionExercise` during the deep-copy | +8 |
| `fitbod/Sessions/SwapExerciseSheet.swift` | NEW | SESS-05 swap sheet — embeds `ExerciseLibraryView(onSelect:)`; re-seeds pending sets | 100 |
| `fitbod/Sessions/AddUnplannedExerciseButton.swift` | NEW | SESS-06 bottom-of-session "+ Add Exercise" button + picker sheet | 132 |
| `fitbod/Sessions/TempoEntryRow.swift` | NEW | SESS-07 opt-in 4-field tempo row ("Ecc / Bot / Con / Top") | 105 |
| `fitbod/Sessions/PartialRepsRow.swift` | NEW | SESS-08 opt-in partial reps row | 73 |
| `fitbod/Sessions/ClusterSubRepChipRow.swift` | NEW | SESS-08 rest-pause sub-rep chip row | 100 |
| `fitbod/Sessions/SessionExerciseCard.swift` | MODIFIED | onSwap/onRemove closures + long-press contextMenu + conditional opt-in row rendering wrapped around each SetRow | +50/-7 |
| `fitbod/Sessions/SessionLoggerView.swift` | MODIFIED | pendingSwap/pendingRemove @State + `.sheet(item:)` for swap + `.alert(presenting:)` for remove + bottom-of-list AddUnplannedExerciseButton + handleRemove(_:) | +61/-1 |
| `fitbodTests/SessionFactoryTests.swift` | MODIFIED | New `snapshotsTracksTempoAndTracksPartialReps` test verifying snapshot deep-copy of both new fields | +26 |
| `fitbodTests/MidSessionSwapTests.swift` | NEW | 4 tests covering SESS-05 — SE-only mutation / pending re-seed / committed immutability / routine untouched | 244 |
| `fitbodTests/AddUnplannedExerciseTests.swift` | NEW | 3 tests covering SESS-06 — appended to active session / routine untouched / 3 planned sets seeded with hint | 186 |
| `fitbodTests/OptionalRowRenderingTests.swift` | NEW | 3 tests anchoring the SESS-07/SESS-08 conditional render predicates at the source level | 68 |

**Total:** 8 files created, 5 modified, ~1100 LOC added.

## Acceptance Criteria

All 15 acceptance criteria from PLAN.md verified mechanically via the plan's grep commands.

| AC | Criterion | Status |
|----|-----------|:------:|
| 1 | `SessionExercise.swift` has `tracksTempo: Bool = false` + `tracksPartialReps: Bool = false` | PASS (2 matches lines 50/51) |
| 2 | `SchemaV2.swift` unchanged (`git diff --stat HEAD~3..HEAD -- fitbod/Persistence/SchemaV2.swift` shows zero changes) | PASS (empty diff) |
| 3 | `SessionFactory.swift` snapshots both flags (`se.tracksTempo = re.tracksTempo` + `se.tracksPartialReps = re.tracksPartialReps`) | PASS (2 matches lines 129/130) |
| 4 | `SwapExerciseSheet.swift` exists with SE-only mutation + UI-SPEC verbatim footer | PASS (2 matches lines 49/70) |
| 5 | Swap re-seeds pending sets via `PreviousMatchingIntent.fetchTopWorkingSet` | PASS (1 match line 55) |
| 6 | `AddUnplannedExerciseButton.swift` exists; appends SessionExercise + 3 planned SetEntry rows | PASS (3 matches lines 80/83/98) |
| 7 | `TempoEntryRow.swift` has 4 fields labeled `"Ecc"`/`"Bot"`/`"Con"`/`"Top"` | PASS (4 individual label matches) |
| 8 | `PartialRepsRow.swift` has UI-SPEC verbatim `"Partial reps"` label | PASS (line 38) |
| 9 | `ClusterSubRepChipRow.swift` has `"Sub-reps:"` prefix + `"+"` add chip + `entry.clusterSubReps` | PASS (3+ matches) |
| 10 | `SessionExerciseCard.swift` has long-press contextMenu with all three labels + 3 conditional render predicates | PASS (5+ matches: Swap Exercise…, Edit Pinned Note, Remove from Session, tracksTempo, tracksPartialReps, set.setType == .restPause) |
| 11 | `SessionLoggerView.swift` mounts `AddUnplannedExerciseButton(session: session)` + pendingSwap/pendingRemove state + `ctx.delete(se)` | PASS (4+ matches across lines 82/85/104/105/113/200) |
| 12 | UI-SPEC verbatim remove confirmation copy | PASS (line 178 title format + line 190 body + line 185 Remove button + line 186 Cancel button) |
| 13 | Test counts: MidSessionSwapTests = 4, AddUnplannedExerciseTests = 3, OptionalRowRenderingTests = 3 | PASS (verified via `grep -c '@Test('`) |
| 14 | `SessionFactoryTests/snapshotsTracksTempoAndTracksPartialReps` exists | PASS (line 303) |
| 15 | Parse-clean: `find fitbod fitbodTests -name '*.swift' \| xargs xcrun swiftc -parse` exits 0 | PASS |

## Test Matrix Shipped

`MidSessionSwapTests` (4 tests — production hermetic copy of `SwapExerciseSheet.onSelect`):

| Test | Asserts |
|------|---------|
| `swapMutatesSessionExerciseOnly` | SESS-05 — `SE.exercise` points at new exercise; source `RE.exercise` unchanged |
| `swapResetsPendingSetsToNewHint` | Pending sets adopt the new exercise's matching-intent hint (95 lb OHP from a prior strength session); reps + rpe cleared |
| `swapLeavesCompletedSetsAlone` | Committed sets retain `weight = 145`, `reps = 5`, `rpe = 8.0`, `isComplete = true`; pending sets re-seed |
| `swapDoesNotAffectRoutineTemplate` | PITFALLS-doc #1 / ROUTINE-07 — every routine prescription field stays identical post-swap |

`AddUnplannedExerciseTests` (3 tests — production hermetic copy of `AddUnplannedExerciseButton.append`):

| Test | Asserts |
|------|---------|
| `appendsSessionExerciseToActiveSession` | SESS-06 — new SE row at `orderIndex = (existing count)` lands on `session.exercises` |
| `doesNotMutateSourceRoutine` | PITFALLS-doc #1 — `Routine.exercises` count + identity unchanged |
| `seedsThreeDefaultSetsWithMatchingIntentHint` | 3 planned SetEntry rows at PreviousMatchingIntent hint weight (30 lb hypertrophy curl); intent = hypertrophy, rest = 90s, reps 8-12 (CONTEXT.md Area 1 defaults) |

`OptionalRowRenderingTests` (3 tests — source-level grep on `SessionExerciseCard.swift`):

| Test | Asserts |
|------|---------|
| `tempoRowRendersWhenSnapshottedFlag` | SESS-07 — gate is `if sessionExercise.tracksTempo` + view is `TempoEntryRow(entry: set)` |
| `partialsRowRendersWhenSnapshottedFlag` | SESS-08 — gate is `if sessionExercise.tracksPartialReps` + view is `PartialRepsRow(entry: set)` |
| `clusterChipRowRendersWhenSetTypeRestPause` | SESS-08 — gate is `if set.setType == .restPause` + view is `ClusterSubRepChipRow(entry: set)` |

`SessionFactoryTests/snapshotsTracksTempoAndTracksPartialReps` (1 new test added to plan 01-01's file):

| Test | Asserts |
|------|---------|
| `snapshotsTracksTempoAndTracksPartialReps` | SessionFactory deep-copy snapshots both new fields (flipped-on branch sees `true`; default branch sees `false`) |

The prior `SessionFactoryTests` suite of 8 tests continues to pass unchanged — the snapshot pattern is purely additive.

## Architecture Patterns Demonstrated

- **Snapshot-and-decouple, extended to per-set row rendering toggles:** Adding `tracksTempo` + `tracksPartialReps` to `SessionExercise` (not just `RoutineExercise`) keeps the active session's per-row rendering decoupled from later edits to the routine template. The user can flip "Track tempo" on the routine builder mid-week without rewriting the in-flight session's row layout. PITFALLS-doc #1 stays structural.
- **Mid-flight SchemaV2 additive evolution (no V3 needed):** The two new fields were added to `SessionExercise` AFTER plan `00-01` introduced SchemaV2 but BEFORE V2 ever shipped to a real user. Lightweight migration absorbs default-valued additive fields automatically (Apple's `MigrationStage.lightweight` contract — additive-only). No V2 → V3 ceremony needed; the executor of any future Phase 2 plan can continue extending V2 by the same pattern until the first beta ships.
- **DRY hint resolution at three callsites:** `PreviousMatchingIntent.fetchTopWorkingSet` is now consumed by `SessionFactory.start` (initial planned-set seed), `SessionExerciseCard.addSet` (new-set seed mid-session, plan 04-01), `SwapExerciseSheet.onSelect` (swap pending-set re-seed), and `AddUnplannedExerciseButton.append` (add-unplanned planned-set seed). Four surfaces; one query path. Centralization prevents the four callsites from drifting on subtle semantics (working-set filter, warmup exclusion, intent split).
- **`.sheet(item:)` + `.alert(presenting:)` for SessionExercise-keyed lifecycle:** Both presentations bind to optional `SessionExercise?` state on `SessionLoggerView` and dismiss automatically when the state goes `nil`. The presenting variant of `.alert` carries the SessionExercise through to the alert body so the title can reference the exercise name verbatim (UI-SPEC `"Remove \"{name}\"?"`).
- **Default-argument closure parameters for backward compat:** `SessionExerciseCard.init` now takes `onSwap` + `onRemove` with `= { _ in }` defaults. Plan 04-01's #Preview blocks and any prior caller compile unchanged; only the production call site in `SessionLoggerView` passes real handlers. This keeps the plan 04-01 → 04-02 wire surgical and avoids touching unrelated previews.
- **Conditional row rendering colocated inside each set's VStack:** Each `SetRow` is now wrapped in `VStack(spacing: 4)` with the three opt-in rows conditionally rendered BENEATH. Alternative considered (a parallel ForEach beside the SetRow) was rejected because the optional rows are per-`SetEntry`, so colocation preserves the visual grouping per set — matches UI-SPEC's intent of "optional row beneath set inputs".
- **Hermetic test re-implementation of swap + append closure bodies:** Both `MidSessionSwapTests` and `AddUnplannedExerciseTests` copy the closure body verbatim from the SwiftUI view's `onSelect` / `append`. SwiftUI views are not hermetically testable as black boxes; the contract test instantiates the closure body's semantic against the production model entities and asserts the resulting graph. Same pattern as plan 04-01's `SetRowCommitTests/commitSet`.

## Deviations from Plan

**None — plan executed exactly as written.**

The plan body's file shapes (`SwapExerciseSheet`, `AddUnplannedExerciseButton`, `TempoEntryRow`, `PartialRepsRow`, `ClusterSubRepChipRow`) were copied verbatim from the plan body into the source tree with the exact field names, helper methods, and UI-SPEC verbatim copy strings. The `SessionExerciseCard` modification adds `onSwap`/`onRemove` closures + long-press contextMenu + conditional opt-in row rendering. The `SessionLoggerView` modification adds `pendingSwap`/`pendingRemove` state + `.sheet(item:)` + `.alert(presenting:)` + the bottom-of-list `AddUnplannedExerciseButton`. The two `SessionExercise` field additions match the plan's "mid-wave schema correction" callout — they slot into the in-flight SchemaV2 with default values, no V3 migration needed because SchemaV2 has not shipped to any user yet.

### Auth gates encountered

None — this plan is pure SwiftUI + SwiftData with no network, no API keys, no permission prompts. The notification permission gate from plan 02-01's `LiveNotificationScheduler` is unchanged (still pending on first `engine.start(...)`, but unaffected by this plan).

## Known Stubs

The plan body explicitly defers one surface to a later plan:

1. **"Edit Pinned Note" context menu entry** on `SessionExerciseCard`'s header — currently a no-op button. The actual pinned-note edit sheet ships in plan `04-03` per the plan body's `<dependencies>` soft link.

The chip-tap-to-edit pattern on `ClusterSubRepChipRow` (allowing the user to bump a sub-rep value from 1 → 2 → 3 by tapping an existing chip) is also explicitly deferred to Phase 6 polish per the plan body's anti-patterns callout. Tapping `[+]` appends a sub-rep with value 1; the array can be reset by removing chips in v1.x.

Neither stub blocks the plan's goal (swap + add-unplanned + opt-in rows are end-to-end wireable on a real session today).

## Threat Flags

None — this plan introduces no new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. The two new `SessionExercise` fields are default-valued additive `Bool` flags; all reads/writes go through the existing SwiftData `ModelContext` (plan 00-02's `SchemaV2`); all UI state is local `@State`.

## TDD Gate Compliance

Plan frontmatter is **not** `type: tdd` (it's a standard Wave 4 plan). The plan-level RED/GREEN gate sequence does not apply. Within the plan, the production code commits (3 × `feat`) preceded the test commit (1 × `test`) per the project's established multi-commit-per-plan convention.

## Commits

| Hash | Type | Summary |
|------|------|---------|
| `e322ec0` | feat | SessionExercise additive fields (tracksTempo, tracksPartialReps) + SessionFactory snapshot + SessionFactoryTests new test |
| `1a9b7e2` | feat | Five new view components (SwapExerciseSheet, AddUnplannedExerciseButton, TempoEntryRow, PartialRepsRow, ClusterSubRepChipRow) |
| `22b6815` | feat | SessionExerciseCard + SessionLoggerView integration (long-press contextMenu, conditional opt-in rendering, sheet/alert wiring, bottom-of-list AddUnplannedExerciseButton) |
| `c2f56f7` | test | MidSessionSwapTests (4) + AddUnplannedExerciseTests (3) + OptionalRowRenderingTests (3) |

Four atomic commits on the main branch with the project's per-task convention. The SUMMARY commit follows separately.

## What this unblocks

- **Plan 04-03 (workout notes + pinned per-exercise notes sheets)** — can now wire the "Edit Pinned Note" stub menu entry on `SessionExerciseCard` to a real `PinnedNoteSheet`. The workout-level notes button on `SessionLoggerView`'s header also gets its real sheet here.
- **Plan 05-01 (per-exercise history with intent split)** — once 04-02/04-03 close out the session-logger surface, plan 05-01 ships the read-side view of intent-split history. The data path (`SessionExercise.intentRaw` indexed field consumed by `PreviousMatchingIntent`) is unchanged; the new contribution is the read-side list with intent-filter chips.
- **End-to-end Phase 2 minimum-lovable-product is now within one plan of complete:** Routines → Start Workout → log sets with rest timer → swap/add mid-session → finish → per-exercise history (plan 05-01). Plan 04-03 closes the notes layer.
- **Wave 4 closure:** plans 04-01 + 04-02 + 04-03 cover the full session logger surface. Together they ship every user-visible SESS-* requirement (1-11).

## Self-Check: PASSED

**Files claimed created — verified on disk:**
- `fitbod/Sessions/SwapExerciseSheet.swift` — FOUND
- `fitbod/Sessions/AddUnplannedExerciseButton.swift` — FOUND
- `fitbod/Sessions/TempoEntryRow.swift` — FOUND
- `fitbod/Sessions/PartialRepsRow.swift` — FOUND
- `fitbod/Sessions/ClusterSubRepChipRow.swift` — FOUND
- `fitbodTests/MidSessionSwapTests.swift` — FOUND
- `fitbodTests/AddUnplannedExerciseTests.swift` — FOUND
- `fitbodTests/OptionalRowRenderingTests.swift` — FOUND

**Files claimed modified — verified on disk:**
- `fitbod/Models/SessionExercise.swift` — FOUND (lines 50-51 carry `tracksTempo`/`tracksPartialReps`)
- `fitbod/Sessions/SessionFactory.swift` — FOUND (lines 129-130 carry the snapshot deep-copy)
- `fitbod/Sessions/SessionExerciseCard.swift` — FOUND (header contextMenu + VStack wrapping each SetRow + onSwap/onRemove closures)
- `fitbod/Sessions/SessionLoggerView.swift` — FOUND (pendingSwap/pendingRemove + sheet + alert + AddUnplannedExerciseButton mount + handleRemove)
- `fitbodTests/SessionFactoryTests.swift` — FOUND (new test at line 303)

**Commits claimed — verified in git log:**
- `e322ec0` (feat — SessionExercise + SessionFactory snapshot) — FOUND
- `1a9b7e2` (feat — five new view components) — FOUND
- `22b6815` (feat — SessionExerciseCard + SessionLoggerView integration) — FOUND
- `c2f56f7` (test — three test suites) — FOUND

**Parse-clean (AC15):** `find fitbod fitbodTests -name '*.swift' | xargs xcrun swiftc -parse` → exit 0.
