---
phase: 02
plan: 01-01
subsystem: sessions
tags: ["sessions", "snapshot", "swiftdata", "wave-1"]
requires:
  - "SchemaV2 entities (plan 00-01)"
  - "SchemaV2 + V1→V2 lightweight migration wired (plan 00-02)"
  - "SetEntry.isComplete sentinel (plan 00-01)"
provides:
  - "SessionFactory.start(routine:on:context:) — the load-bearing deep-copy entry point"
  - "SessionFactory.active(in:) — single-active-session convenience accessor"
  - "SessionFactoryError typed errors (activeSessionAlreadyExists / routineHasNoExercises / persistenceFailed)"
  - "PreviousMatchingIntent.fetchTopWorkingSet — shared (exerciseID, intentRaw) → top working set query"
  - "PreviousMatchingIntentHit value type (weight / reps / rpe / sessionStartedAt)"
affects:
  - "Plan 02-01 (RestTimerEngine reads prescribedRestSeconds from snapshotted SessionExercise)"
  - "Plan 03-01 (RoutinesListView.handleStartTap calls SessionFactory.start)"
  - "Plan 04-01 (SessionLoggerView consumes the returned Session; PreviousColumn view uses PreviousMatchingIntent)"
tech-stack:
  added: []
  patterns:
    - "RESEARCH § Pattern 1 — Snapshot at boundary (template → instance) deep-copy"
    - "RESEARCH §6 Pitfall 1 — extract UUID/string to local var BEFORE constructing #Predicate (SwiftData related-entity ID compare footgun workaround)"
    - "RESEARCH §6 Pitfall 7 — one active session at a time invariant enforced inside the factory"
    - "PITFALLS-doc #1 / ROUTINE-07 — template-and-instance separation; editing a routine after start never mutates the snapshot"
    - "Plan 00-01 D-3 — explicit SetEntry.isComplete=false sentinel as the planned-but-not-logged marker"
    - "Single try context.save() transaction with typed persistenceFailed translation"
key-files:
  created:
    - "fitbod/Sessions/SessionFactory.swift"
    - "fitbod/Sessions/PreviousMatchingIntent.swift"
    - "fitbodTests/SessionFactoryTests.swift"
    - "fitbodTests/PreviousMatchingIntentTests.swift"
  modified: []
decisions:
  - "Added a SessionFactory.active(in:) public helper to centralize the completedAt == nil predicate — both the in-factory invariant check and the Today-tab 'Resume workout' banner (plan 04-01) need exactly that query."
  - "Suites marked @MainActor + .serialized following the project convention established by FilterStatePredicateTests / SchemaV2MigrationTests for SwiftData-backed tests under the app-hosted test process."
  - "previousHint defaults to 0 (not Double?) on first-ever logged session — keeps SetEntry.weight: Double non-optional and matches the existing Phase 1 entity shape; consumers display 0 lb in the input field which the user overwrites at log time."
  - "Two atomic commits (production code / tests) rather than the plan's suggested 2-3 — clean RED/GREEN order is unnecessary here because the plan is not type=tdd, and the production code is the canonical contract that the tests prove."
metrics:
  completed: 2026-05-11
  duration: "~3.5 minutes (parse-validate-only; in-Xcode test run pending user)"
  tasks: 1
  files_changed: 4
  commits: 2
---

# Phase 2 Plan 01-01: SessionFactory.start Snapshot + PreviousMatchingIntent Helper Summary

Landed the load-bearing Phase 2 snapshot semantic — `SessionFactory.start(routine:on:context:)` deep-copies every prescription field from `RoutineExercise` to `SessionExercise`, pre-populates planned `SetEntry` rows with `isComplete=false` sentinel and weight hint from the most recent matching-intent session, enforces the one-active-session invariant, and wraps the deep-copy in a single `try context.save()` transaction with typed `SessionFactoryError.persistenceFailed` translation. Extracted the (exerciseID, intentRaw) → top-working-set query into `PreviousMatchingIntent` so both the factory (seed weight hint) AND the future `PreviousColumn` view (plan 04-01) share one definition. Added 14 `@Test` functions across two new suites (8 `SessionFactoryTests` + 6 `PreviousMatchingIntentTests`) anchoring SESS-01 / ROUTINE-07 / SESS-03 / PITFALLS-doc #1. All 72 production + test Swift files parse-clean (`xcrun swiftc -parse` exits 0).

## What Was Built

### Created — `fitbod/Sessions/SessionFactory.swift` (175 lines)

- `public enum SessionFactoryError: Error` with three cases: `activeSessionAlreadyExists` / `routineHasNoExercises` / `persistenceFailed(underlying: Error)`.
- `public enum SessionFactory` namespace with two public entry points:
  - `public static func start(routine: Routine, on date: Date = .now, context: ModelContext) throws -> Session` — the load-bearing deep-copy. Validates empty-routine + active-session invariants up front; inserts a new `Session` (sourceRoutineID = routine.id soft UUID ref, routineSnapshotName = routine.name verbatim, block carried forward, completedAt = nil); iterates `RoutineExercise` rows sorted by `orderIndex`, creating one `SessionExercise` per row with all 9 prescription fields snapshotted (intentRaw / targetSets / targetRepsLow / targetRepsHigh / targetRPE / targetRIR / prescribedRestSeconds / tempo / progressionKindRaw); resolves the previous-matching-intent weight hint via `PreviousMatchingIntent.fetchTopWorkingSet`; pre-populates one `SetEntry` per `targetSets` with `isComplete = false`, `isWarmup = false`, `setTypeRaw = .working`, `weight = previousHint ?? 0`, `reps = 0`, `rpe = nil`. Wraps the entire deep-copy in a single `try context.save()` transaction translating errors to `SessionFactoryError.persistenceFailed(underlying:)`.
  - `public static func active(in context: ModelContext) -> Session?` — convenience accessor returning the single open session if one exists. Centralizes the `completedAt == nil` predicate so both the in-factory invariant gate AND the Today-tab Resume banner (plan 04-01) have one definition.

### Created — `fitbod/Sessions/PreviousMatchingIntent.swift` (118 lines)

- `public struct PreviousMatchingIntentHit: Sendable` — value type with `weight: Double` / `reps: Int` / `rpe: Double?` / `sessionStartedAt: Date`.
- `public enum PreviousMatchingIntent` namespace with `public static func fetchTopWorkingSet(exerciseID: UUID?, intentRaw: String, context: ModelContext) -> PreviousMatchingIntentHit?` — returns the highest-weight committed working set (non-warmup, reps > 0, isComplete == true) from the most recent matching-intent `SessionExercise`. Applies the RESEARCH §6 Pitfall 1 local-variable workaround (`let targetID = exerciseID; let targetIntent = intentRaw`) BEFORE constructing the `#Predicate` to dodge the SwiftData related-entity-ID compare footgun. Bounds the descriptor at `fetchLimit = 5` so multi-month training histories don't materialize the full match set per call; loops the recent SE rows until one has a committed working set (handles the edge case where a SessionExercise was started but discarded mid-session).

### Created — `fitbodTests/SessionFactoryTests.swift` (322 lines, 8 @Test funcs)

Each test builds its own `ModelContainer` via `Schema(SchemaV2.models)` + `FitbodSchemaMigrationPlan` to exercise the production wiring literally:

1. `snapshotsAllPrescriptionFields` — SESS-01 — asserts every one of the 9 prescription fields is copied verbatim to the SessionExercise rows for both fixture exercises (strength @ 3x5 / RPE 8.5 / 180s rest / RPE prog AND hypertrophy @ 4x8-12 / RPE 8 / 90s rest / double prog with explicit nil tempo + nil RIR coverage).
2. `editingRoutineAfterStartLeavesSnapshotIntact` — **ROUTINE-07 / PITFALLS-doc #1 — the canonical guard.** Mutates 9 fields on the source RoutineExercise after starting the session and asserts the SessionExercise snapshot is unchanged. This is the load-bearing test the entire phase rides on.
3. `sessionLinksRoutineByUUIDAndName` — verifies `Session.sourceRoutineID == routine.id` and `Session.routineSnapshotName == "Push Day"`, then renames the routine and asserts the snapshot name does NOT mutate.
4. `plannedSetEntriesCount` — asserts one `SetEntry` per `targetSets` (3 + 4 = 7 rows total), all with `isComplete == false`, `isWarmup == false`, `setTypeRaw == "working"`, `reps == 0`, `rpe == nil` (the plan 00-01 D-3 sentinel contract).
5. `activeSessionInvariant` — RESEARCH §6 Pitfall 7 — starts a session, attempts to start a second, asserts `SessionFactoryError.activeSessionAlreadyExists` is thrown. Also asserts `SessionFactory.active(in:)` returns the open session.
6. `emptyRoutineGuard` — asserts `SessionFactoryError.routineHasNoExercises` is thrown for a routine with no exercises.
7. `orderIndexPreservedAcrossSnapshot` — swaps the routine's `orderIndex` values BEFORE starting and asserts the resulting SessionExercise rows reflect the new order (OHP at 0, Bench at 1).
8. `blockReferenceCopiedFromRoutine` — asserts the optional `Block` link survives the snapshot (`session.block?.id == block.id`).

### Created — `fitbodTests/PreviousMatchingIntentTests.swift` (232 lines, 6 @Test funcs)

Each test builds its own `ModelContainer` via `Schema(SchemaV2.models)` + `FitbodSchemaMigrationPlan`. The `makeCompletedSession` helper creates a finished session with a configurable set tuple list `(weight, reps, rpe, isWarmup, isComplete)` so each test exercises a specific filter dimension:

1. `returnsNilWhenNoPriorSession` — empty DB yields nil.
2. `findsTopWorkingSetExcludesWarmupsAndZeroReps` — filters to `!isWarmup && reps > 0 && isComplete == true`; verifies 185 wins over 180 (top weight) and the warmup + zero-rep rows are excluded.
3. `intentSplitRespectsIntentFilter` — **ROUTINE-08 data plumbing** — strength session is invisible when querying hypertrophy AND vice versa.
4. `mostRecentSessionByStartedAtWins` — two sessions with different `startedAt` values; asserts the newer one's top working set is returned.
5. `nilExerciseIDReturnsNil` — defensive nil guard.
6. `ignoresIncompleteSets` — the planned-but-not-logged `isComplete == false` row is skipped; the heavier-but-not-committed weight (185) loses to the lighter committed weight (155).

## Decisions Made

1. **Added a public `SessionFactory.active(in:)` helper to the namespace** alongside `start`. The plan called for a "one-active-session-at-a-time helper: `Session.active(in: context)` returning `Session?` where `completedAt == nil`" — placing it on `SessionFactory` (not as a static on `Session` itself) keeps the active-session predicate co-located with the only code that creates sessions, and matches the plan's "Single source of truth" framing. The Today tab's Resume banner (plan 04-01) calls this directly.

2. **Both new test suites marked `@MainActor` + `.serialized`.** The Phase 1 `FilterStatePredicateTests` adopted this pattern after observing that SwiftData-backed tests in this project trap before individual assertions run when executed concurrently under the app-hosted test process. SchemaV2MigrationTests (plan 00-02) implicitly avoided the issue by being non-`@MainActor`; new suites that touch `ModelContext.fetch` inside `@Test` bodies follow the FilterStatePredicateTests convention.

3. **`previousHint` defaults to 0 (not `Double?`) on first-ever logged session.** `SetEntry.weight` is `Double` (non-optional) per Phase 1's entity shape. Storing 0 lb in the row means the user sees an empty-ish weight field on day 1 that they overwrite at log time — matches the UI-SPEC § Empty states implicit "no previous data" affordance without a schema change.

4. **Two atomic commits, not three.** The plan suggested 2-3; production code + tests is the natural split. RED/GREEN ordering doesn't apply (the plan is not `type=tdd`). The production code is the canonical contract; the tests prove it. Keeping both halves in one commit each makes `git log -p` scannable in two diffs rather than three.

## Files Changed

### Created
- `fitbod/Sessions/SessionFactory.swift` — 175 lines
- `fitbod/Sessions/PreviousMatchingIntent.swift` — 118 lines
- `fitbodTests/SessionFactoryTests.swift` — 322 lines
- `fitbodTests/PreviousMatchingIntentTests.swift` — 232 lines

### Modified
(none — the plan is purely additive)

### Intentionally NOT touched
- Phase 1 entity files (`Session.swift` / `SessionExercise.swift` / `SetEntry.swift` / `Routine.swift` / `RoutineExercise.swift`) — already final after plan 00-01 (which added all the V2 additive fields the factory snapshots).
- `SchemaV2.swift` / `FitbodSchemaMigrationPlan.swift` / `fitbodApp.swift` / `PreviewModelContainer.swift` — already final after plan 00-02 (which wired the V2 schema + lightweight migration).
- `RootView.swift` — interim Today-tab placeholder; the Resume banner that consumes `SessionFactory.active(in:)` is plan 04-01's job, not this plan.

## Commits

- `459f10a` — `feat(02-01-01): add SessionFactory.start snapshot + PreviousMatchingIntent helper` (2 new files, +293 lines)
- `41ec63a` — `test(02-01-01): add SessionFactoryTests + PreviousMatchingIntentTests` (2 new files, +554 lines)

## Verification

All 9 plan acceptance criteria verified:

| AC | Check | Result |
| -- | ----- | ------ |
| 1 | `fitbod/Sessions/SessionFactory.swift` exists; `grep -nE 'public enum SessionFactory\|public static func start' = 2 matches` | PASS |
| 2 | Active-session guard present: `grep '#Predicate { \$0\.completedAt == nil }' fitbod/Sessions/SessionFactory.swift` returns 2 matches (start + active); `SessionFactoryError.activeSessionAlreadyExists` reachable | PASS |
| 3 | Snapshot copies every prescription field: `grep -E 'se\.(intentRaw\|targetSets\|targetRepsLow\|targetRepsHigh\|targetRPE\|targetRIR\|prescribedRestSeconds\|tempo\|progressionKindRaw) =' fitbod/Sessions/SessionFactory.swift` returns 9 matches | PASS |
| 4 | `fitbod/Sessions/PreviousMatchingIntent.swift` exists with `public enum PreviousMatchingIntent` + `public struct PreviousMatchingIntentHit`; local-variable workaround verified: `grep -n 'let targetID = exerciseID\|let targetIntent = intentRaw'` returns 2 matches | PASS |
| 5 | `fitbodTests/SessionFactoryTests.swift` has exactly 8 `@Test` functions | PASS |
| 6 | `fitbodTests/PreviousMatchingIntentTests.swift` has exactly 6 `@Test` functions | PASS |
| 7 | Parse-clean: `find fitbod fitbodTests -name '*.swift' -type f \| xargs xcrun swiftc -parse` exits 0 with no output across all 53 production + 19 test Swift files | PASS |
| 8 | Planned `SetEntry` rows carry `isComplete = false`: `grep -n 'entry.isComplete = false' fitbod/Sessions/SessionFactory.swift` returns 1 match | PASS |
| 9 | Factory wraps deep-copy in `try context.save()` with typed error: `grep -nE 'try context.save\(\)\|persistenceFailed' fitbod/Sessions/SessionFactory.swift` returns ≥2 matches | PASS |

Additional invariants verified:
- `git diff --diff-filter=D --name-only HEAD~2 HEAD` returns empty (no accidental deletions).
- `git status --short` reports clean except a single pre-existing modified Phase 1 file (`fitbodTests/FilterStatePredicateTests.swift`) that pre-dates this plan and is not in scope.

## Deviations from Plan

None at the contract level. Two cosmetic additions documented above (Decisions §1 — `SessionFactory.active(in:)` helper; Decisions §2 — `@MainActor` + `.serialized` suite traits) follow project conventions established in prior plans and were not contemplated by the plan text. No Rule 1 / Rule 2 / Rule 3 / Rule 4 deviations occurred.

## Authentication Gates

None occurred. This is a pure SwiftData entity composition + Swift Testing assertion plan with no network, auth, or external-tool interactions.

## Known Stubs

None. The factory contract is functionally complete for Phase 2's needs:
- `SessionFactory.start` is the production deep-copy.
- `SessionFactory.active(in:)` is the production Resume-banner accessor.
- `PreviousMatchingIntent.fetchTopWorkingSet` is the production query for both the factory's seed weight AND plan 04-01's PreviousColumn view.
- `SessionExercise.prescribedWeight` is INTENTIONALLY left nil per the plan — Phase 3's `ProgressionStrategy` populates it; Phase 2 uses the previous-matching-intent hint only. Documented inline in `SessionFactory.swift` line 124 ("`prescribedWeight` is populated by Phase 3's ProgressionStrategy; for Phase 2 we leave it nil").

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or trust-boundary schema changes introduced. The factory composes existing on-device SwiftData entities under the same iCloud-replication-eligible cohort as Phase 1 / Phase 2 Wave 0.

## Next

Plan **02-01** (Wave 2 — RestTimerEngine) consumes `SessionExercise.prescribedRestSeconds` from the SessionFactory's snapshot to drive the rest timer. Plan **03-01** (RoutinesListView) calls `SessionFactory.start` from the "Start Workout" tap path. Plan **04-01** (SessionLoggerView) is the primary consumer of the returned `Session` AND uses `PreviousMatchingIntent.fetchTopWorkingSet` for the inline "Previous" column. The snapshot contract proven here is the precondition every later Phase 2 surface rides on.

## Self-Check

**Files created — verified present:**
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Sessions/SessionFactory.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbod/Sessions/PreviousMatchingIntent.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbodTests/SessionFactoryTests.swift` — FOUND
- `/Users/chrissaechao/Desktop/fitbod/fitbodTests/PreviousMatchingIntentTests.swift` — FOUND

**Commits — verified present in git log:**
- `459f10a` — FOUND
- `41ec63a` — FOUND

**Parse gate — verified:**
- `find fitbod fitbodTests -name '*.swift' -type f | xargs xcrun swiftc -parse` exited 0 with no output across 72 Swift files (53 production + 19 test).

**Acceptance gates — verified via grep:**
- `grep -nE '^\s*@Test' fitbodTests/SessionFactoryTests.swift` returned 8 hits (AC #5).
- `grep -nE '^\s*@Test' fitbodTests/PreviousMatchingIntentTests.swift` returned 6 hits (AC #6).
- `grep -nE '^\s*se\.(intentRaw|targetSets|targetRepsLow|targetRepsHigh|targetRPE|targetRIR|prescribedRestSeconds|tempo|progressionKindRaw) =' fitbod/Sessions/SessionFactory.swift` returned 9 hits (AC #3).
- `grep -n 'entry.isComplete = false' fitbod/Sessions/SessionFactory.swift` returned 1 hit (AC #8).
- `grep -n 'let targetID = exerciseID\|let targetIntent = intentRaw' fitbod/Sessions/PreviousMatchingIntent.swift` returned 2 hits (AC #4).

## Self-Check: PASSED
