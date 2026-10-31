---
id: T107
title: The plate screens keep their tabs whole and their controls easy to hit
phase: 3
items: []
depends_on: [T19, T28]
size: M
sim: both
owns: [fitbod/Settings/PlateInventoryEditor.swift, fitbod/Settings/PlateCalculatorSheet.swift, fitbod/Design/PlateTallyRow.swift, fitbod/Design/PlateStackViz.swift, new:fitbodUITests/PlateScreensFitUITests.swift]
---

# T107: The plate screens keep their tabs whole and their controls easy to hit

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F196 to F200, which T19's worker found, and finding F47, which T17's worker found.

- From XXXL up, Plate Inventory's equipment tabs break inside words.
  At AX3 on the small phone they read "BARB" over "ELL" and "DUMB" over "BELL" over "S", and at XXXL on the large phone "DUMBBELL" over "S".
- The calculator's EQUIPMENT heading says "TAP TO CHANGE", but its BAR and INVENTORY cells do nothing when tapped.
- The calculator opens only at half height.
  At AX3 on the small phone its header takes about a third of the sheet, so the target has to be scrolled to.
- The calculator's quick-adjust chips are about 20pt tall and 4pt apart, and Plate Inventory's tally boxes are 20pt tall.
  At AX3 on the small phone each tally box is also only about 20pt wide.
- Inside the Settings sheet, Plate Inventory shows its 24pt filler under Done ▸ as a gray band above the home indicator.
- In the calculator's per-side stack, a smaller plate is drawn over part of a larger plate's label.
  With a 137.5 lb target, the 1.25 covers part of the 45's "45".

## Target

- The equipment tab strip, the calculator sheet's presentation and the footer filler in `fitbod/Settings/PlateInventoryEditor.swift`.
- The EQUIPMENT heading and the quick-adjust chips in `fitbod/Settings/PlateCalculatorSheet.swift`.
- The tally boxes in `fitbod/Design/PlateTallyRow.swift`.
- The plate labels in `fitbod/Design/PlateStackViz.swift`.

## Change

1. Each equipment tab keeps its words whole at every text size on both phones, and "EZ-BAR" may break only after its hyphen.
2. The EQUIPMENT heading drops "TAP TO CHANGE", because the calculator only shows the equipment and the inventory picked in Plate Inventory.
3. At accessibility sizes the calculator opens at full height, as New Block's sheets do, so its target shows without scrolling.
   At default text it opens as it does today.
4. Each quick-adjust chip and each tally box has a touch target at least 44pt tall.
   At AX3 each tally box is also at least 44pt wide.
5. No gray band shows under Plate Inventory's Done ▸ inside the Settings sheet.
6. In the per-side stack, no plate covers another plate's label.

## Constraints

- Keep T19's headers, footers and value layout, and its scaled weight column in `PlateTallyRow`.
- The plate math and the inventory data stay as they are.
- At default text, the tabs, chips and tally boxes look as they do today.
- `PlateStackViz` also draws the logger's plate stack and the warm-up rows' plates, so check those screens as well.

## Ownership

You may edit the files in `owns`, plus Settings, plate and logger UI tests your change breaks.
Ask before you edit anything else.

## Repro first

On both phones, unless a step names one:

- At XXXL and AX3, open Plate Inventory, and assert with the shared `readText` that each tab's label breaks only between words.
- Open the calculator, and assert that no element reads "Tap to change".
  Tap BAR and INVENTORY, and record in `notes.md` that nothing happens.
- At AX3 on the small phone, open the calculator, and assert that its target value is fully on screen without scrolling.
- Tap 10pt above a quick-adjust chip's drawn top edge, and assert that the target changes.
  Tap 10pt above a tally box's drawn top edge, and assert that the plate's count changes.
- At AX3 on the small phone, assert that each tally box is at least 44pt wide.
- Open Plate Inventory from the Settings sheet, sample a column of pixels beside the home indicator from Done ▸'s bottom edge to the bottom of the screen, and assert that they are one color.
- With a 137.5 lb target, save a screenshot of the per-side stack, and record in `notes.md` which label is covered.
  Add a check, in a unit test of the stack's layout or in a UI test, that fails while any plate covers a label.

## Observable acceptance

- Every repro check passes on the phones it names.
- `PlateCalculatorSheetBRUUITests`, `PlateInventoryNavigationUITests`, `PlateInventorySwipeUITests` and `SettingsBRUUITests` pass on both phones.
- `SessionLoggerBRUUITests` and `SkipWarmupsUITests` pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.
- Screenshots of Plate Inventory and the calculator at default text, XXXL and AX3, on both phones, are in `screens/`, with the logger's plate stack at default text.

## Hints

- The tab strip is `equipmentTabStrip`, near `PlateInventoryEditor.swift:146`.
- The calculator sheet is presented near `PlateInventoryEditor.swift:108`.
  New Block presents its sheets with `.presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium])`, near `BlockBuilderView.swift:2290`.
- The 24pt filler is near `PlateInventoryEditor.swift:97`.
- The EQUIPMENT heading is near `PlateCalculatorSheet.swift:388`, and the chips come from `quickAdjustChip(label:delta:)`, near line 299.
- The tally boxes are `tallyColumn`, near `PlateTallyRow.swift:125`, and three T19 UI tests tap the first box by its offset from the row's leading edge.
- The plate labels are rotated near `PlateStackViz.swift:185`.
- T19's notes and screenshots are in the main checkout's `docs/conway-specs/evidence/T19/`.
