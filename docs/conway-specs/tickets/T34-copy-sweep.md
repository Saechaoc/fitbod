---
id: T34
title: Copy sweep
phase: 3
items: [25]
depends_on: [T01, T02, T22]
size: L
sim: small
owns: [fitbod/Periodization/ProgramView.swift, fitbod/Periodization/BlockOverviewScreen.swift, fitbod/Periodization/BlockCard.swift, fitbod/Periodization/BlockBuilderView.swift, fitbod/Sessions/SessionExerciseCard.swift, fitbod/Sessions/SessionHistoryView.swift, fitbod/ExerciseLibrary/ExerciseHistoryView.swift, fitbod/ExerciseLibrary/ExerciseDetailView.swift, fitbod/Progress/ExerciseProgressView.swift, fitbod/Progress/ExercisePRsView.swift, fitbod/Sessions/SessionHistoryRoute.swift, fitbod/Sessions/SessionDetailView.swift, fitbod/Fatigue/PerMuscleDetailView.swift, fitbod/Fatigue/WeeklyRecapSheet.swift, new:fitbodTests/UICopyRulesTests.swift, new:fitbodUITests/CopySweepUITests.swift]
---

# T34: Copy sweep

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

Several labels still break the app's copy rules:

- Counts ignore the singular: a routine with one session reads "1 sessions" on Program and on the block overview.
- Two dialogs say "You can review it from the Routines tab", but the tab is called Program.
- The logger's exercise menu says "Remove from Session", but a logged workout is a "workout" on screen.
- History's PER WEEK shows 0.2 for one workout in four weeks, because it rounds 0.25 to one decimal.
- Exercise history calls logged workouts sessions: its stat strip reads "Sessions · 30d" and its count line "12 sets across 4 sessions" (found by T94).
- Seven pushed screens go back with a bare "‹", and the weekly recap sheet closes with one, against "Sheet close labels" in [../tradeoffs.md](../tradeoffs.md) (finding F163, from T22 and T23's screenshots).
- On the small phone, the weekly recap's header title wraps as "WEEK 44" over "· RECAP", so a line starts with the dot (finding F213, from T87's worker).

Nothing stops these mistakes from coming back.

## Target

The copy sites listed in Hints, and one new source test in `fitbodTests/`.

## Change

1. Every count label in the app uses the T02 plural helper, so it reads "1 session" and "2 sessions".
   This covers sessions, sets, exercises, weeks, days and reps, in lowercase and uppercase.
2. "Routines tab" becomes "Program tab" in both dialogs.
3. "Remove from Session" becomes "Remove from workout".
4. PER WEEK shows up to two decimals with trailing zeros trimmed, such as 0.25, 0.5 or 2 (see "Per-week rate" in [../tradeoffs.md](../tradeoffs.md)).
5. Add `UICopyRulesTests`, a source test that reads every Swift file under `fitbod/`, skips comments, and fails with the file and line when a string literal:
   - contains "Routines tab", "in Routines" or "Remove from Session", or
   - puts an interpolated count directly before one of the plural nouns in step 1, instead of using the plural helper.
6. Fix every site the new test reports, even ones not listed in Hints.
7. Exercise history's "Sessions · 30d" becomes "Workouts · 30d", and its count line reads "12 sets across 4 workouts", through the plural helper.
8. The pushed screens in Hints go back with "‹ BACK", and the weekly recap sheet closes with "DONE" on the right, as "Sheet close labels" says.
9. With DONE in place, the recap's header title never starts a line with "·" on the small phone, at default text or at AX3.

## Constraints

- Leave existing em dashes in app copy alone; this ticket does not ban them.
- Do not change copy that other tickets own, such as Weekly Tonnage (T23) or the Today slab (T27), unless the new test flags it.
  If it does, fix it the same way and say so in your summary.
- Weekly Tonnage and its week detail (T104), Compare (T102), Volume Targets (T38) and the plate calculator (T19) get their back or close labels in those tickets, and the logger keeps its "‹".
- Copy-pinning tests that pin a string you change on purpose get updated in the same commit.
- `BlockBuilderView.swift` changes need all six New Block guardrail suites.

## Ownership

You may edit the files in `owns`, plus any file the new source test flags for a count label, plus copy tests your change breaks.
Ask before you edit anything else.

## Repro first

- Write `UICopyRulesTests` first, run it, and save the list of failures it prints.
- On the small phone, with a routine of one session, write a UI test that asserts Program's routine row shows "1 session".
- In the same suite, open an exercise's menu in the logger and assert that "Remove from workout" exists.
- Write a unit test for the per-week value: one workout in four weeks gives "0.25", two give "0.5", and eight give "2".
- In the UI suite, open each screen in Hints' back-label list and assert that it shows "‹ BACK", and that the weekly recap shows "DONE".
- Open the weekly recap on the small phone, and assert with the shared `readText` that no line of its header title starts with "·".

All of these fail today.

## Observable acceptance

- `UICopyRulesTests` passes, and `notes.md` lists every site it made you fix.
- The UI and unit repro tests pass.
- `fitbodTests` passes, including `ProgramViewFidelityTests`, `BlockOverviewScreenCopyTests` and the six New Block guardrail suites.
- `SessionLoggerBRUUITests`, `SessionHistoryBRUUITests` and `WeeklyRecapUITests` pass on the small phone.

## Hints

- "1 sessions": `ProgramView.swift:585`, and `BlockOverviewScreen.swift:727`, 792 and 1196.
- Other count labels the new test should catch: `BlockBuilderView.swift:1966`, `ExerciseHistoryView.swift:181`, `ExerciseDetailView.swift:504`, and `ExerciseProgressView.swift:377` and 397.
- "Routines tab": `BlockCard.swift:61` and `BlockOverviewScreen.swift:198`.
- "Remove from Session": `SessionExerciseCard.swift:147`.
- PER WEEK: `perWeekLabel` in `SessionHistoryView.swift`, near line 104.
- Exercise history's stat label is near `ExerciseHistoryView.swift:146`, and its count line is the line 181 above.
- `SplitDetailView.swift:211` already handles the singular by hand, which is fine.
- Back-label list, each a bare "‹" today: `ExerciseHistoryView.swift:93`, `ExerciseProgressView.swift:84`, `ExercisePRsView.swift:108`, History in `SessionHistoryView.swift:97`, Summary in `SessionHistoryRoute.swift:64`, `SessionDetailView.swift:75` when opened from History, and `PerMuscleDetailView.swift:103`.
- The weekly recap's "‹" is near `WeeklyRecapSheet.swift:143`.
