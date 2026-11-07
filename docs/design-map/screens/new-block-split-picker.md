---
id: new-block-split-picker
kind: sheet
title: Choose routine
view: fitbod/Periodization/BlockScheduleControls.swift:176
tab: program
presents_from: [new-block]
closes_with: cancel
mock: none
seed: -fitbod-seed-active-block
captured: 2026-10-31 61353088
img: [img/17e-default-light-new-block-split-picker.png, img/17e-default-light-new-block-split-picker--fresh.png, img/17e-default-dark-new-block-split-picker.png, img/17e-ax3-light-new-block-split-picker.png, img/17promax-default-light-new-block-split-picker.png, img/17promax-default-light-new-block-split-picker--fresh.png, img/17promax-ax3-light-new-block-split-picker.png]
tree: tree/new-block-split-picker.txt
---

The lifter picks the routine the new block will run.

<img src="img/17e-default-light-new-block-split-picker.png" width="300" alt="Choose routine in New Block on the iPhone 17e">

## Entry points

| From | Tap | Kind |
|---|---|---|
| [new-block](new-block.md) | + ATTACH ▸ in the Routine row, when no routine is picked | sheet |
| [new-block](new-block.md) | SWAP ▸ in the Routine row, when a routine is picked | sheet |

## Exits

| Control | Goes to | Kind | Closes with |
|---|---|---|---|
| A routine row, such as Live Routine | [new-block](new-block.md), with that routine in the Routine row | sheet | verb |
| CANCEL | [new-block](new-block.md) | sheet | cancel |
| Swipe down | [new-block](new-block.md) | sheet | none |

CANCEL in the header closes the sheet without a pick (T38), as on the other New Block sheets.
It is the same sheet as the overview's routine picker, [split-picker](split-picker.md), since the two were merged into `RoutinePickerSheet`.

## States

| State | How to reach it | Screenshot |
|---|---|---|
| One routine, none picked | Main tour, active-block seed: a blank New Block, then + ATTACH ▸ | [17e light](img/17e-default-light-new-block-split-picker.png) |
| No routines | W16, fresh store: + ATTACH ▸; the sheet shows only its title and an empty page | [17e light fresh](img/17e-default-light-new-block-split-picker--fresh.png) |
| A routine picked | SWAP ▸ after a pick; that row shows ✓ in signal text (not captured; W16 picks a routine but does not reopen the sheet) | - |
| AX3 | Same walk at AX3; the title and row grow, and the half-height sheet still fits, on both phones | [17e AX3](img/17e-ax3-light-new-block-split-picker.png), [Pro Max AX3](img/17promax-ax3-light-new-block-split-picker.png) |

Dark mode and the Pro Max at default text change only colour and size: [17e dark](img/17e-default-dark-new-block-split-picker.png), [Pro Max](img/17promax-default-light-new-block-split-picker.png), [Pro Max fresh](img/17promax-default-light-new-block-split-picker--fresh.png).
The sheet opens at half height and can be dragged to full height by its grabber.

## Compared with the mock-up

No mock-up was drawn for this sheet.

## VoiceOver order

1. "Sheet Grabber", value "Half screen"
2. "Choose Routine"
3. "Live Routine"

Rows give only the routine's name, as on the overview's picker.
The ✓ on a picked routine is a plain "✓" text with no selected trait (from code, `fitbod/Periodization/BlockScheduleControls.swift:200`).
With no routines, VoiceOver finds nothing after the title.

## Findings

- Major: [D-05](../audit.md#d-05).
- Minor: [D-102](../audit.md#d-102).
- Polish: [D-285](../audit.md#d-285).
