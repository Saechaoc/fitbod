---
phase: quick-261029-dfb
plan: 01
type: execute
wave: 1
depends_on: [quick-261029-d6x]
quick_id: 261029-dfb
slug: m1-phase-2a-restore-edge-swipe-back-on-e
autonomous: true
requirements: [M1-SWIPE, M1-43]

must_haves:
  truths:
    - "On every pushed screen, an edge swipe from the left goes back one screen"
    - "An edge swipe on a tab's root screen does nothing and never freezes navigation"
    - "A pushed editor that asks before discarding changes cannot be swiped away while it holds unsaved changes"
    - "Plate Inventory has a visible back control, and every control on Plate Inventory and the plate calculator does something or is gone"
  artifacts:
    - path: ".planning/quick/261029-dfb-m1-phase-2a-restore-edge-swipe-back-on-e/261029-dfb-SUMMARY.md"
      provides: "Per-task commits, the screen-by-screen swipe table, tests, before/after evidence, impact ratings and deviations"
---

<objective>
Restore edge-swipe back on every pushed screen, and fix review item 43, as part of Phase 2 of the approved plan `.planning/noble-wishing-conway.md`.
Item 43 is described in `docs/review-docs/fitbod-m1-review.md`, section 43.
</objective>

<rules>
The rules block of `.planning/quick/261028-uhg-m1-phase-1a-fix-the-blank-copy-edit-shee/261028-uhg-PLAN.md` applies here unchanged, with two substitutions:
`QDIR` is `.planning/quick/261029-dfb-m1-phase-2a-restore-edge-swipe-back-on-e`, and file names use the prefix `261029-dfb-`.
Read that rules block before you start.
</rules>

<context>
- 35 files in `fitbod/` hide the system navigation bar (`.navigationBarHidden(true)` or `.toolbar(.hidden, for: .navigationBar)`), and no code touches `interactivePopGestureRecognizer`.
  `rg -l "navigationBarHidden\(true\)|\.toolbar\(\.hidden, for: \.navigationBar\)" fitbod` lists them.
  Some are sheets or tab roots; only screens pushed onto a `NavigationStack` need swipe-back.
- Phase 1C may already have handled the block overview (item 35); check its SUMMARY in `.planning/quick/261029-d6u-m1-phase-1c-one-block-template-catalog-f/`.
- Plate Inventory (`fitbod/Settings/PlateInventoryEditor.swift`): the header has no left action (about line 58), the bar is hidden (about 86), and the ghost "Save inventory" button (about 325) is a no-op because edits already save as they happen.
  Its "•••" opens the plate calculator.
- Plate calculator (`fitbod/Settings/PlateCalculatorSheet.swift`): the header's "•••" (about 161) is `/* future menu */`, and its "Save inventory" (about 410) is a no-op.
  The design (`bru-screens/plate-calc.jsx`, read only) shows both controls but defines no behavior for either.
Coordinator decisions:
- Fix swipe-back once, for the whole app, with the least code that works on iOS 26.5.
  First try the platform option on one screen (`.toolbar(.hidden, for: .navigationBar)` or `.toolbarVisibility(.hidden, for: .navigationBar)` instead of `.navigationBarHidden(true)`) and test the edge swipe.
  If the platform option does not restore it, add one small `@MainActor` helper that lets the navigation controller's pop gesture begin only when the stack holds more than one screen.
- A pushed editor that confirms before discarding unsaved changes must keep that guarantee: block the swipe while it is dirty, the same way item 3 blocks swipe-down on sheets.
- Plate Inventory: add a BRU back control, and remove the no-op "Save inventory" button because edits save as you make them; keep "Done ▸".
- Plate calculator: remove the no-op "Save inventory" and the undefined "•••".
  Add a roadmap line to `docs/ROADMAP.md` only if code or docs name an intended feature behind either control.
</context>

<tasks>

<task type="auto">
  <name>Task 1: Edge-swipe back on every pushed screen</name>
  <files>One small shared helper (only if the platform option fails), the screens that hide the bar, new UI test file(s)</files>
  <action>
- List every pushed screen that hides the bar, with the route that reaches it.
- Write one edge-swipe UI test per pushed screen before fixing anything: open the screen, drag from the left edge (`app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))` to about `dx: 0.8`), and assert the previous screen is back.
  Record which ones fail today.
- Fix it app-wide as the context says, then rerun every swipe test.
- Add a test that an edge swipe on each tab root changes nothing and that the next tap still navigates.
- Add a test for one dirty pushed editor (if any exists) that the swipe is blocked while it is dirty and works after saving or discarding.
- Record the table (screen, route, before, after) in the SUMMARY.
  </action>
  <verify>All swipe tests pass on both phones; the existing navigation UI suites still pass.</verify>
  <done>One commit for the fix and its tests, the detect file saved, and the Task 1 section of the SUMMARY with the table.</done>
</task>

<task type="auto">
  <name>Task 2: Item 43 - a way back from Plate Inventory and no dead controls on it or the calculator</name>
  <files>fitbod/Settings/PlateInventoryEditor.swift, fitbod/Settings/PlateCalculatorSheet.swift, docs/ROADMAP.md (only if needed), new UI test file</files>
  <action>
- Apply the context decisions for both screens.
- Check every other control on both screens and confirm it does what its label says; list them in the SUMMARY.
Tests:
- UI, before the fix: open Plate Inventory from Settings and assert a back control exists and returns to Settings.
- UI: change a plate count, go back, reopen, and assert the count stuck (edits save as you go).
- UI: assert the removed controls are gone from both screens.
  </action>
  <verify>The new tests fail before the fix and pass after it on both phones; `PlateCalculatorSheetBRUUITests` and the Settings UI tests still pass.</verify>
  <done>One commit for item 43, the detect file saved, and the Task 2 section of the SUMMARY.</done>
</task>

</tasks>

<success_criteria>
- Edge-swipe back works on every pushed screen, never on a tab root, and never discards unsaved edits.
- Item 43 is fixed with regression tests that failed first.
- No new build warnings, and no previously passing test fails.
</success_criteria>

<output>
`261029-dfb-SUMMARY.md` with one section per task: commits, tests added, the failing-first evidence, impact ratings, files touched and any deviation.
</output>
