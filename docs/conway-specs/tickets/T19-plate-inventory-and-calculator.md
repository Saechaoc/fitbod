---
id: T19
title: Plate Inventory and the plate calculator
phase: 2
items: [43, 37, 25]
depends_on: [T17, T18]
size: M
sim: both
owns: [fitbod/Settings/PlateInventoryEditor.swift, fitbod/Settings/PlateCalculatorSheet.swift, docs/ROADMAP.md, fitbodUITests/PlateCalculatorSheetBRUUITests.swift, new:fitbodUITests/PlateInventoryNavigationUITests.swift]
---

# T19: Plate Inventory and the plate calculator

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

Plate Inventory has no back button, and its system bar is hidden.
T18 restores the edge swipe, but the screen still needs a visible way back.
Its SAVE INVENTORY button does nothing.
Edits already save as you make them, so the button has no job.

Plate Inventory's "•••" opens the plate calculator.
The calculator's own "•••" does nothing, and its footer Save does nothing.
The calculator is a sheet, but it closes with a bare "‹", which suggests a pushed screen.
On the small phone at default text, a calculator value breaks inside the number, as "-2." over "5".

## Target

- The header and footer of `fitbod/Settings/PlateInventoryEditor.swift`.
- The header, footer and value labels of `fitbod/Settings/PlateCalculatorSheet.swift`.

## Change

1. Plate Inventory gets a BRU "‹ BACK" in its header, which goes back to the previous screen.
2. Remove Plate Inventory's SAVE INVENTORY, and keep "Done ▸".
3. The calculator's header shows "Plate calculator" in the center and "DONE" on the right, and DONE closes the sheet (see "Sheet close labels" in [../tradeoffs.md](../tradeoffs.md)).
4. Remove the calculator's bare "‹", its "•••", and its footer Save and Done, because the header DONE now closes the sheet.
5. No calculator value breaks inside a number on the small phone, at default text or at AX3.
6. Add one line to `docs/ROADMAP.md` for each removed control, as the worker rules describe: SAVE INVENTORY, the calculator's "•••", its footer Save and its footer Done.

## Constraints

- The plate math and the inventory data stay as they are.
- Keep Plate Inventory's "•••", because it works: it opens the calculator.

## Ownership

You may edit the files in `owns`, plus Settings UI tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone:

- Open Plate Inventory, and assert that a "‹ BACK" control exists.
  None exists today.
- Change a plate count, tap SAVE INVENTORY, and record in `notes.md` that nothing else happens.
- Open the calculator, tap its "•••" and its footer Save, and record that nothing happens.
- Find the calculator value that shows "-2./5", save a screenshot, and assert with a frame check that the value label is one line tall.

## Observable acceptance

- A UI test proves "‹ BACK" returns to the previous screen.
- A UI test proves a plate count change survives leaving and reopening Plate Inventory, with no save button.
- A UI test proves the calculator's DONE closes the sheet, and that no "•••" or Save control is left in it.
- The value check passes at default text and at AX3 on the small phone.
- `PlateCalculatorSheetBRUUITests` and `SettingsBRUUITests` pass on both phones.
- `docs/ROADMAP.md` has one line for each removed control.
- Screenshots of both headers, on both phones, at default text and AX3, are in `screens/`.

## Hints

- Plate Inventory's header is near `PlateInventoryEditor.swift:58-61`, the hidden bar is near line 86, and SAVE INVENTORY and "Done ▸" are near lines 314-328.
- The calculator's "•••" is near `PlateCalculatorSheet.swift:161`, and its footer is near lines 403-416.
- `TryVariationSheet` already has a header with a centered title and DONE on the right.
- Plate Inventory edits write straight to the model through `@Bindable`, which is why they persist without a save.
