# 04-06 Summary - Block and Hybrid Progression Strategies

Implemented:
- `BlockPeriodizedStrategy` with phase intensity multipliers, deload baseline hold, phase context explanations, and no-block/no-baseline defensive paths.
- `HybridStrategy` combining block ceiling and RPE autoregulation via the lower nonzero branch.
- `ProgressionStrategy` block/today context extension.
- `PrescriptionExplanation.phaseContextLine` and `deloadNoteLine`.
- Factory routing: `.block` -> `BlockPeriodizedStrategy`, `.hybrid` -> `HybridStrategy`.
- Session prescription call sites now pass block context where the strategy is held as `any ProgressionStrategy`.
- Focused tests in `BlockPeriodizedStrategyTests` and `HybridStrategyTests`.

Verification:
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/BlockPeriodizedStrategy -only-testing:fitbodTests/HybridStrategy`
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/RPEAutoregStrategy -only-testing:fitbodTests/DoubleProgressionStrategy -only-testing:fitbodTests/PrescriptionExplanation -only-testing:fitbodTests/ProgressionRounding -only-testing:fitbodTests/ManualOverride`
- `xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/PeriodizationEngine -only-testing:fitbodTests/BlockTemplates -only-testing:fitbodTests/FatigueAdvisoryCanonicality -only-testing:fitbodTests/BlockDraftSave -only-testing:fitbodTests/SingleActiveBlockInvariant -only-testing:fitbodTests/BlockBuilderViewCopy -only-testing:fitbodTests/BlocksSection -only-testing:fitbodTests/BlockCardWeekNavigation -only-testing:fitbodTests/TodayViewBlockStacking -only-testing:fitbodTests/RoutineBlockLinkage -only-testing:fitbodTests/PrescriptionEditorBlockCaseFilter -only-testing:fitbodTests/BlockPeriodizedStrategy -only-testing:fitbodTests/HybridStrategy`

Notes:
- `RoutineExercise.prescribedWeight` remains deferred because Phase 3.1 owns SchemaV4. Current strategy baseline resolution uses the existing `lastSessionWeight` path and returns the no-baseline prompt when absent.
- `Session.block` snapshot pinning is intentionally left for 04-07; 04-06 only passes live routine block context into the session-start prescription calculation.
