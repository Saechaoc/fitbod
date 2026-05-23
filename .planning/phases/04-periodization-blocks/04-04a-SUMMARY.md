# 04-04a Summary - Today Block Card and Week Pager

Implemented:
- `BlockCard` for the Today tab with active block name, selected-week paging, edit sheet, and end-block confirmation.
- `MesocycleWeekPage` with phase/week badge text, days remaining, volume/intensity preview, and scheduled routine listing.
- Focused tests in `BlockCardWeekNavigationTests` for week count math, active-week selection, badge copy, days remaining, multiplier copy, and routine ordering.

Verification:
- `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:fitbodTests/BlockCardWeekNavigation`
- `xcodebuild build -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'`

Notes:
- `BlockCard` is value-driven from an injected `Block`; Today decides which block is active.
- Week context is resolved through `PeriodizationEngine`, so date/phase behavior remains shared with the non-UI tests.
