---
id: T04
title: Skip warm-ups works, and counts stay honest
phase: 1
items: [2, 25]
depends_on: [T01, T02]
size: L
sim: both
owns: [fitbod/Sessions/WarmupRampRows.swift, fitbod/Sessions/SessionExerciseCard.swift, fitbod/Sessions/SessionLoggerView.swift, fitbod/Sessions/ResumeWorkoutBanner.swift, fitbod/Views/ResumeWorkoutSlab.swift, new:fitbodUITests/SkipWarmupsUITests.swift]
---

# T04: Skip warm-ups works, and counts stay honest

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

In the workout, SKIP WARM-UPS does nothing.
When warm-ups do get marked done, they count as logged sets, so Today says "4 SETS LOGGED" before a single work set.
The ramp gives no sign that a skip happened.
The Finish dialog shows only "Finish", because iOS 26 hides its cancel button, and a workout with nothing logged still saves.
The Program resume banner and the Finish dialog say "1 sets".

## Target

- The warm-up ramp in the logger: `WarmupRampRows` inside `SessionExerciseCard`.
- The logger's Finish and Discard dialogs in `SessionLoggerView`.
- The Today slab (`ResumeWorkoutSlab`) and the Program resume banner (`ResumeWorkoutBanner`).

## Change

1. SKIP WARM-UPS works on the first tap anywhere in its full-width 44pt row.
   Check every other button in the same header row for the same problem, and fix any you find.
2. After a skip, the ramp collapses to one "WARM-UPS SKIPPED" line with UNDO.
   UNDO brings back the ramp and the warm-ups' previous state.
3. The Today slab, the Program resume banner and the logger all use the T02 logged-work-sets count.
   Skipped warm-ups never count (decision 5).
4. Finish with zero logged work sets offers "Discard workout" instead of saving (decision 6).
   With one or more logged work sets, it offers "Finish".
5. The Finish and Discard dialogs show a visible "Keep logging" button without the cancel role.
   It closes the dialog and leaves the workout open.
6. Counts use the T02 plural helper: "1 set", "2 sets" and "1 SET LOGGED".
7. The Skip button's accessibility hint stays true: "Marks warm-ups as done without logging them."

## Constraints

- Use the T02 count and plural helper, and write no new counting code.
- Discard still asks before it deletes, and it deletes only the workout being discarded.
- Keep accessibility identifiers that existing UI tests use, or update those tests in the same commit.

## Ownership

You may edit the files in `owns`, plus UI tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone:

- Launch with the demo seed, tap RESUME on Today, and tap SKIP WARM-UPS.
  Assert that the ramp shows "WARM-UPS SKIPPED".
  Go back and assert that the slab says "0 SETS LOGGED".
- Open a workout with no work sets done, tap Finish, and assert that "Discard workout" and "Keep logging" show.
- Complete one work set, and assert that the Program banner shows "1 set" and the Finish dialog says "1 set".

All of these fail today.

## Observable acceptance

- The repro tests pass on both phones.
- UNDO restores the ramp, and the slab count stays the same through skip and undo.
- "Keep logging" closes the dialog and leaves the workout running.
- `SessionLoggerBRUUITests`, `WorkoutLoggerJourneyUITests` and `HistoryAndTodayUITests` pass on both phones.
- `fitbodTests` passes.
- Screenshots of the skipped state at default text on both phones are in `screens/`.

## Hints

- Cause: a parent tap gesture on the header row in `SessionExerciseCard.swift` near lines 252-258 wins over the default-styled button in `WarmupRampRows.swift` near 236-250.
  The 44pt frame sits outside the button, so it does not grow the tap area.
- The review has a verified fix: a plain button style, with the frame and a rectangular content shape on the button's label.
- The Finish logic checks `loggedSetCount == 0` in `SessionLoggerView.swift` near line 247.
- "1 sets" comes from `ResumeWorkoutBanner.swift` near line 80 and `SessionLoggerView.swift` near line 157.
