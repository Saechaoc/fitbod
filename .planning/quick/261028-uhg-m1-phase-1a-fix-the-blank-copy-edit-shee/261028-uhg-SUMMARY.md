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
