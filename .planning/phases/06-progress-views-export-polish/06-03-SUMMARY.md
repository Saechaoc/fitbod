---
phase: 06
plan: 03
subsystem: progress-views
tags: ["tonnage", "weekly-bar", "muscle-provider", "PROG-04"]
requires:
  - "SchemaV6 SetEntry (weight, reps, setTypeRaw, isWarmup, isComplete, completedAt, sessionExercise)"
  - "SchemaV6 SessionExercise + Exercise + ExerciseMuscleStimulus + MuscleGroup"
provides:
  - "fitbod.WeeklyTonnageAggregator pure-function aggregator"
  - "fitbod.WeeklyTonnageBar + MuscleSlice Sendable + Equatable value types"
  - "fitbod.MuscleVolumeProvider protocol + UnweightedMuscleVolumeProvider default"
  - "fitbod.TonnageSliceMode + TimeRangeChoice runtime-only enums"
affects:
  - "Phase 6 Wave 2 WeeklyTonnageView (will consume aggregator + filter enums)"
  - "Phase 5 future StimulusWeightedMuscleVolumeProvider (drops in via DI without touching aggregator or view)"
tech-stack:
  added: []
  patterns:
    - "Protocol-based DI seam — aggregator depends on protocol; provider is injected at call site"
    - "ISO-8601 calendar value owned by the function (not Calendar.current.firstWeekday mutation)"
    - "Sendable + Equatable output types — Swift Testing equality + off-main-actor invocation"
key-files:
  created:
    - "fitbod/Progress/WeeklyTonnageAggregator.swift"
    - "fitbod/Progress/MuscleVolumeProvider.swift"
    - "fitbod/Models/Enums/TonnageSliceMode.swift"
    - "fitbodTests/Phase6/WeeklyTonnageAggregatorTests.swift"
  modified: []
decisions:
  - "Filter sets via defense-in-depth: setType==.working && !isWarmup && isComplete && weight>0 && reps>0. Both isWarmup AND setTypeRaw checked because PROJECT.md SetEntry.swift comments call out they are intentionally not redundant — hot-path flag vs full taxonomy. Either alone would let one bad row through."
  - "Aggregator owns its own ISO-8601 Calendar value rather than mutating Calendar.current — guarantees deterministic output regardless of host calendar state and aligns with RESEARCH Don't-Hand-Roll guidance."
  - "UnweightedMuscleVolumeProvider attributes full set tonnage to PRIMARY-role stimuli only — Phase 5 FatigueModel slices on the same string-valued role field, so the muscle attribution semantics stay consistent across surfaces."
metrics:
  duration: "~15 min"
  completed: "2026-05-23"
  files_created: 4
  files_modified: 0
  tasks_completed: 3
---

# Phase 6 Plan 03: Weekly Tonnage Aggregator Summary

Pure-function aggregator that turns a flat `[SetEntry]` into a sorted array of `WeeklyTonnageBar`s, with optional per-muscle stack breakdown when a muscle filter is active. The `MuscleVolumeProvider` protocol seam means Phase 5+ can swap in stimulus-weighted attribution without touching the aggregator or Wave 2's view.

## What shipped

### `fitbod/Progress/WeeklyTonnageAggregator.swift`

```swift
public enum WeeklyTonnageAggregator {
    public static func aggregate(
        sets: [SetEntry],
        weekStartsMonday: Bool,
        selectedMuscleIDs: Set<UUID>,
        provider: MuscleVolumeProvider
    ) -> [WeeklyTonnageBar]
}

public struct WeeklyTonnageBar: Sendable, Equatable {
    public let weekStart: Date
    public let totalTonnage: Double
    public let muscleBreakdown: [MuscleSlice]?
}

public struct MuscleSlice: Sendable, Equatable {
    public let muscleID: UUID
    public let muscleName: String
    public let tonnage: Double
}
```

Algorithm:

1. Filter input to working sets: `setType == .working && !isWarmup && isComplete && weight > 0 && reps > 0`.
2. Bucket by ISO-8601 week start with `firstWeekday = weekStartsMonday ? 2 : 1`.
3. Per-week `totalTonnage = Σ (weight × reps)`.
4. If `selectedMuscleIDs.isEmpty` → `muscleBreakdown = nil`. Else: walk `provider.contributions(for:exercise:)`, filter to selected IDs, sum by `muscleID`, sort by tonnage desc.
5. Return bars sorted by `weekStart` asc.

### `fitbod/Progress/MuscleVolumeProvider.swift`

```swift
public protocol MuscleVolumeProvider: Sendable {
    func contributions(
        for set: SetEntry,
        exercise: Exercise
    ) -> [(muscleID: UUID, muscleName: String, tonnage: Double)]
}

public struct UnweightedMuscleVolumeProvider: MuscleVolumeProvider {
    public init() {}
    // Walks exercise.muscleStimuli; primary-role gets full tonnage;
    // secondary gets zero. Matches CONTEXT D-20 fallback semantics.
}
```

### `fitbod/Models/Enums/TonnageSliceMode.swift`

```swift
public enum TonnageSliceMode: String, CaseIterable, Sendable {
    case timeRange; case blockPhase; case muscle
}
public enum TimeRangeChoice: String, CaseIterable, Sendable {
    case last8wk = "8wk"
    case last26wk = "26wk"
    case allTime = "all"
}
```

Runtime-only — never persisted on a `@Model`. Wave 2 SwiftUI views will hold these in `@State`.

### `fitbodTests/Phase6/WeeklyTonnageAggregatorTests.swift`

6 `@Test` functions, all GREEN:

| Test | Coverage |
| ---- | -------- |
| `workingSetTonnageOnly` | Warmup + drop + incomplete + zero-weight sets excluded from total |
| `mondayWeekStart` | Sunday + Monday cross ISO week boundary correctly under `firstWeekday = 2` |
| `emptySelectedMuscles` | `muscleBreakdown == nil` when no muscles selected |
| `selectedMusclesFiltered` | Stub provider drives deterministic slice output filtered to selected IDs |
| `sortedByWeekStartAscending` | Output sorted asc regardless of input order |
| `unweightedProviderUsesPrimaryMusclesOnly` | UnweightedMuscleVolumeProvider attributes only to primary-role stimuli |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] SetEntry relationship name**

- **Found during:** Task 3 test run
- **Issue:** Plan referenced `se.setEntries` for the back-relationship from `SessionExercise` to its `SetEntry`s. The real schema field name is `sets` (verified in `SessionExercise.swift`).
- **Fix:** Updated test fixture to read `se.sets ?? [workingSet]`.
- **Files modified:** `fitbodTests/Phase6/WeeklyTonnageAggregatorTests.swift`
- **Commit:** `de4e1cd`

## Auth Gates

None.

## Threat Flags

None — pure-function aggregator. No network surface, auth path, or schema change.

## Commits

| Hash | Type | Description |
| ---- | ---- | ----------- |
| `5b6aacf` | `feat(06-03)` | WeeklyTonnageAggregator + MuscleVolumeProvider + TonnageSliceMode + TimeRangeChoice |
| `de4e1cd` | `test(06-03)` | WeeklyTonnageAggregatorTests 6 @Test boundary coverage |

## Self-Check: PASSED

- `fitbod/Progress/WeeklyTonnageAggregator.swift` — FOUND
- `fitbod/Progress/MuscleVolumeProvider.swift` — FOUND
- `fitbod/Models/Enums/TonnageSliceMode.swift` — FOUND
- `fitbodTests/Phase6/WeeklyTonnageAggregatorTests.swift` — FOUND
- Commits `5b6aacf` + `de4e1cd` — FOUND
- `xcodebuild build` — BUILD SUCCEEDED
- `xcodebuild test -only-testing:fitbodTests/WeeklyTonnageAggregatorTests` — all 6 PASS
