---
id: T02
title: Shared counts and plural helper
phase: 1
items: [2, 25, 40]
depends_on: []
size: M
sim: large
owns: [fitbod/Sessions/SessionSetActions.swift, new:fitbod/Design/BRUCountLabel.swift, new:fitbodTests/LoggedWorkSetCountTests.swift]
---

# T02: Shared counts and plural helper

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The app counts logged sets in three places, and all three include warm-ups.
So after a warm-up skip, Today says "4 SETS LOGGED" before a single work set.
The app has no rule for an empty workout, and it writes "1 sets" in several places.
Later tickets need one shared answer for each of these.

## Target

- `fitbod/Sessions/SessionSetActions.swift` for the counting rules.
- One new small file in `fitbod/Design/` for the plural helper.
- Unit tests in `fitbodTests/`.

## Change

1. Logged work sets: one shared function returns the number of completed sets in a workout that are not warm-ups.
   Warm-ups that Skip marked complete never count (decision 5).
2. Empty workout: one shared rule says a finished workout is empty when it has no logged work sets (decision 6).
3. Plural helper: one shared helper formats a count with a singular or plural noun, such as "1 set" and "2 sets".
   It supports the uppercase labels the app uses, such as "1 SET LOGGED".
   It follows the `count == 1 ?` pattern in `fitbod/Progress/ProgressHomeView.swift`.
4. Training math ignores warm-ups: prove with unit tests that muscle volume, PR detection and progression give the same results when a workout also has completed warm-ups.
   If one of them counts warm-ups, fix it in its shared code and say so in your summary.
5. Do not change any screen.
   T04, T22, T23, T27 and T34 wire these helpers into the UI.

## Constraints

- No schema change.
  Use the warm-up and completion fields `SetEntry` already has.
- Keep the helpers small and free of UI, so unit tests can call them directly.

## Ownership

You may edit the files in `owns`, plus the shared volume, PR or progression code if step 4 finds a bug there.
Ask before you edit anything else.

## Repro first

- Write the unit tests first, against the new function names.
- In `repro-fail.txt`, show that the three existing counts return 4 for a workout with four completed warm-ups and no work sets.
  Quote the three formulas you checked.

## Observable acceptance

- Unit tests cover warm-ups only, skipped warm-ups, a mix of warm-ups and work sets, no sets, and finished and unfinished workouts.
- Unit tests cover the plural helper for 0, 1 and 2, with lowercase and uppercase nouns.
- The volume, PR and progression tests with warm-ups pass.
- `fitbodTests` passes on the large phone.
- `git show --stat` lists no view files.
- `notes.md` lists each new function name with a one-line meaning.

## Hints

- The three current counts are in `fitbod/Views/ResumeWorkoutSlab.swift` near lines 53-57, `fitbod/Sessions/ResumeWorkoutBanner.swift` near 138-143, and `loggedSetCount` in `fitbod/Sessions/SessionLoggerView.swift` near 271-275.
- `handleSkipWarmups()` in `fitbod/Sessions/SessionExerciseCard.swift` marks every warm-up complete.
- Muscle volume lives in `fitbod/Fatigue/`, in-session PRs near `InSessionPRState`, and progression in `fitbod/Prescription/`.
- The parallel effort added `Session.loggedSetCount` in `4d7e07e`, and the logger, the Today slab and the Program banner already use it.
  If it exists when you start, it is the shared rule from step 1: keep it, test it, and build the empty-workout rule on it.
