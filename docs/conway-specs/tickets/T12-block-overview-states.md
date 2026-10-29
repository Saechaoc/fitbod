---
id: T12
title: Block overview states
phase: 1
items: [28, 29, 25]
depends_on: [T01, T02, T11]
size: L
sim: both
owns: [fitbod/Periodization/BlockOverviewScreen.swift, fitbod/App/DemoWorkoutSeed.swift, new:fitbodUITests/BlockOverviewStatesUITests.swift, new:fitbodTests/BlockNumberingTests.swift]
---

# T12: Block overview states

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The block overview shows the active hero, "● ACTIVE BLOCK · #41", for every block that is not completed, including ready and draft blocks.
The number is the week of the year, so a block in October shows "#41".
Phase 1 shows NOW before the block has started.
A completed block marks every phase DONE and every session "Completed", whatever was logged.
It also still shows TODAY, NEXT and "1 LEFT".
On an active block, the week strip labels every future day NEXT.

## Target

The block overview screen, `fitbod/Periodization/BlockOverviewScreen.swift`: its hero, block number, week index, phase rows, sessions section, day states and week strip.

## Change

1. The hero follows the derived status:
   - active: today's active hero
   - ready: a "READY BLOCK" hero with the start date, the weeks and the phases, and no progress
   - draft: a "DRAFT BLOCK" hero that names the first missing piece, with the wording from T11
   - completed: today's completed hero
2. Blocks are numbered in start-date order, with ties broken by name (see "Block numbers" in [../tradeoffs.md](../tradeoffs.md)).
   The same number shows everywhere, including the accessibility label.
3. Before the start date, nothing shows NOW, a current week or progress.
4. On a completed block, each phase row shows one honest state, based on the block's end date:
   - "DONE": the block ran through the phase's last day
   - "CUT SHORT": the block ended during the phase
   - "NOT REACHED": the block ended before the phase started
5. On a completed block, a session shows "Completed" only when a finished workout with logged work sets exists for it during the block (decision 6, T02's rule).
   Otherwise it shows "Not logged".
6. Completed blocks show no day states: no TODAY, NEXT or "N LEFT".
7. On an active block, only the next training day shows NEXT.
   Later days show no state label.
8. Every accessibility label matches what the hero shows.

## Constraints

- Status stays derived; never store it.
- A completed block reads its phases from its archived configuration, never from the live template.
- No schema change.
- Update `BlockOverviewScreenCopyTests` and `BlockOverviewScreenWeekCarouselTests` only where you change pinned copy on purpose.

## Ownership

You may edit the files in `owns`, plus block overview tests your change breaks.
You may add DEBUG seeds for blocks in each state next to `DemoWorkoutSeed.swift`.
Ask before you edit anything else.

## Repro first

On both phones:

- Open a ready block, and assert that the hero does not say ACTIVE.
- With two blocks, assert that their heroes show "#1" and "#2".
- Open a ready block that starts tomorrow, and assert that no phase shows NOW.
- End a block during week 1, open it, and assert that later phases do not show DONE and that no TODAY, NEXT or LEFT label exists.
- Open an active block, and assert that exactly one day in the week strip shows NEXT.

All of these fail today.

## Observable acceptance

- Every repro test passes on both phones.
- A unit test covers block numbering, including a tie on start date.
- A unit test covers the three completed-phase states.
- Screenshots of the ready, draft, active and completed heroes on the small phone are in `screens/`.
- `fitbodTests` passes.

## Hints

- The hero choice is near lines 318-325, with the hero texts near 331 and 405.
- `blockSequenceNumber` is near 209-213, and `currentWeekIndex` near 229-231 falls back to 0.
- `dayState` is near 265-295, "N LEFT" near 511, and the day labels near 570-571.
- NOW is decided near 768-769, the archived phase rows are near 900-960, and "Completed" is hard-coded near 794 and 920.
- `BlockLifecycleService.decodeArchive` returns the archived configuration and throws a typed error.
- `MesocycleWeekPage.swift` near line 119 also returns "Completed".
  Check whether it has the same problem, and report it in `notes.md` without fixing it.
