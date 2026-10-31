---
id: T26
title: Block hero, Program rows and routine editor text fit
phase: 2
items: [37, 46, 25]
depends_on: [T12, T15]
size: M
sim: small
owns: [fitbod/Periodization/BlockOverviewScreen.swift, fitbod/Periodization/ProgramView.swift, fitbod/Periodization/SplitDetailView.swift, new:fitbodUITests/BlockAndRoutineTextFitUITests.swift]
---

# T26: Block hero, Program rows and routine editor text fit

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

Words break in the middle on the small phone:

- Block overview hero, at default text: "Accumulatio" over "n week", and "Powerbuildin" over "g".
  At AX3: "Accumul" over "ation", and "Powerbu" over "ilding".
- Program at AX3: "ACCUMULATI" over "ON", and a block's name tag, such as POWERBUILDING, runs off the screen.
- Routine editor at default text: the meta line under the title breaks mid-word.
  At AX3: "1 EXERCI" over "SE", "REM" over "OVE", and the slot number wraps "0" above "1" in a fixed 32pt column.

At every size, Program's active block row shows the phase twice: "W1 · ACCUMULATION" at the top right, and "Week 1 of 5 · Accumulation" under the name.

T20's worker also found findings F146, F147 and F148 on these screens:

- Program's ROUTINES row reads "1 sessions" for a routine with one session, because it skips the shared plural helper.
- The routine screen's "Remove Session?" dialog offers only a cancel-role "Cancel", which iOS 26 hides, so it has no visible way back.
- At AX3, XCUITest swipes on the routine screen started a session row's reorder drag instead of scrolling, and nobody has checked it with a finger yet.

## Target

- The hero labels in `fitbod/Periodization/BlockOverviewScreen.swift`.
- The block and routine rows in `fitbod/Periodization/ProgramView.swift`.
- The meta line and slot rows in `fitbod/Periodization/SplitDetailView.swift`.
- The "Remove Session?" dialog and the session rows' reorder gesture in `fitbod/Periodization/SplitDetailView.swift`.

## Change

1. On these screens, nothing breaks inside a word on the small phone, at default text or at AX3.
2. Each hero word stays whole: the hero text scales down until its longest word fits.
3. Program's block row keeps its name tag inside the screen, and its phase text wraps only between words.
   The row shows the phase once, in the line "Week 1 of 5 · Accumulation"; the top-right "W1 · PHASE" text goes.
4. The routine editor's slot number shows "01" in full at every text size.
5. "REMOVE" and the exercise count in each slot row stay whole.
6. On the large phone at default text, these screens look as they do today.
7. Program's ROUTINES row counts sessions with the shared plural helper, so one session reads "1 session".
8. The "Remove Session?" dialog gets a visible plain "Keep session" button, which closes it and changes nothing, as T20 did for "Archive routine?".
9. At AX3, a quick swipe that starts on a session row scrolls the routine screen.
   If the row's reorder gesture catches that swipe, make the reorder start only after a long press.

## Constraints

- Use the `dynamicTypeSize.isAccessibilitySize` branch for any layout change, as the worker rules say.
- Keep the BRU fonts.
- Update `BlockOverviewScreenCopyTests` and `ProgramViewFidelityTests` only where you change pinned structure on purpose.

## Ownership

You may edit the files in `owns`, plus Program and block overview tests your change breaks.
Ask before you edit anything else.

## Repro first

On the small phone, with a block named "Powerbuilding" in its accumulation phase:

- Save screenshots of the block overview hero, Program's rows and the routine editor, at default text and at AX3.
- Look at each one, and write one line per label in `notes.md`.
- Assert with frame checks that the slot number and "REMOVE" are each one line tall at AX3.
- Assert that the name tag's frame lies inside the screen at AX3.
- Assert that the block row's phase name appears in exactly one element.
- Assert that a routine with one session reads "1 session" in Program's ROUTINES row.
- Open "Remove Session?", and assert that a visible "Keep session" closes it and keeps the session.
- At AX3, press a session row for under 0.1 s, drag up, and assert that the screen scrolls and no reorder starts.

## Observable acceptance

- Every frame check passes on the small phone at default text and at AX3.
- The ROUTINES row count, "Keep session" and AX3 scroll repro tests pass on the small phone.
- The new screenshots show no word broken in the middle.
- `BlockOverviewScreenCopyTests` and `ProgramViewFidelityTests` pass with `fitbodTests`.
- Screenshots before and after, for each screen and text size, are in `screens/`.

## Hints

- The hero's phase-week label is near `BlockOverviewScreen.swift:344-349`, in the 42pt display font.
- The routine row is near `ProgramView.swift:579-599`.
  Find the block row's phase text and name tag by their text in the same file.
  The two phase texts are near `ProgramView.swift:494` and 510.
- The slot number is near `SplitDetailView.swift:518-521`, "Remove" is near 574-579, and the meta line is near 211.
- `RoutineSplitRow` in `ProgramView.swift` builds the "N sessions" text, and `BRUCountLabel.text(_:_:)` is the shared plural helper.
- T20's "Archive routine?" dialog in `SplitDetailView.swift` shows the visible plain button.
