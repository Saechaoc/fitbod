---
phase: quick-261029-dfj
plan: 01
type: execute
wave: 1
depends_on: [quick-261029-dfc]
quick_id: 261029-dfj
slug: m1-phase-2c-stop-mid-word-breaks-and-tru
autonomous: true
requirements: [M1-37, M1-46]

must_haves:
  truths:
    - "On the 17e at default text, no label in the block hero, the New Block legend, the plate calculator or the routine editor breaks mid-word"
    - "At AX3 on the 17e, the New Block top bar and bottom button are readable, chart phase labels do not overlap, and no listed label breaks mid-word or runs off screen"
  artifacts:
    - path: ".planning/quick/261029-dfj-m1-phase-2c-stop-mid-word-breaks-and-tru/261029-dfj-SUMMARY.md"
      provides: "Per-task commits, tests, before/after screenshots, impact ratings and deviations"
---

<objective>
Fix review items 37 and 46, as part of Phase 2 of the approved plan `.planning/noble-wishing-conway.md`.
Both are listed, with file and line pointers, in `docs/review-docs/fitbod-m1-review.md`, sections 37 and 46.
</objective>

<rules>
The rules block of `.planning/quick/261028-uhg-m1-phase-1a-fix-the-blank-copy-edit-shee/261028-uhg-PLAN.md` applies here unchanged, with two substitutions:
`QDIR` is `.planning/quick/261029-dfj-m1-phase-2c-stop-mid-word-breaks-and-tru`, and file names use the prefix `261029-dfj-`.
Read that rules block before you start.
Task 1 edits New Block files, so its rule 7 applies: run all six guardrail suites.
</rules>

<context>
- Fix tools, in order of preference: let the layout give the text room (stack or wrap whole words at accessibility sizes); `ViewThatFits` with a shorter label; `lineLimit(1)` with `minimumScaleFactor` as the last resort.
  Never let a single word break across lines.
- Phases 1C and 1D changed `BlockBuilderView.swift`, `BlockOverviewScreen.swift` and `ProgramView.swift`; read their SUMMARYs first so you build on the current layout.
- AX3 in UI tests: launch arguments `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL`, or the helper Phase 1D added.
- A test can detect a mid-word break by checking that a label's frame is no taller than one line when its text has no space, or by comparing the label's frame with its container; justify the check you choose in the SUMMARY.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Block hero and New Block on the small phone and at AX3</name>
  <files>fitbod/Periodization/BlockOverviewScreen.swift, fitbod/Periodization/BlockBuilderView.swift, the six guardrail suites if pinned copy changes, new UI test file</files>
  <action>
Cover the item 37 and 46 entries for the block hero ("Accumulatio/n", "Powerbuildin/g"), the New Block legend ("INTEN/SITY", "PROGRESSION/OVERVIEW"), `NewBlockTopBar` truncation, the bottom "SAVE TE…" button, and the chart's overlapping phase labels.
Tests, written before the fix, on the 17e at default text and at AX3: the listed labels are not split, the top bar and bottom button show their full text, and no two chart phase labels intersect.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; all six guardrail suites pass.</verify>
  <done>Commits for this task, detect files saved, screenshots checked, and the Task 1 section of the SUMMARY.</done>
</task>

<task type="auto">
  <name>Task 2: Today slab, exercise index, chips, Program tag, routine editor and plate calculator</name>
  <files>fitbod/Views/BlackSlabCTA.swift, fitbod/Views/LiftListRow.swift, fitbod/Periodization/SplitDetailView.swift, fitbod/Periodization/ProgramView.swift, fitbod/Settings/PlateCalculatorSheet.swift, the routine editor's meta line, new UI test file</files>
  <action>
Cover the remaining item 37 and 46 entries: the Today slab meta line ("EXER/CISE/S"), the exercise index in a fixed 32pt frame (`LiftListRow.swift:61-64`, `SplitDetailView.swift:518-521`), the "COMPOUN/D" chip, Program's "ACCUMULATI/ON" and the POWERBUILDING tag that runs off screen, the routine editor's "1 EXERCI/SE" and "REM/OVE", the routine editor's meta line, and the plate calculator's "-2./5".
Tests, written before the fix, on the 17e at default text and at AX3, for each listed label.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; `HistoryAndTodayUITests`, `RoutineBuilderBRUUITests` and `PlateCalculatorSheetBRUUITests` still pass.</verify>
  <done>Commits for this task, detect files saved, screenshots checked, and the Task 2 section of the SUMMARY.</done>
</task>

</tasks>

<success_criteria>
- Items 37 and 46 are fixed, each entry covered by a regression test that failed first or by a checked screenshot.
- No new build warnings, and no previously passing test fails.
</success_criteria>

<output>
`261029-dfj-SUMMARY.md` with one section per task: commits, tests added, the failing-first evidence, impact ratings, files touched and any deviation.
</output>
