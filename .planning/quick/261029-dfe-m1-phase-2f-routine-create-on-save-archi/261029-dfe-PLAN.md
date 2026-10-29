---
phase: quick-261029-dfe
plan: 01
type: execute
wave: 1
depends_on: [quick-261029-dfk]
quick_id: 261029-dfe
slug: m1-phase-2f-routine-create-on-save-archi
autonomous: true
requirements: [M1-15, M1-44, M1-45, M1-47]

must_haves:
  truths:
    - "+ New routine followed by Back leaves no Untitled routine, and the first-run screen still shows"
    - "Archiving a routine asks first; archived routines appear in an Archived list on Program where they can be restored; no other routine list shows them"
    - "VoiceOver reads each phase row once, with one label and one value"
    - "Typing a block name with real key taps keeps every character"
  artifacts:
    - path: ".planning/quick/261029-dfe-m1-phase-2f-routine-create-on-save-archi/261029-dfe-SUMMARY.md"
      provides: "Per-task commits, tests, before/after evidence, impact ratings and deviations"
---

<objective>
Fix review items 15, 44, 45 and 47, as part of Phase 2 of the approved plan `.planning/noble-wishing-conway.md`.
Item 15 has a full section in `docs/review-docs/fitbod-m1-review.md`; items 44, 45 and 47 have short sections there.
</objective>

<rules>
The rules block of `.planning/quick/261028-uhg-m1-phase-1a-fix-the-blank-copy-edit-shee/261028-uhg-PLAN.md` applies here unchanged, with two substitutions:
`QDIR` is `.planning/quick/261029-dfe-m1-phase-2f-routine-create-on-save-archi`, and file names use the prefix `261029-dfe-`.
Read that rules block before you start.
Task 2 edits New Block files, so its rule 7 applies: run all six guardrail suites.
</rules>

<context>
Product decision 7, approved by the user: archiving a routine asks for confirmation first.
Archived routines move to an Archived list on Program, where they can be restored.
Every other routine list leaves them out.
iOS 26 confirmation dialogs have no Cancel button; tests must not tap "Cancel" in one.

Coordinator decisions:
- Item 15: create the routine on its first save, not when "+ New routine" opens the editor.
  The review offers "delete it when untouched" as an alternative; choose it only if create-on-first-save needs a schema change or breaks a flow you can name, and say why.
  Check both entry points: `ProgramView.swift` (about 284-288) and `TodayView.swift` (about 561-565).
  Give the empty BLOCKS section its own empty state, as the review says.
- Item 47: reproduce it first with real key taps (tap the field, then `app.keys["C"].tap()` and so on), not `typeText`.
  If real key taps keep every character, record that the bug is a `typeText` artifact, keep the test, and change no app code.
  If the bug is real, replace the overlay placeholder and tap gesture in `BlockNameField.swift:55-74` with a native `TextField` prompt.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Items 15 and 44 - routine create-on-save, and archive with confirmation and restore</name>
  <files>fitbod/Periodization/ProgramView.swift, fitbod/Views/TodayView.swift, the routine editor's save path, fitbod/Periodization/SplitDetailView.swift, every query that lists routines, new UI test file</files>
  <action>
- Item 15: apply the coordinator decision.
- Item 44: apply decision 7.
  List every routine list or picker in the app and confirm each one excludes archived routines (the CHOOSE ROUTINE sheet already filters `!$0.isArchived`).
Tests, written before the fix, on both phones:
- Item 15: "+ New routine", then Back, from Program and from Today; assert no Untitled routine exists and the first-run screen still shows.
- Item 44: archive a routine, assert the confirmation, confirm, and assert it is gone from Program's routine list, Today and the CHOOSE ROUTINE sheet, and present in the Archived list; restore it and assert it is back.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; `RoutineBuilderBRUUITests`, `MilestoneOneJourneyUITests` and the Program UI tests still pass.</verify>
  <done>Commits for items 15 and 44, detect files saved, and the Task 1 section of the SUMMARY.</done>
</task>

<task type="auto">
  <name>Task 2: Items 45 and 47 - phase rows for VoiceOver and block name typing</name>
  <files>fitbod/Periodization/BlockBuilderView.swift (about line 1372), fitbod/Periodization/BlockPhaseEditorRow.swift (about line 61), fitbod/Periodization/BlockNameField.swift (only if item 47 is real), new UI test file</files>
  <action>
- Item 45: give each phase row `.accessibilityElement(children: .ignore)` with one label and one value, as the review says.
- Item 47: apply the coordinator decision.
Tests, written before the fix, on both phones:
- Item 45: each phase's accessibility label appears exactly once on New Block.
- Item 47: type a block name with real key taps and assert the field holds every character.
  </action>
  <verify>The new tests fail before the fix (item 47 only if the bug is real) and pass after it on both phones; all six guardrail suites and `NewBlockModalUITests` pass.</verify>
  <done>Commits for items 45 and 47 (or the item 47 test alone if the bug is not real), detect files saved, and the Task 2 section of the SUMMARY.</done>
</task>

</tasks>

<success_criteria>
- Items 15, 44 and 45 are fixed, and item 47 is fixed or shown to be a test artifact, each with a regression test.
- No new build warnings, and no previously passing test fails.
</success_criteria>

<output>
`261029-dfe-SUMMARY.md` with one section per task: commits, tests added, the failing-first evidence, impact ratings, files touched and any deviation.
</output>
