---
id: T40
title: Slotted session delete guard
phase: 4
items: []
depends_on: [T01, T20, T38]
size: M
sim: small
owns: [fitbod/Periodization/SplitDetailView.swift, new:fitbodUITests/SlottedSessionDeleteUITests.swift]
---

# T40: Slotted session delete guard

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

A routine slot links to its session with SwiftData's `.deny` delete rule.
The code comments say this rule refuses a hard delete of a session while a routine still uses it.
The unit test `ProgramGraphDeleteRuleBehaviorTests.slottedTemplateDenyRuleRuntimeEnforcement` cannot prove that at runtime, because SwiftData enforces the rule with a process abort.
So the test records a known issue instead.
Nobody has checked which delete paths a user can reach.
No test removes a session from a routine and then relaunches, so nobody knows whether that removal is saved.

## Target

Every place in `fitbod/` that deletes a session template (`SessionTemplate`), a routine slot (`SplitSessionSlot`) or a routine (`Split`), including bulk deletes.
A routine delete removes its slots too.

## Change

1. List every such delete in `delete-paths.md`: the file and line, how a user reaches it, and whether a routine can still hold the session at that moment.
2. Prove each path's reachability from the four tabs and the Settings sheet, with a call chain or a UI test.
3. Write the UI tests in "Repro first".
4. If a reachable path fails, crashes or loses its change after a relaunch, fix it as Hints describes, and keep its test as the regression test.
   Any other fix needs the coordinator's approval first.
5. Write `closeout-statement.md`: a few sentences that say exactly what is proven, with test names, and what is not proven.
   T47 copies it into the closeout report.

## Constraints

- Do not change the schema or any delete rule.
- Do not edit the known-issue test.
- Restore from a backup deletes every session in bulk.
  T41 owns restore, so only record that path here.
- If every reachable path works, change no app code.

## Ownership

You may create the new test file and write evidence.
You may edit `removeSlot` in `SplitDetailView.swift`, only for the fix in Hints, and only after its repro test fails.
Ask before you edit anything else.

## Repro first

On the small phone, write `SlottedSessionDeleteUITests`:

- Remove a session from a routine in the routine editor.
  Assert that no save error appears and that the routine shows one fewer session.
  Relaunch without the reset flag, and assert that the routine still shows one fewer session.
  Assert that the removed session still exists and can be added to the routine again.
- Archive a session that a routine uses, from the session editor.
  Assert that the app keeps running, and that the session's logged workouts still show in history after a relaunch.

There may be no bug.
If a test crashes the app or fails, save the summary to `repro-fail.txt`.
If both pass at once, say "not reproduced" in `notes.md`, keep both tests as regression tests, and finish the listing and the statement.

## Observable acceptance

- `delete-paths.md` lists every delete of a session, a slot or a routine, and each row says how it was checked.
- Both UI tests pass on the small phone, including the steps after the relaunch.
- `closeout-statement.md` exists and names each test it relies on.
- `fitbodTests` passes with the one known issue and nothing else.

## Hints

- Search for `.delete(` and `delete(model:` in `fitbod/`.
- In Core Data, which SwiftData is built on, a delete rule acts when the model that holds the relationship is deleted.
  So the `.deny` rule on the slot's session link may refuse the slot delete itself, not only a session delete.
- `removeSlot` in `SplitDetailView.swift` deletes the slot, saves, and shows a save error when the save fails.
  The routine editor's remove is in Edit mode, as a "Remove" button and a VoiceOver action named "Remove".
- If the slot delete is refused, clearing the slot's session link before the delete avoids the deny rule without a schema change.
- "Archive session" is in the session editor's ••• menu in `RoutineBuilderView.swift`.
- `RoutinesListView.swift` hard-deletes a session in `handleDelete`, but only its previews seem to create that view.
  Prove whether any screen reaches it, and report it as dead code if none does.
  Do not delete it.
- `RoutineCreator.swift` deletes a new routine only when its first save fails, before it has any slots.
- `BackupRestorer.swift` deletes every model type in bulk, except routines and slots (see T41).
