---
id: T83
title: The action popover's items stay whole and take a 44pt tap
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Design/BRUActionPopover.swift, new:fitbodUITests/ActionPopoverFitUITests.swift]
---

# T83: The action popover's items stay whole and take a 44pt tap

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F85, which the T63 worker found on Program's + NEW popover.
`BRUActionPopover` has a fixed 200pt width and fixed 40pt rows.
At AX3 on the small phone, its items read "+ New..." and "+ New r..." in place of "+ New block" and "+ New routine".
Its 40pt rows are also under the 44pt tap minimum in worker-rules at every text size.

## Target

- `fitbod/Design/BRUActionPopover.swift`, which Program's + NEW popover uses.

## Change

1. At every text size, each item shows its whole title, wrapping if it must, and its row grows with the text.
2. Each row takes taps across its full width and at least 44pt of height at every text size.
3. At accessibility sizes, the popover may grow wider than 200pt, but it stays on screen.
4. At default text, the only visible change is the taller rows.

## Constraints

- Keep `BRUActionPopover`'s initializer and items as they are; the component gallery uses it too.
- Do not change `ProgramView.swift`; T63 already places the popover under its header at every text size.

## Ownership

You may edit the files in `owns`, plus Program tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/ActionPopoverFitUITests.swift`, on the small phone with an empty store, open Program's + NEW popover and assert:

- At AX3, each item's text is whole and lies inside the popover, proven with frames and a screenshot.
- At default text, each item passes `UITestNavigation.assertTapTarget(_:minimum:)` at 44pt.

Both fail today.

## Observable acceptance

- The repro tests pass on the small phone.
- `ProgramHeaderAndSheetsAX3UITests` and `ProgramEmptyStateAX3UITests` pass on the small phone.
- Screenshots of the popover at default text and AX3 on the small phone, before and after the fix, are in `screens/`.

## Hints

- The width and row height are `BRUActionPopoverTokens`, near line 70 of `BRUActionPopover.swift`.
- Program shows the popover near line 277 of `ProgramView.swift`, below its measured header.
