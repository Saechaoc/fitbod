---
phase: 05-fatigue-model-plateau-detection
plan: 03
subsystem: ui-and-services
tags: [plateau-detection, e1rm, suggestedaction, swiftui, ui-testing, set-06]

requires:
  - phase: 05 plan 01
    provides: OneRepMaxEstimator + SchemaV6 additive plateauWindowOverride/plateauToleranceOverride + FatigueTestFixtures
  - phase: 05 plan 02
    provides: FatigueModel.weeklyVolume + FatigueModel.volumeZone (Branch 1 consumes); SessionExerciseCard host
  - phase: 04
    provides: Block + BlockPhase schema for Branch 3 deload-window detection (read-only)

provides:
  - PlateauDetector pure-function service (evaluate + suggestedAction + PlateauSignal + SuggestedAction)
  - StallBadge SwiftUI view (orange "Stalled" capsule)
  - SuggestedActionChip SwiftUI view (D-13 verbatim labels + accessibility hints)
  - TryVariationSheet (medium/large detents; mechanic + primary-muscle overlap; logged-only filter)
  - SessionExerciseCard plateau wire (.task evaluates + header inserts StallBadge + chip)
  - ExerciseDetailView "Plateau Detection" section (SET-06 editor)

affects:
  - phase: 05 plan 04 (DeloadAdvisor will wire DeloadSignalDetailSheet for the .deload chip route)
  - phase: 05 plan 05 (PerMuscleDetailView will wire the .addVolume chip route + replace the heatmap placeholder)
  - phase: 05 plan 06 (the SET-06 override surface composes with the global plateau settings in Settings tab)

tech-stack:
  added: []
  patterns:
    - "Pure-function decision tree (4 branches, priority-ordered) for advisory output — exercise-scoped service, not whole-week aggregate; no FatigueAdvisory conformance"
    - "BLOCK-08 / Pitfall #11 type-level discipline: PlateauDetector returns SuggestedAction enum case .deload as an advisory hint; never mutates Block state"
    - "Swift 6 #Predicate composition limits: when type-checker times out, split into a minimal #Predicate + Swift post-filters (proven in plan 02; reused here for SessionExercise multi-hop intent gate)"
    - "SwiftUI Form Toggle in UI tests: tap via XCUICoordinate(withNormalizedOffset:) on the inner control, not the row-level outer Switch element"
    - "SwiftUI Cell-row tap vs Button-row tap: in SwiftUI List, the cell tap doesn't always navigate; tap the inner Button accessibility element"

key-files:
  created:
    - fitbod/Fatigue/PlateauDetector.swift
    - fitbod/Fatigue/StallBadge.swift
    - fitbod/Fatigue/SuggestedActionChip.swift
    - fitbod/Fatigue/TryVariationSheet.swift
    - fitbodUITests/PlateauOverrideUITests.swift
  modified:
    - fitbod/Sessions/SessionExerciseCard.swift
    - fitbod/ExerciseLibrary/ExerciseDetailView.swift
    - fitbodTests/Fatigue/PlateauDetectorTests.swift
    - fitbodTests/Fatigue/SuggestedActionTests.swift

key-decisions:
  - "BlockPhase schema mapping: Phase 1 ships BlockPhase.nameRaw (not kindRaw) + BlockPhase.weeks (not weekCount); phase start dates are computed as Block.startDate + cumulative weeks of preceding phases (ordered by orderIndex). Updated PlateauDetector Branch 3 to match the actual schema."
  - "PlateauDetector.suggestedAction Branch 2 uses median weight as the 'matched load' anchor with ±max(smallestIncrement, 0.5kg) tolerance — simpler than per-pair modal grouping and survives the same 'increment, decrement, redo' RPE creep pattern."
  - "TryVariationSheet ships logged-only filter per Pitfall #6 — never-logged exercises are excluded from the candidate list. The 'View all similar exercises in library' footer button is the escape hatch."
  - "SessionExerciseCard wires only the .tryVariation chip route fully; .addVolume / .dropIntensity / .deload remain TODO stubs because their destination views (PerMuscleDetailView / inline prescription editor / DeloadSignalDetailSheet) ship in plans 04 + 05."
  - "UI tests use XCUICoordinate tap for SwiftUI Toggle (the row-level Switch tap doesn't flip the state on iOS 26 simulator); tap on the inner Button predicate (CONTAINS '·') for Library row navigation (cell tap doesn't navigate in SwiftUI 26)."

patterns-established:
  - "PlateauDetector branch-decision pattern: priority-ordered Bool predicates with early return — Branch 1 wins over Branch 2 when both fire (anchored by test); each branch is a private @MainActor helper for isolated unit testing in future plans."
  - "SuggestedAction.label + .accessibilityHint extensions live in SuggestedActionChip.swift (not the enum file) so the service stays pure (no SwiftUI dependency in the data layer)."
  - "TryVariationSheet candidate selection pipeline: FetchDescriptor for mechanic match → Swift filter for primary-muscle overlap → second FetchDescriptor for logged-at-least-once gate → sort + prefix(3). Avoids multi-hop predicates inside #Predicate."

requirements-completed: [PROG-06, SET-06]

duration: 31min
completed: 2026-05-23
---

# Phase 5 Plan 03: Wave 2 PlateauDetector + Suggested Action Summary

**PlateauDetector pure-function service (evaluate + D-13 4-branch suggestedAction) + StallBadge + SuggestedActionChip + TryVariationSheet + SessionExerciseCard wire + ExerciseDetailView Plateau Detection section. Stall flags + auto-picked chips now appear on the exercise card during an active session; SET-06 closes end-to-end.**

## Performance

- **Duration:** ~31 min
- **Started:** 2026-05-23T16:20:37Z
- **Completed:** 2026-05-23T16:51:42Z
- **Tasks:** 3 (all autonomous, all TDD-style)
- **Files modified:** 4
- **Files created:** 5

## Accomplishments

- `PlateauDetector.evaluate(exerciseID:intent:in:settings:now:)` reads the last N intent-matched SessionExercise rows, computes top-set e1RM per session via OneRepMaxEstimator (PROG-02 high-rep suppression), and returns `.notEnoughData` / `.stalled(e1RMs:rangeRatio:)` / `.progressing(e1RMs:)`. Per-exercise window + tolerance overrides resolved from `Exercise.plateauWindowOverride` + `Exercise.plateauToleranceOverride` (SET-06 schema fields shipped in plan 01).
- `PlateauDetector.suggestedAction(...)` implements the D-13 4-branch decision tree: Branch 1 (priority) `.addVolume` when primary-muscle volume < MAV; Branch 2 `.dropIntensity` on RPE creep ≥1.0 at matched load (median weight anchor + smallestIncrement tolerance); Branch 3 `.deload` on active Block accumulation/intensification week ≥3 with a scheduled deload phase within 14 days; Branch 4 (default) `.tryVariation`.
- BLOCK-08 / Pitfall #11 type-level discipline preserved: PlateauDetector returns the `.deload` SuggestedAction enum case (an advisory hint surfaced via a chip), never mutates Block state.
- StallBadge: orange 24pt capsule with "Stalled" label per UI-SPEC §Copywriting Contract verbatim; `Color(.systemOrange)` family (semantic, not literal) per UI-SPEC §Color.
- SuggestedActionChip: accent-tinted capsule with D-13 verbatim labels ("Add volume" / "Drop intensity" / "Consider deload" / "Try variation") + 32pt min-height hit area + per-action accessibility hints.
- TryVariationSheet: presented for the .tryVariation route. Candidate selection by Exercise.mechanic equality + ≥1 overlapping primary muscle slug + logged-at-least-once filter (Pitfall #6 mitigation). NavigationStack with `.medium + .large` detents; "Done" toolbar; "View all similar exercises in library" accent text link footer; empty-state copy verbatim.
- SessionExerciseCard wire: `@State plateauSignal` + `@State suggestedAction` + `@State presentingTryVariation` + `.task(id: sessionExercise.id)` calls `evaluatePlateau()`; header `HStack` inserts StallBadge + SuggestedActionChip after the CalibratingBadge and before the Spacer; `.sheet(isPresented:)` presents TryVariationSheet for the .tryVariation route. The .addVolume / .dropIntensity / .deload routes are no-op stubs marked for plans 04 + 05.
- ExerciseDetailView "Plateau Detection" section: Toggle "Override global settings" + conditional Window (1...12 sessions) + Tolerance (0.5...10% displayed, stored as decimal) Steppers + "Use global defaults" accent button + footer citing global defaults. SET-06 closes end-to-end.
- Two UI tests in PlateauOverrideUITests pass (`testPlateauDetectionSectionReachable` + `testOverrideToggleReveals_Steppers`).
- 2 of the remaining 5 plan-01 RED scaffolds now GREEN (PlateauDetector + SuggestedAction). 3 remain (DeloadAdvisor / MuscleVolumeTargetSeeder / WeeklyRecapTrigger) for plans 04 + 06.

## Task Commits

1. **Task 1: PlateauDetector pure function + D-13 4-branch suggestedAction + GREEN tests** — `aee96a6` (feat)
2. **Task 2: StallBadge + SuggestedActionChip + TryVariationSheet + SessionExerciseCard wire** — `734711c` (feat)
3. **Task 3: ExerciseDetailView Plateau Detection section + UI tests (SET-06)** — `840e2fd` (feat)

## Files Created/Modified

### Source (production)

- `fitbod/Fatigue/PlateauDetector.swift` — pure-function namespace + PlateauSignal + SuggestedAction + 4-branch decision tree + per-exercise override resolution.
- `fitbod/Fatigue/StallBadge.swift` — orange capsule with verbatim "Stalled" label + accessibility.
- `fitbod/Fatigue/SuggestedActionChip.swift` — accent capsule + D-13 verbatim labels + per-action a11y hints (SuggestedAction extension lives here, not in the service file, to keep PlateauDetector free of SwiftUI imports).
- `fitbod/Fatigue/TryVariationSheet.swift` — selection pipeline (mechanic + overlap + logged-only) + empty state + Done toolbar + accent footer link.
- `fitbod/Sessions/SessionExerciseCard.swift` — Phase 5 state vars + .task evaluation + header HStack insertion + .sheet wire + handleSuggestedAction router (only .tryVariation wired this plan).
- `fitbod/ExerciseLibrary/ExerciseDetailView.swift` — new Plateau Detection section with paired toggle + conditional Steppers + footer + "Use global defaults" button.

### Tests

- `fitbodTests/Fatigue/PlateauDetectorTests.swift` — 9 GREEN @Test functions covering D-12 stalled/progressing, D-11 not-enough-data, PROG-02 high-rep filter, D-10 intent split, SET-06 window + tolerance overrides, top-set selection by e1RM (not heaviest weight), rangeRatio formula.
- `fitbodTests/Fatigue/SuggestedActionTests.swift` — 8 GREEN @Test functions covering no-stall short-circuit (notEnoughData / progressing → nil), Branch 1 addVolume, Branch 2 dropIntensity, Branch 3 deload (real Block fixture with cumulative phase weeks), Branch 4 tryVariation, no-active-block edge, branch priority (Branch 1 wins over Branch 2 when both fire).
- `fitbodUITests/PlateauOverrideUITests.swift` — 2 UI tests covering section reachability + toggle reveal.

## Decisions Made

- **BlockPhase field mapping fix:** Phase 1 ships BlockPhase.nameRaw (not kindRaw) + BlockPhase.weeks (not weekCount); BlockPhase doesn't have its own startDate. Updated PlateauDetector Branch 3 to compute phase start dates as Block.startDate + cumulative weeks of preceding phases sorted by orderIndex (Rule 1 — implementation aligned to actual schema).
- **TryVariationSheet logged-only filter** per Pitfall #6: a candidate's id must appear in at least one SessionExercise row. The "View all similar exercises in library" footer link is the escape hatch for users who want to see never-logged matches.
- **SessionExerciseCard only wires .tryVariation route fully.** .addVolume / .dropIntensity / .deload remain stubs because their destination views (PerMuscleDetailView / Phase 3 inline editor / DeloadSignalDetailSheet) ship in plans 04 + 05.
- **UI test interaction patterns:** SwiftUI Toggle in Form requires XCUICoordinate-based tap (the outer row-level Switch element doesn't flip on iOS 26 simulator); SwiftUI List Cell tap doesn't always navigate to the detail view (tap the inner Button predicate matching the row label format CONTAINS '·' instead).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] BlockPhase schema field names: planned `kindRaw` / `weekCount` / phase-level `startDate` don't exist**
- **Found during:** Task 1 (PlateauDetector Branch 3 implementation)
- **Issue:** The plan referenced `BlockPhase.kindRaw` and `BlockPhase.weekCount` and treated each phase as having its own `startDate`. Phase 1's actual schema uses `BlockPhase.nameRaw` and `BlockPhase.weeks`; phases don't carry a startDate (they inherit from Block.startDate + cumulative weeks of preceding phases ordered by orderIndex).
- **Fix:** Rewrote the Branch 3 phase-walking logic to accumulate `phase.weeks * 7 days` from `block.startDate`, identifying the current phase by `now ∈ [phaseStart, phaseEnd)` and reading `phase.nameRaw` for the accumulation/intensification gate.
- **Files modified:** fitbod/Fatigue/PlateauDetector.swift
- **Verification:** Branch 3 test (`branch3DeloadOnActiveBlockWeek3`) constructs a fixture with `accum.weeks=4` + `deload.weeks=1` + `block.startDate = now - 14 days` → weekIndex=2 + deload starts at day 28 (14 days from now). Assertion passes.
- **Committed in:** aee96a6 (Task 1)

**2. [Rule 1 - Bug] Typed-tuple destructure trips Swift 6 type-checker**
- **Found during:** Task 1 (PlateauDetectorTests `topSetSelectionPicksHighestE1RM`)
- **Issue:** The plan's sample code used `for (j, wr): (Int, (Double, Int)) in [(0, (100, 5)), ...]).enumerated()`. Swift 6's type checker emits "failed to produce diagnostic for expression; please submit a bug report" on this typed-tuple destructure.
- **Fix:** Extracted the array literal to a typed `let workingSets: [(Double, Int)] = [...]` then `for (j, wr) in workingSets.enumerated()`. Functionally identical, type-checker friendly.
- **Files modified:** fitbodTests/Fatigue/PlateauDetectorTests.swift
- **Verification:** `xcodebuild test -only-testing:fitbodTests/PlateauDetectorTests` reports PASS.
- **Committed in:** aee96a6 (Task 1)

**3. [Rule 3 - Blocking] SwiftUI List Cell tap doesn't navigate in iOS 26 simulator**
- **Found during:** Task 3 (PlateauOverrideUITests initial run)
- **Issue:** First UI test attempts (`app.collectionViews.cells.firstMatch.tap()` and `app.descendants(matching: .cell).firstMatch.tap()`) found the cell element but the tap didn't push to the detail view — the test asserted "Plateau Detection section not visible" because the screen was still the Library list.
- **Fix:** Switched to `app.buttons.matching(NSPredicate(format: "label CONTAINS '·'")).firstMatch.tap()` — the SwiftUI List wraps each row's tap target in a Button whose label format is "{name}, {equipment}, ·, {mechanic}".
- **Files modified:** fitbodUITests/PlateauOverrideUITests.swift
- **Verification:** `testPlateauDetectionSectionReachable` passes after the fix.
- **Committed in:** 840e2fd (Task 3)

**4. [Rule 3 - Blocking] SwiftUI Toggle in Form doesn't respond to row-level Switch.tap() on iOS 26 simulator**
- **Found during:** Task 3 (PlateauOverrideUITests second run)
- **Issue:** `app.switches.matching(togglePred).firstMatch.tap()` was tapping the outer row-level Switch element but the toggle state stayed at value=0 (confirmed via element tree export). The conditional Steppers + "Use global defaults" button never appeared.
- **Fix:** Switched to `toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()` — coordinate tap on the right edge of the row reliably triggers the inner SwiftUI control. Added an extra wait + swipe sequence to bring the revealed Steppers + button into view (they live below the toggle row, which can be near the bottom of the screen).
- **Files modified:** fitbodUITests/PlateauOverrideUITests.swift
- **Verification:** `testOverrideToggleReveals_Steppers` passes after the fix.
- **Committed in:** 840e2fd (Task 3)

---

**Total deviations:** 4 auto-fixed (2 Rule 1 bug, 2 Rule 3 blocking)
**Impact on plan:** All four fixes were necessary correctness/test-pass corrections without scope change. The BlockPhase schema fix (#1) is a Phase 1 ↔ Phase 5 contract reconciliation that future Phase 5/6 services should re-use as the canonical pattern.

## Issues Encountered

- **Branch 3 test construction:** The `branch3DeloadOnActiveBlockWeek3` test needs a Block whose accumulation phase started 14 days ago + a deload phase starting at day 28 (14 days from now). The cumulative-weeks computation required careful date math; documented inline in the test fixture for future plans.
- **iOS 26 UI test affordances:** SwiftUI on iOS 26 simulator has subtle differences from prior simulators in how Form Toggle and List Cell elements respond to test taps. Both deviations (#3 + #4 above) are now documented in `patterns-established` so plans 04 + 06 inherit the fix patterns.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Plan 04 (DeloadAdvisor service + DeloadSignalDetailSheet) is unblocked:
- `PlateauDetector.SuggestedAction.deload` chip already renders on stalled exercise cards when Branch 3 fires; plan 04 wires the `handleSuggestedAction(.deload)` route to `DeloadSignalDetailSheet`.
- BLOCK-08 type-level discipline preserved — DeloadAdvisor will conform to Phase 4's `FatigueAdvisory` protocol and return `FatigueSuggestion?`, never a mutation.

Plan 05 (PerMuscleDetailView + body silhouette heatmap) is unblocked:
- `handleSuggestedAction(.addVolume)` and `MuscleVolumeBar.onTap` are both stubbed and ready to navigate to plan 05's PerMuscleDetailView.
- `FatigueSurfaceView.heatmapPlaceholder` is a stub waiting for plan 05's `BodySilhouetteView`.

Plan 06 (settings editors + seeders + recap) is unblocked:
- The global plateau settings in Settings tab can mirror the SET-06 editor pattern shipped here (paired toggle + Stepper bounds = input validation contract).

## Self-Check: PASSED

- `fitbod/Fatigue/PlateauDetector.swift` exists.
- `fitbod/Fatigue/StallBadge.swift` exists.
- `fitbod/Fatigue/SuggestedActionChip.swift` exists.
- `fitbod/Fatigue/TryVariationSheet.swift` exists.
- `fitbodUITests/PlateauOverrideUITests.swift` exists.
- Commits `aee96a6`, `734711c`, `840e2fd` all present in `git log --oneline`.
- `xcodebuild build` → BUILD SUCCEEDED.
- 2 RED scaffolds (PlateauDetector + SuggestedAction) now GREEN (17 @Test functions added).
- PlateauOverrideUITests both pass.
- Phase 1–4 + plans 01–02 regression sweep (full xcodebuild test excluding remaining RED scaffolds + UI tests) → TEST SUCCEEDED.

---
*Phase: 05-fatigue-model-plateau-detection*
*Completed: 2026-05-23*
