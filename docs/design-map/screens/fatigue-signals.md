---
id: fatigue-signals
kind: sheet
title: Fatigue signals
view: fitbod/Fatigue/DeloadSignalDetailSheet.swift:39
tab: today
presents_from: [today, logger]
closes_with: done
mock: none
seed: none
captured: none
img: []
tree: none
---

The lifter reads which fatigue signals fired and decides whether to deload.

No screenshot exists: the sheet needs three finished workouts that fire a fatigue signal, and no seed makes them; this page is written from the code.

## Entry points

| From | Tap | Kind |
|---|---|---|
| [today](today.md) | the body of the "▲ CONSIDER DELOAD" banner | sheet |
| [logger](logger.md) | the CONSIDER DELOAD chip on an exercise card | sheet |

## Exits

| Control | Goes to | Kind | Closes with |
|---|---|---|---|
| DONE (header, right) | the screen it came from | sheet | done |

The sheet opens at half height and can be dragged to full height or down to close.

## States

| State | How to reach it | Screenshot |
|---|---|---|
| e1RM drop | not captured: e1RM falls over the last 3 workouts against the 3 before; reads "{N}% drop over last 3 vs prior 3 sessions" | none |
| RPE creep | not captured: RPE rises at the same load; reads "+{x} RPE at same load ({exercise}, {intent})" | none |
| Missed rep range | not captured: sets fall below the target rep range | none |

Only the signals that fired are listed.
A footer under them reads "This is an advisory. Block schedule is canonical - deload when you decide, not automatically."

## Compared with the mock-up

No mock-up was drawn for this sheet.

## VoiceOver order

No accessibility tree exists because the sheet was not captured.
From the code, the order is the title "Fatigue Signals", the DONE button, one row per fired signal, then the footer.

## Findings

- Polish: [D-251](../audit.md#d-251), [D-252](../audit.md#d-252).
