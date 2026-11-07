---
phase: quick-261106-pl1
plan: "01"
status: complete
date: 2026-11-06
commits: [a3b3ead4, 425a1e64, 99b989b4, 50c0a6be, aefa0f5f, 56dc453c]
---

# Today redesign step 1.1: TodayState and the plan line

Step 1.1 of `docs/design-map/redesign/plan.md` is built.
Today's only block context is now a two-line plan line that opens Block overview.
The stat strip, block band, week cells, deload-week banner and plan-complete note are gone.

## Commits

| Task | Commit | What |
| --- | --- | --- |
| 1 | a3b3ead4 | `BlockPosition.label` is the one form of a block's week and phase, read by Today, Block overview and Program; Block overview counts WORKOUTS DONE |
| 2 | 425a1e64 | `TodayState.resolve` covers the Today state table, 23 unit tests |
| 3 | 99b989b4 | The plan line replaces the stat strip, block band and week cells; Today re-reads the date on foreground and on a system day change |
| 4 | 50c0a6be | The deload advisory is one 44pt notice row with DISMISS; `DeloadWeekBanner` deleted |
| 5 | aefa0f5f | UI suites read `today.root` and reach History through Progress |
| 6 | 56dc453c | `-fitbod-seed-block-states-deload`, eight 17e captures, changelog entry |

## Deviations

- `BlockPosition` is `@MainActor`; Swift 6 rejected it without that once it left the view.
- `BlockPosition.label` reads "PLAN COMPLETE" for a block with no phases (Review Focus 4).
- `TodayView` keeps `Date.now` for the weekly-recap week start and `pendingReviewBlocks`; both are outside the day state.
- `EmptyWorkoutCountsUITests.testDayStreakCountsOnlyTheLoggedWorkout` deleted: Today no longer shows a day streak.
- `SessionHistoryBRUUITests` now lands on Progress after deleting a workout, since History opens from Progress.
- The long-block-name capture renamed the seeded block in the simulator store with sqlite; the changelog says so.
- GitNexus impact and detect-changes were not run; the index was stale.

## Verification

Full run `/tmp/fitbod-test-out/full-20261106-175323/full.xcresult`: 1,332 enumerated and run, 1,326 passed, 5 failed, 1 expected failure.

- `SwapExercisePrescriptionTests/variationUndoFailureRollsBackAndCanRetry()` fails 3 of 3 alone (expects `fx.press.id`, gets another exercise). It failed from the first run after Task 1, and no task touches swap code. Open.
- `MilestoneOneJourneyUITests/testAuthorRoutineLogRelaunchFinishAndHistory` fails 3 of 3, and fails the same way at `a3b3ead4^`, before this plan. Open.
- `SessionHistoryBRUUITests/testCorrectionSaveCancelDeleteAndRelaunch`, `BlockLifecycleEntryPointsUITests/testEditBlockStillGivesADraftBlockARoutine` and `BlockDraftKeepsUITests/testPresetKeepsItsNameAndWeeksWhenTheNameFieldTakesFocus` passed alone on rerun. Their errors fit simulator contention while captures ran on a second simulator.

Date refresh by hand: background, wait 5 s, foreground; the plan line stays current with no stale flash.
A midnight rollover cannot be driven on the simulator; `TodayStateTests.theDayTurnsOverWithNow` covers the function side.

Captures reviewed: plan line present on all eight, no removed component left, no clipping, double rule or misalignment.
