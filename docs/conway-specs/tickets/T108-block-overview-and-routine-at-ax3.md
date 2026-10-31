---
id: T108
title: The block overview and the routine screen read cleanly at AX3
phase: 3
items: []
depends_on: [T26]
size: S
sim: small
owns: [fitbod/Periodization/BlockOverviewScreen.swift, fitbod/Periodization/SplitDetailView.swift, new:fitbodUITests/BlockOverviewAndRoutineAX3UITests.swift]
---

# T108: The block overview and the routine screen read cleanly at AX3

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F203 to F205, which T26's worker found at AX3 on the small phone.

- The routine screen's live-edit banner, "ACTIVE BLOCK / Part of active block - edits apply to upcoming workouts.", stays fixed above the scroll view.
  It takes about 140pt of the roughly 390pt between the header and the tab bar, so the first session row starts under the tab bar.
- The active block hero's stat row wraps each part over two lines: "W1 /" over "5", "VOL" over "HOLD" and "INT" over "100%".
  No word breaks, but the row reads as a grid.
- A draft block's "+ ATTACH ROUTINE ▸" puts its "▸" on a line of its own.

## Target

- The live-edit banner's place in `fitbod/Periodization/SplitDetailView.swift`.
- The active hero's stat row and the routine band's attach button in `fitbod/Periodization/BlockOverviewScreen.swift`.

## Change

1. At accessibility sizes the routine screen's live-edit banner scrolls with the page, so the first session row shows when the screen opens.
2. At accessibility sizes the active hero's stat row puts each part on its own line, without the dots between them, so "W1 / 5", "VOL HOLD" and "INT 100%" each read on one line.
3. "+ ATTACH ROUTINE ▸" keeps its "▸" on the same line as ROUTINE at every text size.

## Constraints

- Change layout only at accessibility sizes, through `dynamicTypeSize.isAccessibilitySize`, except that change 3 may hold at every size if default text looks the same.
- Keep T26's hero headline, Program rows, session rows and reorder exactly as they are.
- The banner's text and colors stay as they are.
- On both phones at default text, these screens look as they do today.

## Ownership

You may edit the files in `owns`, plus block overview and routine screen tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone at AX3, with T26's `-fitbod-seed-powerbuilding` seed:

- Open the Upper Lower routine from Program, and assert that the first session row is fully above the tab bar without scrolling.
- Open the active Powerbuilding block, and assert with the shared `readText` that "W1 / 5", "VOL HOLD" and "INT 100%" each read on one line.
- Open the draft Powerbuilding block, and assert with `readText` that "ROUTINE" and "▸" read on the same line.

All of these fail today.

## Observable acceptance

- Every repro test passes on the small phone.
- `BlockAndRoutineTextFitUITests` and `BlockOverviewStatesUITests` pass on the small phone.
- `fitbodTests` passes, and the app and the widget build.
- Screenshots of the three screens at default text and AX3 on the small phone, and at default text on the large phone, are in `screens/`.

## Hints

- The routine screen places `LiveEditBanner()` near `SplitDetailView.swift:138`.
  The session editor shows the same banner, but that screen is T38's, so leave it.
- The hero's stat row is near `BlockOverviewScreen.swift:561`, and "+ ATTACH ROUTINE ▸" is near line 910.
- A non-breaking space before "▸" is one way to keep it on ROUTINE's line.
- T26's notes and screenshots are in the main checkout's `docs/conway-specs/evidence/T26/`.
