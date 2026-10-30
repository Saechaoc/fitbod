# 261029-a9s SUMMARY: Milestone 1, Phase 1B

Branch `undine` (Orca worktree `q-261029-a9s`), based on `48e09ca`.
The coordinator rebased the four commits onto `main` (`9be17d6`), so the commit tables below show the hashes on `main`.
The worker's hashes were `e801df5` (item 5), `93897c8` (item 6), `199375b` (item 4) and `34ce818` (item 34); its own runs below cite them.
Simulators: "sw6 iPhone 17 Pro Max" `69E32D56-148D-40A7-9D1B-543F6878B1D1` (440pt) and "sw6 iPhone 17e" `FF89B400-1160-4818-8436-314B014D2614` (390pt), default text size, light appearance.
GitNexus cannot parse Swift on this machine, so every impact rating below is a manual caller check (`rg`) with my own estimate, and every detect file is `git diff --cached --stat` plus the changed symbols.

Baseline on the Pro Max before any change (HEAD `48e09ca`), the two failures this plan owns:

- `MilestoneOneJourneyUITests.swift:412: XCTAssertEqual failed: ("106") is not equal to ("10") - Text replacement must not retain a prefix or suffix`.
- `WhyThisWeightSheetBRUUITests/testWhyThisWeightSectionHeadVisible`: `UITestNavigation.swift:54: XCTAssertTrue failed - Expected a visible control: "Why this weight" StaticText`.

Both pass now on both phones (details below).

## Task 1: Items 5 and 6 - reliable target reps, one RPE control, and a journey test that enters numbers like a user

### Commits

| Item | Commit | Message |
|---|---|---|
| 5 | `4dc68fb` | fix(routines): target reps step instead of typing, and low never passes high |
| 6 | `2529e90` | fix(routines): target RPE is one control with an explicit no-target choice |

Detect files: `261029-a9s-detect-item5.txt` (7 files, own estimate LOW-MEDIUM), `261029-a9s-detect-item6.txt` (3 files, LOW-MEDIUM).
The journey-test change is in the item 5 commit: it cannot land earlier (the steppers did not exist) or later (item 5 removes the text fields the old journey typed into), and every commit had to stay green.

### Files touched

- Item 5: `fitbod/Routines/PrescriptionEditorRow.swift`, `fitbod/Routines/RoutineDraft.swift`, `fitbodTests/RoutineBuilderCopyTests.swift`, `fitbodUITests/MilestoneOneJourneyUITests.swift`, `fitbodUITests/UITestNavigation.swift`, new `fitbodTests/TargetRepsRangeTests.swift`, new `fitbodUITests/PrescriptionEditorUITests.swift`.
- Item 6: `fitbod/Routines/PrescriptionEditorRow.swift`, `fitbod/Sessions/InlineRPEChipRow.swift`, `fitbodUITests/PrescriptionEditorUITests.swift`.

### What changed

- Item 5: the two reps `TextField(value:format:)` fields are two `BRUStepper`s, "Min reps" and "Max reps" (44pt − and + cells).
  `RoutineExerciseDraft` gained `maxTargetReps` (50) and the computed `targetRepsLowRange` / `targetRepsHighRange`: low stops at high and high stops at low, so stepping can never cross them.
  The ranges stay valid for values typed before this fix (0, 68, low above high), so the editor never builds an inverted `ClosedRange`.
  No stored property, so no schema change.
- Item 6: the two RPE fields bound to one value are now one control: the logger's `InlineRPEChipRow` (6-10, long press a chip for a decimal) inside a container with identifier `prescription.rpe`.
  `InlineRPEChipRow` gained an optional `noneLabel`; the editor passes "No target", which adds a trailing NO TARGET chip that clears the RPE.
  The logger passes nothing and is unchanged.
- Journey test: a new `enter(_:into:)` replaces `replace(_:with:)`.
  Numbers are typed only by tapping and typing, with no deletion first; the exact-value check after typing catches any leftover digit.
  A prefilled name ("Untitled routine") is selected with a triple tap and typed over, so nothing depends on where a tap leaves the caret (review item 5's "Test" note).
  Sets and reps are stepped with the shared `UITestNavigation.step(_:to:)`.

### Tests added

- `fitbodUITests/PrescriptionEditorUITests.swift`
  - `testHighRepsChangesFromSixToEight`: a new barbell bench press (4-6 reps), step high from 6 to 8, the stepper reads 8 and the chip reads "4–8 reps"; then low is stepped to 8 and neither + on low nor − on high moves past the other; the stepper is at least 44pt tall.
  - `testTargetRPEIsOneControlThatSurvivesReopening`: exactly one `prescription.rpe` control; RPE 8 → 9; save; reopen from the session's Edit; "RPE 9"; NO TARGET; save; reopen; "RPE —" (screenshot attached).
- `fitbodTests/TargetRepsRangeTests.swift` (Swift Testing, 3 tests, 8 cases): each end stops at the other and follows it; equal ends cannot cross (1, 6, 50); stored out-of-range values give valid ranges.

### Failing-first evidence (Pro Max, before each fix)

- Item 5, typed the way a user does (tap the 6, type 8): `PrescriptionEditorUITests.swift:25: XCTAssertEqual failed: ("Optional("86")") is not equal to ("Optional("8")") - Raising the top of the rep range must give 8`.
- Item 6: `PrescriptionEditorUITests.swift:36: XCTAssertEqual failed: ("2") is not equal to ("1") - Target RPE must be a single control`.
- Journey, unchanged code: `("106") is not equal to ("10")` (baseline above).
- Unit: `TargetRepsRangeTests` uses API that did not exist before the fix (`targetRepsLowRange`, `targetRepsHighRange`, `maxTargetReps`).
- The UI tests were first written against the old text fields (tap, type) and ran red as above; after each fix their interaction moved to the new controls (step, tap a chip) and their assertions stayed the same.

### Results after the fixes

| Run | Pro Max | 17e |
|---|---|---|
| `PrescriptionEditorUITests` (2) | pass | pass |
| `MilestoneOneJourneyUITests` (3, including the authored journey) | pass | pass |
| `RoutineBuilderBRUUITests` (2) | pass | pass |
| `SessionLoggerBRUUITests` (3), after the `InlineRPEChipRow` change | pass | pass (in the Task 2 run) |
| Swift Testing: `TargetRepsRange`, `RoutineBuilderCopy`, `RoutineBuilderBRUCopy`, `SessionLoggerCopy`, `SessionLoggerBRUCopy`, `BRUGrepAudit`, `Phase3BRUGrepAudit`, `RoutineBuilderHeaderPickers`, `SessionWidgetsBRUCopy`, `PrescriptionDefaults`, `RoutineDraftValidation`, `PrescriptionEditorBlockCaseFilter` (69 tests) | pass | `TargetRepsRange` + `RoutineBuilderCopy` pass |
| Full suite at HEAD `34ce818` (see Task 2) | pass | not run |

No new build warnings; the only warning is the existing `BlockBuilderView.swift:736` deprecated `Text` `+`.

### Impact ratings (GitNexus unavailable - manual caller check)

| Symbol | Callers | Own estimate |
|---|---|---|
| `PrescriptionEditorRow` | `RoutineExerciseCard.swift:91` (+ own preview) | MEDIUM: every exercise in the session editor |
| `RoutineExerciseDraft` (new computed ranges only) | `PrescriptionEditorRow` | LOW |
| `InlineRPEChipRow.init(rpe:noneLabel:)` | `SetRow.swift:222` (logger, no `noneLabel`, unchanged), `PrescriptionEditorRow`, previews | LOW-MEDIUM |
| `MilestoneOneJourneyUITests.replace` → `enter` | own file only | LOW |
| `UITestNavigation.step` / `tapStepper` (new) | `PrescriptionEditorUITests`, `MilestoneOneJourneyUITests` | LOW |

### Deviations and observations

- The editor's "Reps" label became "Min reps" and "Max reps", because each `BRUStepper` needs its own label; `RoutineBuilderCopyTests` now anchors the two new labels.
- `-fitbod-reset-store` reset race: not observed in any run (6 authored-journey runs across both phones, including the full suite).
- Simulator flake: once, after many runs, the Pro Max stopped reporting idle after typing into the exercise picker ("App animations complete notification not received", 60 s per step), as the Phase 1A worker saw. I stopped the run, rebooted the Pro Max, and the same tests passed (30 s and 48 s).
- xcodebuild spent about 10 minutes after each finished run in `simctl diagnose --timeout=600`; my runs pass `-collect-test-diagnostics never`.
- Not fixed (outside this task): `RoutineDraft.snapshotHash()` ignores reps and RPE, so changing only them does not arm the Discard prompt.

## Task 2: Items 4 and 34 - a visible WHY control with working Use and Override, and one-tap export and backup

### Commits

| Item | Commit | Message |
|---|---|---|
| 4 | `5d234ba` | fix(workout): a visible WHY opens Why-this-weight, and Use and Override work |
| 34 | `d936b32` | fix(settings): one tap on Export CSV, Export JSON or backup CREATE shares |

Detect files: `261029-a9s-detect-item4.txt` (7 files, own estimate MEDIUM: every logger set row), `261029-a9s-detect-item34.txt` (8 files, LOW-MEDIUM).

### Files touched

- Item 4: `fitbod/Sessions/PrescriptionWeightCell.swift`, `fitbod/Sessions/SetRow.swift`, `fitbod/Sessions/WhyThisWeightSheet.swift`, `fitbodUITests/WorkoutUITestNavigation.swift`, `fitbodUITests/WhyThisWeightSheetBRUUITests.swift`, new `fitbodUITests/WhyThisWeightControlUITests.swift`, new `fitbodTests/SetRowWhyLayoutTests.swift`.
- Item 34: `fitbod/Settings/SettingsView.swift`, new `fitbod/Export/ExportShareItems.swift`, header comments in `fitbod/Export/ExportService.swift`, `fitbod/Export/CSVFile.swift`, `fitbod/Export/JSONFile.swift` and `fitbod/Backup/FitbodBackupFile.swift`, new `fitbodUITests/SettingsExportUITests.swift`, new `fitbodTests/ExportShareItemsTests.swift`.

### What changed

- Item 4, WHY: a BRU text button "WHY" (`labelSmall`, ink, 44x44 hit area, identifier `set.why.<exercise>.S<n>`, VoiceOver "Why this weight") at the leading end of each set row's second line, in the 40pt indent under the set label.
  It shows on exactly the rows where the old long press could open the sheet (an explanation exists); the RPE chips move 10pt right.
  `SetRow` owns the presentation state and hands it to `PrescriptionWeightCell` through a new optional `isExplaining` binding; previews and the existing unit tests keep the cell's own state.
- Item 4, keyboard: whenever the sheet opens, the cell ends editing (`resignFirstResponder`, as the logger's DONE does), so the keyboard never covers it; the field's focus change still persists any edit.
- Item 4, Use: writes `roundedWeight` into the set (text, weight, and the manual-override flag by the same rule as typing), persists through `onEditCommitted`, and the sheet closes.
- Item 4, Override: `WhyThisWeightSheet` gained a defaulted `onOverride`; the cell focuses the weight field once the sheet is gone.
- Item 4, removed: the simultaneous long press (the review's cause: the `TextField` takes the touch) and its "Long press for prescription breakdown." hint.
  Nothing else depended on it; the two Why tests now open the sheet with WHY.
  The weight cell's accessibility action "Explain prescribed weight" is now "Why this weight" (added through `.accessibilityActions` only when an explanation exists).
- Item 34: `CSVExportItem` and `JSONExportItem` (`DataRepresentation`) and `BackupShareItem` (`FileRepresentation`, `.fitbodBackup`) render through `ExportService` and `BackupArchiver` only when the share sheet asks for the file.
  Each Settings control is one `ShareLink` with a `SharePreview` of the dated file name.
  Each item reports on the main actor whether rendering worked; Settings shows the same inline errors as before ("Couldn't prepare export. Try again.", "Couldn't create backup. Try again.") and clears them after a render that works.
  The render-then-swap state and `renderCSV`/`renderJSON`/`renderBackup` are gone; `ExportCard` lost its spinner (the share sheet shows its own progress while an activity loads the file).
  CREATE's label got `.contentShape(Rectangle())`, so its whole 44pt cell is tappable.

### Tests added

- `fitbodUITests/WhyThisWeightControlUITests.swift` (3, screenshots attached)
  - `testWhyOpensSheetWithKeyboardDismissed`: focus set 1's reps (keyboard up), one tap on WHY, the "Why this weight" head appears and is hittable, and the keyboard is gone.
  - `testUseWritesSuggestedWeight`: type 90 over the prescribed weight, WHY, read the suggestion from "Use N ▸", tap it, the sheet closes and the weight field reads N.
  - `testOverrideFocusesWeightField`: WHY, Override, the sheet closes and the weight field has keyboard focus.
- `fitbodTests/SetRowWhyLayoutTests.swift` (Swift Testing, 1 test, 3 cases: drop, failure, warm-up): a real `SetRow` with an explanation, measured at 358pt (the 17e's 390pt minus the card's padding), is exactly as tall as a working-set row, so WHY, the five RPE chips and a set-type chip stay on one line.
  A throwaway check at 300pt (deleted before the commit) confirmed the measurement does see a wrap.
  This is a guard for the coordinator's layout condition, not a failing-first test: without WHY the line already fit.
- `fitbodUITests/SettingsExportUITests.swift` (3): one tap on Export CSV, Export JSON or CREATE shows the share sheet (`ActivityListView`, screenshot attached), then a tap outside it (`PopoverDismissRegion`) closes it without sharing.
- `fitbodTests/ExportShareItemsTests.swift` (Swift Testing, 4): making an item renders nothing; exporting it renders the CSV header row, a JSON document with `formatVersion` 1, or a ZIP backup (`PK`), and reports success; a failed render is reported and rethrown.
- Changed: `WhyThisWeightSheetBRUUITests` opens the sheet through WHY (`UITestNavigation.openWeightExplanation`), and `testWhyThisWeightHeroSlabAppearsAfterLongPress` is renamed `testWhyThisWeightHeroSlabAppearsAfterWhyTap`.

### Failing-first evidence (Pro Max, app at the Task 1 commits, before any Task 2 app change)

- Item 4, all three new tests: `WhyThisWeightControlUITests.swift:70: XCTAssertTrue failed - Set 1 must show a visible WHY control`.
  Baseline: `testWhyThisWeightSectionHeadVisible` failed with `Expected a visible control: "Why this weight" StaticText` (the review: the long press left the keyboard over the section head).
- Item 34: `SettingsExportUITests.swift:16`, `:21` and `:26: XCTAssertTrue failed - One tap on Export CSV / Export JSON / backup CREATE must open the share sheet`.
  A throwaway probe then tapped Export CSV a second time, and the share sheet appeared: the two-tap bug.
- Unit: `ExportShareItemsTests` uses types the fix adds.
- Test-only changes after the fix: the WHY tests scroll WHY into the band between the fixed workout header and the keyboard's DONE bar before tapping, because XCUITest calls a row under the header hittable and the tap lands on the header; the export tests close the share sheet with a tap outside it, because the remote sheet view rejects element swipes.

### Results after the fixes

| Run | Pro Max | 17e |
|---|---|---|
| `WhyThisWeightControlUITests` (3) | pass | pass |
| `WhyThisWeightSheetBRUUITests` (3, including the baseline failure) | pass | pass |
| `PrescriptionWeightCellBRUUITests` (1) | pass | pass |
| `SettingsExportUITests` (3) | pass | pass |
| `SettingsBRUUITests` (3) | pass | pass |
| `SessionLoggerBRUUITests` (3), `WorkoutLoggerJourneyUITests` (6), `NoteSheetsUITests` (5) | pass | pass |
| Swift Testing: `SetRowWhyLayout`, `ExportShareItems`, `Phase3BRUSurfaces`, `Phase3BRUGrepAudit`, `BRUGrepAudit`, `BRUGrepAuditPhase6`, `BRUPhase5GrepAudit`, `SessionLoggerBRUCopy`, `SessionLoggerCopy`, `ManualOverride`, `BackupArchiver`, `BackupRoundTrip`, `CSVExporter`, `JSONExporter`, `ExportDocumentSnapshot`, `SettingsUnitsIntegration` | 74 tests in 16 suites pass | the first 7 (46 tests) pass |

Full suite on the Pro Max at HEAD `34ce818` (Task 1 and Task 2 together): 985 Swift Testing tests in 160 suites passed with 1 known issue (the expected `ProgramGraphDeleteRuleBehaviorTests` failure), and all 71 UI tests passed, including both baseline failures.
`ExerciseCopyEditSheetUITests/testCopyOpensFilledEditorOnFirstTap` hit the simulator idle flake in that run (198 s instead of about 20 s) and still passed.

Large text, 17e at AX3 (`accessibility-extra-large`), checked with a throwaway test that was deleted afterwards: set 1's WHY sits on its own line above the RPE chips, unclipped, 57.7 x 44pt, and one tap opens the sheet.
`WhyThisWeightControlUITests` itself does not run at AX3: the shared `UITestNavigation.openSeededWorkout()` waits for `set.reps.1.S1`, which the lazy list has not built yet at that size (the existing Why tests use the same helper; the large-text pass is Phase 2B).

No new build warnings; the only warning is the existing `BlockBuilderView.swift:736`.

### Impact ratings (GitNexus unavailable - manual caller check)

| Symbol | Callers | Own estimate |
|---|---|---|
| `WhyThisWeightSheet` (new defaulted `onOverride`) | `PrescriptionWeightCell`, previews, `Phase3BRUSurfacesTests` x4 (unchanged) | LOW |
| `PrescriptionWeightCell` (new defaulted `isExplaining`) | `SetRow.swift:116`, previews, `Phase3BRUSurfacesTests` x2 (unchanged) | MEDIUM: every logger row |
| `SetRow` | `SessionExerciseCard.swift:265` (+ preview) | MEDIUM: every logger row |
| `SettingsView` export and backup sections | Today's Settings sheet, previews | LOW-MEDIUM |
| `CSVExportItem`, `JSONExportItem`, `BackupShareItem`, `ShareItemRendering` (new) | `SettingsView`, `ExportShareItemsTests` | LOW |
| `ExportService`, `BackupArchiver`, `CSVFile`, `JSONFile`, `FitbodBackupFile` | code unchanged; header comments only | LOW |

### Deviations and observations

- **WHY placement (deviation from "next to the prescribed weight", decided by the coordinator).**
  On the 17e, a set row's first line is S-label 32 + PREV 80 + WEIGHT 60 + REPS 44 + note 44 + done 44 + 6 gaps of 6 = 340 of 358pt, so about 18pt is free and a 44pt WHY cannot sit beside the weight.
  First answer: A, the trailing end of line 2 (rejected B, WHY under the weight: every set row grows about 30pt and line 1 needs a custom alignment; rejected C, WHY beside the weight with the note button moved to line 2: it moves the note button Phase 1A just fixed).
  Follow-up: a set with a type chip (DROP/FAIL/W-UP, about 43pt) needs about 341pt on line 2's 318pt after its 40pt indent, so trailing WHY would wrap the RPE chips at 390pt.
  Final answer: A2, the leading end of line 2 for every row that gets it (rejected A1, `ViewThatFits`: a layout branch that moves WHY between rows; rejected A3: accept the chip wrap at 390pt).
  Its conditions are met: 44x44 with no overlap (6pt gap to the first chip, own line below the done button), the "Why this weight" action stays on the weight cell, WHY stays visible and tappable at AX3 (above), and `SetRowWhyLayoutTests` checks DROP, FAIL and W-UP rows at 358pt.
- The sheet's hero still shows "×—" and "@—": `PrescriptionWeightCell` never passed reps or RPE to `WhyThisWeightSheet` (pre-existing, outside this task).
- Focusing a set's reps or weight field scrolls that row under the fixed workout header (in the failure hierarchy, set 1's row sat at y 53-171 under a header ending at y 180). This is pre-existing keyboard avoidance in the logger; the journey test's own reveal works around it.
- A working set's `SetTypeChip` label is `EmptyView`, so the logger has no way to give a working set a type; the layout test builds typed sets in code.
- On iOS 26 the share sheet is a card that closes on a tap outside it (`PopoverDismissRegion`); it has no Close button.
- The UI tests close the share sheet without sharing, so they never make the items render; `ExportShareItemsTests` covers rendering. The backup is still written to the Documents directory, as before.
- Both simulators are left at the default text size (`large`) and light appearance.
