---
id: T39
title: Number entry like a user
phase: 4
items: [5]
depends_on: [T06, T09, T19, T29, T37, T38]
size: L
sim: both
owns: [fitbod/Sessions/PrescriptionWeightCell.swift, fitbod/Sessions/SetRow.swift, fitbod/Sessions/PartialRepsRow.swift, fitbod/Sessions/TempoEntryRow.swift, fitbod/Routines/PrescriptionEditorRow.swift, fitbod/Routines/RoutineBuilderView.swift, fitbod/ExerciseLibrary/ExerciseDetailView.swift, fitbod/Settings/PlateInventoryEditor.swift, fitbodUITests/UITestNavigation.swift, new:fitbod/Design/SelectAllOnFocus.swift, new:fitbodUITests/NumberEntryUITests.swift]
---

# T39: Number entry like a user

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

Item 5 turned a target of 6 reps into 16: the user tapped the field and typed, and the digit joined the old value instead of replacing it.
T06 replaced the reps fields with steppers, but every other number field still works the same way.
The UI tests did not catch item 5, because they clear a field before they type, which no user does.
Some screens with number pads also have no DONE key, and a focused field can sit under the keyboard or a bottom bar.
The shared `UITestNavigation.hittable` helper polls in 0.5 s steps, which `docs/test-performance-guide.md` section 2.6 says not to do (finding F247, from T104's worker).
In the logger, a tap on an empty set's reps field while rest is running ends the rest but leaves the field without keyboard focus, so typing fails until a second tap (finding F264, from T101's worker).

## Target

- Every numeric text field in the app; Hints lists them.
- The shared UI test helpers in `fitbodUITests/UITestNavigation.swift`.

## Change

1. When a numeric field gains focus, its whole value is selected, so the first digit typed replaces it.
   Put this rule in one small shared modifier in `fitbod/Design/`, and use it on every numeric field.
2. Every screen with a numeric field has a keyboard DONE, styled like the one in the workout logger.
   Today only the logger has one, so add it to the session editor, exercise detail and Plate Inventory.
3. The focused field is never hidden by the keyboard, the save bar or the rest bar.
4. Add a shared typing helper to `UITestNavigation.swift`.
   It taps a field, waits for keyboard focus, types without clearing the field first, and returns the field's value.
5. Move every UI test that enters a number onto the new helper.
   Remove a private typing helper once nothing uses it.
6. `UITestNavigation.hittable` polls in 50 to 100 ms steps, with the same overall ceiling, and `waitUntilStill` checks the frame in steps that small while still requiring it to hold for its interval (findings F247 and F262).
   `type` and `hittable` read `exists` before they call `waitForExistence`, which costs about 1 s even when the element is already there (finding F274).
7. In the logger, one tap on an empty set's reps field while rest is running both ends the rest and gives the field keyboard focus, so the first digit typed lands.
8. A logger weight field that loses focus with no number in it shows the set's weight again, so the field always shows the weight the set will log (finding F354, from T125's worker; `tradeoffs.md` "Emptied weight field").
   Today a cleared field shows "—" while the set keeps, and logs, its old weight.

## Constraints

- Keep T06's steppers, T09's WHY control and T19's Plate Inventory changes exactly as they are.
- Units relabel numbers and never convert them.
- A field bound to a number with a format may need a text binding before it can select its text.
  Keep its validation and its save rules.

## Ownership

You may edit the files in `owns`, plus the UI tests you move onto the new helper.
Ask before you edit anything else.

## Repro first

With the new helper, on the small phone, write `NumberEntryUITests`, one case per screen with one launch each, because a typed digit that joins the old value logs a wrong number:

- In the session editor, give a tempo field 2, then tap that field, type 3, and assert that it reads 3.
- In the logger, tap a work set's weight field that shows a value, type a new weight, and assert that the field shows only the new weight.
- In Plate Inventory, tap the bar weight, type 20, and assert that it reads 20.
- In the logger, tap a work set's weight field that shows a value, delete every digit, tap DONE, and assert that the field shows the set's weight again (change 8).
- For each of these fields, assert that the field's frame lies above the keyboard and above any bottom bar.

Expect these to fail today, because the typed digits join the old value.
`docs/VERIFICATION.md` records the same failure at AX3: a max-reps entry became 106 instead of 10.
If one of them passes today, say so in `notes.md`.

## Observable acceptance

- Every repro test passes on the small phone (both phones are release readiness, `docs/DEVELOPMENT.md`).
- Every numeric field in Hints selects its value on focus; `notes.md` lists each field with the test that covers it.
- `MilestoneOneJourneyUITests`, `WorkoutLoggerJourneyUITests`, `WorkoutSwapJourneyUITests` and every other kept suite that types a number pass on the small phone (T143 deleted `PlateauOverrideUITests` and `PrescriptionEditorUITests`).
- No UI test clears a numeric field before it types, and `notes.md` names the search that shows it.

## Hints

- Numeric fields: `PrescriptionWeightCell.swift:81`, `SetRow.swift:149`, `PartialRepsRow.swift:48`, `TempoEntryRow.swift:67`, the tempo fields near `PrescriptionEditorRow.swift:290`, `ExerciseDetailView.swift:370`, and `PlateInventoryEditor.swift:210` and 433.
- Find them all with a search for `keyboardType(.decimalPad)` and `keyboardType(.numberPad)`.
- The logger's DONE is a keyboard toolbar near `SessionLoggerView.swift:123`.
- Put each DONE on the screen, not on each row, because a keyboard toolbar on every row shows one DONE per row.
- The session editor is `RoutineBuilderView`, which holds `PrescriptionEditorRow`; T110 removed its per-set overrides.
- SwiftUI's `TextField` accepts a text selection binding on iOS 18 and later.
- `MilestoneOneJourneyUITests.swift` has a private `replace(_:with:)` helper near line 379.
- `UITestNavigation.textLines` (and so `readText`) uses Vision's `.accurate` level, which on the simulator dropped whole words from a 390 x 60pt crop in T35's runs; say in its comment that callers read narrow, single-line crops (finding F282).
- Change 8: `PrescriptionWeightCell`'s `onChange(of: weightText)` ignores text that `Double` cannot read, and nothing writes the field again when it loses focus.
  Its `onAppear` seeds the prescription into a set whose weight is 0, so writing 0 for an empty field is not the fix.
  T125 made the cell report the weight in the field, so the set's plates (`set.plates.<suffix>`) follow it; keep that.
- The Library search field's XCUI frame spans its whole row, so `UITestNavigation.type(replacing: true)` taps its × instead of focusing it; the new typing helper should tap the field's text area (finding F293, from T37's worker).
