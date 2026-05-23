# Phase 4 Progress Log

## 2026-05-22 — Wave 0 Pure Foundation

- Checkpoint completed: non-conflicting 04-01 primitives landed: PeriodizationEngine, MesocycleWeekContext, BlockTemplates, BlockPhaseColors, FatigueAdvisory, StubFatigueAdvisory.
- Files changed: fitbod/Prescription/PeriodizationEngine.swift, fitbod/Periodization/MesocycleWeekContext.swift, fitbod/Periodization/BlockTemplates.swift, fitbod/Periodization/BlockPhaseColors.swift, fitbod/Prescription/FatigueAdvisory.swift, fitbod/Prescription/StubFatigueAdvisory.swift, fitbodTests/PeriodizationEngineTests.swift, fitbodTests/BlockTemplatesTests.swift, fitbodTests/FatigueAdvisoryCanonicalityTests.swift.
- Tests run: xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/PeriodizationEngine -only-testing:fitbodTests/BlockTemplates -only-testing:fitbodTests/FatigueAdvisoryCanonicality.
- Failures found: initial RED build failed on missing Wave-0 APIs as expected; focused GREEN run passed.
- Next checkpoint: BlockBuilderView and transactional single-active block save.
- Deferred: SchemaV4-specific 04-01 work because Phase 3.1 is happening in parallel and owns SchemaV4.

## 2026-05-22 — 04-02 Block Builder Core

- Checkpoint completed: BlockDraft, BlockPhaseDraft, BlockPhaseEditorRow, BlockBuilderView, and single-active save behavior.
- Files changed: fitbod/Periodization/BlockDraft.swift, fitbod/Periodization/BlockPhaseDraft.swift, fitbod/Periodization/BlockPhaseEditorRow.swift, fitbod/Periodization/BlockBuilderView.swift, fitbodTests/BlockDraftSaveTests.swift, fitbodTests/SingleActiveBlockInvariantTests.swift, fitbodTests/BlockBuilderViewCopyTests.swift.
- Tests run: xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/BlockDraftSave -only-testing:fitbodTests/SingleActiveBlockInvariant -only-testing:fitbodTests/BlockBuilderViewCopy.
- Regressions run: xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'; xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/RoutineDraftValidation -only-testing:fitbodTests/RoutineBuilderCopy -only-testing:fitbodTests/RoutinesListCopy.
- Failures found: initial RED build failed on missing BlockDraft API as expected; implementation and regression runs passed.
- Next checkpoint: RoutinesListView Blocks section and BlockRow.
- Deferred: Block.reviewedAt persistence until the SchemaV4 ownership conflict with Phase 3.1 is resolved.

## 2026-05-22 — 04-03 Routines Blocks Section

- Checkpoint completed: RoutinesListView now has a Blocks section, + Block template menu, BlockRow, edit sheet, and delete confirmation.
- Files changed: fitbod/Periodization/BlockRow.swift, fitbod/Routines/RoutinesListView.swift, fitbodTests/BlocksSectionTests.swift.
- Tests run: xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/BlocksSection.
- Regressions run: xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'; xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/BlockDraftSave -only-testing:fitbodTests/SingleActiveBlockInvariant -only-testing:fitbodTests/BlockBuilderViewCopy -only-testing:fitbodTests/RoutinesListCopy.
- Failures found: initial RED build failed on missing BlockRow API and exposed that Bool SortDescriptor is unsuitable here; implementation uses a pure active-first/start-date sort helper instead.
- Next checkpoint: Today-tab BlockCard and MesocycleWeekPage.
- Deferred: none beyond the existing SchemaV4/reviewedAt deferral.

## 2026-05-22 — 04-04a/04-04b Today Block Surfaces

- Checkpoint completed: Today now renders active block context through `BlockCard` and `MesocycleWeekPage`, plus the scheduled deload banner, fatigue advisory scaffold, and no-active-block start CTA.
- Files changed: fitbod/Periodization/BlockCard.swift, fitbod/Periodization/MesocycleWeekPage.swift, fitbod/Periodization/DeloadWeekBanner.swift, fitbod/Periodization/ConsiderDeloadBanner.swift, fitbod/Periodization/StartBlockCTA.swift, fitbod/App/RootView.swift, fitbodTests/BlockCardWeekNavigationTests.swift, fitbodTests/TodayViewBlockStackingTests.swift.
- Tests run: xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/BlockCardWeekNavigation -only-testing:fitbodTests/TodayViewBlockStacking.
- Regressions run: xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'; xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/PeriodizationEngine -only-testing:fitbodTests/BlockTemplates -only-testing:fitbodTests/FatigueAdvisoryCanonicality -only-testing:fitbodTests/BlockDraftSave -only-testing:fitbodTests/SingleActiveBlockInvariant -only-testing:fitbodTests/BlocksSection.
- Failures found: initial RED run failed on missing `BlockCard` and `MesocycleWeekPage` APIs as expected; implementation and regression runs passed.
- Next checkpoint: Routine-to-block linking, BlockPickerMenu, and conditional progression picker filtering.
- Deferred: fatigue recommendation scoring remains Phase 5; `ConsiderDeloadBanner` is only the Phase 4 advisory scaffold.

## 2026-05-22 — 04-05 Routine Block Linking

- Checkpoint completed: routine builder now links/unlinks blocks, `RoutineDraft.blockID` materializes `Routine.block` by fetch-by-id, and the progression picker hides `.block`/`.hybrid` outside a block.
- Files changed: fitbod/Periodization/BlockPickerMenu.swift, fitbod/Routines/RoutineDraft.swift, fitbod/Routines/RoutineBuilderView.swift, fitbod/Routines/RoutineExerciseCard.swift, fitbod/Routines/PrescriptionEditorRow.swift, fitbodTests/RoutineBlockLinkageTests.swift, fitbodTests/PrescriptionEditorBlockCaseFilterTests.swift.
- Tests run: xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/RoutineBlockLinkage -only-testing:fitbodTests/PrescriptionEditorBlockCaseFilter.
- Regressions run: xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'; xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/RoutineDraftValidation -only-testing:fitbodTests/RoutineBuilderCopy -only-testing:fitbodTests/RoutinesListCopy -only-testing:fitbodTests/BlockDraftSave -only-testing:fitbodTests/SingleActiveBlockInvariant -only-testing:fitbodTests/BlocksSection -only-testing:fitbodTests/BlockCardWeekNavigation -only-testing:fitbodTests/TodayViewBlockStacking.
- Failures found: initial RED run failed on missing `RoutineDraft.blockID` as expected; implementation and regression runs passed.
- Next checkpoint: Block-periodized and hybrid progression strategies with factory wiring and prescription explanations.
- Deferred: SchemaV4-specific migration assertions remain deferred while Phase 3.1 owns SchemaV4.

## 2026-05-22 — 04-06 Block and Hybrid Strategies

- Checkpoint completed: `BlockPeriodizedStrategy`, `HybridStrategy`, factory routing, block/today strategy context, phase context explanations, and deload note explanations.
- Files changed: fitbod/Prescription/ProgressionStrategy.swift, fitbod/Prescription/RPEAutoregStrategy.swift, fitbod/Prescription/DoubleProgressionStrategy.swift, fitbod/Prescription/BlockPeriodizedStrategy.swift, fitbod/Prescription/HybridStrategy.swift, fitbod/Prescription/ProgressionStrategyFactory.swift, fitbod/Sessions/SessionFactory.swift, fitbod/Sessions/SessionExerciseCard.swift, fitbodTests/BlockPeriodizedStrategyTests.swift, fitbodTests/HybridStrategyTests.swift.
- Tests run: xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/BlockPeriodizedStrategy -only-testing:fitbodTests/HybridStrategy.
- Regressions run: xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/RPEAutoregStrategy -only-testing:fitbodTests/DoubleProgressionStrategy -only-testing:fitbodTests/PrescriptionExplanation -only-testing:fitbodTests/ProgressionRounding -only-testing:fitbodTests/ManualOverride; xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'; xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/PeriodizationEngine -only-testing:fitbodTests/BlockTemplates -only-testing:fitbodTests/FatigueAdvisoryCanonicality -only-testing:fitbodTests/BlockDraftSave -only-testing:fitbodTests/SingleActiveBlockInvariant -only-testing:fitbodTests/BlockBuilderViewCopy -only-testing:fitbodTests/BlocksSection -only-testing:fitbodTests/BlockCardWeekNavigation -only-testing:fitbodTests/TodayViewBlockStacking -only-testing:fitbodTests/RoutineBlockLinkage -only-testing:fitbodTests/PrescriptionEditorBlockCaseFilter -only-testing:fitbodTests/BlockPeriodizedStrategy -only-testing:fitbodTests/HybridStrategy.
- Failures found: initial RED run failed on missing `BlockPeriodizedStrategy`, `HybridStrategy`, and explanation fields as expected; implementation and regression runs passed.
- Next checkpoint: deload-aware session generation, set-count cuts, session block snapshot pinning, and warm-up deload integration.
- Deferred: `RoutineExercise.prescribedWeight` D-17 explicit baseline remains deferred because Phase 3.1 owns SchemaV4.
