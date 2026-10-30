# 261028-uhg SUMMARY: Milestone 1, Phase 1A

## Task 1: Items 1 and 2 - one-tap Copy/Edit sheet, working SKIP WARM-UPS, shared logged-set count

### Commits

| Item | Commit | Message |
|---|---|---|
| 1 | `ba8e0fa` | fix(library): COPY and EDIT open a filled editor on the first tap |
| 2 | `4d7e07e` | fix(workout): SKIP WARM-UPS works on the first tap and never counts as logged sets |

Detect files: `261028-uhg-detect-item1.txt` (risk low, 2 symbols), `261028-uhg-detect-item2.txt` (risk medium; the 5 affected flows all start at `ResumeWorkoutBanner.bannerBody`, which now reads the shared count).

### Files touched

- Item 1: `fitbod/ExerciseLibrary/ExerciseDetailView.swift`, `fitbod/ExerciseLibrary/CustomExerciseDraft.swift`, new `fitbodUITests/ExerciseCopyEditSheetUITests.swift`.
- Item 2: `fitbod/Sessions/WarmupRampRows.swift`, `fitbod/Sessions/SessionExerciseCard.swift`, `fitbod/Sessions/SessionLoggerView.swift`, `fitbod/Views/ResumeWorkoutSlab.swift`, `fitbod/Sessions/ResumeWorkoutBanner.swift`, `fitbod/Models/Session.swift`, new `fitbodUITests/SkipWarmupsUITests.swift`, new `fitbodTests/LoggedSetCountTests.swift`.

### What changed

- Item 1: `ExerciseDetailView` presents the editor with `.sheet(item: $editorDraft)`.
  `presentingCustomEditor` and `draftFromCopy` are gone.
  `CustomExerciseDraft` gained `extension CustomExerciseDraft: Identifiable {}` (class identity, no new stored state).
- Item 2, button: the SKIP WARM-UPS `Button` has `.buttonStyle(.plain)`, and its 44pt frame and `contentShape` moved inside the label.
- Item 2, follow-up A: when every warm-up is complete (only SKIP can complete them; the ramp rows have no tap target), the ramp collapses to one BRU line, "WARM-UPS SKIPPED", with a trailing UNDO button (`labelSmall`, `bruMuted`/`bruInk`, 44pt target, VoiceOver label "Undo skipped warm-ups").
  UNDO calls the new `SessionExerciseCard.handleUndoSkipWarmups()`, which clears `isComplete` on the warm-ups and saves.
  `WarmupRampRows.init` gained `onUndoSkip` with a `{}` default, matching the card's callback-default idiom, so the existing `Phase3BRUSurfacesTests` callers compile unchanged.
- Item 2, follow-up B: new computed `Session.loggedSetCount` (completed and not a warm-up) in the existing `extension Session` in `Session.swift`.
  No stored property, so no schema change.
  It replaces three local counts, which were deleted: `SessionLoggerView.loggedSetCount` (Finish dialog message and the Discard check), `ResumeWorkoutSlab.setsLogged` (Today slab, its Discard confirmation) and `ResumeWorkoutBanner.setCount(for:)` (Program banner).

### Tests added

- `fitbodUITests/ExerciseCopyEditSheetUITests.swift`
  - `testCopyOpensFilledEditorOnFirstTap`: Library, "Barbell Bench Press - Medium Grip", one tap on COPY, the name field appears within 3 s and reads "... (Copy)".
  - `testEditOpensFilledEditorOnFirstTap`: creates a custom exercise by saving a Copy, opens it, one tap on EDIT, the name field appears within 3 s with the exercise's name.
- `fitbodUITests/SkipWarmupsUITests.swift`
  - `testSkipCollapsesRampLogsNothingAndUndoRestores`: demo workout, one tap on SKIP WARM-UPS, "WARM-UPS SKIPPED" shows and the skip button is gone (screenshot attached), Back, the Today slab reads "0 sets logged", RESUME, the skip persisted, UNDO, the ramp returns.
- `fitbodTests/LoggedSetCountTests.swift` (Swift Testing, 3 tests): mixed exercises count only completed working sets; skipped warm-ups alone count 0; an empty session counts 0.

### Failing-first evidence (Pro Max, before each fix)

- Copy: `ExerciseCopyEditSheetUITests.swift:21: XCTAssertTrue failed - One tap on COPY must open a filled editor`.
- Edit, first version (custom made through "+ New"): `XCTAssertTrue failed - One tap on EDIT must open a filled editor`.
- Edit, final version (custom made by saving a Copy), run against the unfixed `ExerciseDetailView.swift`: fails in `tapOnce` at line 61 waiting for "Save", because the first COPY tap opens the blank sheet.
- Skip, unfixed code: `SkipWarmupsUITests.swift:22: XCTAssertTrue failed - One tap on SKIP WARM-UPS must collapse the ramp`.
- Skip, with the button fix and skipped line but before the shared count: `SkipWarmupsUITests.swift:28: XCTAssertTrue failed - Skipped warm-ups must not count as logged sets` (review follow-up B).
- Unit, before `Session.loggedSetCount` existed: `LoggedSetCountTests.swift:55:25: error: value of type 'Session' has no member 'loggedSetCount'`.

### Results after the fixes

| Run | Pro Max `79CAC9F7` | 17e `C2512FF6` |
|---|---|---|
| `ExerciseCopyEditSheetUITests` (2) | pass | pass |
| `SkipWarmupsUITests` (1) | pass | pass |
| `LoggedSetCountTests` (3) | pass | pass |
| Source guardrail suites that read the touched files (10 suites, 78 tests: `SessionWidgetsBRUCopy`, `SessionLoggerCopy`, `OptionalRowRendering`, `BRUPhase5GrepAudit`, `Phase3BRUGrepAudit`, `TodayViewBRUCopy`, `RoutinesListCopy`, `SessionLoggerBRUCopy`, `Phase3BRUSurfaces`, `LoggedSetCount`) | pass | not run |
| `SessionLoggerBRUUITests` (3) + `WorkoutLoggerJourneyUITests` (6) | pass, 9 of 9 | not run |

No new build warnings.
The only warning is the existing `BlockBuilderView.swift:736` deprecated `Text` `+`, which belongs to the New Block files and was left alone.

### Impact ratings (`gitnexus impact`, upstream)

| Symbol | Risk | Direct callers checked |
|---|---|---|
| `ExerciseDetailView` | CRITICAL | 2: its own file and `ExerciseLibraryView` (navigation destination) |
| `ExerciseDetailView.openEditor` | CRITICAL | 1: its own file (header action and Copy CTA) |
| `CustomExerciseDraft` | CRITICAL | graph lists 470; real constructors are `ExerciseLibraryView`, `ExerciseDetailView.makeDraft`, the editor preview |
| `WarmupRampRows` | CRITICAL | 4: `SessionExerciseCard`, its previews, `Phase3BRUSurfacesTests` |
| `SessionExerciseCard.handleSkipWarmups` | CRITICAL | 1: the card's ramp mount |
| `SessionExerciseCard` | CRITICAL | 2 |
| `SessionLoggerView` | CRITICAL | 5 |
| `ResumeWorkoutSlab` | CRITICAL | 2 |
| `ResumeWorkoutBanner` | CRITICAL | 3 |
| `Session` | CRITICAL | 459 (model type; the change only adds a computed property) |
| `SessionLoggerView.loggedSetCount`, `ResumeWorkoutSlab.setsLogged`, `ResumeWorkoutBanner.setCount` | LOW | none outside their own files |
| `WarmupRampRows.skipWarmUpsButton` | LOW | none |

As rule 5 predicts, the CRITICAL ratings come from shared SwiftUI files; the named callers were checked and none needed changes.

### Checks requested by the plan

- Other Buttons in the `SessionExerciseCard` header row: `PinnedNoteCapsule` and `SuggestedActionChip` already use `.buttonStyle(.plain)`; `BumpBanner` has no Button (the header tap dismisses it); the context menu items are system menu buttons.
  `SuggestedActionChip` applies `.frame(minHeight: 44)` outside its button, so its hit area is only the chip; it works, but it is outside this task's files and was not changed.
- Volume, PRs and progression already ignore warm-ups, so skipped warm-ups never reach them:
  volume `FatigueModel.fetchWorkingSets` (`isWarmup == false` plus `workingKinds`), `PerMuscleDetailView`, `WeeklyRecapSheet`, `WeeklyTonnageAggregator`, `WeeklyTonnageView`;
  PRs `PRDetector` (line 264), `ExercisePRsView`;
  progression `SessionFactory` (448, 529, 611), `PreviousMatchingIntent`, `PlateauDetector`, `DeloadAdvisor`;
  history and charts `SessionSummary`, `SessionHistoryRow`, `SessionHistoryView`, `SeriesBuilder`, `SessionComparator`, `ExerciseHistoryView`, `ExerciseDetailView`, `BlockReviewView`, `ProgressHomeView`.

### Deviations and observations

- `fitbod/Models/Session.swift` is not in the brief's target list; the plan's Task 1 asks for the shared count "on the existing model types", so it lives there as a computed property.
- The Edit test creates its custom exercise by saving a Copy instead of typing in "+ New".
  On 2 of 4 runs (once per phone), typing into the "+ New" editor's name field left the app never idle ("App animations complete notification not received"), with the app at 0% CPU and the software keyboard missing or stuck over the Library afterwards.
  The "+ New" path is unchanged by this task, and a rebooted Pro Max ran it cleanly, so this looks like simulator keyboard state; it is worth watching in `MilestoneOneJourneyUITests`, which types in the same field.
- Simulator state at start: the Pro Max was in landscape-left orientation and dark appearance.
  The new UI tests set portrait in `setUp`; both phones were left at light appearance and the default `large` text size.
- BRU labels reach accessibility uppercased (the detail Back button reads "BACK", the skip button "SKIP ALL WARM-UP SETS"), so the new tests match labels without case.
  This may be worth a VoiceOver check later.

## Task 2: Items 33, 41 and 42 - note sheets edit a local copy, correct set number, BRU Pinned Note sheet

### Commits

| Item | Commit | Message |
|---|---|---|
| 41 | `c0f6773` | fix(workout): the first working set's note reads SET 1 NOTE |
| 42 | `e74c810` | fix(workout): the Pinned Note sheet uses the BRU design |
| 33 | `2f6a955` | fix(workout): note sheets save only on SAVE |
| side fix | `639ff4e` | fix(workout): note editors sit right under the header, on paper |

Detect files: `261028-uhg-detect-item41.txt`, `-item42.txt`, `-item33.txt`, `-notelayout.txt` (all risk low, 0 affected processes).

### What changed

- 41: `PerSetNoteSheet` title uses `SessionSetActions.displayNumber(of:)`.
- 42: `PinnedNoteSheet` rebuilt with the `WorkoutNotesSheet` structure: `BRUHeaderBar` (CANCEL, PINNED NOTE, SAVE), bordered `TextEditor` on `bruPaper`, hint "Shown above this exercise's sets".
  No newer Pinned Note design in `bru-screens/` (the `find -newer` check returned nothing).
  The file left the "deferred" exclusion in `BRUGrepAuditTests` and moved to the audited-by-BRUGrepAudit group in `Phase3BRUGrepAuditTests`.
- 33: each sheet holds `@State text`, loaded from the model in `init`; SAVE writes it back (empty becomes nil), calls `ctx.save()`, and dismisses; CANCEL and swipe-down only dismiss.
  `NotesPersistenceTests` comments updated (they described write-through).
- Side fix (seen in the Pinned Note screenshots, same in all three sheets): removed the 46pt spacer that doubled the `safeAreaInset` header offset, and added `.scrollContentBackground(.hidden)` so the editor is not a white box inset inside the ink border.

### Tests

`fitbodUITests/NoteSheetsUITests.swift` (5 tests): `testFirstWorkingSetNoteIsSetOne`, `testPinnedNoteSheetIsBRU` (attaches empty and typed screenshots), and `testWorkoutNoteSavesOnlyOnSave`, `testSetNoteSavesOnlyOnSave`, `testPinnedNoteSavesOnlyOnSave` (SAVE then reopen, CANCEL then reopen, swipe-down then reopen; attaches a screenshot of each sheet).

### Failing-first evidence

- 41, both phones: `XCTAssertEqual failed: ("SET 5 NOTE") is not equal to ("SET 1 NOTE") - Warm-ups must not count in the set note's number`.
- 33, Pro Max, all three sheets: `XCTAssertEqual failed: ("Optional(" draftKept")") is not equal to ("Optional("Kept")") - CANCEL must throw the edit away`.
- 33, 17e, run once with `continueAfterFailure = true` (reverted) to reach the swipe step: the same CANCEL failure, plus `("Optional("  draftdraftKept")") ... - Swipe-down must throw the edit away`, for all three sheets.
- The tap puts the cursor at the start of the text, so the typed edit lands before "Kept"; the test still catches any kept edit.

### Results after the fixes

| Run | Pro Max | 17e |
|---|---|---|
| `NoteSheetsUITests` (5) | pass | pass |
| `SessionLoggerBRUUITests` (3) | pass | not run |
| `NotesPersistence`, `SessionWidgetsBRUCopy`, `Phase3BRUGrepAudit`, `BRUGrepAudit` (31) | pass | audits only (18), pass |

Screenshots viewed on both phones: nothing clipped at 390pt or 440pt.
No new warnings (only the existing `BlockBuilderView.swift:736`).
Both phones left at light appearance and `large` text size.

### Impact ratings

| Symbol | Risk | Direct callers |
|---|---|---|
| `WorkoutNotesSheet` | CRITICAL | `SessionLoggerView` (+ own preview) |
| `PerSetNoteSheet` | CRITICAL | `SetRow` (+ own preview) |
| `PinnedNoteSheet` | CRITICAL | `SessionLoggerView` |
| `excludedFileSuffixes` (two audit tests), `session`/`entry`/`sessionExercise` properties | UNKNOWN (not resolved by GitNexus) | test-only / own file |

The call sites needed no change: each sheet's `init` signature is unchanged.

### Deviations

- Commit order 41, 42, 33, so the item 33 test ran against the BRU Pinned sheet.
- The extra side-fix commit `639ff4e` (user rule: fix clearly-off UI along the way).

## Task 3: Item 3 - editor sheets resist swipe-down while they hold unsaved edits

### Commit

| Item | Commit | Message |
|---|---|---|
| 3 | `78625e7` | fix(editors): a swipe-down no longer throws away unsaved edits |

Built on branch `archerfish` (Orca worktree `q-261028-uhg-t3`) on top of `0ebd71e`, where the commit was `d6e64aa`.
The coordinator rebased it onto `main` (`50225e1`) as `78625e7` and reran the tests listed under "Coordinator check after the rebase".
Detect file: `261028-uhg-detect-item3.txt`.
GitNexus is unavailable on this machine, so the file holds `git diff --cached --stat`, the changed symbols and the presenting flows, with my own risk estimate (low).

### Files touched

- `fitbod/Routines/RoutineBuilderView.swift` (+2), `fitbod/ExerciseLibrary/CustomExerciseEditor.swift` (+2), `fitbod/Periodization/BlockBuilderView.swift` (+8), `fitbod/Periodization/BlockDraft.swift` (+42).
- New `fitbodUITests/EditorSwipeDismissUITests.swift` and `fitbodTests/BlockDraftSnapshotTests.swift`.
- Not touched by `78625e7`: `PrescriptionEditorRow.swift`, `RoutineDraft.swift`, `BlockNameField.swift`, `BlockPhaseEditorRow.swift` (`RoutineDraft.swift` changed later, in the fix under "After the review").

### What changed

- Session editor (`RoutineBuilderView`): `.interactiveDismissDisabled(hasUnsavedChanges)` on its root view, reusing the flag behind "Discard changes?".
- Custom exercise editor (`CustomExerciseEditor`): `.interactiveDismissDisabled(isDirty)`, reusing the flag behind "Discard Changes?".
- New Block builder (`BlockBuilderView`): it had no change tracking, and its CANCEL and "< PROGRAM" close without asking.
  New `BlockDraft.snapshot()` returns an `Equatable` copy of every field the builder edits: name, days per week, each phase's kind, weeks, volume and intensity in order, the attached routine's id, the scheduling mode, and the training days.
  The training days are sorted, so toggling a day off and on again is not an edit.
  The builder does not edit `startDate` or `isActive`, so the snapshot leaves them out.
  The builder stores the snapshot in `.task`, after applying any preset chosen before it opened, and `hasUnsavedChanges` compares it with the live snapshot.
- Each modifier sits on the editor's own root, so every presenter gets the guard with no call-site change.
  Pickers and sheets that an editor presents keep their own swipe behavior (checked by the New Block test since the review).
- A guarded swipe is resisted silently; Cancel and Back keep their dialogs.

### Editor sheets

Every `.sheet(` and `.fullScreenCover(` in `fitbod/` was checked.

Guarded (an editor with a dirty flag):

| Editor | Presented from | Dirty flag |
|---|---|---|
| Session editor, `RoutineBuilderView` | `SplitDetailView.swift:728` (+ Add session, then + New session), `SessionTemplateDetailView.swift:65` (edit), `RoutinesListView.swift:161,166` | `hasUnsavedChanges`, from `RoutineDraft.snapshotHash()` |
| Custom exercise editor, `CustomExerciseEditor` | `ExerciseLibraryView.swift:135` (+ New), `ExerciseDetailView.swift:139` (COPY, EDIT) | `isDirty`, from `CustomExerciseDraft.snapshot()` |
| New Block builder, `BlockBuilderView` | Sheets: `TodayView.swift:277` (Start a block, block overview edit), `BlockCard.swift:32` (Edit Block), `BlockReviewView.swift:63` (next block), `RoutinesListView.swift:174`, `BlockPickerMenu.swift:55`. Full-screen cover: `ProgramView.swift:201`, where swipe-down never applied. | New `hasUnsavedChanges`, from `BlockDraft.snapshot()` |

Left alone:

| Sheet | Reason |
|---|---|
| `WorkoutNotesSheet` (`SessionLoggerView.swift:176`), `PinnedNoteSheet` (`SessionLoggerView.swift:180`), `PerSetNoteSheet` (`SetRow.swift:189`) | Decision 4: swipe-down throws the local copy away (covered by `NoteSheetsUITests`). |
| `NewBlockDurationSheet` (`BlockBuilderView.swift:143`), `NewBlockPhaseEditorSheet` (`BlockBuilderView.swift:1392`), `SupersetAssignmentSheet` (`RoutineBuilderView.swift:192`) | They write to the parent editor's draft as you go, and the parent's guard protects those edits (for the session editor, since the fix in "After the review" below). |
| `WarmupConfigSheet` (`RoutineBuilderView.swift:203`) | It keeps a local copy of its two toggles: SAVE writes them, and CANCEL and swipe-down throw them away, as its header comment (T-03.2-18) intends, like the note sheets. |
| `NewFolderSheet`, `MoveRoutineSheet` (`RoutinesListView.swift:155,158`) | No dirty flag, and CANCEL closes without asking. `RoutinesListView`, like `BlockPickerMenu`, has no presenter in the app, only previews. |
| `AddPlateSheet` (`PlateInventoryEditor.swift:93`) | One text field and no dirty flag; its Cancel closes without asking. |
| `SettingsView` (`TodayView.swift:314`) and the editors pushed inside it | They write through to the model ("Save inventory" is a documented no-op), so nothing is unsaved. |
| `DecimalRPEPickerSheet` (`InlineRPEChipRow.swift:60`, in the logger) | Bound live to the set's RPE; Cancel and Done both just close. |
| Pickers that act on one tap: `FilterPickerSheet`, `MusclePickerSheet`, the exercise pickers (`RoutineBuilderView.swift:216`, `InlineExerciseSearchRow.swift:35`, `AddUnplannedExerciseButton.swift:44`), `SwapExerciseSheet`, `TryVariationSheet`, `SlotPickerSheet`, `SplitPickerSheet`, and the New Block template, add-phase, routine, start-choice and preset pickers | No draft. |
| Read-only or immediate: `BlockReviewView`, the deload signal sheets (`TodayView.swift:292`, `SessionExerciseCard.swift:341`), `WeeklyRecapSheet`, `WhyThisWeightSheet`, `SessionHistoryView`, `PlateCalculatorSheet`, the expanded rest timer, the routine swap confirmation (`BlockOverviewScreen.swift:185`), and the workout summary cover (`SessionLoggerView.swift:200`) | Nothing to lose. |
| `.sheet(isPresented: .constant(true))` in `WhyThisWeightSheet`, `WarmupConfigSheet`, `DecimalRPEPickerSheet`, `PlateCalculatorSheet` | `#Preview` only. |

### Tests added

- `fitbodUITests/EditorSwipeDismissUITests.swift`, 3 tests.
  Each one drags from the editor's header to the bottom of the screen while the editor is untouched, and asserts that it closes.
  It then reopens the editor, makes one change, drags again, and asserts that the editor is still on screen and still holds the change.
  Finally it leaves through the editor's own exit.
  - `testSessionEditorResistsSwipeDownOnlyWithUnsavedEdits`: Today, + New routine, + Add session, + New session.
    The change types the session name "Push C", as in the review's repro.
    Back then shows "Discard changes?", and Discard closes the editor.
  - `testCustomExerciseEditorResistsSwipeDownOnlyWithUnsavedEdits`: Library, + New.
    The change sets Mechanic to Isolation, which needs no keyboard (see the simulator keyboard note in Task 1).
    Cancel then shows "Discard Changes?", and Discard closes the editor.
  - `testNewBlockBuilderResistsSwipeDownOnlyWithUnsavedEdits`: Today on a fresh store, Start a block, which presents the builder as a sheet.
    The change picks FIXED WEEKLY scheduling.
    CANCEL then closes the builder.
- `fitbodTests/BlockDraftSnapshotTests.swift` (Swift Testing, 3 tests): each of ten builder edits changes the snapshot; undoing a phase delete restores it; toggling a training day off and on again does not count.

### Failing-first evidence (before the fix)

On the Pro Max, in each test the untouched swipe closed the editor, and the run then failed at the guarded swipe:

- `EditorSwipeDismissUITests.swift:27: XCTAssertFalse failed - A swipe-down must not close a session editor with unsaved edits`.
- `EditorSwipeDismissUITests.swift:52: XCTAssertFalse failed - A swipe-down must not close a custom exercise editor with unsaved edits`.
- `EditorSwipeDismissUITests.swift:76: XCTAssertFalse failed - A swipe-down must not close a New Block builder with unsaved edits`.
- An earlier draft of the test, which used `XCTWaiter`, failed the same three steps with `XCTAssertEqual failed: ("XCTWaiterResult(rawValue: 1)") is not equal to ("XCTWaiterResult(rawValue: 2)")`.
  The final version uses `waitForNonExistence` and also checks that the edit survived the swipe.
- Unit, before `BlockDraft.snapshot()` existed: `BlockDraftSnapshotTests.swift:37:32: error: value of type 'BlockDraft' has no member 'snapshot'`.
- 17e: one run with only the three `.interactiveDismissDisabled` lines taken out (the rest of the change does nothing without them) failed the same three tests at the same lines, with the same messages.
  The lines were then put back, and `git diff` against `d6e64aa` is empty.

### Results after the fix

| Run | Pro Max `BD457ACF` | 17e `E42692EE` |
|---|---|---|
| `EditorSwipeDismissUITests` (3) | pass | pass |
| `BlockDraftSnapshotTests` (3) | pass | pass |
| `RoutineBuilderBRUUITests` (2), `NewBlockModalUITests` (1), `ExerciseCopyEditSheetUITests` (2) | pass, 5 of 5 | not run |
| The six New Block guardrail suites together (`BlockBuilderViewCopy`, `BlockBuilderViewActivation`, `NewBlockBuilderFidelity`, `NewBlockProgressionChart`, `BRUPeriodizationAudit`, `BRUPeriodizationRegression`), plus every other suite that reads a touched file or uses `BlockDraft` (`Phase3BRUGrepAudit`, `BRUGrepAudit`, `BRUPhase5GrepAudit`, `PrescriptionEditorBlockCaseFilter`, `RoutineBuilderBRUCopy`, `RoutineBuilderCopy`, `RoutineBuilderHeaderPickers`, `RoutineBuilderLiveEdit`, `BlockDraftSave`, `SingleActiveBlockInvariant`, `CustomExerciseDraft`, `BlockDraftSnapshot`): 18 suites, 105 tests | pass | not run |

No new build warnings.
The only warning is still the existing deprecated `Text` `+` in `BlockBuilderView.swift`, now at line 744 (it was 736; this change adds 8 lines above it).
Both phones were checked afterwards at light appearance and the default `large` text size, then shut down.

### Coordinator check after the rebase

After rebasing onto `main` (`50225e1`, which includes the 260610-hcv phase-row change in `BlockBuilderView.swift`), the coordinator reran on the Pro Max `BD457ACF`:
`EditorSwipeDismissUITests` (3 of 3 pass), and `BlockDraftSnapshotTests` with the six New Block guardrail suites (38 tests in 7 suites, all pass).

### Impact ratings

GitNexus unavailable - manual caller check (`rg`), with my own estimate:

| Symbol | Risk | Callers checked |
|---|---|---|
| `RoutineBuilderView` (body) | LOW | `SplitDetailView.swift:734`, `SessionTemplateDetailView.swift:67`, `RoutinesListView.swift:163,168`, `ProgramViewFidelityTests.swift:193`, own preview |
| `CustomExerciseEditor` (body) | LOW | `ExerciseLibraryView.swift:139`, `ExerciseDetailView.swift:144`, own preview |
| `BlockBuilderView` (body, new `initialSnapshot` and `hasUnsavedChanges`) | LOW | `TodayView.swift:281,283`, `BlockCard.swift:34`, `BlockReviewView.swift:65`, `ProgramView.swift:204,206,208`, `RoutinesListView.swift:178,180`, `BlockPickerMenu.swift:56`, own previews |
| `BlockDraft` (new `snapshot()` and `Snapshot`) | LOW | Additive extension; no existing member or initializer changed |
| `RoutineBuilderView.hasUnsavedChanges`, `CustomExerciseEditor.isDirty` (private) | LOW | Own file only: the discard handler and the new modifier |

No signature changed, so no caller needed an edit.

### Deviations and observations

- The review doc (`docs/review-docs/fitbod-m1-review.md`, item 3) reached this worker mid-task.
  The fix and the session editor test match its cause, fix and test.
  Its suggestion to check the workout notes editor is settled by decision 4.
- `BlockBuilderView.swift` is also being edited by another worker (phase-row layout).
  This change stays within 8 lines near the top of the view, and the snapshot code lives in `BlockDraft.swift`.
- The builder's body now reads every phase's fields through the snapshot, so a phase stepper tap re-evaluates the builder's body.
  The drag reorder from 260610-g9d is unaffected: per-frame drag state stays in the row's `@GestureState`, and `draft.phases` changes once, on drop.
- Fixed after the review (see "After the review"): `RoutineDraft.snapshotHash()` used to cover only the name, block, intent, progression, exercise count, total set count and exercise ids.
  Editing an exercise's target reps, RPE, rest, warm-ups, per-set overrides or superset, or reordering exercises added in the same visit, left the session editor clean.
  Neither Back's dialog nor the new swipe guard protected those edits.
- Follow-up, product decision: New Block's CANCEL and "< PROGRAM" still close without asking; only the swipe is guarded.
  A "Discard changes?" dialog there could reuse `hasUnsavedChanges`.
- Optional, from the review: a guarded swipe is resisted silently.
  Bridging `UIAdaptivePresentationControllerDelegate.presentationControllerDidAttemptToDismiss` would show the Discard dialog instead.

### After the review

A ponytail review of `0ebd71e..5fb605f` reported three findings and one point it could not check; the user asked for them to be fixed.

| Review point | What changed | Commit |
|---|---|---|
| 1, must fix: the session editor's fingerprint (`RoutineDraft.snapshotHash()`) missed most exercise edits, so a swipe-down closed the editor and lost them, and Back closed without asking | The fingerprint now holds every field `save(into:context:)` writes: the session's name, notes, folder, block, intent and progression, and for each exercise in order its row id, catalog exercise, sets, reps, RPE, rest, tempo, tempo and partial-rep tracking, superset, warm-up override and per-set targets. | `6631230` |
| 2, should fix: this SUMMARY said `WarmupConfigSheet` writes as you go | The row under "Editor sheets" is corrected. | SUMMARY only |
| 3, nice to have: the note sheet and editor swipe tests each had their own label lookup and sheet drag | Both now use `XCUIElementQuery.labeled(_:)` and `UITestNavigation.dragSheetDown(from:in:)` from the new `fitbodUITests/SheetUITestNavigation.swift`, a separate file because the `undine` branch appends to `UITestNavigation.swift`. | `10d32fd` |
| Not checked: whether a picker opened from an edited editor still swipes away | The New Block test now opens the routine picker, which has no close button, from an edited builder; a swipe closes it, and the builder stays open. | `10d32fd` |

- Behavior change: in the session editor, Back and Discard now also ask "Discard changes?" after edits that only touch exercise targets; before, they closed and lost those edits.
- Failing first (Pro Max): the new `RoutineBuilderHeaderPickersTests.snapshotHashRespondsToExerciseEdits` failed all ten cases on the old fingerprint, for example "Editing the rest must count as unsaved" (also reps, RPE, tempo, tempo tracking, partial reps, superset, warm-ups, per-set target and order).
- After `6631230` (Pro Max): `RoutineBuilderHeaderPickers`, `RoutineDraftValidation`, `RoutineBlockLinkage`, `ProgramViewFidelity`, `RoutineBuilderLiveEdit`, `RoutineBuilderCopy` and `RoutineBuilderBRUCopy` (7 suites, 42 tests), `RoutineBuilderBRUUITests` (2) and `EditorSwipeDismissUITests` (3) pass.
  The first `EditorSwipeDismissUITests` run failed once before any editor opened: the Today helper found "+ New routine" but never saw it hittable after 12 swipes.
  `RoutineBuilderBRUUITests` passed through the same helper in that run, and the re-run passed 3 of 3.
- After `10d32fd`: `EditorSwipeDismissUITests` (3) and `NoteSheetsUITests` (5) pass on the Pro Max and the 17e.
- No new warnings in the touched files.
- Merge check with `git merge-tree` (no refs changed): this branch merges cleanly with `main` and with `undine`, which also edits `RoutineDraft.swift` in a separate hunk near `targetRepsHigh`.
  With `hogfish` the code merges cleanly; its only conflict, in its own `260610-hcv-SUMMARY.md`, already exists between `main` and `hogfish`.
- Detect files: `261028-uhg-detect-item3-hash.txt` and `261028-uhg-detect-item3-tests.txt`.
- The Task 3 dispatch had already settled, so these two commits were not reported to the coordinator.
