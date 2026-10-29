---
id: T21
title: Name-first new routine
phase: 2
items: [15]
depends_on: [T01]
size: L
sim: both
owns: [fitbod/Routines/RoutineCreator.swift, fitbod/Periodization/ProgramView.swift, fitbod/Views/TodayView.swift, new:fitbod/Routines/NewRoutineNameScreen.swift, fitbodUITests/MilestoneOneJourneyUITests.swift, new:fitbodUITests/NewRoutineFlowUITests.swift]
---

# T21: Name-first new routine

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

On Program, tap "+ NEW", then "+ New routine", then Back without typing anything.
ROUTINES now lists "Untitled routine, 0 sessions".
The first-run screen (NO PROGRAM, "+ DEFINE BLOCK ▶" and the templates) is gone for good, because it shows only while there are no blocks and no routines.
What remains is a BLOCKS heading with nothing under it.
The cause is that Program and Today create the routine before the user enters anything.

## Target

- The "+ New routine" entry points on Program and on Today.
- `fitbod/Routines/RoutineCreator.swift`.
- The BLOCKS section on Program when no block exists.

## Change

1. "+ New routine" pushes a name step modeled on `BruNewRoutineScreen` in `bru-screens/create-flows.jsx` (see "New routine flow" in [../tradeoffs.md](../tradeoffs.md)).
2. The name step's header has "‹ BACK" on the left, "New routine" in the center and "SAVE" on the right.
   Its name field shows the placeholder "Name your routine".
3. SAVE is muted and disabled until the trimmed name is not empty.
4. No routine exists until the user taps SAVE.
   "‹ BACK" and the edge swipe create nothing.
5. After SAVE, the routine editor replaces the name step, so Back from the editor returns to where the user started.
6. Program and Today use the same name step.
7. The first-run screen stays until a block or a routine really exists.
8. When routines exist but no block does, the BLOCKS section shows "No blocks yet." and a "+ DEFINE BLOCK ▶" action that opens New Block, as the hero's action does.
9. Update `MilestoneOneJourneyUITests` so the journey names its routine in the new step.

## Constraints

- Build only the name step.
  The mockup's other fields belong to the full inline creator, which T48 puts on the roadmap.
- Use BRU components and tokens, and keep the glossary: the screen says "routine", never "split".

## Ownership

You may edit the files in `owns`, plus UI tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, from a fresh store:

- On Program, tap "+ NEW", then "+ New routine", then go back.
  Assert that ROUTINES has no "Untitled routine" and that the first-run screen still shows.
- Do the same from Today's entry point.

Both fail today.

## Observable acceptance

- Every repro test passes on both phones.
- A UI test types a name, taps SAVE, and sees the routine editor with that name, and Program lists the routine.
- A UI test proves SAVE stays disabled for an empty or blank name.
- A UI test with one routine and no block sees "No blocks yet.", and "+ DEFINE BLOCK ▶" opens New Block.
- `MilestoneOneJourneyUITests` passes on both phones.
- Screenshots of the name step at default text and AX3, and of the empty BLOCKS section, are in `screens/`.

## Hints

- The early create calls are near `ProgramView.swift:284-288` and `TodayView.swift:561-565`.
  Their comment says the routine is created up front so it is never orphaned; the name step removes that need.
- The first-run gate is near `ProgramView.swift:127-140`.
- `BruNewRoutineScreen` starts near line 360 of `bru-screens/create-flows.jsx`.
  Read it only; never edit `bru-screens/`.
- If a tab drives its stack with a navigation path, replacing the name step means replacing its path entry with the editor's route.
