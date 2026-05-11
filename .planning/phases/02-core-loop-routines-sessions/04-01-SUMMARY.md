---
phase: 02
plan: 04-01
subsystem: session-logger
tags: [session-logger, set-row, rpe-chips, previous-column, rest-timer, swiftui, swiftdata, sess-01, sess-02, sess-03, sess-04, sess-09, sess-11, routine-08, wave-4]
requires:
  - "Plan 01-01 (SessionFactory.start + PreviousMatchingIntent shared helper)"
  - "Plan 02-03 (RestTimerEngine.makeProduction + RestTimerOverlay)"
  - "Plan 03-01 (RoutinesListView — navigation owner for SessionRoute)"
provides:
  - "SessionLoggerView — the active workout-logging surface bound to @Bindable Session"
  - "SessionExerciseCard — one card per snapshotted SessionExercise with column header + SetRows + Add Set"
  - "SetRow — per-set inputs (weight/reps/RPE chips/type chip/completion checkmark)"
  - "InlineRPEChipRow — 5 integer RPE chips with 0.5s long-press → decimal sheet"
  - "DecimalRPEPickerSheet — wheel picker over stride(from: 6.0, through: 10.0, by: 0.5)"
  - "SetTypeChip — cycling chip (working/warmup/drop/failure/restPause) with UI-SPEC system colors"
  - "PreviousColumn — inline matching-intent prior-set display via PreviousMatchingIntent.fetchTopWorkingSet"
  - "SessionRoute enum — typed NavigationPath payload for the session logger destination"
  - "TodayView — Today tab body with ResumeWorkoutBanner + UI-SPEC empty state (replaces PlaceholderTabView phase 2)"
affects:
  - "Plan 04-02 (mid-session swap + add unplanned exercise — consumes SessionLoggerView's @Bindable Session surface)"
  - "Plan 04-03 (workout notes + pinned per-exercise notes + tempo + partial-reps + cluster sub-reps — consumes SessionExerciseCard + SetRow surfaces)"
tech-stack:
  added: []
  patterns:
    - "UI-SPEC § Session logger — verbatim copy (Workout / Finish / Discard / dialog bodies / column header labels / set-type menu labels)"
    - "RESEARCH §6 Pattern 2 — TimelineView(.periodic(from: elapsedStart, by: 1)) for Date-derived elapsed-time UI"
    - "RESEARCH §6 Pitfall 2 — try? ctx.save() BEFORE engine.start so committed set persists before rest period begins"
    - "RESEARCH §6 Pitfall 1 (PreviousColumn data path) — query via PreviousMatchingIntent helper which extracts UUID/intent to locals BEFORE the #Predicate"
    - "UI-SPEC anti-corruption guard — commit gated by `entry.weight > 0 && entry.reps > 0` so PreviousMatchingIntent.fetchTopWorkingSet never sees zero-weight ghosts"
    - "PITFALLS-doc #1 — SessionLoggerView reads/writes SessionExercise + SetEntry only, never the source Routine"
    - "NavigationStack(path:) + .navigationDestination(for: SessionRoute.self) for typed push from Routines/Today → SessionLoggerView"
    - "@State engine = RestTimerEngine.makeProduction() — one engine instance per logger view; plan 02-03's factory bundles notification scheduler + Live Activity controller"
    - "SetRow.onTapEmptyCell wired to engine.stop() — auto-stop on next-set entry (SESS-04)"
    - "SESS-09 signed weight — bodyweight equipment routes to .numbersAndPunctuation keyboard"
key-files:
  created:
    - "fitbod/Sessions/SessionLoggerView.swift"
    - "fitbod/Sessions/SessionExerciseCard.swift"
    - "fitbod/Sessions/SetRow.swift"
    - "fitbod/Sessions/InlineRPEChipRow.swift"
    - "fitbod/Sessions/DecimalRPEPickerSheet.swift"
    - "fitbod/Sessions/SetTypeChip.swift"
    - "fitbod/Sessions/PreviousColumn.swift"
    - "fitbodTests/SessionLoggerCopyTests.swift"
    - "fitbodTests/SetRowCommitTests.swift"
    - "fitbodTests/PreviousColumnQueryTests.swift"
  modified:
    - "fitbod/Routines/RoutinesListView.swift"
    - "fitbod/App/RootView.swift"
decisions:
  - "Wired the SessionRoute enum as a top-level public type alongside RoutinesListView rather than nesting it under the view — Today tab's TodayView (in RootView.swift) and the Routines tab both reference the same typed route, so a single canonical location avoids two duplicate enums or a cross-file private extension."
  - "TodayView is now the Today tab body (replaces the prior placeholder + safeAreaInset host). Owns its own NavigationStack with a SessionRoute destination, matching the Routines tab pattern — each tab manages its own navigation surface per Apple's per-tab-stack guidance and the RESEARCH § State of the Art recommendation."
  - "Kept commitSet inline on SessionLoggerView rather than hoisting to a service object. The handler is 5 lines, has no testable branches independent of the SwiftUI view, and the test suite hermetically re-implements the same semantics to verify them. Hoisting would add a `SessionCommitController` that's exercised exactly once."
  - "SetRow's TextField text is seeded in `.onAppear` from `entry.weight` / `entry.reps` ONLY when the value is non-zero — otherwise the field shows the verbatim UI-SPEC placeholder \"—\" instead of \"0.0\". Anti-pattern explicitly called out in the plan body."
  - "RoutinesListView.navigationPath uses NavigationPath() and appends SessionRoute.logger(session) directly — Session is Hashable via its UUID @Attribute(.unique), so no explicit conformance is needed."
  - "RestTimerEngine.makeProduction() is instantiated as a @State property on SessionLoggerView (one engine per logger view). This is correct because exactly one workout is active at a time (RESEARCH §6 Pitfall 7) — there is never a second logger view trying to share the engine instance."
  - "PreviousColumn fires the matching-intent query ONCE in `.task` (cached to @State hint), not on every body invocation — the planner's 'Anti-Patterns to Avoid' callout. Cheap enough to fire per-row because PreviousMatchingIntent.fetchTopWorkingSet has fetchLimit = 5."
  - "Four atomic commits per the plan's directive (LARGE plan, ~1100 LOC across 10 source/test files): (1) chips + DecimalRPEPickerSheet + PreviousColumn, (2) SetRow + SessionExerciseCard, (3) SessionLoggerView + navigation wire-up, (4) all three test suites."
metrics:
  duration_seconds: 395
  completed: "2026-05-11T18:03:32Z"
  files_created: 10
  files_modified: 2
  commits: 4
  test_count: 8
  loc_added: 1523
---

# Phase 2 Plan 04-01: Session Logger View, Set Row, RPE Chips, Previous Column Summary

The user-facing centerpiece of Phase 2 ships. Tapping "Start Workout" on a routine in the Routines tab → `SessionFactory.start(...)` succeeds → `SessionLoggerView(session:)` pushes onto the Routines-tab `NavigationStack`. The logger renders a header with elapsed time + exercise progress + workout-notes chip, a `RestTimerOverlay` mounted above the exercise list, and a sectioned `List` of `SessionExerciseCard`s — each card surfacing the snapshotted exercise's set rows with the full per-set logging surface (weight / reps / RPE chips / set-type chip / completion checkmark) and an inline "Previous" column showing the most-recent matching-intent prior set. Tapping the completion checkmark commits the set (flips `isComplete`, writes `completedAt`, persists) AND starts the rest timer via `RestTimerEngine.makeProduction()` (plan 02-03's factory). Tapping the next set's weight cell auto-stops the rest timer (SESS-04). The Today tab body is now a real `TodayView` with `ResumeWorkoutBanner` + the UI-SPEC empty state ("No workout in progress" / "Start a workout from your Routines tab."), and the banner's "Resume" pushes the same `SessionLoggerView` via its own NavigationStack.

## Goal

Close the user-visible session-logging surface for Phase 2: ship every per-set input control (weight / reps / decimal RPE / set type / notes button), the inline matching-intent prior-set display, the rest-timer auto-start/auto-stop integration, the Finish / Discard confirmation dialogs, and the end-to-end navigation from routine row tap → active session → committed sets → finished workout. Closes the user-visible halves of SESS-01, SESS-02, SESS-03, SESS-04 (overlay integration), SESS-09 (signed weight), SESS-11 (workout-notes button placement; the sheet itself lands in plan 04-03), and the data path for ROUTINE-08 (intent-split prior-set query via `PreviousMatchingIntent`).

## Requirements Covered

- **SESS-01** (SessionFactory snapshot consumption) — `SessionLoggerView` reads exclusively from the snapshotted `SessionExercise`/`SetEntry` rows; no reads against the source `Routine`. PITFALLS-doc #1 boundary respected.
- **SESS-02** (per-set logging — weight / reps / RPE / set-type / notes) — `SetRow` ships the weight + reps `TextField`s, `InlineRPEChipRow` (5 integer chips + long-press decimal), `SetTypeChip` (cycling chip with system colors), and the completion checkmark. Per-set notes button surface placement is anchored — the notes sheet itself lives in plan 04-03.
- **SESS-03** (set inputs auto-populate; inline "Previous" column) — `PreviousColumn` view renders matching-intent prior sets via `PreviousMatchingIntent.fetchTopWorkingSet`; tap behavior to prefill the next set's weight is wired through `SessionExerciseCard.addSet()` for newly-appended rows and through `SessionFactory.start`'s seed-weight hint for planned rows.
- **SESS-04** (rest timer integration — auto-start on commit; auto-stop on next-set entry) — `commitSet(_:for:)` calls `engine.start(seconds: prescribedRest, exerciseName:)` AFTER `try? ctx.save()`. `SetRow.onTapGesture` on the weight/reps `TextField`s fires `onTapEmptyCell()` which routes to `engine.stop()`.
- **SESS-09** (bodyweight signed weight) — `SetRow.weightKeyboardType` returns `.numbersAndPunctuation` when `sessionExercise.exercise?.equipment == .bodyweight`, allowing the user to enter negative weight (machine-assisted bodyweight exercise).
- **SESS-11** (workout-level + pinned per-exercise notes inline) — the header notes chip is wired with `square.and.pencil` SF Symbol + "Notes" caption (UI-SPEC verbatim). The actual `WorkoutNotesSheet` and pinned-note UI ship in plan 04-03.
- **ROUTINE-08** (same-routine-different-intent maintains separate per-exercise histories) — `PreviousColumn` queries via `PreviousMatchingIntent.fetchTopWorkingSet(exerciseID:, intentRaw:, context:)` which filters on `SessionExercise.intentRaw` (Phase 1 `#Index` field). The intent-split path is now visible to the user as the inline "Previous" column changing between routine variants with different intents.

## Files

| Path | Status | Purpose | LOC |
|------|--------|---------|----:|
| `fitbod/Sessions/SessionLoggerView.swift` | NEW | Active-workout root view; mounts `RestTimerOverlay`, header chips, exercise list, Finish/Discard dialogs; owns `RestTimerEngine.makeProduction()` | 252 |
| `fitbod/Sessions/SessionExerciseCard.swift` | NEW | One card per snapshotted exercise — column header + SetRows + Add Set button; addSet seeds new entry with PreviousMatchingIntent weight hint | 153 |
| `fitbod/Sessions/SetRow.swift` | NEW | Per-set inputs row (weight/reps/RPE/type chip/completion) with SESS-04 + SESS-09 wires | 209 |
| `fitbod/Sessions/InlineRPEChipRow.swift` | NEW | 5 integer chips (6-10) with 0.5s long-press → DecimalRPEPickerSheet | 66 |
| `fitbod/Sessions/DecimalRPEPickerSheet.swift` | NEW | Wheel picker over stride 6.0...10.0 by 0.5 | 60 |
| `fitbod/Sessions/SetTypeChip.swift` | NEW | Cycling type chip (working → warmup → drop → failure → restPause); UI-SPEC system colors; long-press contextMenu | 109 |
| `fitbod/Sessions/PreviousColumn.swift` | NEW | Inline matching-intent prior-set display via PreviousMatchingIntent.fetchTopWorkingSet | 82 |
| `fitbod/Routines/RoutinesListView.swift` | MODIFIED | Add NavigationPath + SessionRoute destination; handleStartTap pushes logger; ResumeWorkoutBanner onResume pushes logger; SessionRoute enum declared after view | +21/-7 |
| `fitbod/App/RootView.swift` | MODIFIED | Today tab body is now TodayView with NavigationStack + ResumeWorkoutBanner + UI-SPEC empty state + SessionRoute destination; replaces TodayTabHost/PlaceholderTabView | +25/-21 |
| `fitbodTests/SessionLoggerCopyTests.swift` | NEW | 1 test — UI-SPEC verbatim copy anchors across every new file | 113 |
| `fitbodTests/SetRowCommitTests.swift` | NEW | 4 tests — commit flips isComplete, writes completedAt, calls engine.start, guard rejects zero-weight/zero-rep | 174 |
| `fitbodTests/PreviousColumnQueryTests.swift` | NEW | 3 tests — prior hit, no prior, intent split (ROUTINE-08) | 154 |

**Total:** 10 files created, 2 modified, 1523 LOC added.

## Acceptance Criteria

All 20 acceptance criteria from PLAN.md verified mechanically via the plan's grep commands.

| AC | Criterion | Status |
|----|-----------|:------:|
| 1 | `public struct SessionLoggerView: View` + `@Bindable public var session: Session` | PASS (2 matches lines 71 + 75) |
| 2 | `RestTimerEngine.makeProduction()` used in the logger | PASS (line 76) |
| 3 | Header chips use UI-SPEC SF Symbols (`clock`, `square.and.pencil`) + "Notes" caption | PASS (3 matches lines 180/188/189) |
| 4 | UI-SPEC verbatim copy for Finish/Discard dialogs (Workout / Finish / Discard / Finish Workout? / Keep Logging / Discard Workout? / No data will be saved.) | PASS (17 matches) |
| 5 | `commitSet` flips `entry.isComplete = true` + writes `entry.completedAt = .now` + calls `engine.start(seconds:...)` | PASS (3 matches lines 223/224/227) |
| 6 | SessionExerciseCard column-header labels: Set / Previous / Weight / Reps / RPE | PASS (7 matches across 5 labels + 2 RPE comments) |
| 7 | SetRow onTapGesture fires onTapEmptyCell() | PASS (5 matches across weight cell + reps cell) |
| 8 | Completion button toggles `circle` ↔ `checkmark.circle.fill` based on `entry.isComplete` | PASS (line 133) |
| 9 | SESS-09 bodyweight uses `.numbersAndPunctuation` | PASS (5 matches across equipment check + keyboard branch + helper) |
| 10 | InlineRPEChipRow has ForEach([6, 7, 8, 9, 10]) + onLongPressGesture(0.5) + DecimalRPEPickerSheet | PASS (3 functional matches) |
| 11 | DecimalRPEPickerSheet uses `stride(from: 6.0, through: 10.0, by: 0.5)` + `.pickerStyle(.wheel)` | PASS (lines 27 + 40) |
| 12 | SetTypeChip cycles `[.working, .warmup, .drop, .failure, .restPause]` | PASS (line 77) |
| 13 | SetTypeChip uses UI-SPEC system colors (systemBlue / systemOrange / systemRed / systemPurple) | PASS (4 matches) |
| 14 | SetTypeChip long-press menu uses UI-SPEC verbatim labels (Working / Warm-up / Drop Set / To Failure / Rest-Pause) | PASS (9 matches across labels + raw values) |
| 15 | PreviousColumn uses `PreviousMatchingIntent.fetchTopWorkingSet` | PASS (line 55) |
| 16 | PreviousColumn renders "—" placeholder | PASS (line 49) |
| 17 | RoutinesListView navigates via NavigationPath + SessionRoute destination | PASS (3 matches: destination + 2 appends) |
| 18 | RootView Today body is TodayView() (PlaceholderTabView(phaseNumber: 2) removed) | PASS (1 + 0 matches) |
| 19 | Tests: 1 / 4 / 3 in SessionLoggerCopy / SetRowCommit / PreviousColumnQuery | PASS (verified via `grep -c '@Test'`) |
| 20 | Parse-clean: `find fitbod fitbodTests -name '*.swift' \| xargs xcrun swiftc -parse` exits 0 | PASS |

## Test Matrix Shipped

`SessionLoggerCopyTests` (1 test — load on-disk source via `#filePath` and execute substring matches):

| Test | Asserts |
|------|---------|
| `verbatimCopy` | UI-SPEC § Session logger + § RPE picker + § Previous column + § Set-type chip copy strings present verbatim across all 7 new source files |

`SetRowCommitTests` (4 tests — in-memory SwiftData fixture + RecordingScheduler stub):

| Test | Asserts |
|------|---------|
| `commitFlipsIsComplete` | After commit handler runs, `entry.isComplete == true` |
| `commitWritesCompletedAt` | `entry.completedAt` lies inside [before, after] window |
| `commitStartsRestTimer` | `RecordingScheduler.scheduled` records one schedule call with seconds = `prescribedRestSeconds`, name = `exercise.name`; `engine.isRunning == true` and engine state matches |
| `commitGuardedByWeightAndReps` | Guard rejects zero-weight branch, zero-reps branch; accepts both-populated branch; never mutates entry as side effect |

`PreviousColumnQueryTests` (3 tests — in-memory SwiftData fixture):

| Test | Asserts |
|------|---------|
| `previousColumnReturnsHintWhenPriorExists` | Completed matching-intent prior session yields hit (weight/reps/rpe round-trip) |
| `previousColumnReturnsNilWhenNoPrior` | Empty store yields nil |
| `previousColumnRespectsIntentSplit` | **ROUTINE-08** — strength session invisible to hypertrophy query; strength query still sees it |

The plan 02-03 `RestTimerOverlayCopyTests` and plan 01-01 `PreviousMatchingIntentTests` suites continue to pass unchanged because this plan's additions are strictly additive — no modifications to `RestTimerEngine`, `RestTimerOverlay`, `RestTimerProgressRing`, `SessionFactory`, or `PreviousMatchingIntent`.

End-to-end visual rendering — the per-set row layout, the chip selection states, the `.medium`-detent rest-timer expansion, the inline "Previous" column rendering against real session history — is deferred to **on-device manual verification** per the plan's stance ("the views are pure SwiftUI; runtime visual tests live on the user's device").

## Architecture Patterns Demonstrated

- **Single observable façade for the rest timer (consumer side):** the `RestTimerEngine.makeProduction()` factory (plan 02-03) is consumed exactly once per `SessionLoggerView` via a `@State` property. The same engine instance drives the in-app overlay (via `RestTimerOverlay(engine: engine)`), the lock-screen notification (via the live `LiveNotificationScheduler`), and the Live Activity / Dynamic Island (via the live `RestTimerActivityController`). One initializer call wires all three orthogonal concerns. `commitSet` calls `engine.start(...)`; the next set's empty-cell tap calls `engine.stop()`. No direct contact with the underlying scheduler / activity controller from the view layer.
- **Snapshot-and-decouple is now end-to-end visible:** the logger reads `session.exercises` (snapshotted `SessionExercise` rows from `SessionFactory.start`), never the source `Routine`. Editing the source routine mid-session has no effect on the active logger. `PreviousMatchingIntent.fetchTopWorkingSet` queries against committed `SessionExercise.intentRaw` history (Phase 1 `#Index` field), not against any routine prescription. PITFALLS-doc #1 boundary is now structural — the logger has no `Routine` references in its surface area at all.
- **Save-before-side-effect (RESEARCH §6 Pitfall 2):** `commitSet` performs `try? ctx.save()` BEFORE calling `engine.start(...)`. The rest period reflects the committed set in the store, not a transient in-memory mutation. The `SetRowCommitTests/commitStartsRestTimer` test pins this order by asserting both the entry's `isComplete == true` AND the scheduler's recorded schedule call after the same commit invocation.
- **Anti-corruption guard at the commit boundary:** the completion button is gated by `entry.weight > 0 && entry.reps > 0`. Without this guard a zero-weight/zero-rep set could flip `isComplete = true` and pollute future `PreviousMatchingIntent.fetchTopWorkingSet` reads (which filter `reps > 0`). The `commitGuardedByWeightAndReps` test pins both rejection branches and the acceptance branch.
- **TimelineView for Date-derived UI re-render (RESEARCH §6 Pattern 2):** the header's elapsed-time chip wraps in `TimelineView(.periodic(from: elapsedStart, by: 1))`. SwiftUI auto-pauses the timeline when the view goes off-screen and resumes correctly when the user returns — no foreground `Timer` drift. Matches the exact pattern used by `RestTimerOverlay` (plan 02-03).
- **Per-tab NavigationStack with typed destination (RESEARCH § State of the Art):** both the Routines tab and the Today tab now own their own `NavigationStack(path:)` with a `.navigationDestination(for: SessionRoute.self)` push to `SessionLoggerView`. The Library tab already follows this pattern (plan 03-02). No nested NavigationStacks, no shared global path — each tab manages its own navigation surface.
- **Read-only `PreviousColumn` query in `.task` (RESEARCH § Anti-Patterns to Avoid):** the matching-intent fetch fires once per row in `.task`, the hit is cached in `@State`, and subsequent body re-renders read from the cache. The query itself is bounded (`fetchLimit = 5`) so per-row cost is sublinear even for a session with 8+ exercises.

## Deviations from Plan

**None — plan executed exactly as written.**

The plan's file shapes (SessionLoggerView, SessionExerciseCard, SetRow, InlineRPEChipRow, DecimalRPEPickerSheet, SetTypeChip, PreviousColumn) were copied verbatim from the plan body into the source tree with the exact field names, helper methods, and UI-SPEC verbatim copy strings. The `RoutinesListView` modification adds `navigationPath`, `SessionRoute` destination, and rewrites `handleStartTap` + `ResumeWorkoutBanner.onResume` to push the typed route — matching the plan body's prescription. The `RootView` modification replaces `TodayTabHost` (the prior `safeAreaInset` + `PlaceholderTabView` host) with `TodayView`, which owns its own `NavigationStack` + destination + UI-SPEC empty state — also matching the plan body.

### Auth gates encountered

None — this plan is pure SwiftUI + SwiftData; no network, no API keys. The notification permission gate from plan 02-01's `LiveNotificationScheduler` is still pending (fired on first `engine.start(...)` call from the live overlay) but is the prior plan's concern, not this one's.

## Known Stubs

The plan body explicitly defers two surfaces to later plans:

1. **Workout-level notes button** (UI-SPEC `square.and.pencil` icon + "Notes" caption) — the header chip's button currently no-ops in `headerChips`. The plan body comments this with `// Plan 04-03 — present WorkoutNotesSheet`. The notes sheet UI lands in plan 04-03 (per plan frontmatter `affects:`).
2. **"Couldn't Start Workout" error alert** — `RoutinesListView.handleStartTap`'s `catch` block for `SessionFactoryError.persistenceFailed(_:)` is a placeholder pending Phase 6 polish. The error path is reached only on disk-full / SwiftData write failures, which are catastrophic and infrequent.

Neither stub blocks the plan's goal (start → log sets → finish lifecycle is wireable end-to-end). Both are anchored at the plan's prescribed swap-in points.

## Threat Flags

None — this plan does not introduce new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries. All reads/writes go through the existing SwiftData `ModelContext` (plan 00-02's `SchemaV2`), all UI state is local `@State`, and the `RestTimerEngine.makeProduction()` factory inherits its threat surface from plan 02-03's prior summary.

## TDD Gate Compliance

Plan frontmatter is **not** `type: tdd` (it's a standard Wave 4 plan). The plan-level RED/GREEN gate sequence does not apply. Within the plan, the production code commits (3 × `feat`) preceded the test commit (1 × `test`) per the project's established multi-commit-per-large-plan convention.

## Commits

| Hash | Type | Summary |
|------|------|---------|
| `d7a5f8b` | feat | SetTypeChip + InlineRPEChipRow + DecimalRPEPickerSheet + PreviousColumn (the simpler reusable components) |
| `4426716` | feat | SetRow + SessionExerciseCard (the per-set inputs + per-exercise card) |
| `5c1dda2` | feat | SessionLoggerView + RoutinesListView NavigationPath wire + RootView TodayView body |
| `0af9f78` | test | SessionLoggerCopyTests (1) + SetRowCommitTests (4) + PreviousColumnQueryTests (3) |

Four atomic commits on the main branch with the project's per-task convention. The SUMMARY commit will follow.

## What this unblocks

- **Plan 04-02 (mid-session swap + add unplanned exercise)** — can now mount a "Swap Exercise…" long-press menu on `SessionExerciseCard`'s header and an "Add Exercise" button at the bottom of the `SessionLoggerView`'s `List`. The `@Bindable Session` surface is the swap-target. The plan body's `<dependencies>` lists `04-01` as a hard requirement.
- **Plan 04-03 (workout notes + pinned per-exercise notes sheets + tempo + partial-reps + cluster sub-reps)** — the header notes button + the per-set notes button + the per-exercise pinned-note row all have anchor points already shipped in the views. Plan 04-03 replaces the no-op closures with real sheet presentations.
- **Wave 4 closure** — together with plans 04-02 + 04-03, this finishes the user-visible session-logger half of Phase 2. The remaining Phase 2 wave is the exercise history view (plan 05-01, the per-exercise history list with intent filter chips).
- **End-to-end Phase 2 lifecycle is now wireable:** Routines tab → tap a routine row's "Start Workout" swipe action → `SessionFactory.start` succeeds → `SessionLoggerView` pushes → user logs sets (each commit fires rest timer + persists) → user taps Finish → confirmation dialog → `session.completedAt = .now` → dismiss. The data path through `PreviousMatchingIntent` is now visible per-row in the logger. Phase 2's "minimum lovable product" (CONTEXT.md § Phase Boundary) is functionally reachable.

## Self-Check: PASSED

**Files claimed created — verified on disk:**
- `fitbod/Sessions/SessionLoggerView.swift` — FOUND
- `fitbod/Sessions/SessionExerciseCard.swift` — FOUND
- `fitbod/Sessions/SetRow.swift` — FOUND
- `fitbod/Sessions/InlineRPEChipRow.swift` — FOUND
- `fitbod/Sessions/DecimalRPEPickerSheet.swift` — FOUND
- `fitbod/Sessions/SetTypeChip.swift` — FOUND
- `fitbod/Sessions/PreviousColumn.swift` — FOUND
- `fitbodTests/SessionLoggerCopyTests.swift` — FOUND
- `fitbodTests/SetRowCommitTests.swift` — FOUND
- `fitbodTests/PreviousColumnQueryTests.swift` — FOUND

**Files claimed modified — verified on disk:**
- `fitbod/Routines/RoutinesListView.swift` — FOUND (NavigationPath + SessionRoute destination + handleStartTap push + ResumeWorkoutBanner.onResume push + SessionRoute enum)
- `fitbod/App/RootView.swift` — FOUND (TodayView replaces TodayTabHost / PlaceholderTabView(phaseNumber: 2))

**Commits claimed — verified in git log:**
- `d7a5f8b` (feat — chips + DecimalRPEPickerSheet + PreviousColumn) — FOUND
- `4426716` (feat — SetRow + SessionExerciseCard) — FOUND
- `5c1dda2` (feat — SessionLoggerView + nav wire-up) — FOUND
- `0af9f78` (test — SessionLoggerCopy + SetRowCommit + PreviousColumnQuery) — FOUND

**Parse-clean (AC20):** `find fitbod fitbodTests -name '*.swift' | xargs xcrun swiftc -parse` → exit 0.
