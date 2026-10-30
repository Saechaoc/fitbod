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
- A working set's `SetTypeChip` label is `EmptyView`, so its type changed only through the set-type menu, which opened on a hold anywhere in the set row; since `c25645e` (T49, below) the set label opens that menu. The layout test builds typed sets in code.
- On iOS 26 the share sheet is a card that closes on a tap outside it (`PopoverDismissRegion`); it has no Close button.
- The UI tests close the share sheet without sharing, so they never make the items render; `ExportShareItemsTests` covers rendering. The backup is still written to the Documents directory, as before.
- Both simulators are left at the default text size (`large`) and light appearance.

## Follow-up after review: holding an RPE chip in the session editor

A review of `48e09ca..HEAD` found five problems. The user asked to fix the first and log the rest. The other four, plus one found while fixing the first, are in `.planning/backlog/phase-1b-review-follow-ups.md`.

| Finding | Commit | Message |
|---|---|---|
| 1 | `c35e0eb` | fix(routines): holding an RPE chip in the session editor sets a decimal target |

- **Problem:** after item 6, a target such as 8.5 comes only from holding an RPE chip. In the open editor that hold opened the exercise card's menu instead, because the card's `.contextMenu` covered the whole card.
- **Second cause, found while fixing:** with the menu moved, the hold still did nothing. `InlineRPEChipRow` put `.onLongPressGesture` on a `Button`, which swallows it, so the decimal picker never opened anywhere, the logger included.
- **Fix:** the card's menu now opens from the title row only (the tap-to-expand area is unchanged), and each chip watches the hold with `.simultaneousGesture(LongPressGesture(minimumDuration: 0.5))`. The source anchors in `SessionLoggerCopyTests.verbatimCopy` and `SessionLoggerBRUCopyTests.inlineRPEChipRowExposesFiveValues` follow.
- **Test:** `PrescriptionEditorUITests/testHoldingAnRPEChipSetsADecimalTarget`: holding the title opens the card menu, holding "RPE 8" opens the wheel, and 8.5 then Done shows "RPE 8.5".
- **Failing first (Pro Max):** `PrescriptionEditorUITests.swift:96`, "Holding an RPE chip must open the decimal picker", with the card menu (Edit prescription / Edit warm-up… / Duplicate exercise / Remove) in the failure hierarchy. With only the menu moved, the same line failed with no menu and no picker.
- **Logger, unchanged at `c35e0eb` (fixed in `c25645e`, T49 below):** holding an RPE chip in the logger opens the set-type menu for the whole set row, because `SetTypeChip`'s `.contextMenu` sits in a `List` row. A logger test of the hold failed for that reason and was not kept. A throwaway check found no stray picker after closing that menu, after tapping a chip, or after choosing a menu item.
- **Results, Pro Max** (branch rebased on `main` `9be17d6`): `PrescriptionEditorUITests` 3/3, `RoutineBuilderBRUUITests` 2/2, `SessionLoggerBRUUITests` 3/3, `MilestoneOneJourneyUITests` 3/3, `WorkoutLoggerJourneyUITests` 6/6, `NoteSheetsUITests` 5/5, `EditorSwipeDismissUITests` 3/3, and 34 unit tests in 5 suites (`SessionLoggerCopyTests`, `SessionLoggerBRUCopyTests`, `RoutineBuilderBRUCopyTests`, `BRUGrepAuditTests`, `Phase3BRUGrepAuditTests`).
- **Results, 17e:** `PrescriptionEditorUITests` 3/3, `MilestoneOneJourneyUITests` 3/3, `RoutineBuilderBRUUITests` 2/2, `SessionLoggerBRUUITests` 3/3. The idle flake hit twice, each time right after a tap on the exercise picker's search field and before any changed view was on screen; after a reboot the stalled tests passed. No new build warnings.
- **Impact (GitNexus unavailable - manual caller check):** `RoutineExerciseCard`: `RoutineBuilderView.swift:451` and previews, LOW. `InlineRPEChipRow`: `SetRow.swift:233` (every logger row), `PrescriptionEditorRow.swift:174` and previews, MEDIUM. Detect file: `261029-a9s-detect-review1.txt`.

## T49: holding an RPE chip opens the decimal picker, in the editor and the logger

The user asked this worktree to own conway ticket T49 (`docs/conway-specs/tickets/T49-rpe-chip-hold-opens-decimal-picker.md`, added on `main` in `815e3f6`), and to fix the three findings of a second review of `d936b32..c35e0eb`. T49 also covers backlog item 5. Nothing under `docs/conway-specs/` was edited, and `undine` was not rebased, merged or pushed.

| Commit | Message |
|---|---|
| `c35e0eb` | fix(routines): holding an RPE chip in the session editor sets a decimal target (see above) |
| `c25645e` | fix(sessions): hold an RPE chip for a half step in the logger and the editor |

### T49 coverage

| T49 | Status | How |
|---|---|---|
| Change 1: a hold opens the picker with that chip's value, in the editor and the logger | Done | Chip hold (`c35e0eb`); picker starts at the held value; set-type menus no longer take the hold (`c25645e`) |
| Change 2: the picked value is written | Done | Done writes the target in the editor and the set's RPE in the logger; Cancel and a swipe-down write nothing |
| Change 3: the card's menu opens from the title row with the same items, not inside the open editor | Done | `RoutineExerciseCard` (`c35e0eb`) |
| Change 4: a stored half step shows as itself on screen and to VoiceOver | Done | Its own selected chip "8.5", label "RPE 8.5", selected trait; chip 8 is not selected |
| Change 5: a tap sets a whole number; NO TARGET clears | Done | Unchanged; the tap is ignored only while a hold's picker is up |
| Repro 1, editor hold | Passes | `PrescriptionEditorUITests/testHoldingAnRPEChipSetsADecimalTarget` |
| Repro 2, logger hold | Passes | `RPEDecimalHoldUITests/testHoldingAnRPEChipInTheLoggerSetsAHalfStep` |
| Repro 3, 8.5 survives reopening, chip 8 not selected | Passes | `PrescriptionEditorUITests/testAHalfStepTargetSurvivesReopeningAsItsOwnChip` |
| Card menu from the title row; Remove works | Passes | End of `testHoldingAnRPEChipSetsADecimalTarget` |
| `PrescriptionEditorUITests`, `SessionLoggerBRUUITests`, `WorkoutLoggerJourneyUITests` on both phones | Pass | Results below |
| `fitbodTests` | Passes | Both phones |
| Screenshots of the open picker in the editor and the logger, default text, both phones | Saved | `screens/` in this folder, not the ticket's evidence folder, because `docs/conway-specs/` was off limits |

### What changed

- **Chip row** (`InlineRPEChipRow`): the hold opens the picker at the held value. The chip's tap also fires when a hold ends; it is now ignored while the hold's picker is up, so a hold alone never picks the chip. A stored value that is not a whole number, such as 8.5, gets its own selected chip between 8 and 9, and selection compares exact values, so chip 8 is no longer selected for 8.5. Selected chips, including NO TARGET, carry the selected trait for VoiceOver.
- **Picker** (`DecimalRPEPickerSheet`, now `init(initial:onDone:)`): the wheel keeps its own value. Done hands it to `onDone`; Cancel and a swipe-down drop it. The start value snaps to the wheel's half steps, so an old typed target such as 7.8 still opens on a wheel value.
- **Set-type chip** (`SetTypeChip`): a `Menu` with tap-to-cycle as its primary action replaces the `.contextMenu`. In a `List` row a context menu takes a hold anywhere in the row, which is why the logger's RPE hold opened the set-type menu. A tap still cycles, and a hold opens the same five items, now built from one list (`SetTypeMenuItems`).
- **Set label** (`SetRow`): a working set shows no set-type chip, so the row-wide hold was its only way to get a type. The set label (S1) now opens the same menu on a tap. Its target is 44pt wide over the 32pt column, using negative padding so nothing moves. VoiceOver reads "Set 1 type", with the type as its value.
- **Tests**: `PrescriptionEditorUITests` extends the hold test (title-row menu, Cancel keeps the target, the picker starts at the held number, a hold alone picks nothing, Done saves 8.5 as its own chip, Remove) and adds the reopening test. The new `RPEDecimalHoldUITests` has the logger hold and `testSetTypeMenusLeaveTheRPEChipHoldFree`: the set label types a working set, a tap on the chip still cycles, the RPE hold still opens the picker on a typed set, and a hold on the chip opens its menu. `UITestNavigation.tapPickerButton` is shared. The source anchors in `SessionLoggerCopyTests.verbatimCopy` and `SessionLoggerBRUCopyTests.inlineRPEChipRowExposesFiveValues` now require `simultaneousGesture(LongPressGesture(minimumDuration: 0.5)`, so the old `.onLongPressGesture` fails them.

### Failing first (Pro Max; line numbers are from the test file at the time of each run)

- Cancel, at `c35e0eb`: `PrescriptionEditorUITests.swift:93`, "Cancel must keep the old target". After Cancel the target read "RPE 8.5".
- The tap that ends a hold, with only the picker fix: `PrescriptionEditorUITests.swift:98`, "A hold alone must not pick the chip". Holding 9 and tapping Cancel left "RPE 9".
- T49 repro 3, at `c35e0eb`: `PrescriptionEditorUITests.swift:165`, "The half step must show as its own chip". After reopening, "RPE 8.5" showed only in the summary, next to chips 6 to 10.
- T49 repro 2, at `c35e0eb`: `RPEDecimalHoldUITests.swift:22`, "Holding an RPE chip in the logger must open the decimal picker". The set-type menu (Working, Warm-up, Drop Set, To Failure, Rest-Pause) opened instead.
- T49 repro 1: before `c35e0eb`, `PrescriptionEditorUITests.swift:96` failed with the card's menu on screen (see the follow-up above).

### Results at `c25645e`

- **Pro Max:** `fitbodTests` 989 tests in 161 suites passed with 1 known issue (the expected `ProgramGraphDeleteRuleBehaviorTests` one). 37 UI tests in 13 suites passed: `EditorSwipeDismissUITests` 3, `MilestoneOneJourneyUITests` 3, `NoteSheetsUITests` 5, `PrescriptionEditorUITests` 4, `PrescriptionWeightCellBRUUITests` 1, `RPEDecimalHoldUITests` 2, `RoutineBuilderBRUUITests` 2, `SessionLoggerBRUUITests` 3, `SkipWarmupsUITests` 1, `WhyThisWeightControlUITests` 3, `WhyThisWeightSheetBRUUITests` 3, `WorkoutLoggerJourneyUITests` 6, `WorkoutSwapJourneyUITests` 1. The first run hung at the exercise picker's search field in `testHoldingAnRPEChipSetsADecimalTarget` (60 s per step, before any changed view was on screen). After a reboot, a second run passed every test the first had not reached.
- **17e:** one run, with no hang. `fitbodTests` 989 tests in 161 suites passed with the same 1 known issue, and the same 37 UI tests passed.
- The app and the widget (`FitbodWidgetsExtension`) build. The only warning is the existing `BlockBuilderView.swift:744`.
- After the runs, a comment-only edit in `SetRow.swift` went into the commit; its build and 27 source-reading tests passed again on the Pro Max.
- Merge check: `git merge-tree --write-tree main c25645e`, with `main` at `d806fe2`, reports no conflicts. The code `main` gained since `5b9be27` reads set RPE as `Double?`, so half steps suit it.

### Screens (default text, light)

- `screens/t49-editor-picker-promax.png`, `screens/t49-editor-picker-17e.png`: the session editor after holding 9 while the target is 8. The wheel starts at 9.0 and the summary still reads RPE 8.
- `screens/t49-logger-picker-promax.png`, `screens/t49-logger-picker-17e.png`: the workout logger after holding set 1's 8. The wheel starts at 8.0.
- `screens/t49-logger-half-step-promax.png`, `screens/t49-logger-half-step-17e.png`: set 1 after Done with 8.5. The chips read 6 7 8 8.5 9 10, with only 8.5 selected; at 390pt all six still fit on WHY's line.
- `screens/t49-editor-half-step-promax.png`, `screens/t49-editor-half-step-17e.png`: the reopened session. RPE 8.5 shows in the summary and on every set row (@8.5), and the target row has a selected 8.5 chip. The "•••" where the exercise number should be is T29's existing issue.

### Second review of `d936b32..c35e0eb`

1. Cancel in the picker did not cancel: fixed in `c25645e`. Fixing it also answered that review's "Not checked" question: the chip's tap does fire when a hold ends. It is now ignored while the hold's picker is up.
2. The hand-off did not say that the target RPE control differs from T06's plan. T49 now records that T06 is skipped and the editor keeps the chip row. Since `c25645e` the chips also give half steps, so the "whole numbers only" reason in `tradeoffs.md` "RPE entry" no longer holds.
3. The hold's source anchors also matched the old code: they now require `simultaneousGesture(LongPressGesture(minimumDuration: 0.5)`.

### Deviations and notes

- `SetTypeChip.swift` and `SetRow.swift` are outside T49's `owns`. T49 says to ask before editing the set-type file; the user's request covered the logger hold. T09 and T39 own `SetRow.swift` and are both todo in `main`'s run log. The change there is the set label's menu and one shared binding.
- The picker keeps "CANCEL" and "DONE", the UI-SPEC's verbatim labels, although worker-rules ask for "CANCEL" and "SAVE" on sheets that edit data.
- The editor tests use the empty-session flow, not a seeded session, because the T01 helpers are not on `main` yet.
- Not checked: how VoiceOver users reach the half-step picker. There is no named action for it.
- Impact (GitNexus unavailable - manual caller check): `InlineRPEChipRow` MEDIUM (every logger row and the editor), `SetTypeChip` MEDIUM, `SetRow` MEDIUM (one caller, `SessionExerciseCard.swift:265`), `DecimalRPEPickerSheet` LOW (one caller). Detect file: `261029-a9s-detect-t49.txt`.
- Left: backlog items 1 to 4 in `.planning/backlog/phase-1b-review-follow-ups.md`.
- Both simulators are left at the default text size and light appearance.
