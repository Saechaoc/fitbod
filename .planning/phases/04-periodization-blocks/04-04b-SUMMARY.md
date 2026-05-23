# 04-04b Summary - Today Banner Stack

Implemented:
- `DeloadWeekBanner` for scheduled block deload weeks.
- `ConsiderDeloadBanner` advisory scaffold backed by `FatigueAdvisory`; the stub stays hidden until Phase 5 fatigue work supplies recommendations.
- `StartBlockCTA` for the no-active-block Today state.
- Today/Home stack ordering in `RootView`: scheduled deload banner, advisory banner, block card or start CTA, then active-session resume banner.
- Focused source-anchor tests in `TodayViewBlockStackingTests`.

Verification:
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/TodayViewBlockStacking`
- `xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/PeriodizationEngine -only-testing:fitbodTests/BlockTemplates -only-testing:fitbodTests/FatigueAdvisoryCanonicality -only-testing:fitbodTests/BlockDraftSave -only-testing:fitbodTests/SingleActiveBlockInvariant -only-testing:fitbodTests/BlocksSection`

Notes:
- Scheduled block deloads are canonical: Today renders the scheduled deload banner from the active block phase and does not let fatigue advisory state override the schedule.
- The advisory scaffold intentionally does not implement Phase 5 fatigue scoring.
