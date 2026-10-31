---
id: T32
title: Custom exercise editor and muscle picker in BRU
phase: 2
items: [20]
depends_on: [T03, T05, T31]
size: L
sim: both
owns: [fitbod/ExerciseLibrary/CustomExerciseEditor.swift, fitbod/ExerciseLibrary/CustomExerciseImagePicker.swift, fitbod/ExerciseLibrary/MuscleWeightRow.swift, fitbod/ExerciseLibrary/MusclePickerSheet.swift, fitbodTests/Phase3BRUGrepAuditTests.swift, new:fitbodUITests/CustomExerciseEditorBRUUITests.swift]
---

# T32: Custom exercise editor and muscle picker in BRU

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

The custom exercise editor is a stock iOS `Form`, with rounded cells, a segmented control, a menu picker, a slider and SF Symbols.
The muscle picker is a stock `List` with the system navigation bar and a glass "Cancel" pill.
Both look like a different app next to the BRU screens.

In the picker, Lower Back shows the region "Upper" beside it, which looks wrong.
A copy of Barbell Bench Press lists its secondary muscles before its primary one: Triceps, Shoulders, then Chest.

## Target

- The editor: `fitbod/ExerciseLibrary/CustomExerciseEditor.swift`, with its rows in `MuscleWeightRow.swift` and its image section in `CustomExerciseImagePicker.swift`.
- The picker: `fitbod/ExerciseLibrary/MusclePickerSheet.swift`.

## Change

1. Rebuild the editor as a BRU screen that follows the design T31 names in `evidence/T31/export-diff.md`.
   If T31 found no newer export, follow `bru-screens/custom-exercise.jsx` and `bru-screens/Fitbod-Session/screens/phase-1--custom-exercise.png`.
2. Keep the fields the editor has today, in the design's order:
   - the header: CANCEL, "New exercise" (or the edit title), and SAVE
   - NAME, in the display font
   - CLASSIFICATION, with Equipment and Mechanic only
   - "Primary muscle stimulus", with "Required" on the right
   - "Secondary stimulus", then "+ ADD MUSCLE"
   - the image section, then "Delete exercise" when editing
3. Leave out the design's PATTERN, TEMPO, BAR WT and INCREMENT cells, because the editor has no such fields today.
   T48 puts them on the roadmap.
4. Each muscle row shows a PRIMARY or SECONDARY chip, the muscle's display name, the design's four weight ticks, and a "REMOVE" text control.
   Tapping the chip switches the role, and the row moves to the other section.
   See "Muscle weight control" in [../tradeoffs.md](../tradeoffs.md).
5. Primary muscles always show above secondary ones, and each section lists its muscles by weight, highest first.
6. Equipment opens a BRU list of the choices, and Mechanic uses `BRUSegmentedControl`.
7. The footer shows the design's status line, such as "VALID · 2 PRIMARY MAPPED".
   While the exercise cannot be saved, it says what is missing, using today's validation rules.
8. The muscle picker becomes a BRU sheet: a `BRUHeaderBar` with CANCEL and "Add muscle", and one row per muscle.
   Each row shows only the muscle's display name, sorted by display name (see "Muscle picker labels").
9. The image section uses BRU text controls, not SF Symbols.
10. Remove the four files in Target from the exclusion list in `Phase3BRUGrepAuditTests`, so the BRU audit covers them.

## Constraints

- Keep T05's dirty guard: swipe-down is blocked while the draft has unsaved changes, and CANCEL still asks before it discards.
- Keep T03's behavior: Copy and Edit open on the first tap, and a new exercise starts with the Library search text as its name.
- Keep today's rules: the first muscle added is primary at 100%, later ones are secondary at 50%, and adding a muscle twice does nothing.
- Keep every accessibility identifier that existing tests use, such as `customExercise.name` and `musclePicker.<slug>`.
- Do not change any muscle's stored region, and do not change the SwiftData schema.

## Ownership

You may edit the files in `owns`, plus Library tests your change breaks.
Ask before you edit anything else, including `CustomExerciseDraft.swift`.

## Repro first

On both phones, write a UI test that opens the editor from the Library:

- Assert that the editor has no element of type `Slider`, `SegmentedControl` or `Switch`.
- Open the picker, and assert that no navigation bar exists and that the Lower Back row's label is exactly "Lower Back".
- Copy Barbell Bench Press, and assert that the Chest row sits above the Triceps and Shoulders rows.

All three fail today.

## Observable acceptance

- Every repro test passes on both phones.
- A UI test creates an exercise with one primary and one secondary muscle, saves it, reopens it with Edit, and finds both muscles with their roles and weights.
- `Phase3BRUGrepAuditTests` passes with the four files no longer excluded.
- `ExerciseCopyEditSheetUITests`, `EditorSwipeDismissUITests`, `CustomExerciseEntryUITests` and `MilestoneOneJourneyUITests` pass on both phones.
- Screenshots of the editor and the picker, at default text and AX3, in light and dark mode on the small phone, are in `screens/`.

## Hints

- The region text in the picker is near `MusclePickerSheet.swift:57`.
- `MuscleWeightRow.swift` has the stock slider and segmented role picker; its file comment shows the old layout.
- `SettingsView.swift` uses `BRUSegmentedControl`, and `BRUDashedSlot` suits "+ ADD MUSCLE".
- `WorkoutNotesSheet.swift` shows how a BRU sheet hides the system bar and uses `BRUHeaderBar`.
