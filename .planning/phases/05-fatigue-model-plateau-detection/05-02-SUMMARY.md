---
phase: 05-fatigue-model-plateau-detection
plan: 02
subsystem: ui-and-services
tags: [swiftdata, fatigue-model, volume-bars, stimulus-seeder, ui-host, swiftui, today-tab]

requires:
  - phase: 05 plan 01
    provides: VolumeZone enum + verbatim D-06 verbs; StimulusWeightTable (57 lifts); RPVolumeLandmarks (17 muscles); 4 Asset Catalog zone colors; SchemaV6 + idempotency flags
  - phase: 04
    provides: BlockCard + ConsiderDeloadBanner mount sites in TodayView (FatigueSurfaceView lands below them per UI-SPEC ordering)

provides:
  - FatigueModel pure-function service (weeklyVolume + contributionPerSession + frequencyHits + weekOverWeekDelta + volumeZone delegate)
  - WeightedSetTotal + WeekOverWeekDelta Sendable value types (D-07 split, D-08 verbatim deltaCopy)
  - StimulusWeightSeeder runs every launch; writes 57 curated lifts onto ExerciseMuscleStimulus rows; preserves user-edited rows
  - MuscleVolumeBar SwiftUI view (UI-SPEC §MuscleVolumeBar verbatim layout, two-tone fill, MEV/MAV ticks, reduce-motion gated overMRV pulse, advisory ring slot)
  - FatigueSurfaceView Today-tab host (volume section + heatmap placeholder + empty-state copy verbatim)
  - First user-visible Phase 5 deliverable: open Today → see per-muscle weekly volume

affects:
  - phase: 05 plan 03 (PlateauDetector consumes OneRepMaxEstimator; tap-target on MuscleVolumeBar wires to plan 05's PerMuscleDetailView)
  - phase: 05 plan 05 (BodySilhouetteHeatmap replaces the placeholder section in FatigueSurfaceView)
  - phase: 05 plan 06 (DeloadAdvisor wires the isAdvisoryActive amber ring on MuscleVolumeBar; MuscleVolumeTargetSeeder replaces transient fallback)
  - phase: 06 (e1RM charts will reuse FatigueModel.weeklyVolume + the WeightedSetTotal value type)

tech-stack:
  added: []
  patterns:
    - "Pure-function @MainActor enum service with Sendable supporting value types — composable from view body without a parallel view-model layer"
    - "Pitfall #1 mitigated by keeping multi-hop optional traversal + array-contains predicates OUT of #Predicate and running them as Swift post-filters (Swift 6 type-checker times out on the full inline form)"
    - "Idempotent seeder with row-level guard (no UserDefaults flag) — supports schema/curation drift on app updates without clobbering user tuning"
    - "UI-SPEC §Asset Contract enforcement: Asset Catalog colors only via Color(\"VolumeBelowMEVGray\") etc.; reduce-motion gated SwiftUI animation"
    - "Transient (non-inserted) @Model fallback row pattern for surfaces that render before their seeder runs"

key-files:
  created:
    - fitbod/Fatigue/FatigueModel.swift
    - fitbod/Fatigue/StimulusWeightSeeder.swift
    - fitbod/Fatigue/MuscleVolumeBar.swift
    - fitbod/Fatigue/FatigueSurfaceView.swift
    - fitbodUITests/VolumeBarsUITests.swift
  modified:
    - fitbod/App/RootView.swift
    - fitbodTests/Fatigue/FatigueModelWeeklyVolumeTests.swift
    - fitbodTests/Fatigue/FrequencyHitsTests.swift
    - fitbodTests/Fatigue/StimulusWeightSeederTests.swift

key-decisions:
  - "Predicate composition moved out of #Predicate macro: Swift 6's type-checker times out composing isComplete + isWarmup + workingKinds.contains(...) + multi-hop sessionExercise?.session?.startedAt in a single #Predicate body. The two simple gates (isComplete + isWarmup) live in #Predicate; the workingKinds gate and the multi-hop date traversal live as Swift post-filters. Aligns with Pitfall #1 (multi-hop optional chains forbidden inside #Predicate)."
  - "StimulusWeightSeeder uses find-or-update semantics (NOT delete-and-recreate) to preserve SwiftData identity of existing ExerciseMuscleStimulus rows."
  - "T-05-01 mitigation lives in internal clampedWeight helper exposed for testing — defense in depth against future table-curation drift."
  - "FatigueSurfaceView falls back to a transient (non-inserted) MuscleVolumeTarget seeded from RPVolumeLandmarks when the user hasn't yet seeded persistent rows. Lets the surface render before plan 06's MuscleVolumeTargetSeeder runs without blocking the user."
  - "UI tests select Today tab explicitly (the simulator's last-active tab persists across launches — defaulting to Library is common on the dev machine). Tests gracefully tolerate either the empty-state copy OR D-06 verb strings depending on the on-disk store's session count."

patterns-established:
  - "MainActor-bound predicate fetch + Swift post-filter pattern — applicable to every Phase 5/6 service that needs both array-contains AND multi-hop optional traversal."
  - "Transient @Model fallback for views that render before their seeder runs — used by FatigueSurfaceView for MuscleVolumeTarget."
  - "UI test pattern: selectTabExplicitly + waitForSeedComplete + scrollUntilVisible — composable helpers for every Phase 5+ surface UI test."

requirements-completed: [VOL-01, VOL-02, VOL-04, VOL-06]

duration: 29min
completed: 2026-05-23
---

# Phase 5 Plan 02: Wave 1 FatigueModel + Volume Bars Summary

**FatigueModel pure-function service (stimulus-weighted weekly volume + frequency hits + week-over-week delta) + StimulusWeightSeeder (57 curated lifts with T-05-01 clamp) + MuscleVolumeBar SwiftUI view (D-06 verbatim verbs, D-07 two-tone fill, D-08 verbatim delta) + FatigueSurfaceView Today-tab host. The first user-visible Phase 5 surface is live.**

## Performance

- **Duration:** ~29 min
- **Started:** 2026-05-23T15:51:50Z
- **Completed:** 2026-05-23T16:20:37Z
- **Tasks:** 3 (all autonomous, all TDD-style)
- **Files modified:** 4
- **Files created:** 5

## Accomplishments

- `FatigueModel.weeklyVolume(muscleSlug:weekStart:in:)` returns a stimulus-weighted `WeightedSetTotal` with direct/indirect split per D-07. Algorithm: minimal #Predicate (isComplete + isWarmup) + Swift post-filter for workingKinds + multi-hop session date window + in-memory traversal of `entry.sessionExercise?.exercise?.muscleStimuli`.
- `FatigueModel.contributionPerSession` returns `[Session.id: Double]` so `FatigueModel.frequencyHits` can thresh-and-count sessions meeting the D-03 ≥2-set frequency threshold. The "multiple indirect can add up to a hit" semantics are anchored by an explicit test (4 secondary-0.5 sets in one session ≥ 2.0 → 1 hit).
- `FatigueModel.weekOverWeekDelta` returns a `WeekOverWeekDelta` value type carrying D-08 verbatim copy — "+N vs last week" / "-N vs last week" / "no change vs last week" — pre-baked so views stay dumb.
- `FatigueModel.volumeZone` delegates to plan 01's free `volumeZone(...)` — single source of truth for the D-05 strict-`<` boundaries.
- `StimulusWeightSeeder` runs every launch in `RootView.runSeed()` AFTER the exercise library importer. Iterates `StimulusWeightTable.overrides` (57 lifts), find-or-update writes onto matching `ExerciseMuscleStimulus` rows where `userEditedWeight == false`. T-05-01 clamp `[0, 1]` enforced via `internal static clampedWeight(_:)` (exposed for unit testing).
- `MuscleVolumeBar` ships verbatim per UI-SPEC §MuscleVolumeBar internal layout: name + sets-vs-mrv trailing accessory + GeometryReader bar track with two-tone fill (indirect 0.40 opacity + direct 1.0 opacity + MEV/MAV tick marks) + D-06 verbatim verb label + D-08 verbatim delta line. Reduce-motion gated overMRV pulse animation. `isAdvisoryActive` parameter slot for plan 06's amber ring.
- `FatigueSurfaceView` mounts on the Today tab below `ResumeWorkoutBanner`. @Query-driven volume section + heatmap placeholder + empty-state copy verbatim. Falls back to `RPVolumeLandmarks`-seeded transient `MuscleVolumeTarget` rows when the user hasn't yet seeded persistent targets.
- UI tests pass: launching the app on a simulated device, selecting the Today tab, scrolling to the surface, asserting either the empty-state or a D-06 verb string is rendered.
- 3 of the 8 RED scaffolds from plan 01 are now GREEN (FatigueModelWeeklyVolume + FrequencyHits + StimulusWeightSeeder). 5 remain (PlateauDetector / SuggestedAction / DeloadAdvisor / MuscleVolumeTargetSeeder / WeeklyRecapTrigger) for plans 03 / 04 / 06.

## Task Commits

1. **Task 1: FatigueModel pure-function service + Sendable value types + 2 GREEN test suites** — `64e207d` (feat)
2. **Task 2: StimulusWeightSeeder + RootView wire + GREEN test suite** — `ef35e23` (feat)
3. **Task 3: MuscleVolumeBar + FatigueSurfaceView + Today-tab mount + UI tests** — `9155489` (feat)

## Files Created/Modified

### Source (production)

- `fitbod/Fatigue/FatigueModel.swift` — pure-function namespace + WeightedSetTotal + WeekOverWeekDelta.
- `fitbod/Fatigue/StimulusWeightSeeder.swift` — @MainActor enum + seedIfNeeded + clampedWeight helper.
- `fitbod/Fatigue/MuscleVolumeBar.swift` — single-muscle bar row SwiftUI view.
- `fitbod/Fatigue/FatigueSurfaceView.swift` — Today-tab host + Date.mondayAtMidnight extension.
- `fitbod/App/RootView.swift` — `StimulusWeightSeeder.seedIfNeeded` wire in runSeed + `FatigueSurfaceView()` mount in TodayView.

### Tests

- `fitbodTests/Fatigue/FatigueModelWeeklyVolumeTests.swift` — 13 GREEN @Test functions including 3-set bench-press direct/indirect split, week-window inclusivity/exclusivity, Pitfall #3 setTypeRaw guard, Pitfall #9 rest-pause cluster counting as 1 set, D-08 ± delta variants, volumeZone delegation.
- `fitbodTests/Fatigue/FrequencyHitsTests.swift` — 5 GREEN @Test functions including the D-03 anchor "single 0.5 indirect does NOT count" + the additive "4 × 0.5 secondary does count" test.
- `fitbodTests/Fatigue/StimulusWeightSeederTests.swift` — 6 GREEN @Test functions including full-table writeback + user-edit preservation + non-curated immutability + idempotency + T-05-01 clamp boundaries + find-or-update no-duplicate-rows.
- `fitbodUITests/VolumeBarsUITests.swift` — 2 GREEN UI tests (header reachable + empty-state-or-verb-string visible).

## Decisions Made

- **Predicate compilation strategy:** Swift 6's strict concurrency mode's type checker times out trying to compose `isComplete + isWarmup + workingKinds.contains(setTypeRaw) + sessionExercise?.session?.startedAt >= weekStart + ... < weekEnd` in a single `#Predicate` macro body. Refactored to a minimal predicate (just the two simple Bool gates) + a Swift post-filter for the array-contains gate + the multi-hop date window. Aligns with Pitfall #1 (multi-hop optional chains forbidden inside #Predicate anyway).
- **`StimulusWeightSeeder` uses find-or-update, not delete-and-recreate.** Preserves SwiftData identity of existing rows so any future relationship using them (e.g., snapshot tests) isn't broken.
- **`FatigueSurfaceView` transient-fallback target.** When the user hasn't seeded persistent `MuscleVolumeTarget` rows (plan 06 ships the seeder), the surface still renders bars by constructing transient `MuscleVolumeTarget` instances from `RPVolumeLandmarks`. Avoids a chicken-and-egg dependency on the plan 06 seeder.
- **UI test must select Today tab.** The simulator preserves the last-active tab across launches; on the dev machine the most recently used tab is often Library. Tests now call `selectTodayTab` explicitly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Swift 6 type-checker timeout in #Predicate composition**
- **Found during:** Task 1 (FatigueModel build)
- **Issue:** The plan specified all five gates (isComplete + isWarmup + workingKinds.contains + multi-hop start >= captureStart + multi-hop start < captureEnd) inside the #Predicate body. Swift 6's strict-concurrency type checker reports: "The compiler is unable to type-check this expression in reasonable time; try breaking up the expression into distinct sub-expressions." Build fails.
- **Fix:** Kept the two simple Bool gates (isComplete + isWarmup) in #Predicate. Moved the array-contains and the multi-hop optional-chain date window to a Swift `.filter { ... }` post-pass. This is consistent with Pitfall #1 (multi-hop optional chains were never safe inside #Predicate anyway).
- **Files modified:** fitbod/Fatigue/FatigueModel.swift
- **Verification:** xcodebuild BUILD SUCCEEDED; all 13 FatigueModelWeeklyVolumeTests pass.
- **Committed in:** 64e207d (Task 1)

**2. [Rule 3 - Blocking] UI tests fail because simulator launches on Library tab**
- **Found during:** Task 3 (UI test run)
- **Issue:** Initial UI tests asserted `app.staticTexts["Volume This Week"].waitForExistence(timeout: 30)` directly after launch. Failed because the simulator persists last-active tab state; the launch tab was Library, not Today. The "Volume This Week" element really wasn't in the app's accessibility tree because the FatigueSurfaceView was on Today, which wasn't visible.
- **Fix:** Added `selectTodayTab` helper that taps `app.tabBars.buttons["Today"]` (waitForExistence first) before asserting. Also added `waitForSeedComplete` for splash-screen delays and `scrollUntilVisible` for scrollable content.
- **Files modified:** fitbodUITests/VolumeBarsUITests.swift
- **Verification:** Both UI tests pass (`** TEST SUCCEEDED **`).
- **Committed in:** 9155489 (Task 3)

---

**Total deviations:** 2 auto-fixed (both Rule 3 blocking)
**Impact on plan:** Both fixes were necessary build/test-pass corrections without scope change. No new public-API surface added.

## Issues Encountered

- **Initial xcresult diagnostic loop:** First UI test run failed with no obvious error in the streaming xcodebuild output. Diagnosed by parsing `xcrun xcresulttool get test-results activities` for the failed test, then exporting attachments to get the element hierarchy — which revealed the app was on the Library tab, not Today, at the time of the assertion. Documented the UI-test pattern (tab selection + splash wait + scroll into view) under `patterns-established` for future Phase 5/6 surface tests.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plan 03 (Slice D — PlateauDetector + SuggestedAction) is unblocked:
- `OneRepMaxEstimator` shipped in plan 01 — PlateauDetector consumes it directly for top-set e1RM per session.
- `FatigueModel.weeklyVolume` shipped in this plan — PlateauDetector's `suggestedAction → addVolume` branch reads it for the "muscle < MAV" check.
- `FatigueTestFixtures.makeContext()` + `weeklySessions(...)` are battle-tested across 3 fatigue suites now.
- `MuscleVolumeBar.onTap` parameter slot is wired with a no-op default; plan 05's `PerMuscleDetailView` will replace it with a NavigationLink.

Plan 05 (Wave 3 — body silhouette heatmap) is unblocked:
- `FatigueSurfaceView.heatmapPlaceholder` is a stub waiting for plan 05's `BodySilhouetteView`.

Plan 06 (Slice F — settings editors + seeders + recap) is unblocked:
- `MuscleVolumeBar.isAdvisoryActive` parameter slot is wired; plan 06's `DeloadAdvisor.evaluate` will provide the source.
- `FatigueSurfaceView` transient-target fallback is the foreseen replacement target for plan 06's `MuscleVolumeTargetSeeder`.

## Self-Check: PASSED

- `fitbod/Fatigue/FatigueModel.swift` exists.
- `fitbod/Fatigue/StimulusWeightSeeder.swift` exists.
- `fitbod/Fatigue/MuscleVolumeBar.swift` exists.
- `fitbod/Fatigue/FatigueSurfaceView.swift` exists.
- `fitbodUITests/VolumeBarsUITests.swift` exists.
- Commits `64e207d`, `ef35e23`, `9155489` all present in `git log --oneline`.
- `xcodebuild build` → BUILD SUCCEEDED.
- 3 RED scaffolds (FatigueModelWeeklyVolume / FrequencyHits / StimulusWeightSeeder) now GREEN.
- Phase 1–4 regression sweep (full xcodebuild test excluding remaining RED scaffolds + UI tests in other targets) → TEST SUCCEEDED.
- VolumeBarsUITests both pass on the iPhone 17 simulator.

---
*Phase: 05-fatigue-model-plateau-detection*
*Completed: 2026-05-23*
