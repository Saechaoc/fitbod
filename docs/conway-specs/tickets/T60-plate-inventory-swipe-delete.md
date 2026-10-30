---
id: T60
title: Plate inventory rows delete with a swipe
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Settings/PlateInventoryEditor.swift, new:fitbodUITests/PlateInventoryDeleteUITests.swift]
---

# T60: Plate inventory rows delete with a swipe

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F31, which the T09 worker read from the code.
Plate Inventory gives each plate row a swipe-to-delete action.
The rows sit in a `LazyVStack` inside a `ScrollView`, where `.swipeActions` does nothing, so a plate can never be deleted.

## Target

- The plate rows in `fitbod/Settings/PlateInventoryEditor.swift`.

## Change

1. Swiping a plate row from the trailing edge shows Delete, and Delete removes that plate from the inventory.
2. The screen keeps its BRU look: no stock list separators, insets or backgrounds.
3. Every other control on the screen works as before.

## Constraints

- Keep the plate math and the stored inventory format.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/PlateInventoryDeleteUITests.swift`, open Settings, then Plate Inventory.
Swipe a plate row to the left and assert that Delete appears.
Tap it, leave the screen, open it again, and assert that the plate is gone.

Today no Delete appears.

## Observable acceptance

- The repro test passes on the small phone.
- `PlateCalculatorSheetBRUUITests` passes on the small phone.
- `fitbodTests` passes.
- A screenshot of a row with Delete showing is in `screens/`.

## Hints

- `.swipeActions` is near line 273, inside the `LazyVStack` near line 263.
- `delete(plate:from:)` is near line 371.
- Swipe actions work only on rows of a `List`.
