---
id: T86
title: The block review fits its screen, names what Start next opens, and stops once a block starts
phase: 1
items: []
depends_on: []
size: M
sim: small
owns: [fitbod/Periodization/BlockReviewView.swift, fitbodTests/BlockReviewTriggerTests.swift, fitbodUITests/BlockReviewAfterEndUITests.swift]
---

# T86: The block review fits its screen, names what Start next opens, and stops once a block starts

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F93, F94 and F96.
T70 (`85352dd`) made the block review open after END BLOCK, so lifters now meet three problems in it.

- The bottom action bar is about 350pt tall on the small phone instead of about 52pt, and it cuts off the RECOMMENDED NEXT BLOCK band.
  Its 2pt divider `Rectangle` has a width but no height, so the bar takes all the height it is offered.
- The band recommends "Intensification · 4 weeks", where 4 is a fixed placeholder.
  Start next opens the 8-week Hypertrophy Meso template instead, because `BlockTemplates.template(for: .intensification)` returns it.
- Plan custom puts the review off, and Today opens it again on every visit.
  If the lifter then starts a block from Program, the ended block is still the last to end, so its review covers Today on every visit for the whole new block.
  The only way out is Start next, which opens a builder the lifter must cancel.

## Target

- `bottomActionBar`, `recommendedNextBand` and `pendingReviewBlocks` in `fitbod/Periodization/BlockReviewView.swift`.

## Change

1. The action bar is as tall as its buttons, and the band shows whole above it, on the small phone at default text and at AX3.
2. The band names the template Start next opens, with that template's total weeks, for example "Hypertrophy Meso · 8 weeks".
3. While any block is active, no review opens.
   With no active block, Today opens the review of the block that ended last until the lifter acknowledges it, as T70 made it.
4. Start next still acknowledges the review and opens the builder, and Plan custom still puts the review off.

See "The block review" in [../tradeoffs.md](../tradeoffs.md).

## Constraints

- Keep T70's rule that acknowledging records only `reviewedAt`.
- Do not change `BlockTemplates` or `recommendedNextKind`.

## Ownership

You may edit the files in `owns`, plus block and Today tests your change breaks.
Ask before you edit anything else.

## Repro first

- In `fitbodTests/BlockReviewTriggerTests.swift`, with an ended, unacknowledged block and a newer active block, assert that `pendingReviewBlocks` returns nothing.
  It fails today.
- In `fitbodUITests/BlockReviewAfterEndUITests.swift`, once END BLOCK opens the review on the small phone, assert that the action bar is at most 64pt tall, that the band's text lies whole above it, and that the band names the template whose builder Start next opens.
  These fail today.

## Observable acceptance

- The repro tests pass, the UI test on the small phone.
- `BlockReviewAfterEndUITests` and `BlockLifecycleEntryPointsUITests` pass on the small phone.
- `BlockReviewTriggerTests` and `BlockReviewMathTests` pass with `fitbodTests`.
- Screenshots of the review on the small phone at default text and AX3, before and after the fix, are in `screens/`.

## Hints

- The divider is near line 291 of `BlockReviewView.swift`, the band near line 250 with its placeholder weeks near line 252, and `pendingReviewBlocks` near line 489.
- `BlockTemplates.template(for:)`, near line 105 of `BlockTemplates.swift`, maps the recommended phase to the template Start next opens.
