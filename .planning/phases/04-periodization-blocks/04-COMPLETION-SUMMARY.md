# Phase 4 Completion Summary

Completed on 2026-05-23.

## Implemented

- Training block persistence and additive migration: `Block`, `BlockPhase`, `SchemaV4`, `SchemaV5`, and `FitbodSchemaMigrationPlan`.
- Block authoring and management: `BlockDraft`, `BlockPhaseDraft`, `BlockBuilderView`, `BlockPhaseEditorRow`, `BlockRow`, and the Blocks section in `RoutinesListView`.
- Today/Home periodization surfaces: `BlockCard`, `MesocycleWeekPage`, `DeloadWeekBanner`, `ConsiderDeloadBanner`, `StartBlockCTA`, and the TodayView banner/review stack in `RootView`.
- Routine-to-block linking: `RoutineDraft.blockID`, `BlockPickerMenu`, block-aware progression filtering, and save-path demotion of invalid `.block` / `.hybrid` selections outside a block.
- Progression strategies: `BlockPeriodizedStrategy`, `HybridStrategy`, factory wiring, phase-aware explanations, and explicit `now` handling in RPE autoreg prediction.
- Deload-aware session generation: scheduled block deloads cut working set counts with safe clamps, suppress deload warm-up ramps, and snapshot the routine block relation onto started sessions.
- Phase-end review: `BlockReviewView`, `BlockReviewStatistics`, `E1RMHelper`, TodayView pending-review trigger, and acknowledge transaction writing `reviewedAt` plus `isActive = false`.

## Tests

- New/updated Phase 4 suites cover PeriodizationEngine, BlockTemplates, FatigueAdvisory canonicality, BlockDraft save, SingleActiveBlockInvariant, BlockBuilder copy, BlocksSection, BlockCard week navigation, TodayView block stacking, RoutineBlockLinkage, PrescriptionEditor block-case filtering, BlockPeriodizedStrategy, HybridStrategy, SessionBlockSnapshot, DeloadVolumeApplication, WarmupDeloadIntegration, BlockReviewMath, BlockReviewTrigger, and SchemaV4/SchemaV5 migration wiring.
- Regression stabilization updated Phase 1-3 tests for current schema usage, explicit custom-exercise deletion behavior, deterministic seed fixture selection, and add-unplanned orderIndex assignment.
- Final verification command:
  `xcodebuild test -scheme fitbod -derivedDataPath /tmp/fitbod-codex-derived -destination 'platform=iOS Simulator,id=EEE2FCB2-0E42-4D6D-9EC4-39EC183C7429' -parallel-testing-enabled NO`
- Final result: TEST SUCCEEDED, 401 unit tests and 6 UI tests.

## Known Limitations

- `Session.block` snapshots the block relationship, not immutable block field values. Editing a block name after a session starts is visible through the relationship; this is pinned by tests and matches the Phase 4 snapshot contract.
- Historical migration tests avoid registering incompatible historical SwiftData containers in the same process because SwiftData caches schema metadata globally. The deterministic backfill logic, migration ordering, and current V5 runtime container are still covered.
- Subjective visual checks such as phase colors and week-swipe feel remain manual-only per `04-VALIDATION.md`.

## Deferred Work

- Phase 5 owns real fatigue scoring and plateau detection. Phase 4 ships only the advisory protocol, stub, and read-only `ConsiderDeloadBanner` scaffold.
- Phase 6 owns full PR detection and progress views. Block review currently shows the PR section as the planned Phase 6 placeholder.
