---
phase: quick-261029-dfk
plan: 01
type: execute
wave: 1
depends_on: [quick-261029-dfd]
quick_id: 261029-dfk
slug: m1-phase-2e-library-search-prefill-bru-c
autonomous: true
requirements: [M1-19, M1-21, M1-20]

must_haves:
  truths:
    - "Create custom exercise from a search with no match opens the editor with the search text as the name"
    - "Every screen shows an exercise's display name, never its lowercase search key"
    - "The muscle detail screen has no duplicate row label"
    - "The custom exercise editor and the muscle picker are built from BRU components, list primary muscles first, and label Lower Back correctly"
  artifacts:
    - path: ".planning/quick/261029-dfk-m1-phase-2e-library-search-prefill-bru-c/261029-dfk-SUMMARY.md"
      provides: "Per-task commits, tests, before/after screenshots, impact ratings and deviations"
---

<objective>
Fix review items 19, 21 and 20, as part of Phase 2 of the approved plan `/Users/chrissaechao/.claude/plans/noble-wishing-conway.md`.
Each item has a full section in `/Users/chrissaechao/Desktop/fitbod-review/fitbod-m1-review.md`; item 21 also has a note under "Second-pass updates to items 1-25".
</objective>

<rules>
The rules block of `.planning/quick/261028-uhg-m1-phase-1a-fix-the-blank-copy-edit-shee/261028-uhg-PLAN.md` applies here unchanged, with two substitutions:
`QDIR` is `.planning/quick/261029-dfk-m1-phase-2e-library-search-prefill-bru-c`, and file names use the prefix `261029-dfk-`.
Read that rules block before you start.
</rules>

<context>
- Item 19 uses the same `.sheet(item:)` pattern that Phase 1A applied to item 1 in `ExerciseDetailView.swift`; reuse it.
- Item 21 sites: `fitbod/Views/LiftListRow.swift:39`, `ExerciseHistoryView.swift:67`, `PerMuscleDetailView.swift:309`, `WeeklyRecapSheet.swift:766` and `776`, and `TryVariationSheet.swift:174`.
  Search for any other display use of `canonicalName` and fix it too; keep `canonicalName` for search and matching.
- Item 20 design references: `bru-screens/custom-exercise.jsx` and `bru-screens/Fitbod-Session/screens/phase-1--custom-exercise.png` (read only).
  Before you build, run `find bru-screens -newer .planning/quick/261029-dfk-m1-phase-2e-library-search-prefill-bru-c/261029-dfk-PLAN.md -type f` and also look for any export newer than 2026-10-28; build from the newest design and name it in the SUMMARY.
- Phase 1A added `.interactiveDismissDisabled` to the custom exercise editor (item 3); keep it.
- Known stall (Phase 1A, worker 1A-1): typing into the "+ New" editor's name field left the app never idle on 2 of 4 runs, once per phone.
  XCTest reported "App animations complete notification not received", the app sat at 0% CPU, and the software keyboard was missing or stuck over the Library afterwards.
  A rebooted Pro Max ran it cleanly, so it may be simulator keyboard state, but it is not proven.
  Task 2 adds a UI test that opens "+ New" from the Library and types a name with real key taps; run it three times on each phone.
  If it stalls, find the cause (for example an endless animation or focus loop in the editor) and fix it, or record the evidence that it is simulator-only.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Items 19 and 21 - search prefill and display names</name>
  <files>fitbod/ExerciseLibrary/ExerciseLibraryView.swift, the item 21 sites, new UI test file</files>
  <action>
Follow the review's fix for each item.
Tests, written before the fix, on both phones:
- Item 19: search for a made-up name, tap CREATE CUSTOM EXERCISE, and assert the Name field holds the trimmed search text.
- Item 21: on Today's lift list and a muscle detail screen, assert the exercise shows its display name (for example "Barbell Bench Press - Medium Grip"), not the lowercase key; assert the duplicate row label is gone.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; existing Library and muscle detail UI tests still pass.</verify>
  <done>Commits for items 19 and 21, detect files saved, and the Task 1 section of the SUMMARY.</done>
</task>

<task type="auto">
  <name>Task 2: Item 20 - BRU custom exercise editor and muscle picker</name>
  <files>fitbod/ExerciseLibrary/CustomExerciseEditor.swift, fitbod/ExerciseLibrary/MusclePickerSheet.swift, the region label mapping for Lower Back, new UI test file</files>
  <action>
Rebuild both screens with BRU components to match the newest design, sort muscles primary first, and fix the Lower Back region label.
Keep every behavior the current editor has: validation, save, cancel with its confirmation, edit of an existing custom exercise, and the dirty-state swipe guard.
Tests:
- UI, before the fix: the muscle picker lists primary muscles first, and Lower Back shows a readable label.
- UI: create, edit and cancel a custom exercise end to end through the rebuilt editor.
- Attach screenshots of both screens on both phones at default text and AX3, look at each, and fix anything that reads badly.
  </action>
  <verify>The new tests fail before the fix where noted and pass after it on both phones; `ExerciseCopyEditSheetUITests` (from Phase 1A) and the Library UI tests still pass.</verify>
  <done>One commit for item 20, the detect file saved, screenshots checked, and the Task 2 section of the SUMMARY.</done>
</task>

</tasks>

<success_criteria>
- Items 19, 20 and 21 are fixed, each with a regression test that failed first or checked screenshots.
- No new build warnings, and no previously passing test fails.
</success_criteria>

<output>
`261029-dfk-SUMMARY.md` with one section per task: commits, tests added, the failing-first evidence, impact ratings, files touched and any deviation.
</output>
