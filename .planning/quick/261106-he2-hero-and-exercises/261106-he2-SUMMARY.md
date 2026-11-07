---
phase: quick-261106-he2
plan: "01"
status: complete
date: 2026-11-07
commits: [0b2a8187, cd35a280, 538d09a1, 7fb2babf, 2ab3e6cc, 3cb65f6b]
---

# Today redesign step 1.2: hero and exercises

Step 1.2 of `docs/design-map/redesign/plan.md` is built.
The hero reads TODAY under a fixed-weekly block and NEXT UP · n OF m under a rotation, counts the working sets the logger will generate, and carries the deload caption.
The exercise list heads EXERCISES · n with VIEW ›, and each row reads the working-set count and rep range for the current phase.

## Commits

| Task | Commit | What |
| --- | --- | --- |
| 1 | 0b2a8187 | `PeriodizationEngine.workingSetCount(targetSets:phase:)` is the one rule for the working sets a phase yields; `SessionFactory` calls it; 4 unit tests |
| 2 | cd35a280 | `SessionFactory.start` and `WorkoutStarter.start` take the caller's calendar, so the factory plans the phase Today shows; 2 unit tests |
| 3 | 538d09a1 | `BlackSlabCTA` takes a label and a phase: `heroLabel(mode:position:slotCount:)`, the working-set count and the DELOAD WEEK · LIGHTER SETS caption; the day counter is gone; 3 unit tests, copy guard updated |
| 4 | 7fb2babf | `LiftListSection` heads EXERCISES · n with VIEW › opening the session; `LiftListRow` reads `sets × lo-hi` for the phase; chips, warm-up count and "Tap to reorder" dropped |
| 5 | 2ab3e6cc | `TodayHeroUITests`: Start workout ▸ sits above the tab bar and the deload week shows its cut sets; the deload seed gives its deload phase volume 0.5 |
| 6 | 3cb65f6b | Four 17e captures and the changelog entry |

## Deviations

- a91184cd (`fix(sessions)`) and 1fe3348e (`fix(library)`) landed on `main` from another session between Task 4 and Task 5. Neither touches a file this step edits; they fix the two failures 1.1 left open.
- `simctl` could not write the light-mode captures into `docs/design-map/screens/img` ("You don't have permission to save the file"); the two light PNGs lack the `com.apple.macl` extended attribute the dark ones carry. They were captured into the scratchpad and copied in.
- The changelog entry is dated 2026-11-07, the day the step landed, not the plan's 2026-11-06.
- The `LiftListRow` preview fixture set `generateWarmups`; the Task 4 guard search found it, and it went with the warm-up count.
- GitNexus impact calls fail without `repo: "fitbod"` while three repositories are indexed; each was rerun with it.

## Verification

GitNexus impact before each edit: `WorkoutStarter` LOW, `TodayView` LOW (2 direct callers); `SessionFactory`, `BlackSlabCTA`, `LiftListRow` and `LiftListSection` CRITICAL.
The CRITICAL labels come from the graph counting every UI test file as a caller (532 direct for `SessionFactory`, 531 at depth 2 for the three views) with no affected process.
Every real caller of the changed signatures (`WorkoutStarter`, `TodayView`, the factory and starter tests) changed in the same commit.
`detect_changes` before each commit named only the step's own symbols.

Per task:

- Task 1: helper and factory suites, 37 passed.
- Task 2: factory and starter suites, 21 passed.
- Tasks 3 and 4: fast tier, 1,259 run, 1,257 passed, the swap Undo failure 1.1 left open, 1 expected failure.
- Task 5: `TodayHeroUITests` 2 of 2; the four neighbouring Today suites 8 of 9, the miss being `MilestoneOneJourneyUITests`, open at the time.

Full run `/tmp/fitbod-test-out/full-20261107-074201/full.xcresult`: 1,342 enumerated and run, 1,339 passed, 2 failed, 1 expected failure.
The unit tier alone: 1,259 run, 1,258 passed, 1 expected failure, so the swap Undo failure 1.1 left open is closed by a91184cd.
The count is 1.1's 1,332 plus 10: Task 1 adds 4 test functions, Task 2 adds 2, Task 3 adds 3 and folds two copy tests into one, Task 5 adds 2 UI tests.

- `WorkoutSwapJourneyUITests/testVariationUndoRestoresPendingInputsAndSurvivesRelaunch` failed at its relaunch with "The tab bar never appeared".
  The result bundle holds a crash log: the app died in `fitbodApp.init`, the `fatalError` after `FitbodModelContainer.make` threw.
  The simulator log shows SwiftData failing to open `default.store` 0.7 s into that launch with SQLite error 4618, a short read, so the factory moved the store aside and the fresh store failed too.
  Passed alone on rerun (`/tmp/fitbod-test-out/fast-20261107-081221/fast.xcresult`). Nothing in this step touches the container.
- `SessionHistoryBRUUITests/testCorrectionSaveCancelDeleteAndRelaunch` failed waiting for the "Delete this workout?" sheet after its relaunch, as it did in 1.1's full run.
  No crash log. Passed alone on the same rerun. Open as a contention flake.

Open finding, not fixed here: `FitbodModelContainer.make` treats every `ModelContainer` creation error as an incompatible store.
A transient disk error at launch moves a good store into `IncompatibleStores/`, and the app comes up empty or, as here, dies when the fresh store fails too.
That is a data-integrity gap in persistence and deserves its own quick task.

Captures reviewed by eye, light and dark, active block and deload week: hero label, set count, minutes, deload caption, EXERCISES · 1 with VIEW ›, rows `3 × 5-8` and `1 × 5-8`, no chip, no day counter.

- `docs/design-map/screens/img/17e-default-light-today--active-block.png`
- `docs/design-map/screens/img/17e-default-dark-today--active-block.png`
- `docs/design-map/screens/img/17e-default-light-today--deload-week.png`
- `docs/design-map/screens/img/17e-default-dark-today--deload-week.png`
