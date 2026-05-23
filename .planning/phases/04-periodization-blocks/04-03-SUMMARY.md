# 04-03 Summary — Routines Blocks Section

Implemented:
- `BlockRow` with active dot, caption text, week badge text, delete swipe action, and testable display helpers.
- `RoutinesListView` Blocks section above routine folders with the `+ Block` menu, inline empty state, create/edit `BlockBuilderView` sheets, and delete confirmation.
- `BlocksSectionTests` covering UI copy anchors, row text math, delete cascade/nullify behavior, and active-first/start-date display sorting.

Verification:
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/BlocksSection`
- `xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/BlockDraftSave -only-testing:fitbodTests/SingleActiveBlockInvariant -only-testing:fitbodTests/BlockBuilderViewCopy -only-testing:fitbodTests/RoutinesListCopy`

Notes:
- Active-first block ordering is applied in a pure helper after querying by start date. Direct Bool `SortDescriptor` use was avoided because it selects an unsuitable overload in this toolchain.
- SchemaV4-owned fields remain deferred while Phase 3.1 owns that schema version.
