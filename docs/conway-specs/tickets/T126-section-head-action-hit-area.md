---
id: T126
title: Section head actions keep their touch area off the title at accessibility sizes
phase: 3
items: []
depends_on: [T37]
size: S
sim: small
owns: [fitbod/Design/BRUSectionHead.swift, new:fitbodTests/BRUSectionHeadLayoutTests.swift]
---

# T126: Section head actions keep their touch area off the title at accessibility sizes

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F292, from the review in T37.

- Since T37, at accessibility sizes `BRUSectionHead` puts its right label under the title.
- When that label is an action, such as "+ ADD SESSION", its touch area reaches about 8pt up into the title above it, so a tap near the bottom of the title can fire the action.
- T35 fixed the same problem in `BRUHeaderBar` by keeping the space the touch area needs between the title and the actions.

## Target

- The stacked layout at accessibility sizes in `fitbod/Design/BRUSectionHead.swift`.

## Change

1. At accessibility sizes the right action's touch area never overlaps the title, and the action keeps a touch target of at least 44pt.
2. At standard sizes the section head looks and behaves exactly as it does today.

## Constraints

- `BRUSectionHead` has about 65 call sites in 24 files; change only its accessibility-size layout.
- Keep T37's stacking and the `.isHeader` trait.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

In `BRUSectionHeadLayoutTests`, host a section head with an action at AX3 and at default text, and measure the frames:

- At AX3, assert that the action's touch area, its frame grown by its hit margin, stays clear of the title's frame.
  It overlaps by about 8pt today.
- At default text, assert that the layout matches today's.

## Observable acceptance

- The repro tests pass with `fitbodTests` on the large phone.
- `LibraryPolishUITests` and the program and routine suites that use an action section head pass on the small phone.
- A screenshot of an action section head at AX3 on the small phone is in `screens/`.

## Hints

- T37's notes in the main checkout's `docs/conway-specs/evidence/T37/` describe the overlap, and `review.md` there has the finding.
- T35's `BRUHeaderMetrics.actionHitReach` in `fitbod/Design/BRUHeaderBar.swift` shows one way to keep the space.
- `bruHitArea(_:)` in `fitbod/Design/BRUHitArea.swift` sets the hit margin.
