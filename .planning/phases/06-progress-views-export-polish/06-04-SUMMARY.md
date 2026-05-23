---
phase: 06
plan: 04
subsystem: progress-views
tags: ["session-comparison", "PROG-07"]
requires:
  - "06-01 OneRepMax kernel (top-set tiebreaker per D-05)"
  - "SchemaV6 Session (intentRaw, sourceRoutineID, startedAt, exercises)"
  - "SchemaV6 SessionExercise (exercise, orderIndex, sets)"
  - "Phase 3.1 PIVOT-02 (intent is session-level)"
provides:
  - "fitbod.SessionComparator pure-function-with-one-fetch kernel"
  - "fitbod.SessionComparisonRow + TopSetSummary Sendable + Equatable value types"
affects:
  - "Wave 4 SessionComparisonView (plan 06-07 will consume compare(current:context:))"
  - "Wave 4 CompletedSessionView 'Compare to last week' link"
tech-stack:
  added: []
  patterns:
    - "Split-predicate pattern (Phase 5 FatigueModel — Swift 6 #Predicate type-checker timeouts on multi-hop composite filters)"
    - "Local-let UUID workaround for #Predicate (RESEARCH Pitfall 3)"
    - "Post-fetch Swift sort + walk to recover the multi-property match"
key-files:
  created:
    - "fitbod/Progress/SessionComparator.swift"
    - "fitbodTests/Phase6/SessionComparatorTests.swift"
  modified: []
decisions:
  - "D-22 implemented per RESEARCH correction (per-exercise on triple sourceRoutineID + exerciseID + intent) AND per Phase 3.1 PIVOT-02 (intent reads from Session.intentRaw, not SessionExercise) — the plan's literal D-22 phrasing AND its RESEARCH correction both reference SessionExercise.intentRaw, which no longer exists. We use Session.intentRaw."
  - "Predicate split into a SIMPLE single-hop #Predicate on Session + Swift-side walk of session.exercises. The all-inline composite filter timed out the Swift 6 type-checker (same failure mode Phase 5 FatigueModel hit). The fetchLimit on the Session-side predicate caps work at 50 candidate sessions before the Swift filter — well above any realistic single-user history."
  - "Top working set picker routes through OneRepMax.estimate even though the candidate sort would have to inspect every set anyway — keeping the e1RM call site in one place means future tweaks to the kernel don't require touching the comparator."
metrics:
  duration: "~15 min"
  completed: "2026-05-23"
  files_created: 2
  files_modified: 0
  tasks_completed: 2
---

# Phase 6 Plan 04: SessionComparator Summary

Pure-function-with-one-fetch kernel that powers Wave 4's `SessionComparisonView`. For each exercise in the current session, finds the most recent prior `SessionExercise` matching the `(sourceRoutineID, exerciseID, intent)` triple within a 14-day window and emits a diff row (Δweight, Δreps, Δe1RM).

## What shipped

### `fitbod/Progress/SessionComparator.swift`

```swift
public struct TopSetSummary: Sendable, Equatable { ... }
public struct SessionComparisonRow: Sendable, Equatable { ... }

public enum SessionComparator {
    public static func compare(
        current: Session,
        context: ModelContext,
        windowDays: Int = 14
    ) -> [SessionComparisonRow]

    public static func findPriorMatch(
        current: SessionExercise,
        currentSession: Session,
        context: ModelContext,
        windowDays: Int = 14
    ) -> SessionExercise?
}
```

**Match rule (CORRECTED per RESEARCH + Phase 3.1 PIVOT-02):**

1. `prior.exercise?.id == current.exercise?.id`
2. `prior.session?.intentRaw == current.session?.intentRaw` (Phase 3.1)
3. `prior.session?.sourceRoutineID == current.session?.sourceRoutineID`
4. `currentStart - priorStart ∈ (0, windowDays × 86400)`

**Implementation strategy:** Single-hop `#Predicate` on `Session` (cheap gate) + Swift-side walk of `session.exercises` to apply the per-exercise filter. Phase 5 FatigueModel proved this is the only shape Swift 6's `#Predicate` type-checker tolerates at this composition depth.

**Top-set selection (D-05):** Highest `OneRepMax.estimate`; tiebreaker 1 highest weight; tiebreaker 2 latest `completedAt`. Verified by the `topSetByE1RMNotWeight` test — a 100×5 set (e1RM 112.5) wins over a 105×1 set (e1RM 105.0) even though 105 > 100.

### `fitbodTests/Phase6/SessionComparatorTests.swift`

8 `@Test` functions, all GREEN:

| Test | Coverage |
| ---- | -------- |
| `perExerciseMatchByTriple` | Same routine + exercise + intent within 14 days matches |
| `intentSplitNeverCrosses` | Strength current does not match hypertrophy prior |
| `sourceRoutineIDMatchRequired` | Different routines do not cross |
| `fourteenDayWindowStrict` | 13 days back matches; 15 days back does not |
| `topSetByE1RMNotWeight` | D-05 picks higher e1RM over heavier weight |
| `noPriorMatchEmitsNilRow` | Unique exercise → nil lastWeek + nil deltas |
| `freestandingSessionNullRoutineID` | nil sourceRoutineID → all priors nil |
| `orderIndexPreserved` | Output sort matches current.exercises orderIndex asc |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Swift 6 #Predicate type-checker timeout**

- **Found during:** Task 1 build
- **Issue:** Inline composite `#Predicate` on `SessionExercise` with chained `se.session?.X` traversals timed out the Swift 6 type-checker. Compiler emitted "unable to type-check this expression in reasonable time".
- **Fix:** Split into single-hop `#Predicate` on `Session` (filters `sourceRoutineID`, `intentRaw`, `startedAt` window) + Swift-side walk of `session.exercises` to apply the per-exercise gate. Same algorithm; compiles. Matches Phase 5 FatigueModel pattern from RESEARCH Pitfall #1.
- **Files modified:** `fitbod/Progress/SessionComparator.swift`
- **Commit:** `260946b`

**2. [Rule 1 - Plan reconciliation] Intent location changed in Phase 3.1**

- **Found during:** Reading plan vs codebase
- **Issue:** Plan (and its RESEARCH correction) reference `SessionExercise.intentRaw`. Phase 3.1 PIVOT-02 moved intent to `Session.intentRaw`; the SessionExercise field no longer exists.
- **Fix:** Predicate reads `sess.intentRaw` on the parent Session; comparator passes `currentSession.intentRaw` rather than the SessionExercise's (non-existent) field.
- **Files modified:** `fitbod/Progress/SessionComparator.swift`
- **Commit:** `260946b`

## Auth Gates

None.

## Threat Flags

None — pure-function kernel reading existing schema.

## Commits

| Hash | Type | Description |
| ---- | ---- | ----------- |
| `260946b` | `feat(06-04)` | SessionComparator + Sendable value types |
| `67ccbed` | `test(06-04)` | SessionComparatorTests 8 @Test boundary coverage |

## Self-Check: PASSED

- `fitbod/Progress/SessionComparator.swift` — FOUND
- `fitbodTests/Phase6/SessionComparatorTests.swift` — FOUND
- Commits `260946b` + `67ccbed` — FOUND
- `xcodebuild build` — BUILD SUCCEEDED
- `xcodebuild test -only-testing:fitbodTests/SessionComparatorTests` — all 8 PASS
