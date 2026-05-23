---
phase: 06
plan: 02
subsystem: progress-views
tags: ["pr-detection", "PROG-05", "PROG-08"]
requires:
  - "06-01 OneRepMax kernel (for .e1RM PR comparator)"
  - "SchemaV6 SetEntry (weight, reps, rpe, setTypeRaw, isWarmup, isComplete, completedAt, sessionExercise)"
  - "SchemaV6 Session.intentRaw (Phase 3.1 PIVOT-02 — session-level intent)"
provides:
  - "fitbod.PRDetector pure-function kernel (buildTable, check, isWorkingSet)"
  - "fitbod.PRTable + PRRecord Sendable value types"
  - "fitbod.PRKind + RepBucket enums"
  - "#Index<SetEntry>([\\.completedAt]) additive metadata"
  - "fitbodTests.Phase6.SessionFixtures + PRFixtures (shared Phase 6 fixtures)"
  - "fitbodTests.Phase6.SchemaNamesRegressionTest canary"
affects:
  - "Wave 3 ExercisePRsView (will consume PRTable.allRecords + record(...))"
  - "Wave 4 InSessionPRBanner (will consume buildTable + check(set:against:))"
  - "Every downstream Phase 6 test plan (06-04..06-10) reuses SessionFixtures + PRFixtures"
tech-stack:
  added: []
  patterns:
    - "PRDetector + facade pattern matches Phase 5 OneRepMaxEstimator / FatigueModel — pure-function namespace, no @MainActor on the kernel"
    - "#Index non-persistent metadata addition (no SchemaV7 bump) — RESEARCH §'#Index addition'"
    - "Word-boundary identifier match in canary (prevents `setKind` matching `SupersetKind`)"
key-files:
  created:
    - "fitbod/Models/Enums/PRKind.swift"
    - "fitbod/Progress/PRDetector.swift"
    - "fitbodTests/Phase6/Fixtures/SessionFixtures.swift"
    - "fitbodTests/Phase6/Fixtures/PRFixtures.swift"
    - "fitbodTests/Phase6/Support/SchemaNamesRegressionTest.swift"
    - "fitbodTests/Phase6/PRDetectorTests.swift"
  modified:
    - "fitbod/Models/SetEntry.swift (added #Index<SetEntry>([\\.completedAt]))"
decisions:
  - "PRTable storage is a `[Key: PRRecord]` dictionary keyed by composite `(exerciseID, intent, kind, bucket)` — flat hash lookup gives O(1) check() per kind without nested dictionary walks. Total slot count stays well under 1000 even for years of single-user data."
  - "PRDetector.check uses strict-> comparator (tie is NOT a new PR) per CONTEXT D-16 — matches the intuitive lifter expectation that re-hitting your old PR doesn't earn a fresh banner."
  - "Intent is read via `set.sessionExercise?.session?.intentRaw` (Phase 3.1 PIVOT-02 session-level location) — not SessionExercise (which Phase 3.1 stripped)."
  - "Reused existing fitbodTests/TestSupport/InMemoryContainer.makeCurrent() instead of creating a Phase6/Support/InMemoryContainer duplicate (plan permitted both)."
metrics:
  duration: "~25 min"
  completed: "2026-05-23"
  files_created: 6
  files_modified: 1
  tasks_completed: 4
---

# Phase 6 Plan 02: PRDetector + Index + Phase 6 Fixtures Summary

PR detection kernel + shared Phase 6 test fixtures. Two consumers: `ExercisePRsView` (Wave 3 list) calls `buildTable` once at view-appear; `InSessionPRBanner` (Wave 4 banner) calls `buildTable` once at `SessionFactory.start` and `check(set:against:)` on every committed set, mutating the table in place so multiple PRs in one set stack on one banner.

## What shipped

### `fitbod/Models/Enums/PRKind.swift`

- `PRKind`: `weight`, `reps`, `volume`, `e1RM = "e1rm"` (canonical UI order)
- `RepBucket`: `strength = "1-6"`, `hypertrophy = "7-10"`, `highRep = "11+"`
- `RepBucket.bucket(for:)` helper returns nil for non-positive reps

### `fitbod/Progress/PRDetector.swift`

```swift
public struct PRRecord: Sendable, Equatable {
    public let weight: Double
    public let reps: Int
    public let rpe: Double?
    public let setEntryID: UUID
    public let sessionStartedAt: Date
}

public struct PRTable: Sendable {
    public func record(exerciseID:intent:kind:bucket:) -> PRRecord?
    public func allRecords(forExerciseID:intent:) -> [(kind, bucket, record)]
}

public enum PRDetector {
    public static func buildTable(from sets: [SetEntry]) -> PRTable
    public static func check(set: SetEntry, against table: inout PRTable) -> Set<PRKind>
    @inlinable public static func isWorkingSet(_ set: SetEntry) -> Bool
}
```

- Partitions by `(exerciseID, intent, PRKind, RepBucket)` per CONTEXT D-10 + D-11.
- `check` mutates the table in place via `inout PRTable` so subsequent sets in the same session see the new records (D-14 + UI-SPEC In-session PR banner flow step 5).
- Strict-> comparator (tie is NOT a new PR) per D-16.
- e1RM PR suppressed for `.highRep` bucket (PROG-02 + D-04).
- `wasManualOverride` does NOT suppress detection (CONTEXT D-17) — honest higher-weight set is a real PR regardless of entry mode.

### `fitbod/Models/SetEntry.swift` (modified)

Added `#Index<SetEntry>([\.completedAt])` as the first declaration in the class body. Non-persistent metadata per RESEARCH §"#Index addition" — no SchemaV7 bump.

### `fitbodTests/Phase6/Fixtures/SessionFixtures.swift`

```swift
@MainActor enum SessionFixtures {
    @discardableResult
    static func makeCompletedSession(
        ctx: ModelContext,
        startedAt: Date,
        exercise: Exercise,
        intentRaw: String,
        sets: [(weight: Double, reps: Int, rpe: Double?,
                isWarmup: Bool, isComplete: Bool)]
    ) throws -> Session
}
```

Lifted from `PreviousMatchingIntentTests.makeCompletedSession` verbatim (Phase 2 pattern). Reused by every downstream Phase 6 test plan.

### `fitbodTests/Phase6/Fixtures/PRFixtures.swift`

```swift
@MainActor enum PRFixtures {
    static func seedKnownPRHistory(ctx: ModelContext) throws -> SeedResult
}
```

Deterministic 4-session seed: Bench (strength W0 + W1; hypertrophy W2), Squat (strength W0). Exposes `expected: [(UUID, Intent, PRKind, RepBucket, Double)]` with hand-computed PR values for assertion.

### `fitbodTests/Phase6/Support/SchemaNamesRegressionTest.swift`

Two-layer canary:

1. **Compile-time KeyPath block** — `PartialKeyPath<SetEntry>`, `<Session>`, `<SessionExercise>` arrays referencing every real field this phase reads. File refuses to compile if SwiftData renames a field.
2. **Build-time forbidden-token scan** — walks `fitbod/Models/` via `FileManager.enumerator`, checks each `*.swift` file for `actualWeight` / `actualReps` / `actualRPE` / `performedAt` / `setKind` with **word-boundary identifier matching** (prevents `setKind` matching `SupersetKind`).

### `fitbodTests/Phase6/PRDetectorTests.swift`

6 `@Test` functions, all GREEN:

| Test | Coverage |
| ---- | -------- |
| `buildTableMatchesExpectedPRs` | Every expected slot in `PRFixtures.expected` resolves to the hand-computed value |
| `singleSetSingleKindWins` | A set that only beats weight returns exactly `{.weight}` |
| `singleSetStacksMultipleKinds` | A set that beats weight + reps + volume + e1RM returns all four (D-16) |
| `tableMutatesInPlace` | Calling check twice with the same set returns empty the second time |
| `tiesAreNotPRs` | A tie returns empty (strict-> rule) |
| `highRepSuppressesE1RM` | A 12-rep set never returns `.e1RM` even when topping weight/reps/volume |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `Foundation.Process` is macOS-only**

- **Found during:** Task 2 test compile
- **Issue:** Plan specified using `Process` to spawn `/usr/bin/env grep` for the forbidden-token scan. `Foundation.Process` is unavailable on the iOS Simulator target where tests run; build failed with `cannot find 'Process' in scope` errors.
- **Fix:** Replaced subprocess `grep` with an in-process `FileManager.enumerator` walk + `String.contains` scan over `fitbod/Models/`. Same diagnostic output, no external process dependency.
- **Files modified:** `fitbodTests/Phase6/Support/SchemaNamesRegressionTest.swift`
- **Commit:** `8383683`

**2. [Rule 1 - Bug] Forbidden-token substring match false-positives `SupersetKind`**

- **Found during:** First green run of `noStaleCONTEXTeraFieldNames`
- **Issue:** Plain `String.contains("setKind")` matched `SupersetKind` (a legitimate Phase 1 enum in `SupersetGroup.swift`) — falsely flagged a violation.
- **Fix:** Added a `containsAsIdentifier(_:in:)` helper that requires the match neighbors not be Swift identifier-continuation characters (alphanumeric or underscore). Prevents the false positive without weakening the canary.
- **Files modified:** `fitbodTests/Phase6/Support/SchemaNamesRegressionTest.swift`
- **Commit:** `8383683`

**3. [Rule 1 - Bug] String interpolation escape error**

- **Found during:** First test compile of `SchemaNamesRegressionTest`
- **Issue:** Used `\(violations.map(\.token).joined(separator: \", \"))` — escaped quotes inside a string interpolation are not legal Swift.
- **Fix:** Hoisted the join into a `let joined = ...` binding outside the interpolation.
- **Files modified:** `fitbodTests/Phase6/Support/SchemaNamesRegressionTest.swift`
- **Commit:** `8383683`

## Auth Gates

None.

## Threat Flags

None — pure-function kernel + additive non-persistent `#Index`. No schema migration, no network surface, no auth path.

## Commits

| Hash | Type | Description |
| ---- | ---- | ----------- |
| `e4e1e95` | `feat(06-02)` | PRDetector kernel + PRKind/RepBucket enums + SetEntry #Index |
| `8383683` | `test(06-02)` | PRDetector tests + Phase 6 fixtures + schema-names canary |

## Self-Check: PASSED

- `fitbod/Models/Enums/PRKind.swift` — FOUND
- `fitbod/Progress/PRDetector.swift` — FOUND
- `fitbod/Models/SetEntry.swift` `#Index<SetEntry>([\.completedAt])` — FOUND
- `fitbodTests/Phase6/Fixtures/SessionFixtures.swift` — FOUND
- `fitbodTests/Phase6/Fixtures/PRFixtures.swift` — FOUND
- `fitbodTests/Phase6/Support/SchemaNamesRegressionTest.swift` — FOUND
- `fitbodTests/Phase6/PRDetectorTests.swift` — FOUND
- Commits `e4e1e95` + `8383683` — FOUND
- `xcodebuild test -only-testing:fitbodTests/PRDetectorTests -only-testing:fitbodTests/SchemaNamesRegressionTest` — all PASS
- No SchemaV7 added (verified)
