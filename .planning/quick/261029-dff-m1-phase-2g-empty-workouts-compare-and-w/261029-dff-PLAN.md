---
phase: quick-261029-dff
plan: 01
type: execute
wave: 1
depends_on: [quick-261029-dfe]
quick_id: 261029-dff
slug: m1-phase-2g-empty-workouts-compare-and-w
autonomous: true
requirements: [M1-40, M1-39, M1-38]

must_haves:
  truths:
    - "Finishing a workout with no completed working sets offers Discard instead of saving it"
    - "Empty workouts already saved stay in history but are left out of session counts and Compare"
    - "Compare pairs the latest two finished workouts that have sets, and its exercise names are aligned"
    - "Weekly Tonnage uses the unit setting, correct plurals, one week rule for bars and totals, and a fixed week range"
  artifacts:
    - path: ".planning/quick/261029-dff-m1-phase-2g-empty-workouts-compare-and-w/261029-dff-SUMMARY.md"
      provides: "Per-task commits, tests, before/after evidence, impact ratings and deviations"
---

<objective>
Fix review items 40, 39 and 38, as part of Phase 2 of the approved plan `/Users/chrissaechao/.claude/plans/noble-wishing-conway.md`.
Each item has a short section in `/Users/chrissaechao/Desktop/fitbod-review/fitbod-m1-review.md`.
</objective>

<rules>
The rules block of `.planning/quick/261028-uhg-m1-phase-1a-fix-the-blank-copy-edit-shee/261028-uhg-PLAN.md` applies here unchanged, with two substitutions:
`QDIR` is `.planning/quick/261029-dff-m1-phase-2g-empty-workouts-compare-and-w`, and file names use the prefix `261029-dff-`.
Read that rules block before you start.
</rules>

<context>
Product decision 6, approved by the user: finishing a workout with no completed sets offers Discard instead of saving.
Empty workouts already saved stay in history, but they are left out of session counts and Compare.
"Completed sets" means completed working sets, the shared count that Phase 1A added for item 2 (decision 5); reuse it.

Coordinator decisions:
- Item 38 week rule: bars and totals must use one rule.
  Use the aggregator's Monday weeks (`fitbod/Progress/WeeklyTonnageAggregator.swift:112`) for the chart too, through one shared calendar value.
- Item 38 range: keep the chart's week domain fixed (for example the last 8 weeks, or the filter's range), so one week of data draws one bar at normal width.
- Plurals: if no shared plural helper exists yet, add one small helper next to the existing `count == 1 ?` pattern (`fitbod/Progress/ProgressHomeView.swift:314`) and use it here; Phase 3 will reuse it everywhere.
- The weight unit comes from the user's unit setting through the existing helpers; do not hard-code "KG" or "LB".
</context>

<tasks>

<task type="auto">
  <name>Task 1: Items 40 and 39 - empty workouts and Compare</name>
  <files>fitbod/Sessions/SessionLoggerView.swift (the Finish flow), fitbod/Progress/ProgressHomeView.swift, fitbod/Progress/SessionComparisonView.swift, new UI and unit test files</files>
  <action>
- Item 40: apply decision 6 in the Finish flow and in every session count.
- Item 39: Compare pairs the latest two finished workouts that have completed working sets, and the exercise names align (leading, not centered).
Tests, written before the fix, on both phones:
- Item 40: start a workout, complete no working sets, tap Finish, and assert Discard is offered; discard and assert history has no new entry.
  With one real and one empty finished workout already in history, assert Progress says "1 session".
- Item 39: with that same history, assert Compare does not pair the real workout with the empty one.
- Unit: the session count and the Compare pairing ignore empty workouts.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; `WorkoutLoggerJourneyUITests`, `HistoryAndTodayUITests` and `MilestoneOneJourneyUITests` still pass.</verify>
  <done>Commits for items 40 and 39, detect files saved, and the Task 1 section of the SUMMARY.</done>
</task>

<task type="auto">
  <name>Task 2: Item 38 - Weekly Tonnage</name>
  <files>fitbod/Progress/WeeklyTonnageView.swift, fitbod/Progress/WeeklyTonnageAggregator.swift, the plural helper, new UI and unit test files</files>
  <action>
Apply the coordinator decisions for the unit, the plural, the week rule and the range.
Tests, written before the fix:
- Unit: a workout on a Sunday lands in the same week bin in the chart data and in the aggregator totals.
- UI on both phones: with the unit set to pounds, the axis title reads "TONNAGE (LB)"; with one week of data, the range label reads "1 WEEK" and the single bar is narrower than half the chart width.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; existing Weekly Tonnage tests still pass.</verify>
  <done>One commit for item 38, the detect file saved, and the Task 2 section of the SUMMARY.</done>
</task>

</tasks>

<success_criteria>
- Items 38, 39 and 40 are fixed, each with a regression test that failed first.
- No new build warnings, and no previously passing test fails.
</success_criteria>

<output>
`261029-dff-SUMMARY.md` with one section per task: commits, tests added, the failing-first evidence, impact ratings, files touched and any deviation.
</output>
