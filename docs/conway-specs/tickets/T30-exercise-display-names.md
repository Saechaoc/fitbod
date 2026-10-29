---
id: T30
title: Exercise display names
phase: 2
items: [21]
depends_on: [T01]
size: S
sim: small
owns: [fitbod/Fatigue/PerMuscleDetailView.swift, fitbod/Fatigue/WeeklyRecapSheet.swift, fitbod/ExerciseLibrary/ExerciseHistoryView.swift, fitbod/Views/LiftListRow.swift, fitbod/Fatigue/TryVariationSheet.swift, new:fitbodTests/ExerciseDisplayNameSourceTests.swift, new:fitbodUITests/ExerciseDisplayNameUITests.swift]
---

# T30: Exercise display names

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

Open a muscle from Today.
CONTRIBUTING EXERCISES lists "barbell bench press - medium grip" in lowercase, while every other screen says "Barbell Bench Press - Medium Grip".
The lowercase text is `canonicalName`, the search key, and five more places show it: Today's lift list, exercise history, Try variation and two lines of the weekly recap.
The same muscle screen shows ADJUST TARGETS as its section heading and again as the only row under it.

## Target

The six display sites listed in Hints, and the ADJUST TARGETS row in `fitbod/Fatigue/PerMuscleDetailView.swift`.

## Change

1. Every screen shows an exercise's `name`, never its `canonicalName`.
2. Sorting and search may keep using `canonicalName`.
3. The row under ADJUST TARGETS reads "Edit volume targets", with the same chevron as other navigation rows.
4. Add a source test that fails when `canonicalName` feeds text shown on screen in any of these files.

## Constraints

- Do not change `canonicalName` itself, search or the catalog seed.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, with the demo seed:

- Open a muscle from Today's heatmap, and assert that CONTRIBUTING EXERCISES shows "Barbell Bench Press - Medium Grip" with its capitals.
- Assert that Today's lift list shows the same capitalized name.
- Assert that the muscle screen has exactly one element labeled "Adjust targets" or "ADJUST TARGETS".
- Run the new source test and watch it fail.

All of these fail today.

## Observable acceptance

- Every repro test passes on the small phone.
- The source test passes with `fitbodTests`.
- `PerMuscleDetailUITests` and `WeeklyRecapUITests` pass on the small phone.
- Screenshots of the muscle screen and the lift list are in `screens/`.

## Hints

- The display sites: `PerMuscleDetailView.swift:309`, `WeeklyRecapSheet.swift:766` and 776, `ExerciseHistoryView.swift:67`, `LiftListRow.swift:39` and `TryVariationSheet.swift:174`.
- `TryVariationSheet.swift:141` sorts by `canonicalName`, which is fine.
- The section heading is near `PerMuscleDetailView.swift:230`, and the row is near 240.
