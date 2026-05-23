# 04-05 Summary - Routine Block Linking

Implemented:
- `BlockPickerMenu` in the routine builder header with `No Block`, active-first block selection, and `+ Create New Block`.
- `RoutineDraft.blockID` with save-time fetch-by-id materialization into `Routine.block`, including nil and unknown-id nullification.
- `RoutineBuilderView` propagation of `hasBlock` into each exercise card.
- `PrescriptionEditorRow` filtering so `.block` and `.hybrid` are only shown when the routine has a block.
- Block-required help copy: "Add routine to a block to use these."
- Focused tests in `RoutineBlockLinkageTests` and `PrescriptionEditorBlockCaseFilterTests`.

Verification:
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/RoutineBlockLinkage -only-testing:fitbodTests/PrescriptionEditorBlockCaseFilter`
- `xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/RoutineDraftValidation -only-testing:fitbodTests/RoutineBuilderCopy -only-testing:fitbodTests/RoutinesListCopy -only-testing:fitbodTests/BlockDraftSave -only-testing:fitbodTests/SingleActiveBlockInvariant -only-testing:fitbodTests/BlocksSection -only-testing:fitbodTests/BlockCardWeekNavigation -only-testing:fitbodTests/TodayViewBlockStacking`

Notes:
- The linkage tests use `SchemaV3.models` because the parallel Phase 3.1 work still owns SchemaV4.
- The picker help copy follows the Phase 4 product decision prompt over the older UI-SPEC footnote wording.
