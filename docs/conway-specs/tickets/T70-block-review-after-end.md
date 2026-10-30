---
id: T70
title: The block review opens after a block ends
phase: 1
items: []
depends_on: []
size: M
sim: small
owns: [fitbod/Periodization/BlockReviewView.swift, fitbod/Views/TodayView.swift, fitbodTests/BlockReviewTriggerTests.swift, fitbodTests/BlockReviewedAtTests.swift, new:fitbodUITests/BlockReviewAfterEndUITests.swift]
---

# T70: The block review opens after a block ends

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F53, which the T67 worker reported and the coordinator confirmed in the code.
Today opens the end-of-block review for the blocks that `BlockReviewStatistics.pendingReviewBlocks` returns: active blocks with no `reviewedAt` whose end date has passed.
`BlockLifecycleService` never makes such a block.
An active block has no end date, and `end` sets the end date in the same save that makes the block inactive.
Nothing else sets an end date except restoring a backup, so the review never opens.
Its tests still pin the old model, where an active block's end date was its planned end.
`BlockReviewStatistics.acknowledge` also sets `isActive = false` itself, a second way to end a block, which T65's rule forbids.

## Target

- `triggerDescriptor`, `pendingReviewBlocks` and `acknowledge` in `fitbod/Periodization/BlockReviewView.swift`.
- Today's review check in `fitbod/Views/TodayView.swift`.

## Change

1. After the lifter ends a block with END BLOCK, Today opens that block's review the next time Today shows.
   It keeps opening on later visits until the lifter acknowledges it, as the review's "Plan custom" already expects.
2. Only the block that ended last can open a review; a block that ended before it never does.
3. Acknowledging records `reviewedAt` and changes nothing else on the block; it never writes `isActive`.
4. The review's tests describe the new trigger.

## Constraints

- No schema change.
- `BlockLifecycleService` stays the only way to start or end a block.
- Keep the review's sections and copy.

## Ownership

You may edit the files in `owns`, plus block and Today tests your change breaks.
For example, `BlockLifecycleEntryPointsUITests` ends a block and returns to Today, where the review will now open.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/BlockReviewTriggerTests.swift`, end an active block with `BlockLifecycleService.end`, and assert that `pendingReviewBlocks` returns it.
  It returns nothing today.
- In `fitbodUITests/BlockReviewAfterEndUITests.swift`, on the small phone with T17's seed `-fitbod-seed-active-block`, end the block from Today's block overview, and assert that the review opens on Today.
  It never opens today.

## Observable acceptance

- The repro tests pass, the UI test on the small phone.
- `BlockReviewTriggerTests`, `BlockReviewedAtTests`, `BlockReviewMathTests`, `BlockLifecycleServiceTests` and `BlockLifecycleEntryPointsTests` pass with `fitbodTests`.
- `BlockLifecycleEntryPointsUITests` passes on the small phone.
- A screenshot of the review after ending a block is in `screens/`.

## Hints

- `triggerDescriptor` is near line 469 of `BlockReviewView.swift`, `pendingReviewBlocks` near 480 and `acknowledge` near 492.
- Today runs the check in its `.task` near line 348 of `TodayView.swift`, the check's only caller, and shows the review in a sheet near line 287.
- `BlockLifecycleService.start` leaves an active block with no end date (see its comment near line 105), and `end` is near line 122.
- `BlockLifecycleEntryPointsUITests.testEndBlockFromTodaysBandCompletesTheBlock` (T67) ends a block from Today with the same seed.
