---
phase: quick-261029-dhz
plan: 01
type: execute
wave: 1
depends_on: [quick-261029-dff]
quick_id: 261029-dhz
slug: m1-phase-3-p3-polish-and-copy-volume-row
autonomous: true
requirements: [M1-22, M1-23, M1-24, M1-25]

must_haves:
  truths:
    - "Volume tick labels never touch the muscle name, and no divider is stepped"
    - "SKIP is visible at the rest sheet's half-height detent"
    - "The item 24 large-text problems are gone at AX3 on both phones"
    - "Every count label uses one plural helper, so no screen says 1 sets, 1 sessions or 1 EXERCISES"
    - "Copy names the Program tab, Routine and Session as the glossary says, and never shows Split or SessionTemplate"
    - "Each item 25 nit is fixed, or listed in the SUMMARY with the decision that leaves it"
  artifacts:
    - path: ".planning/quick/261029-dhz-m1-phase-3-p3-polish-and-copy-volume-row/261029-dhz-SUMMARY.md"
      provides: "Per-task commits, tests, before/after screenshots, impact ratings, decisions and deviations"
---

<objective>
Fix review items 22, 23, 24 and 25, plus the item 25 additions, as Phase 3 of the approved plan `/Users/chrissaechao/.claude/plans/noble-wishing-conway.md`.
Items 22-25 have full sections in `/Users/chrissaechao/Desktop/fitbod-review/fitbod-m1-review.md`; the additions are under "Second-pass updates to items 1-25" there, and in "Additions to item 25" in the approved plan.
</objective>

<rules>
The rules block of `.planning/quick/261028-uhg-m1-phase-1a-fix-the-blank-copy-edit-shee/261028-uhg-PLAN.md` applies here unchanged, with two substitutions:
`QDIR` is `.planning/quick/261029-dhz-m1-phase-3-p3-polish-and-copy-volume-row`, and file names use the prefix `261029-dhz-`.
Read that rules block before you start.
Any task that edits a New Block file follows its rule 7.
</rules>

<context>
Phases 1 and 2 already fixed some additions: the block overview's "Routines tab" copy (1C), the CHOOSE ROUTINE close control and New Block's CANCEL contrast (1D), and possibly a shared plural helper (2G).
Read the earlier SUMMARYs under `.planning/quick/261028-*` and `.planning/quick/261029-*` first, skip what is done, and reuse what exists.

Coordinator decisions (ask before departing from one):
- Plurals: one shared helper, following the `count == 1 ?` pattern at `fitbod/Progress/ProgressHomeView.swift:314`, used by every count label.
- Dialogs: iOS 26 hides `.cancel` buttons, so the Finish and Discard dialogs get a visible non-cancel "Keep logging" (or "Keep editing") button.
- Rest time: one format everywhere a rest duration appears, `m:ss` (for example "3:00").
- Sheet close style: sheets close with CANCEL (and SAVE or DONE where they save); "‹ BACK" is only for pushed screens.
- Back controls: keep the design's "‹" glyph, but every back control has a 44pt target and the accessibility label "Back".
- Library: group exercise names that start with a digit under "#".
- The reorder control opens a menu, so show the app's menu glyph ("•••") instead of a drag handle, and stop `.accessibilityElement(children: .combine)` at `RoutineExerciseCard.swift:177` from merging the row's identifiers.
- Warm-up ramp: a bar-only row shows "BAR", and VoiceOver reads each row as a sentence (for example "Warm-up 1: bar, 10 reps").
- History "PER WEEK": show up to two decimals (0.25, 1.5, 3).
- Stat values: follow the mockup's display font (`bru-screens/Fitbod-Session/bru-theme.jsx:149`) unless the BRU design-system docs say otherwise; say which you followed.
- Left as is, and recorded in the SUMMARY: the first-log PR question (decision 9, stays on the roadmap; confirm `docs/ROADMAP.md` lists it) and the dark-mode inverse slabs on Today (a design call).
- AX3 in UI tests: launch arguments `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXL`, or the helper an earlier phase added.
- Found in Phase 1A (worker 1A-1), for Task 4:
  - `SuggestedActionChip` in the `SessionExerciseCard` header applies `.frame(minHeight: 44)` outside its button, so only the visible chip takes taps.
    Move the frame and `contentShape` inside the label, as Phase 1A did for SKIP WARM-UPS in `WarmupRampRows.swift`.
  - BRU labels reach accessibility in uppercase: the exercise detail Back button reads "BACK" and the skip button "SKIP ALL WARM-UP SETS", even though the code sets "Skip all warm-up sets".
    Find the cause (likely a `.textCase(.uppercase)` on a parent view, which also changes accessibility labels) and make spoken labels sentence case without changing what is drawn.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Items 22 and 23 plus Today's volume and week-strip nits</name>
  <files>The volume row views, fitbod/Sessions/RestTimer/RestTimerOverlay.swift, fitbod/Views/TodayStatStrip.swift, the Today week strip, the volume target rows, new UI test file</files>
  <action>
- Item 22: give the tick labels their own row with room below the muscle name, keep them inside the bar's width, and find and fix the stepped divider on the 17e.
- Item 23: make SKIP visible at the half-height detent.
- Volume target rows show that they can be tapped.
- Today's third stat shows a real value or is hidden when there is none.
- The week strip marks only the next training day NEXT.
Tests, written before the fix, on both phones: tick label frames do not intersect the muscle name; SKIP is hittable at the medium detent; the week strip shows NEXT at most once.
Screenshots: the volume rows on the 17e (light), checked for the divider.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; `HistoryAndTodayUITests` and the rest timer UI tests still pass.</verify>
  <done>Commits for this task, detect files saved, and the Task 1 section of the SUMMARY.</done>
</task>

<task type="auto">
  <name>Task 2: Item 24 and the Today empty-state card</name>
  <files>fitbod/Design/BRUHeaderBar.swift, fitbod/Views/BlackSlabCTA.swift, fitbod/Sessions/InlineRPEChipRow.swift, the exercise detail view, the Today legend, fitbod/Periodization/StartBlockCTA.swift, fitbod/Design/BRUReadout.swift, new UI test file</files>
  <action>
- Fix each item 24 entry at AX3.
- `StartBlockCTA`: remove the double padding so it aligns with the 16pt edges, match the heading case of the card above it, and use `bruSignalText` for its link.
- Stat values: apply the font decision.
Tests, written before the fix, at AX3 on both phones: the Today header's left and right items do not intersect; "RESUME ▶" stays on one line; the RPE chip "10" has inner padding (its text frame lies inside the chip with at least 4pt on each side); "RECENT PERFORMANCE" does not split mid-word.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; `HistoryAndTodayUITests` and `SessionLoggerBRUUITests` still pass.</verify>
  <done>Commits for this task, detect files saved, AX3 screenshots checked, and the Task 2 section of the SUMMARY.</done>
</task>

<task type="auto">
  <name>Task 3: Item 25, part 1 - plurals, glossary copy, dialogs, rest time and sheet close style</name>
  <files>The plural helper and every count label it replaces, fitbod/Periodization/BlockCard.swift, fitbod/Progress/WeeklyTonnageFilterChips.swift, the logger's "Remove from Session" menu, the Finish and Discard dialogs, rest-time labels, sheet headers, new UI and unit test files</files>
  <action>
- Plurals: replace every hand-written count label with the shared helper; known sites are `ResumeWorkoutBanner.swift:80`, `SessionLoggerView.swift:157`, `ProgramView.swift:585`, `BlockOverviewScreen.swift` (about 727, 792 and 1196) and `BlackSlabCTA.swift:85`; search for more.
- Glossary: `BlockCard.swift:61` and `WeeklyTonnageFilterChips.swift:110` name the Program tab; the logger menu says "Remove from workout"; search for any other on-screen "Split", "SessionTemplate" or "Routines tab".
- Dialogs, rest time and sheet close style: apply the decisions.
Tests: a unit test for the plural helper; UI tests for the Finish dialog's "Keep logging" button and for one singular label on each of the banner, the Finish dialog and the Today slab.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; existing copy and guardrail suites pass after you update the copy they pin.</verify>
  <done>Commits for this task, detect files saved, and the Task 3 section of the SUMMARY.</done>
</task>

<task type="auto">
  <name>Task 4: Item 25, part 2 - Library, exercise detail, reorder control, warm-up VoiceOver, history rate, Program block row and back controls</name>
  <files>fitbod/ExerciseLibrary/ExerciseLibraryView.swift, the exercise detail view, fitbod/Routines/RoutineExerciseCard.swift, fitbod/Sessions/WarmupRampRows.swift, the history PER WEEK stat, the Program block row, back controls such as fitbod/Settings/MuscleVolumeTargetEditor.swift:49, new UI test file</files>
  <action>
- Library "#" section, "View all history" as a BRU navigation row, a readable search placeholder, the reorder glyph and its accessibility, warm-up "BAR" and VoiceOver, "PER WEEK" decimals, the phase shown once on Program's block row, and back controls with 44pt targets and the label "Back".
Tests, written before the fix, on both phones: "3/4 Sit-Up" sits under "#"; each routine exercise row keeps unique identifiers; a bar-only warm-up row shows "BAR"; "PER WEEK" reads "0.25" for one workout in four weeks; Program's block row shows the phase once; each listed back control is at least 44pt and labeled "Back".
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; the Library, routine and history UI suites still pass.</verify>
  <done>Commits for this task, detect files saved, and the Task 4 section of the SUMMARY.</done>
</task>

</tasks>

<success_criteria>
- Items 22, 23, 24 and 25 and the additions are fixed with regression tests or checked screenshots, or recorded with the decision that leaves them.
- No new build warnings, and no previously passing test fails.
</success_criteria>

<output>
`261029-dhz-SUMMARY.md` with one section per task: commits, tests added, the failing-first evidence, impact ratings, decisions, files touched and any deviation.
</output>
