---
phase: quick-261028-uhg
plan: 01
type: execute
wave: 1
depends_on: []
quick_id: 261028-uhg
slug: m1-phase-1a-fix-the-blank-copy-edit-shee
autonomous: true
requirements: [M1-1, M1-2, M1-33, M1-41, M1-42, M1-3]

must_haves:
  truths:
    - "One tap on COPY (built-in exercise) or EDIT (custom exercise) opens a filled editor sheet"
    - "SKIP WARM-UPS works on the first tap and shows a skipped state with UNDO"
    - "Skipped warm-ups never count as logged sets; one shared count of completed working sets drives the logger header, the Finish check, the Today resume slab and the Program resume banner"
    - "In the workout, set and pinned note sheets, SAVE writes the text, and CANCEL or swipe-down discards it"
    - "The note sheet of the first working set is titled SET 1 NOTE, even when warm-ups come before it"
    - "The Pinned Note sheet uses BRU components and layout, like WorkoutNotesSheet"
    - "Every editor sheet with unsaved edits resists swipe-down; Cancel and Back still show their discard dialogs"
    - "Each fix has a UI regression test that failed before the fix and passes after it on both sw6 phones"
  artifacts:
    - path: ".planning/quick/261028-uhg-m1-phase-1a-fix-the-blank-copy-edit-shee/261028-uhg-SUMMARY.md"
      provides: "Per-task commits, tests, before/after evidence, impact ratings and deviations"
  key_links:
    - from: "fitbod/ExerciseLibrary/ExerciseDetailView.swift"
      to: "CustomExerciseEditor"
      via: ".sheet(item:) driven by the draft itself"
      pattern: "sheet\\(item:"
    - from: "shared completed-working-set count"
      to: "SessionLoggerView, ResumeWorkoutSlab, ResumeWorkoutBanner"
      via: "one function or computed property used by all three"
---

<objective>
Fix Milestone 1 review items 1, 2, 3, 33, 41 and 42, as part of Phase 1 of the approved plan `/Users/chrissaechao/.claude/plans/noble-wishing-conway.md`.
Each fix starts with a UI test that reproduces the bug the way a user meets it, and that test stays as a regression test.

Full descriptions, causes and suggested fixes for every item are in `/Users/chrissaechao/Desktop/fitbod-review/fitbod-m1-review.md`.
Read only the sections for your task's items.

Output: one commit per item (or per tightly coupled pair), new UI and unit tests, and a section per task in `261028-uhg-SUMMARY.md`.
</objective>

<rules>
These rules apply to every worker that executes a task from this plan.
Where this plan is more specific than CLAUDE.md, follow this plan.

1. Work only on your assigned task.
   Start every Bash call with `cd /Users/chrissaechao/Desktop/fitbod &&`.
   Put helper scripts, logs and commit-message files in your own session scratchpad.
2. Simulators: use only "sw6 iPhone 17 Pro Max" `79CAC9F7-95DE-4AEB-84F6-660A8F2E36EE` and "sw6 iPhone 17e" `C2512FF6-0EC6-4044-8B18-53E451AB0899`.
   Never use "iPhone 17 Pro" `61A37501-...` (personal data) or any `fitbod-codex-*` device.
   Leave both phones at default text size and light appearance when you finish.
3. Build and test command (one at a time, never two xcodebuild runs at once):
   ```sh
   xcodebuild -project fitbod.xcodeproj -scheme fitbod \
     -destination 'platform=iOS Simulator,id=<SIM>' \
     -derivedDataPath ~/Library/Developer/Xcode/DerivedData/fitbod-m1-orca \
     -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO \
     test -only-testing:<Target>/<Class>[/<method>] > <log> 2>&1
   grep -E "error:|\*\* (BUILD|TEST) (SUCCEEDED|FAILED)|Test Case .*(passed|failed)|Executed [0-9]+ test" <log> | tail -40
   ```
   Never paste unfiltered xcodebuild output into your context.
4. Reproduce first.
   For each item, write the UI test (XCTest, `fitbodUITests/`) before touching app code.
   Run it on the Pro Max and confirm it fails for the reason the review describes.
   Record the failure message in the SUMMARY.
   Then fix, rerun it until it passes, and run it on the 17e as well.
   Logic changes also get a Swift Testing unit test in `fitbodTests/`.
   The DEBUG launch arguments `-fitbod-reset-store -fitbod-seed-demo-workout` give a clean store with an in-progress demo workout.
   Reuse the helpers in `fitbodUITests/UITestNavigation.swift` and `WorkoutUITestNavigation.swift`.
   The test targets use synchronized folders, so new files need no project-file edit.
5. Before you edit a function, type or property, run `gitnexus impact <name> --repo fitbod` and note the risk level in the SUMMARY.
   GitNexus rates shared SwiftUI files HIGH or CRITICAL because many modules import each other.
   Report the rating, check the named callers, and continue.
6. Code rules: `@Observable` with `@State`/`@Bindable`/`.environment` only, never `ObservableObject`.
   Keep `@Query` directly in views.
   Use BRU tokens and components only (`Color.bru*`, `BRUFont`, `BRUButton`, `BRUStepper`, `.toggleStyle(.bru)`), never literal colors.
   No SwiftData schema change: SchemaV7 is the only schema.
   UI copy follows the glossary: Program tab, Routine, Session; never show `Split` or `SessionTemplate`.
   Match the surrounding code's naming, comment density and idiom.
7. If you touch any New Block file (`BlockBuilderView.swift`, `BlockNameField.swift`, `BlockDraft.swift`, `BlockPhaseEditorRow.swift`), run all six guardrail suites together: `BlockBuilderViewCopyTests`, `BlockBuilderViewActivationTests`, `NewBlockBuilderFidelityTests`, `NewBlockProgressionChartTests`, `BRUPeriodizationAuditTests` and `BRUPeriodizationRegressionTests`.
8. Commits:
   - Stage exact paths only.
     Never use `git add -A`, `git add .`, `git commit -a`, `git commit --amend`, `--no-verify`, `git stash`, `git checkout`/`git restore` on files, `git clean`, `git reset --hard` or `git push`.
   - Before each commit, wait until `.gitnexus/.reindex.lock` is gone (the post-commit hook creates it), then run `gitnexus detect-changes --scope staged --repo fitbod` and save its output to `QDIR/261028-uhg-detect-<item>.txt`.
     Never run plain `gitnexus analyze`; it rewrites CLAUDE.md and AGENTS.md.
   - Message: `fix(<area>): <what changed for the user>`, a short plain-English body, then the Claude-Session line your environment gives you, if any.
     Never add a Co-Authored-By trailer; the user's CLAUDE.md forbids it.
   - Every commit must build, and the tests you ran for it must pass.
9. Do not touch these paths, which belong to the user or another session: `.planning/config.json`, `bru-screens/**`, `ARCHITECTURE.md`, `CONVENTIONS.md`, `CLAUDE.md`, `.claude/**`, `AGENTS.md`, `.repowise/**`, `graphify-out/**`, `.planning/graphs/**`, `.planning/STATE.md`, `.planning/ROADMAP.md`.
   Do not commit anything under `.planning/`; the coordinator commits the plan, the detect files and the SUMMARY.
10. If you need a decision that this plan does not cover, ask the coordinator with your Orca `ask` command and wait.
    Never ask the user directly.
    If a fix turns out much larger than described, stop and ask before expanding scope.
11. Finish by writing your task's section in `QDIR/261028-uhg-SUMMARY.md` (create the file if it is missing, and keep other sections intact), then send `worker_done`.

`QDIR` is `.planning/quick/261028-uhg-m1-phase-1a-fix-the-blank-copy-edit-shee`.
</rules>

<context>
Baseline (Phase 0, 2026-10-29): 1,026 tests; 1,023 passed, 2 failed, 1 expected failure.
The two failures are item 5 (`MilestoneOneJourneyUITests/testAuthorRoutineLogRelaunchFinishAndHistory`) and item 4 (`WhyThisWeightSheetBRUUITests/testWhyThisWeightSectionHeadVisible`).
They belong to Phase 1B; do not try to fix them here.

iOS 26 confirmation dialogs have no Cancel button, so UI tests must not tap "Cancel" in a confirmation dialog.
A parent `.onTapGesture` in a List row swallows child Buttons that have no `buttonStyle`; give such buttons `.buttonStyle(.plain)` and put the frame and `contentShape` inside the label.

Product decisions approved by the user (do not reopen them):
- Decision 4: the workout, set and pinned note sheets each edit a local copy.
  SAVE writes the copy to the model.
  CANCEL and swipe-down throw the copy away.
- Decision 5: "logged sets" means completed working sets.
  Warm-ups never count, whether completed or skipped.
  One shared count drives the logger header, the Finish check, the Today resume slab and the Program resume banner.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Items 1 and 2 - one-tap Copy/Edit sheet, working SKIP WARM-UPS, shared logged-set count</name>
  <files>fitbod/ExerciseLibrary/ExerciseDetailView.swift, fitbod/ExerciseLibrary/CustomExerciseDraft.swift, fitbod/Sessions/WarmupRampRows.swift, fitbod/Sessions/SessionExerciseCard.swift, fitbod/Sessions/SessionLoggerView.swift, fitbod/Views/ResumeWorkoutSlab.swift, fitbod/Sessions/ResumeWorkoutBanner.swift, new UI and unit test files</files>
  <action>
Item 1 (review section "1. P0"):
`ExerciseDetailView.swift:146-168` presents the editor with `.sheet(isPresented:)` and reads `draftFromCopy` only inside the sheet closure, so the first sheet renders empty.
Drive the sheet with the draft itself: `@State private var editorDraft: CustomExerciseDraft?` and `.sheet(item: $editorDraft)`.
Delete `presentingCustomEditor` and `draftFromCopy`.
`CustomExerciseDraft` is a final class, so `extension CustomExerciseDraft: Identifiable {}` is enough if it does not already conform.
Test: on a built-in exercise ("Barbell Bench Press - Medium Grip"), one tap on COPY shows the editor's name field within 3 seconds.
Then create a custom exercise through the app and check that one tap on EDIT does the same.

Item 2 (review section "2. P1", including follow-ups A and B):
- `WarmupRampRows.swift:234-250`: give the SKIP WARM-UPS button `.buttonStyle(.plain)`, and move `.frame(maxWidth: .infinity, minHeight: 44)` and `.contentShape(Rectangle())` inside its label.
  Check every other Button inside the `SessionExerciseCard` header row (the row with `.onTapGesture` at about line 254) for the same problem.
- After a skip, collapse the ramp to one BRU line, "WARM-UPS SKIPPED", with an UNDO button that restores the warm-ups.
- Add one shared count of completed working sets (completed and not a warm-up) on the existing model types, without a schema change.
  Use it in `SessionLoggerView.loggedSetCount` (271-275, and the Finish check at 247), `ResumeWorkoutSlab.setsLogged` (53-57) and `ResumeWorkoutBanner.setCount` (138-143).
- Confirm that volume, PR and progression code already ignore warm-ups, and record what you checked.
Tests:
- UI: launch with the demo flags, tap RESUME on Today, tap SKIP WARM-UPS once, and assert the skipped line is visible.
  Go back and assert that the Today slab still reports 0 sets logged.
  Tap UNDO and assert that the ramp rows return.
- Unit: the shared count ignores warm-ups and incomplete sets.
  </action>
  <verify>Both new UI tests fail before the fix and pass after it on the Pro Max and the 17e; the unit test passes; `SessionLoggerBRUUITests` and `WorkoutLoggerJourneyUITests` still pass on the Pro Max.</verify>
  <done>Two commits (item 1, item 2), detect files saved, and the Task 1 section of the SUMMARY records the before and after test results.</done>
</task>

<task type="auto">
  <name>Task 2: Items 33, 41 and 42 - note sheets edit a local copy, correct set number, BRU Pinned Note sheet</name>
  <files>fitbod/Sessions/WorkoutNotesSheet.swift, fitbod/Sessions/PerSetNoteSheet.swift, fitbod/Sessions/PinnedNoteSheet.swift, their call sites, new UI test file</files>
  <action>
Item 33: `WorkoutNotesSheet`, `PerSetNoteSheet` and `PinnedNoteSheet` bind straight to the model, so text typed before CANCEL is already saved.
Give each sheet a local `@State` copy, loaded from the model when it appears.
SAVE writes the copy to the model; CANCEL and swipe-down do not (decision 4).
Item 41: `PerSetNoteSheet.swift:72` titles the sheet with `orderIndex + 1`, which counts warm-ups, so the first working set shows "SET 5 NOTE".
Use `SessionSetActions.displayNumber(of:)`, as `SetRow.swift:275-281` already does.
Item 42: `PinnedNoteSheet` uses stock iOS controls.
Rebuild it with the same BRU structure as `WorkoutNotesSheet` (header, text editor styling, CANCEL and SAVE actions).
Before you rebuild it, run `find bru-screens -newer .planning/quick/261028-uhg-m1-phase-1a-fix-the-blank-copy-edit-shee/261028-uhg-PLAN.md -type f` and read any new Pinned Note design; if there is none, match `WorkoutNotesSheet`.
Tests (one UI test file is fine):
- For each of the three sheets: type text, tap CANCEL, reopen, and assert the old text; type text, swipe down, reopen, and assert the old text; type text, tap SAVE, reopen, and assert the new text.
- The first working set's note sheet title reads "SET 1 NOTE" in the demo workout, which has warm-ups.
- Attach a screenshot of the Pinned Note sheet on each phone to the test result, and look at both yourself.
  </action>
  <verify>The new tests fail before the fixes (for 33 and 41) and pass after them on both phones; the Pinned Note screenshots show BRU styling with nothing clipped at 390pt and 440pt widths.</verify>
  <done>Commits for 33, 41 and 42, detect files saved, and the Task 2 section of the SUMMARY.</done>
</task>

<task type="auto">
  <name>Task 3: Item 3 - editor sheets resist swipe-down while they hold unsaved edits</name>
  <files>Editor views presented in sheets (start with fitbod/Routines/RoutineBuilderView.swift, fitbod/ExerciseLibrary/CustomExerciseEditor.swift, the New Block builder if it is presented as a sheet, and any other sheet that tracks unsaved changes), new UI test file</files>
  <action>
The app has no `.interactiveDismissDisabled` anywhere, so a swipe-down closes an editor and throws away its changes, while Cancel and Back ask first.
List every `.sheet(` and `.fullScreenCover(` whose content is an editor with a dirty flag (for example `hasUnsavedChanges` at `RoutineBuilderView.swift:522` and `isDirty` at `CustomExerciseEditor.swift:252`).
Add `.interactiveDismissDisabled(<dirty flag>)` to each editor's root view inside the sheet.
The note sheets from Task 2 are the exception: decision 4 says swipe-down discards them.
Record the full list, with each editor's decision, in the SUMMARY.
Tests: for the session editor, the custom exercise editor and the New Block builder (if it is a sheet), change a field, drag down from the sheet's top edge, and assert the editor is still on screen.
Also assert that an untouched editor still closes on swipe-down.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; `RoutineBuilderBRUUITests` and `NewBlockModalUITests` still pass; if New Block files changed, all six guardrail suites pass.</verify>
  <done>One commit, the detect file saved, and the Task 3 section of the SUMMARY with the editor list.</done>
</task>

</tasks>

<verification>
After each task, the coordinator reviews the diff, checks the detect files, and reruns the new tests on one phone.
After all three tasks, the coordinator runs the new tests on both phones and updates STATE.md.
</verification>

<success_criteria>
- Items 1, 2, 3, 33, 41 and 42 are fixed, each with a regression test that failed first.
- The shared logged-set count is used at all four sites.
- No new build warnings, and no previously passing test fails.
</success_criteria>

<output>
`261028-uhg-SUMMARY.md` with one section per task: commits, tests added, the failing-first evidence, impact ratings, files touched and any deviation.
</output>
