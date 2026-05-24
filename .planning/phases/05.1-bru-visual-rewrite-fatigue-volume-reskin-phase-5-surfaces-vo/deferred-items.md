# Deferred Items

## Out-of-scope pre-existing build failures (discovered during Plan 05.1-05 execution)

### Sibling Wave 2 RED test files — not caused by Plan 05.1-05

These files exist in the repo from sibling Wave 2 plans (05.1-06/07) that run in parallel.
They are intentionally RED tests referencing types not yet implemented:

1. `fitbodTests/Fatigue/WeeklyRecapSheetBRUTests.swift`
   - References `WeeklyRecapSheet.MetricCell`, `WeeklyRecapSheet.SectionLabels`,
     `WeeklyRecapSheet.EmptyStateCopy`, `WeeklyRecapSheet.deltaColor` — not yet implemented
   - Will turn GREEN when Plan 05.1-07 implements WeeklyRecapSheet BRU reskin
   - `PresentationDetent` reference appears to be a test isolation issue in that file

2. `fitbodTests/PerMuscleDetailViewBRUTests.swift`
   - From Plan 05.1-06; references PerMuscleDetailView types not yet implemented

**Plan 05.1-05 app target BUILD SUCCEEDED.** The test target build fails only due to these sibling RED tests. Per execution scope boundary rules, these are not fixed by Plan 05.1-05.

**Resolution:** Sibling executors for plans 05.1-06 and 05.1-07 will implement the referenced types, turning these tests GREEN.
