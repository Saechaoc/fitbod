---
id: T20
title: Archive asks first, and restore works
phase: 2
items: [44]
depends_on: [T01]
size: L
sim: both
owns: [fitbod/Periodization/SplitDetailView.swift, fitbod/Periodization/ProgramView.swift, new:fitbod/Periodization/ArchivedRoutinesView.swift, new:fitbodUITests/ArchiveRoutineUITests.swift]
---

# T20: Archive asks first, and restore works

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

Archiving a routine happens at once, with no confirmation and no undo.
Nothing in the app lists archived routines or restores them.
After an archive, the other tab keeps showing the archived routine.

## Target

- The archive action in `fitbod/Periodization/SplitDetailView.swift`.
- A new list of archived routines, reached from Program.
- Every place in the app that lists routines.

## Change

1. Archive first asks "Archive routine?".
   The dialog has "Archive" and a visible "Keep routine" (decision 7).
2. The existing deny rule still runs first.
   A routine that an active or upcoming block uses still shows today's alert, and nothing changes.
3. Program shows an "Archived routines" entry only when at least one routine is archived (see "Archived routines" in [../tradeoffs.md](../tradeoffs.md)).
4. The entry opens a list titled "ARCHIVED ROUTINES", with a RESTORE action on each row.
5. RESTORE makes the routine active again, and it shows in every routine list at once.
6. No other routine list shows an archived routine, in any tab.
7. If a routine's detail screen is still open in the other tab when the routine is archived, that screen goes back to its list.
8. A block that already uses an archived routine keeps its link and keeps working.

## Constraints

- Archive stays a soft delete through `isArchived`.
  Never hard-delete a routine.
- Filter in `@Query` predicates, not in memory, as `CLAUDE.md` says.
  `isArchived` is a stored Bool, so it is safe in a predicate.
- No schema change.
- Update `RoutinesListCopyTests` only where you change pinned copy on purpose.

## Ownership

You may edit the files in `owns`, plus UI tests your change breaks.
You may also edit any view whose routine list shows archived routines, but only to leave them out.
Ask before you edit anything else.

## Repro first

On the small phone:

- Open a routine that no active block uses, tap Archive, and assert that a confirmation appears.
  The routine is archived at once today.
- Archive a routine from Program, switch to Today, and record in `notes.md` every place that still shows it.
  Assert that it is gone from each place.
- Assert that Program offers a way to reach the archived routine.
  None exists today.

## Observable acceptance

- A UI test archives a routine through the dialog, and the routine is gone from Program and from Today.
- A UI test taps "Keep routine", and the routine stays.
- A UI test opens "Archived routines", taps RESTORE, and the routine is back in Program's list.
- A UI test proves the "Archived routines" entry is hidden when nothing is archived.
- A UI test proves that archiving a routine the active block uses still shows the alert and changes nothing.
- `SplitDeletionGuardTests` and `ProgramGraphInvariantTests` pass with `fitbodTests`.
- Screenshots of the dialog, the entry and the archived list on the small phone are in `screens/`.

## Hints

- Archive is `attemptArchive`, near lines 364-384 of `SplitDetailView.swift`.
  It checks `BlockLifecycleService.assertSplitDeletable`, then sets `isArchived`, saves and dismisses.
- These queries already leave archived routines out: `ProgramView` (near line 86), `TodaySessionPicker` (18), New Block's CHOOSE ROUTINE in `BlockBuilderView` (2056) and `BlockOverviewScreen` (1173).
- `TodayView` fetches the active block's routine by id near line 265, and that path must keep working.
- Each tab keeps its own navigation stack, so a routine's detail screen can stay open in the other tab.
