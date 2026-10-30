---
id: T87
title: Today shows the block review and the weekly recap one at a time
phase: 2
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Views/TodayView.swift, new:fitbodUITests/TodaySheetOrderUITests.swift]
---

# T87: Today shows the block review and the weekly recap one at a time

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F95, which the T70 worker found by reading the code; nobody has reproduced it yet.
Today asks for the weekly recap in `.onAppear`, which also marks the recap seen, and for the block review in `.task`.
On the first Today visit of a week after a workout last week, with a block review also due, both sheets are asked for on the same appearance.
SwiftUI shows one sheet at a time, so one of them can be dropped.
A dropped recap is already marked seen, so the lifter never gets it.

## Target

- The recap and review presentation in `fitbod/Views/TodayView.swift`.

## Change

1. When both are due, Today shows the block review first and the weekly recap after the review closes.
2. The recap is marked seen only once it has shown.
3. When only one is due, Today behaves as it does today.

## Constraints

- Do not change what makes the recap or the review due.

## Ownership

You may edit the files in `owns`, plus Today tests your change breaks.
If no seed reaches both at once, ask before you add a launch flag to a seed.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/TodaySheetOrderUITests.swift`, on the small phone, reach a Today visit where both the recap and a block review are due.
Assert that the review shows, and that the recap shows after the review closes.
Record in `notes.md` whether this fails today; if it does not, say so and stop, as worker-rules says for a ticket that does not reproduce.

## Observable acceptance

- The repro test passes on the small phone.
- `HistoryAndTodayUITests` and `BlockReviewAfterEndUITests` pass on the small phone.
- Screenshots of the review and then the recap on the small phone are in `screens/`.

## Hints

- `TodayView`'s `.task` asks for the review near line 348, and `.onAppear` and `.task` both call `checkWeeklyRecap()`.
