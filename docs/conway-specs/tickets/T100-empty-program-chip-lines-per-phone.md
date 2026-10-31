---
id: T100
title: The empty Program test expects the chip lines each phone draws
phase: 1
items: []
depends_on: [T15]
size: S
sim: both
owns: [fitbodUITests/ProgramEmptyStateAX3UITests.swift, fitbodUITests/UITestNavigation.swift]
---

# T100: The empty Program test expects the chip lines each phone draws

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F143, from Gate 1.
Gate 1 runs the full suite on the large phone, and `ProgramEmptyStateAX3UITests` fails there in `testEmptyProgramKeepsItsLayoutAtDefaultText`.
At default text the test expects CUSTOM to wrap to a second chip line, a layout that T10 measured on the 390pt small phone.
On the 440pt large phone, WEEKS · 4-12, PHASES · 1-4, DELOAD OPTIONAL and CUSTOM all fit on one line, so the check "CUSTOM wraps to the second chip line" fails with 406.5 against 406.5.
The gate's screenshot shows the four chips whole and apart on that one line, which is the right layout for that width.

## Target

- The chip line check in `testEmptyProgramKeepsItsLayoutAtDefaultText`, in `fitbodUITests/ProgramEmptyStateAX3UITests.swift`.

## Change

1. At default text the test expects the chip lines the phone draws.
   On the small phone, WEEKS, PHASES and DELOAD OPTIONAL share the first line and CUSTOM wraps to the second.
   On the large phone, all four chips share one line.
   On any other width, the test fails with a message that names the width.
2. Tell the phones apart the way `UITestNavigation.saveScreenshot` names them, from the screen width, by letting tests read the phone it already works out instead of repeating the 390pt and 440pt widths.
3. The test's other checks stay as they are: the 71pt button, no overlaps, the 77pt rows and the weeks beside each name.
4. The doc comment above the test names both chip layouts.

## Constraints

- Test-only, so no app code changes.
- Screenshot names stay as they are.

## Ownership

You may edit the files in `owns`, plus tests your change breaks.
Ask before you edit anything else.

## Repro first

- Run `testEmptyProgramKeepsItsLayoutAtDefaultText` on the large phone and see it fail at the check that CUSTOM wraps to the second chip line.

## Observable acceptance

- `ProgramEmptyStateAX3UITests` passes on the small phone and on the large phone.
- The empty Program screenshots at default text from both phones are in `screens/`.

## Hints

- The chip checks are near `ProgramEmptyStateAX3UITests.swift:120-124`.
- `phoneName(width:)` in `fitbodUITests/UITestNavigation.swift` returns "small" for 390pt and "large" for 440pt.
- The gate attached `T15-program-empty-large-default-light`, which shows the four chips on one line.
