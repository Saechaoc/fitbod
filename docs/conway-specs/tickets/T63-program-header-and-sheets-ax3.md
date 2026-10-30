---
id: T63
title: Program's header and block sheets fit AX3, and + NEW takes a 44pt tap
phase: 1
items: []
depends_on: []
size: S
sim: small
owns: [fitbod/Periodization/ProgramView.swift, new:fitbodUITests/ProgramHeaderAndSheetsAX3UITests.swift]
---

# T63: Program's header and block sheets fit AX3, and + NEW takes a 44pt tap

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

These are findings F37 and F38, which the T15 worker found on Program.
Program's header ("PROGRAM" and "+ NEW") is a fixed 30pt row inside a fixed 34pt header.
At AX3 its text is about 38pt tall and overflows that row.
"+ NEW" is only about 39 by 14pt to tap at default text, under the 44pt minimum.
The CHOOSE PRESET sheet's rows have a fixed 52pt height and one line, so long names such as "GENERIC STRENGTH MESO" likely cut off at AX3.
That sheet and the CREATE BLOCK sheet draw fixed 16pt chevrons that do not grow with the text.

## Target

- `ProgramChromeHeader`, `NewBlockPresetPickerSheet` and the CREATE BLOCK sheet in `fitbod/Periodization/ProgramView.swift`.

## Change

1. At AX3, the header's text fits inside the header, and the header grows with it.
2. "+ NEW" takes taps across at least 44 by 44pt at every text size.
3. The "+ NEW" popover still opens right under the header at every text size.
4. At AX3, every CHOOSE PRESET row shows its whole name, wrapping if it must.
5. The chevrons in both sheets grow with the text, like the template rows' chevrons since T15.
6. At default text, the header and both sheets look exactly as they do now.

## Constraints

- Do not change `BRUHeaderBar` or other shared components; ask first if the fix seems to need it.

## Ownership

You may edit the files in `owns`, plus Program tests your change breaks.
Ask before you edit anything else.

## Repro first

In `fitbodUITests/ProgramHeaderAndSheetsAX3UITests.swift`, on the small phone with an empty store:
- At AX3, assert that the header's texts lie inside the header's frame.
- At default text, assert that "+ NEW" passes `UITestNavigation.assertTapTarget(_:minimum:)` at 44pt.
- At AX3, open CHOOSE PRESET and assert that each row's label shows the template's whole name.

These fail today.

## Observable acceptance

- The repro tests pass on the small phone.
- `ProgramEmptyStateAX3UITests` and `BlockTemplateCatalogUITests` pass on the small phone.
- `ProgramViewFidelityTests` passes with `fitbodTests`.
- Screenshots of the header and both sheets at default text and AX3 are in `screens/`, and the default-text ones match today's layout.

## Hints

- `ProgramChromeHeader.totalHeight` positions the "+ NEW" popover, so a taller header must move the popover too.
- T15 (`681cb4c`) scaled the template rows' chevron with `@ScaledMetric` near line 1241.
- `NewBlockPresetPickerSheet` is near line 721, and its row height near line 761.
