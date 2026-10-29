---
phase: quick-260610-hcv
plan: 01
subsystem: ui
tags: [new-block, periodization, phase-card, layout, truncation, milestone-1]

requires: []
provides:
  - New Block phase-card titles and subtitles render in full at 390, 393, 402 and 440pt
  - Rendered-layout regression test in NewBlockBuilderFidelityTests (Vision text recognition at 390/393/402pt)
affects: [New Block and Edit Block builder phase cards]

tech-stack:
  added: []
  patterns:
    - "Host the real BlockBuilderView in a fixed-width UIWindow inside the unit-test host, render it, and read the text back with VNRecognizeTextRequest to catch an ellipsis at a given phone width"

key-files:
  created:
    - .planning/quick/260610-hcv-fix-phase-row-text-cut-off-in-new-block-/260610-hcv-SUMMARY.md
    - .planning/quick/260610-hcv-fix-phase-row-text-cut-off-in-new-block-/260610-hcv-detect-phaserow.txt
    - .planning/quick/260610-hcv-fix-phase-row-text-cut-off-in-new-block-/260610-hcv-promax-440pt-new-block.png
    - .planning/quick/260610-hcv-fix-phase-row-text-cut-off-in-new-block-/260610-hcv-phase-rows-393pt-before.png
    - .planning/quick/260610-hcv-fix-phase-row-text-cut-off-in-new-block-/260610-hcv-phase-rows-390pt-after.png
    - .planning/quick/260610-hcv-fix-phase-row-text-cut-off-in-new-block-/260610-hcv-phase-rows-393pt-after.png
    - .planning/quick/260610-hcv-fix-phase-row-text-cut-off-in-new-block-/260610-hcv-phase-rows-402pt-after.png
  modified:
    - fitbod/Periodization/BlockBuilderView.swift
    - fitbodTests/NewBlockBuilderFidelityTests.swift

key-decisions:
  - "Task 1's eight edits were already in the code (commit 2b1048e), so they were verified, not re-applied"
  - "Titles still truncated at 393pt, so the Spacer between the title and the stat grid was removed and the title block fills that width instead; the title font and its 0.75 minimumScaleFactor (plan item 7) are unchanged"
  - "The regression test reads the rendered text instead of asserting source tokens, so it does not depend on how the layout is written"

duration: ~45 min
completed: 2026-10-29
---

# 260610-hcv SUMMARY: Fix phase row text cut-off in New Block

## Outcome

The eight Task 1 edits were already present, and the six guardrail suites passed.
Rendering the builder at the plan's target widths showed that titles still truncated at 393pt ("Accumulati…", "Intensificati…") and at 390pt, the iPhone 17e width.
One small layout fix (commit `07fba3d`) now shows every title and subtitle in full at 390, 393, 402 and 440pt.
A new regression test failed before the fix and passes after it, and all six guardrail suites plus `NewBlockModalUITests` pass.
A human should glance at the PNGs listed under "Human check".

Branch: `hogfish` (Orca worktree). Nothing pushed or merged.

## Task 1: Tighten phase-row layout (already applied, verified)

All eight prescribed edits are in `fitbod/Periodization/BlockBuilderView.swift`.
They landed in `2b1048e` (2026-06-10, "fix(new-block): pull bottom action bar down toward viewport bottom").
Later, `f01ef58` moved the stat value font to `.bru(.condensed, size: 19)`, which is still Bebas Neue at 19pt.

| # | Edit | Where (line numbers before the fix commit) |
|---|---|---|
| 1 | Inner content `HStack(alignment: .center, spacing: 8)` | 1401 |
| 2 | `Spacer(minLength: 6)` (removed by the fix below) | 1427 |
| 3 | Stat grid `HStack(alignment: .top, spacing: 5)` | 1430 |
| 4 | `NewBlockReadOnlyStatColumn`: width 32, value 19pt, label tracking 0.8 | 1576-1586 |
| 5 | Drag handle `.frame(width: 18, height: 44)` | 1459 |
| 6 | Subtitle `.tracking(0.7)` plus `.minimumScaleFactor(0.8)` | 1421-1424 |
| 7 | Title font and `.minimumScaleFactor(0.75)` unchanged | 1412-1417 |
| 8 | `phaseRowDivider` height 30 | 1349 |

The six guardrail suites run together before any change gave 34 tests in 6 suites, all passing.
The suites were `BlockBuilderViewCopyTests`, `BlockBuilderViewActivationTests`, `NewBlockBuilderFidelityTests`, `NewBlockProgressionChartTests`, `BRUPeriodizationAuditTests` and `BRUPeriodizationRegressionTests`.

## Task 2: Human-verify checkpoint (performed by the worker)

### Pro Max simulator, 440pt

`NewBlockModalUITests/testProgramNewBlockOpensBlankBuilder` passed before and after the fix on "sw6-hcv iPhone 17 Pro Max" (`0B4CD364-1BED-4E12-9310-F0775DED6E7D`).
Its attached "New Block blank modal" screenshot (after the fix) is `260610-hcv-promax-440pt-new-block.png`.

Compared with `bru-screens/New-block/final-design.png`:

- "Accumulation" / "BUILD VOLUME" and "Intensification" / "BUILD STRENGTH" render in full, with no ellipsis.
- The WEEKS / VOL / INT trio with hairline dividers is visible and lines up at the same x on every card.
- The chevron is at the trailing edge, and the ⋮⋮ handle is still present.
- The third card (Deload) sits under the bottom action bar in this screenshot because of scroll position, not truncation.
  The narrow-width renders below show its full text.

### Narrow widths: 390, 393 and 402pt

The only simulator available is 440pt wide, where the bug never appears.
To check the plan's widths, a temporary unit test (deleted, never committed) hosted the real `BlockBuilderView` with all five phase kinds.
It used a `UIWindow` of each width inside the test host and read the cards back with Vision.
A render at 440pt matched the real simulator screenshot, which validates the method.

Before the fix:

| Width | Titles read | Subtitles |
|---|---|---|
| 390pt (iPhone 16e/17e) | "Accumulati...", "Intensificat..." | all in full |
| 393pt (iPhone 16) | "Accumulati...", "Intensificati..." | all in full |
| 402pt (iPhone 17/17 Pro) | full, but "Intensification" was already scaled to about 0.75-0.77, right at the 0.75 floor | all in full |
| 440pt (Pro Max) | full, at 18pt | all in full |

Why it happened: at 18pt, "Accumulation" is 119.0pt and "Intensification" is 123.3pt wide (XCUITest frames at 440pt).
At the 0.75 floor they need 89.3pt and 92.5pt.
At 393pt the title column was only about 87pt, because the Spacer cost 6pt plus one 8pt HStack gap.
Evidence image: `260610-hcv-phase-rows-393pt-before.png`.

Because the must-have "titles render in full on a 393-402pt iPhone" failed at 393pt, step 3 (the smallest fix plus a regression test) applied.

## Fix

### Commit

| Commit | Message |
|---|---|
| `07fba3d` | fix(new-block): show full phase titles on 390-393pt iPhones |

Detect file: `260610-hcv-detect-phaserow.txt` (a `git diff --cached --stat` substitute and the changed symbols).

### What changed

- `NewBlockPhaseEditorRow.cardSurface`: removed `Spacer(minLength: 6)` and gave the title `VStack` `.frame(maxWidth: .infinity, alignment: .leading)`.
  The title column gains 14pt: about 87 to 101pt at 393pt, about 84 to 98pt at 390pt, and about 96 to 110pt at 402pt.
  "Intensification" now needs a scale of about 0.8 at 390pt, safely above the 0.75 floor.
- The stat grid, chevron and handle stay pinned to the trailing edge in the same place.
  The smallest gap between a long title and the first divider is now the row's 8pt HStack spacing.
- No change to fonts, the title's 0.75 `minimumScaleFactor`, subtitle styling, copy, struct names, the stat trio, the chevron, the ⋮⋮ handle or any gesture.
- Two doc comments in the same structs were stale after Task 1 and are corrected: `phaseRowDivider` (34 to 30pt) and `NewBlockReadOnlyStatColumn` (now 32pt with a 19pt value).

### Test added

`fitbodTests/NewBlockBuilderFidelityTests.swift` gained `phaseCardTextRendersInFullOnNarrowPhones()` and the private helper `recognizedText(inBuilderOfWidth:)`.
The test renders the real builder with one card per `BlockPhaseKind` at 390, 393 and 402pt.
It asserts that Vision reads all ten strings in full: Accumulation, BUILD VOLUME, Intensification, BUILD STRENGTH, Peak, SHARPEN OUTPUT, Realization, TEST MAXES, Deload and RECOVER.
It takes about 6 s.
It sits in the existing fidelity suite, so it runs with the six-suite New Block guardrail set.

### Failing-first evidence (before the fix, Pro Max host)

The test failed with 4 issues at `NewBlockBuilderFidelityTests.swift:181`, as predicted:

- `"Accumulation" is cut off at 390pt` (read "Accumulati...")
- `"Intensification" is cut off at 390pt` (read "Intensificat...")
- `"Accumulation" is cut off at 393pt` (read "Accumulati...")
- `"Intensification" is cut off at 393pt` (read "Intensificati...")

402pt passed, and all subtitles passed.

### Results after the fix

| Run (sw6-hcv iPhone 17 Pro Max) | Result |
|---|---|
| `phaseCardTextRendersInFullOnNarrowPhones()` | pass |
| Six guardrail suites together (35 tests, 6 suites, including the new test) | pass |
| `NewBlockModalUITests/testProgramNewBlockOpensBlankBuilder` | pass |
| Vision reading of renders at 390 / 393 / 402 / 440pt | "Accumulation" and "Intensification" in full at every width |
| Affordance probe (temporary UI test, deleted) | tap-to-edit opens the phase editor; Done closes it; long-press-drag on ⋮⋮ reorders (Accumulation moved below Intensification); a full swipe deletes and shows UNDO; UNDO restores the phase |

Evidence images: `260610-hcv-phase-rows-390pt-after.png`, `260610-hcv-phase-rows-393pt-after.png` and `260610-hcv-phase-rows-402pt-after.png` (harness renders at 2x), plus `260610-hcv-promax-440pt-new-block.png` (simulator).

There are no new build warnings.
The only warning in the touched files is the existing `Text +` deprecation at `BlockBuilderView.swift:736`, which this change does not touch.
The simulator is left at light appearance and default text size (`content_size` "large").

## Impact

GitNexus unavailable - manual caller check: `NewBlockPhaseEditorRow` is created once, at `BlockBuilderView.swift:1216` in `NewBlockPhaseListSection`.
`cardSurface` is private and used only at `:1355`.
`phaseRowDivider` and `NewBlockReadOnlyStatColumn` are used only inside the row.
`NewBlockBuilderFidelityTests.swift:87` pins the type name, which is unchanged.
`SplitDetailView.swift:20,603` mentions the row only in comments.
Risk estimate: LOW. The change affects layout only, in one fileprivate view, with a single call site.

## Deviations

1. Task 1 was not re-applied, because the coordinator verified that the edits already exist. They were re-verified above.
2. The plan's "iPhone 17 Pro" simulator was replaced by "sw6-hcv iPhone 17 Pro Max" (environment override C).
   The plan's 393-402pt widths were covered by in-process renders, and the 17e simulator was not run.
3. The test covers 390pt as well, because the approved Milestone 1 plan lists the user's iPhone 17e as 390pt wide.
4. `files_modified` listed only `BlockBuilderView.swift`. The test file is the required regression test.
5. The regression test uses Vision text recognition rather than a source-token assertion, so it checks what the user sees and survives refactors.

## Out-of-scope findings (not fixed)

1. **The revealed Delete button does not delete.**
   After a partial swipe, tapping the red "Delete" button closes the card instead of deleting the phase.
   This was confirmed on the simulator, and the behavior is identical with this fix temporarily reverted.
   Likely cause: in `NewBlockPhaseEditorRow.body`, `.contentShape(Rectangle())` and `.onTapGesture` come after `.offset(x: visibleOffset)`.
   The card's hit area therefore stays at its un-offset frame and covers the button.
   A full swipe still deletes (verified), and the VoiceOver "Delete Phase" action calls `onDelete` directly (code reading, not run).
   This is not in the approved plan's item list, so it needs a decision.
2. The row's `.accessibilityLabel` reaches every child, so the Delete button is announced as "Phase N: …".
   This is already item 45 in the approved plan.
3. The chart's INTENSITY legend chip wraps to "INTENS / ITY" at 393-402pt.
   This is already item 37 (`BlockBuilderView.swift:909-953`).

## Human check

The checkpoint is satisfied by the screenshot evidence, but a human should glance at these files next to `bru-screens/New-block/final-design.png`:

- `260610-hcv-promax-440pt-new-block.png` (simulator, after the fix)
- `260610-hcv-phase-rows-393pt-before.png` and `260610-hcv-phase-rows-393pt-after.png`
- `260610-hcv-phase-rows-390pt-after.png` and `260610-hcv-phase-rows-402pt-after.png`

Known, intended differences from the mock are unchanged by this plan:

- Uppercase subtitles (guarded copy).
- The ⋮⋮ reorder handle.
- Center-aligned stat columns (260610-dbz).
- The non-condensed Geist title font, so long titles scale down slightly on phones 402pt and narrower instead of staying at 18pt.
