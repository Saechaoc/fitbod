---
phase: 06
plan: 06
slug: weekly-tonnage-view
status: complete
completed: 2026-05-23
wave: 4
type: execute
requirements: ["PROG-04"]
depends_on: ["06-03", "06-05"]
tech_stack:
  added: []
  patterns:
    - "Outer/inner @Query split (PATTERNS §Pattern D) — outer owns @State + DI seam, inner host owns the date-bounded @Query<SetEntry>"
    - "ChartFilterState @Observable per PROJECT.md no-ObservableObject-in-new-code rule"
    - "MuscleVolumeProvider DI seam — default UnweightedMuscleVolumeProvider; Phase 5 swap is one-line at ProgressHomeView call site"
    - ".chartOverlay + GeometryReader bar-tap hit-test → proxy.value(atX:) → ISO week-start snap"
    - "Horizontal-scroll filter chip rows per UI-SPEC § Filter-chip row layout"
key_files:
  created:
    - fitbod/Progress/ChartFilterState.swift
    - fitbod/Progress/WeeklyTonnageFilterChips.swift
    - fitbod/Progress/WeeklyTonnageView.swift
    - fitbod/Progress/WeekDetailView.swift
    - fitbodTests/Phase6/WeeklyTonnageFilterStateTests.swift
    - fitbodTests/Phase6/WeeklyTonnageViewCopyTests.swift
  modified: []
decisions:
  - "Block-phase row auto-disable via @Query<Block> count check — when blocks.isEmpty, entire row .opacity(0.5) + .disabled(true) and footer 'No block data yet — define a block in Routines.' (UI-SPEC verbatim) renders below. No env var or feature flag — pure runtime detection so Phase 4 enables it automatically when the first Block lands."
  - "Bar-tap hit detection uses .chartOverlay { proxy in GeometryReader { ... Rectangle().contentShape(Rectangle()).onTapGesture { } } } pattern. Tap location translated via proxy.value(atX:) to a Date, then snapped to its containing ISO 7-day window via Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for:). No 'nearest-bar' fuzz tolerance in v1 — keeps the hit logic auditable."
  - "TimeRangeChoice.lowerBound(now:) extension lives in WeeklyTonnageView.swift (NOT TonnageSliceMode.swift) per plan ownership rule — avoids cross-plan file edits."
  - "MuscleChipRow chip source = full @Query<MuscleGroup> sorted by displayName, NOT 'top-10 trained muscles by volume'. UI-SPEC top-10 spec is a future enhancement; v1 ships all muscles alphabetically since the user is solo and the chip list is reasonable at 17 muscles."
  - "Previous-best RuleMark renders against the visible-domain max (bars.map(\\.totalTonnage).max() ?? 0) — CONTEXT D-21 'previous best week' is best displayed not all-time. Hidden when bars.count < 2."
metrics:
  duration_minutes: ~10
  tasks_completed: 3
  files_created: 6
  files_modified: 0
  commits: 3
---

# Phase 6 Plan 06-06: WeeklyTonnageView Summary

Ship `WeeklyTonnageView` — Swift Charts `BarMark` weekly tonnage chart with three horizontal-scroll filter chip rows (time range / block phase / muscle), `RuleMark` for previous best, and tap-to-drill into `WeekDetailView`. Wires PROG-04 UI side over the Wave 1 aggregator + protocol from 06-03.

## Overview

This plan ships the **user-visible** half of PROG-04. The aggregator + provider seam landed in 06-03; this plan composes them into a SwiftUI surface with the filter chips, the chart, and the drill-down. The `MuscleVolumeProvider` is injected via init parameter (default `UnweightedMuscleVolumeProvider()`), so Phase 5's stimulus-weighted implementation slots in via a one-line edit at the ProgressHomeView call site — no changes to this view's code.

The Block-phase filter row is rendered visually-disabled until Phase 4 ships, detected at runtime via `@Query<Block>.isEmpty`. When the first Block lands, the row enables automatically with no Phase 6 code change required.

## Implementation

### Task 1 — `ChartFilterState` + `WeeklyTonnageFilterChips`

**`fitbod/Progress/ChartFilterState.swift`** (74 lines)
- `@Observable public final class ChartFilterState` (per PROJECT.md "no ObservableObject in new code" rule)
- Three filter dimensions: `timeRange: TimeRangeChoice = .last26wk` / `blockPhases: Set<String> = []` / `selectedMuscles: Set<UUID> = []`
- Defaults match CONTEXT D-19 ("Last 26 wk, all block phases, no muscle filter")
- Not Sendable (Observable macro types aren't Sendable in Swift 6 — class storage is reference-typed; SwiftUI consumes on main actor only)

**`fitbod/Progress/WeeklyTonnageFilterChips.swift`** (157 lines)
- `public struct TimeRangeChipRow` — single-select; binds to `TimeRangeChoice`; chips "Last 8 wk" / "Last 26 wk" / "All time" (UI-SPEC verbatim)
- `public struct BlockPhaseChipRow` — multi-select bound to `Set<String>`; `@Query<Block>` detects empty state; entire row `.opacity(0.5).disabled(true)` + footer "No block data yet — define a block in Routines." (UI-SPEC verbatim) when blocks.isEmpty; chip per `BlockPhaseKind` case with its capitalized display label
- `public struct MuscleChipRow` — multi-select bound to `Set<UUID>`; `@Query<MuscleGroup>(sort: \.displayName)` enumerates chips; footer "Tap a muscle to break the bar by stimulus." (UI-SPEC verbatim) renders only when selection is empty
- All three rows: `ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { … } .padding(.horizontal, 16) }`

### Task 2 — `WeeklyTonnageView` + `WeekDetailView`

**`fitbod/Progress/WeeklyTonnageView.swift`** (208 lines)
- `extension TimeRangeChoice { public func lowerBound(now: Date) -> Date? }` — single call site for the date-range predicate bound. Returns `Calendar.current.date(byAdding: .weekOfYear, value: -N, to: now)` for last8wk/last26wk; nil for allTime.
- `public struct WeeklyTonnageView: View` — outer view owns `@State filterState = ChartFilterState()` + `@State navigationDestination: Date?` + injectable `MuscleVolumeProvider` (default `UnweightedMuscleVolumeProvider()`). Body: VStack of TimeRangeChipRow + BlockPhaseChipRow + MuscleChipRow + inner `WeeklyTonnageChartHost`. `.navigationDestination(item: $navigationDestination) { WeekDetailView(weekStart:) }` wires bar-tap drill-down.
- `private struct WeeklyTonnageChartHost: View` — inner host with `@Query<SetEntry>` (date-bounded via filterState.timeRange.lowerBound(now:) — local-let captured before #Predicate per RESEARCH Pitfall 3) AND `@Query<UserSettings>` (canonical weekStartsMonday source). Body computes `bars = WeeklyTonnageAggregator.aggregate(...)`. Branches: empty → 2-line empty state; non-empty → summary line "{total} kg over {n} weeks" + Chart.
- Chart body: `BarMark` branches on `filterState.selectedMuscles.isEmpty` (single-color `Color.accentColor` vs stacked `.foregroundStyle(by: .value("Muscle", slice.muscleName))`). `RuleMark` "Previous best" dashed secondaryLabel line + annotation renders when `bars.count >= 2`. `.chartXAxis { AxisMarks(values: .stride(by: .weekOfYear)) }` + `.chartYScale(domain: .automatic(includesZero: true))` + `.frame(minHeight: 280)`.
- Bar tap mechanism: `.chartOverlay { proxy in GeometryReader { geometry in Rectangle().fill(Color.clear).contentShape(Rectangle()).onTapGesture { location in ... } } }`. Tap location's x-coordinate is checked against the plot-frame bounds, then translated via `proxy.value(atX:)` to a `Date`, then snapped to ISO week start via `Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for:)` using the same `weekStartsMonday` setting as the aggregator.

**`fitbod/Progress/WeekDetailView.swift`** (87 lines)
- `public struct WeekDetailView: View` with `let weekStart: Date` + `@Query<Session>` filtered to the 7-day window from weekStart. Local-let captures (`lower`, `upper`) before the #Predicate per Pitfall 3.
- List of session rows with `routineSnapshotName` (`.body`) + `startedAt.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())` (`.caption .secondaryLabel`).
- Empty state for defensive case (user reached this view only via non-empty bar; but guard the no-sessions case anyway).
- Nav title format: `"Week of \(weekStart.formatted(.dateTime.month(.abbreviated).day().year()))"` (UI-SPEC verbatim).

### Task 3 — Tests

**`fitbodTests/Phase6/WeeklyTonnageFilterStateTests.swift`** (49 lines, 4 @Test funcs)
- `defaults` — `ChartFilterState()` defaults: timeRange == `.last26wk`, blockPhases.isEmpty, selectedMuscles.isEmpty
- `lowerBound8wk` / `lowerBound26wk` — `TimeRangeChoice.lowerBound(now:)` math against fixed `Date(timeIntervalSince1970: 1_700_000_000)` anchor
- `lowerBoundAllTime` — `.allTime` returns nil

**`fitbodTests/Phase6/WeeklyTonnageViewCopyTests.swift`** (69 lines, 1 @Test func)
- `verbatimCopy` reads `WeeklyTonnageView.swift` + `WeeklyTonnageFilterChips.swift` + `WeekDetailView.swift` via `#filePath` ascent and `#expect(source.contains("..."))` for every UI-SPEC verbatim string. Pattern matches `ExerciseHistoryViewCopyTests` (Phase 1 convention).

### Verification

- `xcodebuild build` → **BUILD SUCCEEDED** after each task
- `xcodebuild test -only-testing:fitbodTests/WeeklyTonnageFilterStateTests` → 4/4 @Test **PASS**
- `xcodebuild test -only-testing:fitbodTests/WeeklyTonnageViewCopyTests` → 1/1 @Test **PASS**

### Deviations from Plan

None. Plan executed exactly as written.

### Known Stubs

None. The Block-phase row's disabled state is intentional behavior pending Phase 4 (deferred per CONTEXT decision graph — not a stub).

## Commit SHAs

- **`dffb2ec`** — `feat(06-06): ChartFilterState + WeeklyTonnageFilterChips (3 chip rows)`
- **`c25cf90`** — `feat(06-06): WeeklyTonnageView + WeekDetailView (BarMark chart + drill-down)`
- **`1c5482e`** — `test(06-06): WeeklyTonnageFilterStateTests + WeeklyTonnageViewCopyTests`

## Self-Check: PASSED

Files exist:
- FOUND: fitbod/Progress/ChartFilterState.swift
- FOUND: fitbod/Progress/WeeklyTonnageFilterChips.swift
- FOUND: fitbod/Progress/WeeklyTonnageView.swift
- FOUND: fitbod/Progress/WeekDetailView.swift
- FOUND: fitbodTests/Phase6/WeeklyTonnageFilterStateTests.swift
- FOUND: fitbodTests/Phase6/WeeklyTonnageViewCopyTests.swift

Commits exist:
- FOUND: dffb2ec
- FOUND: c25cf90
- FOUND: 1c5482e

MuscleVolumeProvider DI seam (Phase 5 swap point):
- FOUND: `MuscleVolumeProvider` referenced in WeeklyTonnageView.swift via `provider: MuscleVolumeProvider = UnweightedMuscleVolumeProvider()` init parameter
