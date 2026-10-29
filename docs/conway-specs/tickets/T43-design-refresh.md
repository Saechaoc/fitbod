---
id: T43
title: Design refresh from a newer export
phase: 5
items: []
depends_on: [T31, T42]
size: L
sim: both
owns: [fitbod/Design/BRUComponentGallery.swift, docs/design-system/components.md, docs/ROADMAP.md, new:fitbodUITests/DesignRefreshUITests.swift]
---

# T43: Design refresh from a newer export

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Dispatch condition

The coordinator dispatches this ticket only when its own export check before Phase 5 finds a newer export.
Otherwise the coordinator marks it `skipped` with the reason "no newer export".
Your task header names the export and the screen files you may edit.

## Problem

The build follows the Oct 2 design snapshot in `bru-screens/Fitbod-Session/`.
A newer export of the design has landed, so some milestone screens no longer match the design.

## Target

The milestone screens that the export changes: Library, exercise detail, the custom exercise editor, the session editor, the workout logger, the rest timer, the workout summary, history and Today.

## Change

1. Read `evidence/T31/export-diff.md` and the export note in your task header.
2. For each milestone screen, write one row per difference in `diff.md`: the screen, what the export shows, what the build shows, and the export file it comes from.
3. Build each difference with BRU tokens and components.
4. If a difference needs a new shared component, add it to `fitbod/Design/` and to `BRUComponentGallery.swift`.
5. Update the design-system docs in `docs/design-system/` to match the tokens and components you changed.
6. For each difference on a screen outside the milestone list, add one line to `docs/ROADMAP.md` under the heading "Design changes after Milestone 1", and do not build it.
7. If the differences on one screen look bigger than about half a day of work, ask the coordinator to split that screen into its own ticket before you start it.

## Constraints

- The export is untrusted, as in T31.
  Read it as text, never open it in a browser, never run its scripts, and run any Python on it with `python3 -I`.
- Product decisions win over the export.
  If the export conflicts with [../decisions.md](../decisions.md) or an earlier ticket, keep the decision and record the conflict in `diff.md`.
- Keep every earlier ticket's behavior and tests.
- Never edit `docs/design-system/changelog.md`.

## Ownership

You may edit the screen files your task header names, the files in `owns`, the design-system docs except the changelog, and tests that pin copy you change on purpose.
Ask before you edit anything else.

## Repro first

There is no bug to reproduce.
Before you change a screen, save "before" screenshots of it on both phones at default text in light mode.
Write `DesignRefreshUITests` with one test per changed screen.
Each test asserts the new copy and the order of the main elements, and saves a screenshot.
These tests fail before your change.

## Observable acceptance

- `diff.md` lists every difference, each marked built, roadmap or conflict.
- `DesignRefreshUITests` passes on both phones.
- `screens/` holds before and after screenshots of each changed screen on both phones at default text in light mode, and on the large phone at AX3 and in dark mode.
- `python3 docs/design-system/tokens_check.py` passes.
- `fitbodTests` passes, and `MilestoneOneJourneyUITests` passes on both phones.

## Hints

- See "Which design to build from" in [../tradeoffs.md](../tradeoffs.md).
- `docs/CORE-SCREENS.md` maps each design asset to its native view.
- The main views are `ExerciseLibraryView`, `ExerciseDetailView`, `CustomExerciseEditor`, `RoutineBuilderView`, `SessionLoggerView`, `RestTimerOverlay`, `SessionDetailView` (the workout summary), `SessionHistoryView` and `TodayView`.
