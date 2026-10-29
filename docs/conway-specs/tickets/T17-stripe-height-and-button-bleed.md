---
id: T17
title: Stripe height and button bleed
phase: 1
items: [30, 16]
depends_on: [T01]
size: M
sim: both
owns: [fitbod/Design/LiveEditBanner.swift, fitbod/Settings/PlateInventoryEditor.swift, fitbod/Design/BRUButton.swift, new:fitbodUITests/StripeAndBleedUITests.swift]
---

# T17: Stripe height and button bleed

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The live-edit banner in the routine editor grows to about 360pt tall.
The Plate Inventory tab strip grows to about 330pt.
In both, a thin colored stripe sits in a row next to other content, and the stripe takes half of the free height.

When a bottom action bar such as DISCARD and SAVE sits at the bottom of a sheet, the BRUButton fill continues below the bar into the home indicator area.
This happens on both phones, whether the button is enabled or disabled.
The cause is a background fill that ignores the safe area by default.

## Target

- `fitbod/Design/LiveEditBanner.swift` and the tab strip in `fitbod/Settings/PlateInventoryEditor.swift`.
- The fill in `fitbod/Design/BRUButton.swift`.

## Change

1. The live-edit banner is a compact band, about 75pt tall at default text.
   At larger text it grows only as much as its text needs.
2. The Plate Inventory tab strip is a normal strip, about 40pt tall at default text.
3. Each stripe keeps its color and width.
4. A BRUButton's fill stops at the button's own frame and never reaches the home indicator area.
5. Pressed and disabled buttons keep their colors.

## Constraints

- `BRUButton` is used on about 27 screens, so GitNexus will rate it HIGH or CRITICAL.
  Report the rating, and run the UI suites listed below.
- If another BRU component bleeds in the same way, write it in `notes.md` as a new finding instead of fixing it.

## Ownership

You may edit the files in `owns`, plus UI tests your change breaks.
Ask before you edit anything else.

## Repro first

- On the small phone, open a routine editor that shows the live-edit banner, and assert that the banner is less than 120pt tall.
  It is about 360pt today.
- Open Settings, then Plate Inventory, and assert that the tab strip is less than 60pt tall.
  It is about 330pt today.
- On both phones, open the session editor with its DISCARD and SAVE bar.
  Take a screenshot, sample pixels in the home indicator area below SAVE, and assert that they match the sheet background, not the button fill.

## Observable acceptance

- Every repro test passes on both phones.
- `RoutineBuilderBRUUITests`, `SettingsBRUUITests` and `NewBlockModalUITests` pass on both phones.
- Screenshots of the banner, the tab strip and the bottom bar, on both phones, are in `screens/`.

## Hints

- The stripe rows are near `LiveEditBanner.swift:49-51` and `PlateInventoryEditor.swift:136-139`.
  The review verified on a copy that fixing the row's vertical size to its content gives the compact band and the normal strip.
- The fill is near `BRUButton.swift:172`.
- `BottomActionBar` holds DISCARD and SAVE in the session editor and in New Block.
- `RoutineBuilderView` and `SplitDetailView` show `LiveEditBanner`.
  Find the condition that shows it, and add a DEBUG seed if setting it up through the UI is slow.
