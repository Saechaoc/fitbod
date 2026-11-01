---
id: T139
title: Week windows follow the calendar across daylight saving, and Muscles Hit keeps a stable order
phase: 3
items: []
depends_on: [T114]
size: M
sim: small
owns: [fitbod/Fatigue/WeeklyRecapSheet.swift, fitbod/Fatigue/PerMuscleDetailView.swift, fitbod/Fatigue/FatigueModel.swift, fitbod/Fatigue/DeloadAdvisor.swift, fitbod/Fatigue/PlateauDetector.swift, new:fitbodTests/WeekWindowCalendarTests.swift]
---

# T139: Week windows follow the calendar across daylight saving, and Muscles Hit keeps a stable order

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F333 and F334, which T114's worker found.

- The weekly recap finds last week by subtracting 7 × 86,400 seconds from the week's start.
  A week that holds a daylight-saving change is an hour longer or shorter, so the recap after the spring change reads "MAR 1 → MAR 8".
- The same fixed-seconds week math sits in `WeeklyRecapSheet.swift` (near lines 120, 694, 712 and 733), `PerMuscleDetailView.swift:300`, `FatigueModel.swift:228` and 262, and `DeloadAdvisor.swift:156`.
  `PlateauDetector.swift` near 359 to 380 uses 86,400-second spans too.
- The recap's Muscles Hit rows with the same count change order between launches, as CONTRIBUTING EXERCISES did before T109.

## Target

- The week boundaries in the files in `owns`, and the Muscles Hit order in `WeeklyRecapSheet.swift`.

## Change

1. Every week boundary in these files comes from the calendar, such as `Calendar.date(byAdding: .day, value: -7, to:)`, so each week starts at local midnight on its first day, a daylight-saving change included.
2. Spans that are durations rather than week boundaries may stay; `notes.md` lists each one kept, with why.
3. The recap's date range, its sessions and its prior-week comparisons cover exactly the calendar week before the current one.
4. Muscles Hit rows with the same count sort by muscle name, so the order never changes between launches.

## Constraints

- Outside a week that holds a daylight-saving change, every number and date stays as it is today.
- Keep T114's sessions target and its tests.
- Keep the user's week start setting, Monday or Sunday.

## Ownership

You may edit the files in `owns`, plus Fatigue and recap tests your change breaks.
Ask before you edit anything else.

## Repro first

In `WeekWindowCalendarTests`, with a calendar in a time zone that observes daylight saving, such as America/Los_Angeles:

- Take the week that starts just after the spring change, and assert that the recap's prior week starts at local midnight exactly seven calendar days earlier.
  It starts an hour off today.
- Assert the same for the fall change.
- Assert that two Muscles Hit rows with the same count come out in name order on every call.

## Observable acceptance

- The repro tests pass with `fitbodTests` on the large phone.
- `WeeklyRecapUITests`, `PerMuscleDetailUITests` and `EmptyWorkoutCountsUITests` pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T114's notes in `docs/conway-specs/evidence/T114/notes.md` describe the DST case.
- Pass a calendar into the functions you test, rather than reading `Calendar.current` inside them, so a test can choose the time zone.
