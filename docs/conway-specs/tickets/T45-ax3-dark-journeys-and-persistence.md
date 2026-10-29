---
id: T45
title: AX3 and dark journeys, relaunch persistence
phase: 6
items: []
depends_on: [T44]
size: L
sim: both
owns: [fitbodUITests/MilestoneOneJourneyUITests.swift, fitbodUITests/HistoryAndTodayUITests.swift, fitbodUITests/WorkoutSwapJourneyUITests.swift]
---

# T45: AX3 and dark journeys, relaunch persistence

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

Done criterion 3 in [../requirements.md](../requirements.md) needs the authored journey to pass on both phones at AX3, and again in dark mode.
`docs/VERIFICATION.md` shows the AX3 journey failing on the small phone and never passing on the large phone.
Done criterion 4 needs one relaunch test that proves the sets, the rest deadline and the history survive.
The journey's relaunch checks the sets, but not the remaining rest time, and it never relaunches after the workout is finished.

## Target

- `MilestoneOneJourneyUITests`, `HistoryAndTodayUITests` and `WorkoutSwapJourneyUITests`.
- The journey's relaunch steps in `MilestoneOneJourneyUITests`.

## Change

1. On each phone, at whole-run AX3 in light mode, run `MilestoneOneJourneyUITests`, `HistoryAndTodayUITests` and `WorkoutSwapJourneyUITests`.
2. On each phone, at default text in dark mode, run `MilestoneOneJourneyUITests`.
3. Extend the journey's relaunch:
   - Before the terminate, read the remaining rest time.
   - After the relaunch, assert that the remaining time is lower, using the same bounds as `testRestTimerAdjustsAndSurvivesBackgroundAndRelaunch` in `WorkoutLoggerJourneyUITests`.
   - After the workout is finished, terminate and relaunch again without the reset flag, and assert that history still shows the workout with its sets.
4. If a journey fails only because an element is off screen at AX3, add a scroll or reveal step with the T01 helpers.
5. Any other failure is a finding.
   Write it in `findings.md` with its screenshot, phone, text size and appearance, and do not change app code.

## Constraints

- Test edits may only add scroll or reveal steps and the relaunch assertions in step 3.
- Never weaken or remove an assertion, and never raise a timeout to hide slowness.
- Change no app code.
- At the end, set both phones back to default text and light mode.

## Ownership

You may edit the three journey files in `owns`.
Ask before you edit anything else.

## Repro first

Run each suite in steps 1 and 2 before you change anything, and save every failure to `repro-fail.txt`.
Then write the relaunch assertions in step 3, and run them once before you finish them, to see that they read the values they check.

## Observable acceptance

- All eight runs pass: three suites on two phones at AX3, and the journey on two phones in dark mode.
  Any run that still fails has each of its failures in `findings.md`.
- The extended relaunch passes on both phones at default text in light mode.
- `screens/` holds the journey's screenshots for each phone at AX3 and in dark mode.
- `after-pass.txt` lists every run with its counts and result bundle path.

## Hints

- The rest countdown comes from an absolute deadline, so after a relaunch the remaining time is lower by about the time the app was closed.
- The journey already relaunches near its `08-resume-after-relaunch` screenshot, and `WorkoutLoggerJourneyUITests` reads the rest time from its label.
- The last AX3 results are in the run tables at the top of `docs/VERIFICATION.md`.
