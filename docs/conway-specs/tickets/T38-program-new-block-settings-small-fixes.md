---
id: T38
title: Small fixes on Program, New Block and Settings
phase: 3
items: [25]
depends_on: [T11, T16, T25, T29]
size: L
sim: small
owns: [fitbod/Periodization/BlockBuilderView.swift, fitbod/Periodization/BlockNameField.swift, fitbod/Settings/MuscleVolumeTargetEditor.swift, fitbod/Routines/RoutineBuilderView.swift, fitbod/Periodization/ArchivedRoutinesView.swift, new:fitbodUITests/SmallFixesUITests.swift]
---

# T38: Small fixes on Program, New Block and Settings

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

- In New Block, the CHOOSE ROUTINE sheet has no close button.
- New Block's CANCEL, in the bottom bar, has low contrast.
- Settings → Volume Targets goes back with a bare "‹".
- The volume target rows expand when tapped, but nothing shows that they can.
- The session editor, opened from a routine, is a sheet that closes with "‹ BACK", while other editing sheets close with "CANCEL".
- At default text on the small phone, the ARCHIVED ROUTINES title wraps onto two lines in its header (finding F149, from T20's screenshots).
- After Volume Targets closes, its muscle rows stay in the accessibility tree for more than 12 seconds, so VoiceOver may still find them (finding F182, from T18's worker).
- New Block's mode chips, day chips and sheet steppers are smaller than 44pt at default text (finding F193, from T25's worker).
- At AX3, a named block's name field cuts its value off, such as "GENERIC STREN…" (finding F192).
- At AX3, the progression chart's LOW label sits under the intensity line's first point (finding F190, from T25's screenshots).

## Target

- The CHOOSE ROUTINE sheet and the bottom bar in `fitbod/Periodization/BlockBuilderView.swift`.
- The header and rows in `fitbod/Settings/MuscleVolumeTargetEditor.swift`.
- The header in `fitbod/Routines/RoutineBuilderView.swift`.
- The header in `fitbod/Periodization/ArchivedRoutinesView.swift`.

## Change

1. The CHOOSE ROUTINE sheet gets a visible "CANCEL" in a BRU header, which closes it without choosing.
2. New Block's CANCEL text meets 4.5:1 contrast on its background, and its outline meets 3:1, in light and dark mode.
3. Volume Targets goes back with "‹ BACK".
4. Each volume target row shows an expand marker: use the one other expandable BRU rows use, or "▸" when closed and "▾" when open.
   VoiceOver reports whether the row is expanded.
5. The session editor's left header action reads "CANCEL" (see "Sheet close labels" in [../tradeoffs.md](../tradeoffs.md)).
   It keeps today's behavior: with unsaved changes it asks before it discards.
6. At default text on the small phone, the ARCHIVED ROUTINES title fits on one line in its header, in the BRU header font.
7. Volume Targets' rows leave the accessibility tree as soon as the screen closes, as Plate Inventory's do.
8. New Block's mode chips, day chips and sheet steppers each have a touch target of at least 44pt, with their look unchanged.
9. At AX3 the block name field shows a named block's whole name, wrapping between words if it must.
10. At AX3 the chart's HIGH and LOW labels stay clear of the plotted lines.

## Constraints

- Keep T11's two saves, T16's dark-mode colors and T25's layout exactly as they are.
- Keep T29's session editor changes.
- `BlockBuilderView.swift` changes need all six New Block guardrail suites.

## Ownership

You may edit the files in `owns`, plus tests that pin the copy you change on purpose.
Ask before you edit anything else.

## Repro first

On the small phone, write `SmallFixesUITests`:

- Open CHOOSE ROUTINE in New Block, and assert that a "CANCEL" button exists in the sheet.
- Open Settings → Volume Targets, and assert that "‹ BACK" exists.
- Assert that a volume target row's accessibility value says whether it is expanded.
- Open a session from a routine, and assert that the session editor's left header action is "CANCEL".
- Save screenshots of New Block's bottom bar in light and dark mode, sample CANCEL's text and background, and assert a contrast of at least 4.5:1.
- Archive a routine, open Program's Archived routines, and assert that its title is one line tall.
- Close Volume Targets with "‹ BACK", and assert that its first muscle row is gone from the accessibility tree within 2 seconds.
- Assert that each New Block mode chip, day chip and sheet stepper is at least 44pt in each dimension.
- At AX3, pick the Generic Strength Meso preset, and assert that the name field reads the whole name.

All of these fail today.

## Observable acceptance

- Every repro test passes on the small phone.
- `NewBlockModalUITests`, `MuscleVolumeTargetEditorUITests` and `RoutineBuilderBRUUITests` pass on the small phone.
- `fitbodTests` passes, including the six New Block guardrail suites.
- Screenshots of each fixed control are in `screens/`.

## Hints

- The CHOOSE ROUTINE sheet is near `BlockBuilderView.swift:2055-2099`, and the bottom bar's CANCEL is in `NewBlockBottomActionBar`, near line 2152.
- CANCEL uses `NewBlockScreenTokens.muted` today.
- The bare "‹" is near `MuscleVolumeTargetEditor.swift:49`, and the row toggle is near line 113.
- The session editor's header is near `RoutineBuilderView.swift:159`, and `handleDiscard()` holds the ask-first rule.
- `BRUHeaderBar.slots(left: .back, center: "Archived routines")` builds the Archived routines header, and its right slot is empty.
- `ArchiveRoutineUITests` reaches the Archived routines list.
