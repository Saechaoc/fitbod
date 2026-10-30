---
id: T77
title: Plate Inventory's swipe-to-delete works on iOS 26 and closes like other rows
phase: 1
items: []
depends_on: []
size: M
sim: both
owns: [fitbod/Settings/PlateInventoryEditor.swift, new:fitbodUITests/PlateInventoryDeleteUITests.swift]
---

# T77: Plate Inventory's swipe-to-delete works on iOS 26 and closes like other rows

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F31 and F67.
T60 found that Plate Inventory's swipe-to-delete works on the iOS 27 lane phones, so F31 did not reproduce there.
On iOS 27, though, the rows sit in a `LazyVStack` inside a `ScrollView` with no swipe-actions container.
So two rows' Delete actions stay open at once, and neither tapping outside the rows nor scrolling closes them (F67).
The app supports iOS 26.4, where `.swipeActions` works only inside a `List`, so on iOS 26 the Delete action probably never appears (F31).
No iOS 26 simulator is installed, so that part cannot be checked here.

## Target

- The plate rows and their swipe actions in `fitbod/Settings/PlateInventoryEditor.swift`.

## Change

1. Opening one row's Delete closes any other open Delete.
2. Tapping outside the rows or scrolling closes an open Delete.
3. A swipe still deletes a plate, and the plate stays gone after reopening Plate Inventory and after a relaunch.

## Constraints

- Do not rely on iOS 27 APIs alone: the app supports iOS 26.4, where swipe actions work only inside a `List`.
- Keep the rows' look: plate stacks, counts, hairlines and the paper background.

## Ownership

You may edit the files in `owns`, plus Plate Inventory tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/PlateInventoryDeleteUITests.swift`, on the small phone:

- Swipe two rows, and assert that only one Delete shows.
- Tap the PLATES AVAILABLE head, and assert that no Delete shows.

Both fail today.
Also keep T60's test that deletes a plate and checks it stays gone.
Its source, `PlateInventoryDeleteUITests.swift.txt`, and T60's `notes.md` come to you through your brief's input bindings.

## Observable acceptance

- The repro tests and the delete test pass on both phones.
- `PlateCalculatorSheetBRUUITests` passes on the small phone.
- `fitbodTests` passes.
- Screenshots of Plate Inventory with one Delete open, on both phones, are in `screens/`.

## Hints

- `SessionLoggerView` and `SessionExerciseCard.cardRow()` show a `List` styled as BRU rows, with zero insets, hidden separators and paper row backgrounds.
- T60's notes explain the iOS 27 behavior; its screenshots stay in its archive.
