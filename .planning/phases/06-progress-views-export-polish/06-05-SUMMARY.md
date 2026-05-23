---
phase: 06
plan: 05
subsystem: progress-views
tags: ["chart", "per-exercise", "intent-split", "PROG-01", "PROG-03"]
requires:
  - "06-01 OneRepMax kernel"
  - "06-02 #Index<SetEntry>([\\.completedAt])"
  - "SchemaV6 SessionExercise + SetEntry (Phase 3.1 session-level intent reach)"
provides:
  - "fitbod.ExerciseProgressView — per-exercise intent-split chart"
  - "fitbod.SeriesBuilder pure-function namespace + E1RMSeriesPoint"
  - "fitbod.SeriesKind enum + SeriesToggleChipRow + ProgressFilterChip"
  - "fitbod.ProgressColors.allSetAverageSeries"
  - "Deep-link entry points on ExerciseDetailView + ExerciseHistoryView"
affects:
  - "Wave 4 ProgressHomeView (plan 06-08) — same kit reused for per-exercise cards"
  - "ExerciseDetailView History section gains 'View progress' row"
  - "ExerciseHistoryView toolbar gains chart-icon top-trailing button"
tech-stack:
  added: ["Charts (already in iOS 18 baseline — first Phase 6 surface to use it)"]
  patterns:
    - "Outer/inner @Query split — outer owns toggles + env; inner ProgressChartHost has local-let UUID #Predicate"
    - "Intent-split via .lineStyle(StrokeStyle(dash:)) not separate Charts — RESEARCH Pattern 1"
    - "Series toggle via Chart-input filter (not @Query predicate rebuild) — keeps fetch stable"
    - "Three layout branches: dual-off / empty / Chart — UI-SPEC verbatim copy in each"
key-files:
  created:
    - "fitbod/Models/Enums/SeriesKind.swift"
    - "fitbod/Progress/ProgressColors.swift"
    - "fitbod/Progress/ProgressFilterChip.swift"
    - "fitbod/Progress/SeriesToggleChipRow.swift"
    - "fitbod/Progress/SeriesBuilder.swift"
    - "fitbod/Progress/ExerciseProgressView.swift"
    - "fitbodTests/Phase6/SeriesBuilderTests.swift"
    - "fitbodTests/Phase6/ExerciseProgressViewCopyTests.swift"
  modified:
    - "fitbod/ExerciseLibrary/ExerciseDetailView.swift (added ProgressEntryRow in History section)"
    - "fitbod/ExerciseLibrary/ExerciseHistoryView.swift (added ProgressChartToolbarButton in topBarTrailing)"
decisions:
  - "Shipped ProgressFilterChip as a sibling of FilterChip rather than modifying the library chip — PATTERNS adjudication #2; keeps the library surface visually stable while letting Phase 6 evolve its own accent-tinted vocabulary."
  - "Chart series toggle filters the array fed to `Chart(...)` rather than rebuilding the @Query predicate. The @Query stays scoped to the exercise (one fetch); toggling is a Swift `.filter` on the materialized array."
  - "Top-set selection in SeriesBuilder still uses the D-05 ordering (e1RM → weight → completedAt) even though SessionComparator already does the same — the two functions serve different consumers (chart vs comparison view) and inlining the same tiebreaker locally is cheaper than introducing a shared helper that both must call."
metrics:
  duration: "~25 min"
  completed: "2026-05-23"
  files_created: 8
  files_modified: 2
  tasks_completed: 4
---

# Phase 6 Plan 05: ExerciseProgressView Summary

Per-exercise intent-split e1RM time series with toggle chips + dual deep-link entry points. The first Phase 6 surface to render Swift Charts.

## What shipped

### `fitbod/Progress/ExerciseProgressView.swift`

Outer/inner @Query split:

```swift
public struct ExerciseProgressView: View {
    public let exercise: Exercise
    @State private var showTopSet = true
    @State private var showAllAvg = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        VStack(spacing: 0) {
            SeriesToggleChipRow(showTopSet: $showTopSet, showAllAvg: $showAllAvg)
            ProgressChartHost(exerciseID: exercise.id, showTopSet: ..., showAllAvg: ..., reduceMotion: ...)
            Spacer()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProgressChartHost: View {
    @Query private var sessionExercises: [SessionExercise]
    // ... local-let UUID #Predicate in init
}
```

Three layout branches:

| Condition | Layout |
| --------- | ------ |
| `!showTopSet && !showAllAvg` | `Text("Select a series to display.")` centered |
| `<2 distinct sessions with usable e1RM` | Empty state: `Not enough data` / `Log 2 sessions to see your trend.` |
| otherwise | `Chart(filtered) { LineMark + PointMark }` with intent-dashed series |

Chart styling (UI-SPEC verbatim):

- `LineMark` + `PointMark` per point
- `.foregroundStyle(by:)` → `chartForegroundStyleScale(["Top set": .accentColor, "All-set avg": ProgressColors.allSetAverageSeries])`
- `.lineStyle(StrokeStyle(lineWidth: kind == .topSet ? 2 : 1.5, dash: intent == .hypertrophy ? [4, 3] : []))`
- `.symbolSize(kind == .topSet ? 60 : 40)`
- `.chartXScale(.automatic(includesZero: false))` + `.chartYScale(.automatic(includesZero: false))`
- `.chartYAxisLabel("e1RM (kg)")`
- `.frame(minHeight: 240)`
- Legend caption: `"Solid: Strength · Dashed: Hypertrophy"`
- Conditional high-rep caption: `"Sets above 10 reps aren't shown in e1RM."` when any working set in the dataset has reps > 10.

Reduce-motion gating: `.animation(reduceMotion ? nil : .smooth(duration: 0.18), value: filtered)`.

### `fitbod/Progress/SeriesBuilder.swift`

Pure-function builder:

```swift
public enum SeriesBuilder {
    public static func buildPoints(from sessionExercises: [SessionExercise]) -> [E1RMSeriesPoint]
}
```

Per session: emit at most one `.topSet` point (D-05) and one `.allSetAvg` point (D-06). Sets with `reps > 10` excluded (PROG-02 suppression); sessions with all-suppressed sets yield zero points.

### `fitbod/Progress/SeriesToggleChipRow.swift` + `ProgressFilterChip.swift`

Horizontal `HStack` of two accent-tinted capsule chips. Both default ON; tapping either flips its `@Binding<Bool>`. UI-SPEC labels: `"Top set"` / `"All-set avg"`. Accessibility names: `"Top set series"` / `"All-set average series"`. `.selectionChanged()` haptic on tap.

### `fitbod/Progress/ProgressColors.swift`

```swift
public enum ProgressColors {
    public static let allSetAverageSeries = Color(red: 0.247, green: 0.749, blue: 0.788) // #3FBFC9
}
```

### `fitbod/Models/Enums/SeriesKind.swift`

`public enum SeriesKind: String, CaseIterable, Sendable { case topSet, allSetAvg }` with `displayLabel` strings `"Top set"` / `"All-set avg"`.

### Deep-link entry points

- `ExerciseDetailView` → `ProgressEntryRow(exercise:)` inside the existing `Section("History")`. Hidden via own `@Query` when set count == 0. Pushes `ExerciseProgressView(exercise:)`.
- `ExerciseHistoryView` → `ToolbarItem(.topBarTrailing) { ProgressChartToolbarButton(exercise:) }`. Hidden when set count == 0. Pushes `ExerciseProgressView(exercise:)`.

### Tests

- `SeriesBuilderTests` — 5 @Test functions (emitsTopSetAndAvgPerSession, excludesWarmupAndIncompleteSets, skipsSessionWhenAllRepsAboveTen, topSetByE1RMTiebreaker, allSetAvgIsArithmeticMean).
- `ExerciseProgressViewCopyTests` — 1 @Test anchoring 9 UI-SPEC verbatim strings across `ExerciseProgressView.swift` + `SeriesToggleChipRow.swift` + `SeriesKind.swift`.

All 6 GREEN on iPhone 17 simulator.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed as written.

## Auth Gates

None.

## Threat Flags

None.

## Commits

| Hash | Type | Description |
| ---- | ---- | ----------- |
| `95b586a` | `feat(06-05)` | ExerciseProgressView + chart infrastructure + deep links |
| `f65579a` | `test(06-05)` | SeriesBuilderTests + ExerciseProgressViewCopyTests |

## Self-Check: PASSED

- 6 created source files — FOUND
- 2 modified source files — FOUND
- 2 test files — FOUND
- Commits `95b586a` + `f65579a` — FOUND
- `xcodebuild build` — BUILD SUCCEEDED
- `xcodebuild test -only-testing:fitbodTests/SeriesBuilderTests -only-testing:fitbodTests/ExerciseProgressViewCopyTests` — all 6 PASS
