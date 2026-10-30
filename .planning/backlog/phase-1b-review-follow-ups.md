---
status: backlog
created: 2026-10-29
risk: medium (item 1), low (items 2-4)
scope: four open follow-ups; item 5 is done
sources:
  - .planning/quick/261029-a9s-m1-phase-1b-target-reps-entry-that-corru/261029-a9s-SUMMARY.md
---

# Backlog: follow-ups from the Phase 1B (261029-a9s) review

A review of branch `undine` (review items 4, 5, 6 and 34) found five problems.
The first, the exercise card's press-and-hold menu taking long presses on the
new RPE chips, was fixed on the branch in `c35e0eb`. The other four are logged here as
items 1-4. Fixing the first turned up item 5 in the workout logger, which
conway ticket T49 then covered on the same branch in `c25645e`.
No current plan or roadmap item covers items 1-4.

## 1. Per-set override rows still corrupt typed reps

- **Where:** `fitbod/Routines/PerSetOverrideRow.swift:55-80` (EDIT PRESCRIPTION →
  Per-set overrides → + ADD OVERRIDE).
- **Problem:** Each override row still uses the 44pt-wide
  `TextField(value:format:)` that review items 5 and 6 replaced in the main
  rows. Tap a 6 and type 8, and the caret can put the 8 before or after the 6,
  giving 86 or 68. An empty override shows "0", and typing 0 is still the only
  way to clear an override RPE.
- **Fix:** Reuse the controls the main rows now use: a `BRUStepper` with
  `1...RoutineExerciseDraft.maxTargetReps` for reps, and
  `InlineRPEChipRow(rpe:noneLabel:)` for RPE. They do not fit the compact
  one-line row, so the row needs a small redesign; check it at 390pt and 440pt.
  Add a UI test like `PrescriptionEditorUITests.testHighRepsChangesFromSixToEight`.

## 2. Old export file types keep sharing code nothing uses

- **Where:** `fitbod/Export/CSVFile.swift:28-45`, `fitbod/Export/JSONFile.swift:18-35`,
  `fitbod/Backup/FitbodBackupFile.swift:33-50`.
- **Problem:** Settings now shares through `CSVExportItem`, `JSONExportItem` and
  `BackupShareItem` (`fitbod/Export/ExportShareItems.swift`), which read only
  `.data` or `.url`. The `Transferable` conformance and `transferRepresentation`
  of the three old types, and their `filename` field, are no longer used anywhere.
- **Fix:** Remove the conformance, the `transferRepresentation` blocks, the
  `CoreTransferable` and `UniformTypeIdentifiers` imports, `filename` (and the
  `filename:` arguments at `ExportService.swift:50,59` and
  `BackupArchiver.swift:123`), and the comments that explain the old sharing.
  About 40 lines.

## 3. The accessibility doc describes the removed long press

- **Where:** `docs/design-system/accessibility.md:27-29`.
- **Problem:** It says prescribed weights offer an "Explain prescribed weight"
  action alongside a long press, and that this still needs a device rerun. The
  long press is gone, the action is now "Why this weight", and each set row has
  a visible WHY button.
- **Fix:** Rewrite the bullet: a visible WHY button at the start of each set's
  RPE-chip line, plus a "Why this weight" action on the weight cell.

## 4. Two copies of the logger scroll helper have drifted

- **Where:** `fitbodUITests/WhyThisWeightControlUITests.swift:85-104`
  (`revealInLogger`), `fitbodUITests/MilestoneOneJourneyUITests.swift:328-352`
  (the set-input branch of `reveal`).
- **Problem:** Both scroll a logger row into the gap between the fixed workout
  header and the keyboard before tapping it, with copied math. They already
  disagree on the keyboard's DONE-bar height (66pt and 58pt).
- **Fix:** Move `revealInLogger` into `UITestNavigation`
  (`fitbodUITests/WorkoutUITestNavigation.swift`) and call it from the journey
  test's set-input branch.

## 5. Done: in the logger, holding an RPE chip opened the set-type menu

- **Status:** done in `c25645e` (conway ticket T49). `SetTypeChip` is now a
  `Menu` with tap-to-cycle as its primary action, and a working set's set label
  (S1) opens the same menu. `RPEDecimalHoldUITests` covers the logger hold.
- **Where:** `fitbod/Sessions/SetTypeChip.swift:52` (the `.contextMenu`),
  inside each set row of the logger `List` (`fitbod/Sessions/SetRow.swift`, line 2).
- **Problem:** In a `List`, a `.contextMenu` anywhere in a row covers the whole
  row. Holding "RPE 8" on set 1 opens "Working / Warm-up / Drop Set / To Failure
  / Rest-Pause" with the whole row as its preview, so a decimal RPE such as 8.5
  cannot be logged. This predates 261029-a9s: the chip's own long press never
  fired before that fix. The editor is a `ScrollView`, so it is not affected.
