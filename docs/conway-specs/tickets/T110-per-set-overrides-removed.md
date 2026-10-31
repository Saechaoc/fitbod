---
id: T110
title: The session editor stops offering per-set overrides that the logger ignores
phase: 2
items: []
depends_on: [T29]
size: M
sim: small
owns: [fitbod/Routines/PrescriptionEditorRow.swift, fitbod/Routines/SetRowsContainer.swift, docs/ROADMAP.md, new:fitbodTests/SetRowsIgnoreOverridesTests.swift, new:fitbodUITests/PerSetOverridesRemovedUITests.swift]
---

# T110: The session editor stops offering per-set overrides that the logger ignores

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F223, which the coordinator found while routing T29's findings, with findings F221 and F222 from T29's worker.

- The session editor's "Per-set overrides" lets you give one set its own reps and RPE, and the editor's set list then shows those rows.
- Nothing applies them: `SessionFactory` builds every working set from the exercise's own prescription, so an override never reaches a workout.
- A logged set has no fields for targets of its own, so applying overrides needs new `SetEntry` fields, a schema change past SchemaV7 that this milestone does not make.
- Adding one override also hides the other default set rows, and a new override shows 0 in both fields.

## Target

- The Per-set overrides section in `fitbod/Routines/PrescriptionEditorRow.swift`.
- The set list in `fitbod/Routines/SetRowsContainer.swift`.

## Change

1. The session editor no longer shows "Per-set overrides", its count, its rows or "+ ADD OVERRIDE".
2. The set list shows the exercise's own prescription for every set, as the logger will log it, even when the exercise has stored overrides.
3. Stored overrides stay as they are: no data is deleted, and backup, export and duplication keep carrying them.
4. Add one line for the removed section to `docs/ROADMAP.md` under "Removed in Milestone 1 closeout", as the worker rules describe.
5. Add one line under "Decisions awaiting product direction": per-set targets need target fields on logged sets, which is a schema change.

## Constraints

- No schema change, and no change to `SessionFactory`, the routine draft or the models.
- Keep T29's other session editor changes as they are.
- Leave `PerSetOverrideRow.swift` in place for a later milestone, even if nothing shows it, and say so in `notes.md`.

## Ownership

You may edit the files in `owns`, plus session editor tests your change breaks, such as `SessionEditorPolishUITests`, `RoutineBuilderCopyTests` and `RoutineBuilderBRUCopyTests`.
Ask before you edit anything else.

## Repro first

- On the small phone, give set 1 of a session's only exercise an override of 5 reps at RPE 9, save, start that session from Today, and record in `notes.md` what the logger shows for set 1.
- In `PerSetOverridesRemovedUITests`, open the session editor, and assert that no element reads "Per-set overrides" or "Add override".
  It fails today.
- In `SetRowsIgnoreOverridesTests`, assert that the set list's rows for an exercise with a stored override on set 1 match its own prescription.
  It fails today.

## Observable acceptance

- Both repro tests pass, the UI test on the small phone.
- `SessionEditorPolishUITests`, `PrescriptionEditorUITests` and `RoutineBuilderBRUUITests` pass on the small phone.
- `fitbodTests` passes, including the backup, export and duplication tests that carry overrides.
- `docs/ROADMAP.md` has both lines.
- Screenshots of the session editor before and after are in `screens/`.

## Hints

- The section is near `PrescriptionEditorRow.swift:295-380`, and its state is `showingPerSetOverrides`, near line 45.
- `SetRowsContainer` switches to the override rows near line 48.
  To test its rows without a view, move the choice of rows into a function the test can call.
- `SessionFactory` builds the working sets from `re.targetSets` near `SessionFactory.swift:286-316`, and `SetEntry` has no target fields.
- The model's own comment in `RoutineExerciseSetOverride.swift` describes the fallback that was never built.
