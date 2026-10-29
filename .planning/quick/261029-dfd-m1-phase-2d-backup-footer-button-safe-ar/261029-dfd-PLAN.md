---
phase: quick-261029-dfd
plan: 01
type: execute
wave: 1
depends_on: [quick-261029-dfj]
quick_id: 261029-dfd
slug: m1-phase-2d-backup-footer-button-safe-ar
autonomous: true
requirements: [M1-14, M1-16, M1-17, M1-18]

must_haves:
  truths:
    - "In the backup footer, CREATE BACKUP is the primary action and RESTORE is secondary, and restore still asks first"
    - "BRUButton fills stop at the safe area and never bleed into the home indicator area"
    - "Prescription toggles use the BRU toggle style, not iOS green"
    - "The override badge stays inside the weight cell, has an accessibility label, and a new exercise with no prescription shows an empty weight field instead of 0"
  artifacts:
    - path: ".planning/quick/261029-dfd-m1-phase-2d-backup-footer-button-safe-ar/261029-dfd-SUMMARY.md"
      provides: "Per-task commits, tests, before/after evidence, impact ratings and deviations"
---

<objective>
Fix review items 14, 16, 17 and 18, as part of Phase 2 of the approved plan `.planning/noble-wishing-conway.md`.
Each item has a full section (what you see, cause, fix, test) in `docs/review-docs/fitbod-m1-review.md`.
</objective>

<rules>
The rules block of `.planning/quick/261028-uhg-m1-phase-1a-fix-the-blank-copy-edit-shee/261028-uhg-PLAN.md` applies here unchanged, with two substitutions:
`QDIR` is `.planning/quick/261029-dfd-m1-phase-2d-backup-footer-button-safe-ar`, and file names use the prefix `261029-dfd-`.
Read that rules block before you start.
</rules>

<context>
- Phase 1B changed the backup CREATE control to a one-tap `ShareLink` (item 34) and changed `PrescriptionWeightCell.swift` and `SetRow.swift` (item 4); read its SUMMARY first and keep both behaviors.
- Item 16: after fixing `BRUButton`, check the other BRU components that paint a background at a screen edge, and list what you checked.
- Item 18: a prescribed weight of 0 means "no prescription".
  Confirm that progression and Why-this-weight code treats 0 the same way, and record what you checked.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Items 14 and 16 - backup footer hierarchy and the BRUButton safe area</name>
  <files>fitbod/Settings/SettingsView.swift, fitbod/Design/BRUButton.swift, other BRU components only if they share the bug, new UI test file</files>
  <action>
Follow the review's fix for each item.
Tests, written before the fix, on both phones:
- Item 14: the CREATE control uses the primary style (assert through an accessibility identifier or trait that the fix exposes, not through color), and RESTORE still shows its confirmation.
- Item 16: on the session editor, the bottom button's frame ends above the bottom safe-area inset; also check it by eye in a screenshot.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; the Settings UI tests and `RoutineBuilderBRUUITests` still pass.</verify>
  <done>Commits for items 14 and 16, detect files saved, and the Task 1 section of the SUMMARY.</done>
</task>

<task type="auto">
  <name>Task 2: Items 17 and 18 - BRU toggles and the set-row weight cell</name>
  <files>fitbod/Routines/PrescriptionEditorRow.swift, fitbod/Sessions/SetRow.swift, fitbod/Sessions/PrescriptionWeightCell.swift, new UI and unit test files</files>
  <action>
Follow the review's fix for each item.
Tests, written before the fix:
- Item 17: a source test that every `Toggle` in `PrescriptionEditorRow.swift` uses `.toggleStyle(.bru)`, in the style of the existing source-introspection suites.
- Item 18, UI on both phones: the override badge's frame lies inside the weight cell and has the accessibility label "changed from prescription"; a newly added exercise with no prescription shows an empty weight field, not "0".
- Item 18, unit: a prescribed weight of 0 counts as no prescription.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; `PrescriptionWeightCellBRUUITests`, `SessionLoggerBRUUITests` and `RoutineBuilderBRUUITests` still pass.</verify>
  <done>Commits for items 17 and 18, detect files saved, and the Task 2 section of the SUMMARY.</done>
</task>

</tasks>

<success_criteria>
- Items 14, 16, 17 and 18 are fixed, each with a regression test that failed first.
- No new build warnings, and no previously passing test fails.
</success_criteria>

<output>
`261029-dfd-SUMMARY.md` with one section per task: commits, tests added, the failing-first evidence, impact ratings, files touched and any deviation.
</output>
