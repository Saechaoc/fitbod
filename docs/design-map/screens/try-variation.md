---
id: try-variation
kind: sheet
title: Try variation
view: fitbod/Fatigue/TryVariationSheet.swift:29
tab: [today, program]
presents_from: [logger]
closes_with: done
mock: none
seed: none
captured: none
img: []
tree: none
---

The lifter looks at up to three exercises like a stalled one, to try one of them instead.

The tour has no screenshot of this sheet, because the stalled seed always suggests ADD VOLUME and never TRY VARIATION.

## Entry points

| From | Tap | Kind |
|---|---|---|
| [logger](logger.md) | The TRY VARIATION chip under a stalled exercise's STALLED badge | sheet |

## Exits

| Control | Goes to | Kind | Closes with |
|---|---|---|---|
| DONE | [logger](logger.md) | sheet | done |
| An exercise row | [logger](logger.md), with nothing changed: the logger ignores the picked exercise (`fitbod/Sessions/SessionExerciseCard.swift:338`) | sheet | verb |
| View all similar exercises in library | [logger](logger.md), with nothing changed: the button only closes the sheet (`fitbod/Fatigue/TryVariationSheet.swift:97`) | sheet | verb |
| A swipe down | [logger](logger.md) | sheet | none |

From the code: the sheet opens at half height and can be dragged to full height.
It has a "TRY VARIATION" header with DONE at the right, the section head "Exercises with similar mechanics and muscle targets:", up to three rows, and a ghost button "View all similar exercises in library".
Each row shows the exercise name and the date it was last logged.
The rows are exercises with the same mechanic and at least one shared main muscle, and only ones the lifter has logged before (`fitbod/Fatigue/TryVariationSheet.swift:132`).

## States

| State | How to reach it | Screenshot |
|---|---|---|
| Loading | Not captured: a spinner shows while the candidates load | - |
| Candidates | Not captured: no seed makes the stall suggest a variation | - |
| No candidates | Not captured: "No similar exercises found in your library." | - |
| Never logged date | Not reachable: rows read "NEVER LOGGED" when there is no log, but only logged exercises are listed (`fitbod/Fatigue/TryVariationSheet.swift:164`) | - |

## Compared with the mock-up

No mock-up exists for this sheet; the plateau mock-up only names a "Swap variation" action.

## VoiceOver order

1. TRY VARIATION
2. DONE
3. Exercises with similar mechanics and muscle targets:
4. Each exercise row, with its last-logged date
5. View all similar exercises in library

Gaps:

- Not checked: there is no tree for this sheet.

## Findings

<!-- findings are linked after the audit -->
