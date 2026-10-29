---
id: T10
title: One block template catalog
phase: 1
items: [26, 27]
depends_on: [T01]
size: L
sim: both
owns: [fitbod/Periodization/BlockTemplates.swift, fitbod/Periodization/ProgramView.swift, fitbod/Periodization/BlockBuilderView.swift, fitbodTests/ProgramViewFidelityTests.swift, fitbodTests/BlockTemplatesTests.swift, docs/ROADMAP.md, new:fitbodUITests/BlockTemplateCatalogUITests.swift]
---

# T10: One block template catalog

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

Program's four template rows promise blocks that New Block does not build.

| Row says | New Block opens with |
|---|---|
| 5W Hypertrophy meso (ACCUM 3, INTNS 1, DELOAD 1) | Hypertrophy Meso, 8 weeks: accumulation 5, intensification 2, deload 1 |
| 4W Linear strength (BUILD 3, TEST 1) | Generic Strength Meso, 8 weeks: accumulation 4, intensification 2, realization 1, deload 1 |
| 8W Powerbuilding (ACCUM 3, INTNS 2, PEAK 2, DELOAD 1) | Powerlifting Peak: accumulation 3, intensification 3, realization 1, deload 1 |
| 4W 5/3/1 cycle | a blank block with 0 weeks |

New Block's preset picker lists six presets that do not match Program's four.
Picking one sets only the name and forces 4 days per week, and only the hypertrophy preset sets phases.

## Target

- The catalog in `fitbod/Periodization/BlockTemplates.swift`.
- Program's template rows in `fitbod/Periodization/ProgramView.swift`.
- The preset picker in `fitbod/Periodization/BlockBuilderView.swift`.

## Change

1. `BlockTemplates.swift` is the only catalog (decision 1).
   Its order is Hypertrophy Meso, Generic Strength Meso, Powerlifting Peak, then 5/3/1 Cycle (see "One template catalog" in [../tradeoffs.md](../tradeoffs.md)).
2. Add 5/3/1 Cycle: 4 weeks, with one week each of accumulation, intensification, realization and deload.
   It uses the same per-kind multipliers as the other templates.
3. Program's rows are built from the catalog and show only its facts: name, total weeks and phases, such as "8W", "Hypertrophy Meso" and "ACCUM 5 · INTNS 2 · DELOAD 1".
4. Remove the cadence and level text and the POPULAR tag, because no data backs them.
5. Tapping a Program row opens New Block with exactly that template's name and phases.
6. New Block's picker lists BLANK first, then the four catalog templates in catalog order, with the catalog's names.
7. Remove the Off-Season and Pre-Meet presets, because they have no definition (decision 2).
   Add one line for each to `docs/ROADMAP.md`, as the worker rules describe.
8. Picking a preset sets the phases, and sets the name by the "Preset name rule".
9. Picking a preset never changes days per week.
10. If the user has edited the phases, picking a preset first asks "Replace your phases?".
    The dialog has "Replace phases" and a visible "Keep my phases", which keeps the edits.
    Unedited phases are replaced without asking.

## Constraints

- The phases of the three existing templates stay exactly as they are.
- No schema change.
- `TodayView` and `BlockPickerMenu` also open New Block from templates, and both must keep working.
- Update `ProgramViewFidelityTests`, `BlockTemplatesTests` and the six New Block guardrail suites so they pin the new copy.

## Ownership

You may edit the files in `owns`, plus `NewBlockModalUITests` and the guardrail suites whose pinned copy you change on purpose.
Ask before you edit anything else.

## Repro first

On the small phone, from a fresh store:

- Tap Program's "Hypertrophy meso" row, and assert that New Block shows the phases the row promised.
  It shows 8 weeks today.
- Tap the 5/3/1 row, and assert that New Block shows 4 weeks.
  It shows 0 weeks today.
- In New Block, set days per week to 3, pick a preset, and assert that days per week is still 3.
  It becomes 4 today.

## Observable acceptance

- A UI test taps each of the four Program rows and checks that New Block's phases match the row text.
- A UI test picks each preset and checks its phases.
- A UI test edits a phase, picks a preset, taps "Keep my phases", and checks that the edit survived.
- A unit test checks the 5/3/1 template: 4 weeks, four phases, in the order above.
- A unit test checks that each row's text comes from its template.
- The six guardrail suites, `ProgramViewFidelityTests`, `BlockTemplatesTests` and `NewBlockModalUITests` pass.
- Screenshots of Program's rows and New Block's picker on both phones are in `screens/`.

## Hints

- `ProgramView.swift` hard-codes the rows near lines 291-324, and its row view near lines 1232-1294 draws POPULAR.
- `ProgramView.swift` near lines 204-206 opens New Block with either a preset or a template.
- The templates are in `BlockTemplates.swift` near lines 29-58, and `BlockTemplates.blank` already exists.
- In `BlockBuilderView.swift`, look for `applyPreset`, `presetWouldReplacePhases` and `NewBlockPreset`.
- The current "Apply Preset?" dialog uses a cancel-role button, which iOS 26 hides.
