---
phase: quick-261029-dfc
plan: 01
type: execute
wave: 1
depends_on: [quick-261029-dfb]
quick_id: 261029-dfc
slug: m1-phase-2b-large-text-layouts-for-the-w
autonomous: true
requirements: [M1-10, M1-11, M1-12, M1-13]

must_haves:
  truths:
    - "At AX3, warm-up rows stack so no label, weight or plate text breaks mid-word"
    - "At AX3, the history and workout summary stat strips keep each value on one line"
    - "At AX3, session editor labels scale, are not clipped, and wrap instead of splitting"
    - "At default text, the exercise index reads 01, 02, and so on, never •••"
  artifacts:
    - path: ".planning/quick/261029-dfc-m1-phase-2b-large-text-layouts-for-the-w/261029-dfc-SUMMARY.md"
      provides: "Per-task commits, tests, before/after screenshots, impact ratings and deviations"
---

<objective>
Fix review items 10, 11, 12 and 13, as part of Phase 2 of the approved plan `/Users/chrissaechao/.claude/plans/noble-wishing-conway.md`.
Each item has a full section (what you see, cause, fix, test) in `/Users/chrissaechao/Desktop/fitbod-review/fitbod-m1-review.md`.
</objective>

<rules>
The rules block of `.planning/quick/261028-uhg-m1-phase-1a-fix-the-blank-copy-edit-shee/261028-uhg-PLAN.md` applies here unchanged, with two substitutions:
`QDIR` is `.planning/quick/261029-dfc-m1-phase-2b-large-text-layouts-for-the-w`, and file names use the prefix `261029-dfc-`.
Read that rules block before you start.
</rules>

<context>
- AX3 in UI tests: launch arguments `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL`.
  Phase 1D Task 3 may have added a helper for this; reuse it if it exists.
- The accessibility-size pattern to copy: `fitbod/Views/TodayStatStrip.swift:196-201` (`dynamicTypeSize.isAccessibilitySize` with `AnyLayout`).
- Item 11 suggests one shared stat strip component.
  Build it only if the two strips really share structure; otherwise apply the same pattern in each and say why in the SUMMARY.
- For visual checks, attach screenshots from both phones at AX3 to the test results, look at each, and fix anything that still reads badly.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Items 10 and 11 - warm-up ramp and stat strips at AX3</name>
  <files>fitbod/Sessions/WarmupRampRows.swift, fitbod/Sessions/SessionHistoryStatStrip.swift, fitbod/Sessions/SessionDetailView.swift, new UI test file</files>
  <action>
Follow the review's fix for each item.
Tests, written before the fix, at AX3 on both phones:
- Item 10: the `W1` label frame is wider than it is tall, and each row's plate text has its own line.
- Item 11: each stat value is a single line (its frame height stays under about 1.5 times its font's line height; justify the bound in the SUMMARY).
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; `SessionLoggerBRUUITests` and `HistoryAndTodayUITests` still pass at default text.</verify>
  <done>Commits for items 10 and 11, detect files saved, AX3 screenshots checked, and the Task 1 section of the SUMMARY.</done>
</task>

<task type="auto">
  <name>Task 2: Items 12 and 13 - session editor at AX3 and the exercise index</name>
  <files>fitbod/Routines/PrescriptionEditorRow.swift, fitbod/Routines/SetRowsContainer.swift, fitbod/Routines/PerSetOverrideRow.swift, fitbod/Routines/RoutineExerciseCard.swift, new UI test file</files>
  <action>
Follow the review's fix for each item.
Phase 1B rebuilt the reps and RPE controls in `PrescriptionEditorRow.swift`; read its SUMMARY first and keep its behavior.
Tests, written before the fix:
- Item 12, at AX3 on both phones: no editor label is clipped (each label's frame lies inside its row) and none splits mid-word.
- Item 13, at default text on both phones: the first exercise row's index label reads "01".
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; `RoutineBuilderBRUUITests` still passes.</verify>
  <done>Commits for items 12 and 13, detect files saved, AX3 screenshots checked, and the Task 2 section of the SUMMARY.</done>
</task>

</tasks>

<success_criteria>
- Items 10, 11, 12 and 13 are fixed, each with a regression test that failed first.
- No new build warnings, and no previously passing test fails.
</success_criteria>

<output>
`261029-dfc-SUMMARY.md` with one section per task: commits, tests added, the failing-first evidence, impact ratings, files touched and any deviation.
</output>
