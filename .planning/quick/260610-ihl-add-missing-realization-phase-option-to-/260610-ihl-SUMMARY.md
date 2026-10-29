---
phase: quick-260610-ihl
plan: "01"
subsystem: periodization
tags: [enum, block-phase, design-fidelity, bru, periodization-engine]
dependency_graph:
  requires: []
  provides: [BlockPhaseKind.peak, distinct-realization-palette, 5-case-phase-cycle]
  affects: [BlockBuilderView, BlockPhaseColors, BlockPhaseDraft, BlockTemplates, BlockOverviewScreen, PeriodizationEngine]
tech_stack:
  added: []
  patterns: [Swift exhaustive switch, CaseIterable enum extension]
key_files:
  created: []
  modified:
    - fitbod/Models/Enums/BlockPhaseKind.swift
    - fitbod/Periodization/BlockPhaseColors.swift
    - fitbod/Periodization/BlockPhaseDraft.swift
    - fitbod/Periodization/BlockTemplates.swift
    - fitbod/Periodization/BlockOverviewScreen.swift
    - fitbod/Prescription/PeriodizationEngine.swift
    - fitbod/Periodization/BlockBuilderView.swift
    - fitbodTests/EnumTests.swift
    - fitbodTests/BlockTemplatesTests.swift
    - fitbodTests/PeriodizationEngineTests.swift
decisions:
  - "Transferred former .realization visual identity (bruGreen badge, forest-green ink, bruInk 0.25 band) verbatim to new .peak case; assigned new plum palette to .realization so distinction is visible in the Add Phase sheet"
  - "Stock template phase arrays (generic/hypertrophy/powerliftingPeak) left bit-identical — no .peak rows inserted — preserving existing BlockTemplatesTests.d10MultipliersVerbatim coverage"
  - "sevenWeekPhases() preview fixture restructured to 5 distinct phases (2+2+1+1+1) matching final-design-2.png; stale 4-case workaround comment removed"
metrics:
  duration: "~12 minutes"
  completed: "2026-06-10"
  tasks_completed: 2
  files_changed: 10
---

# Phase quick-260610-ihl Plan 01: Add Missing Realization Phase Option to Block Builder Summary

**One-liner:** Added `.peak` case between `.intensification` and `.realization` in `BlockPhaseKind`, splitting the former "Peak/SHARPEN OUTPUT" identity from a true "Realization/TEST MAXES" option with a distinct plum palette — restoring all 5 phase rows from final-design-2.png.

## Truths Satisfied

- `BlockPhaseKind.allCases.count == 5` in declaration order: accumulation, intensification, peak, realization, deload.
- The Add Phase sheet iterates `BlockPhaseKind.allCases` — it now renders 5 selectable rows.
- `.peak` renders "Peak / SHARPEN OUTPUT" with bruGreen badge and forest-green phaseLabelInk (verbatim transfer from former `.realization` identity).
- `.realization` renders "Realization / TEST MAXES" with a new distinct plum palette (saturated plum badge `Color(122,60,110)`, deep plum ink `Color(78,38,70)`).
- `BlockPhaseDraft.defaultMultipliers(for: .peak) == (0.8, 0.95)`; `.realization` unchanged at `(0.6, 0.97)`.
- `PeriodizationEngine.recommendedNextKind` cycles: accumulation → intensification → peak → realization → deload → accumulation.
- `BlockTemplates.template(for: .peak)` returns powerliftingPeak.
- Stock template literal arrays (`generic`, `hypertrophy`, `powerliftingPeak`) are bit-identical — no `.peak` rows inserted.
- `sevenWeekPhases()` preview fixture has 5 distinct phases totaling 7 weeks; stale 4-case comment removed.
- All 10 test suites GREEN (171 tests passed, 0 failed).

## Files Touched

| File | Lines Changed | Change |
|------|--------------|--------|
| `fitbod/Models/Enums/BlockPhaseKind.swift` | +1 case, updated comment | Insert `case peak` between intensification and realization |
| `fitbod/Periodization/BlockPhaseColors.swift` | +5 arms, updated 4 arms | `.peak` arm in all 4 switches; `.realization` gets new plum palette |
| `fitbod/Periodization/BlockPhaseDraft.swift` | +2 lines | `case .peak: return (0.8, 0.95)` in defaultMultipliers |
| `fitbod/Periodization/BlockTemplates.swift` | +2 lines | `case .peak: return powerliftingPeak` in template(for:) |
| `fitbod/Periodization/BlockOverviewScreen.swift` | +1 line, updated 1 | kindDescriptor: `.peak → "PEAK · −20% VOL"`, `.realization → "REALIZATION · −40% VOL"` |
| `fitbod/Prescription/PeriodizationEngine.swift` | +2 lines, updated 1 | 5-case recommendedNextKind cycle |
| `fitbod/Periodization/BlockBuilderView.swift` | +3 arms, updated 3, sevenWeekPhases | NewBlockPhaseText 3 switches split; sevenWeekPhases 5 entries; stale comment removed |
| `fitbodTests/EnumTests.swift` | +5 lines, updated 2 | 5-case assertion + order-sensitive assertion |
| `fitbodTests/BlockTemplatesTests.swift` | +3 lines, updated 1 | .peak row in arguments; case .peak: break in d10Multipliers switch |
| `fitbodTests/PeriodizationEngineTests.swift` | +2 rows, updated 1 | (.intensification, .peak) + (.peak, .realization) replace old row |

## Test Results

| Suite | Result |
|-------|--------|
| NewBlockBuilderFidelityTests | PASSED (6 tests) |
| BlockBuilderViewCopyTests | PASSED (1 test) |
| NewBlockProgressionChartTests | PASSED (4 tests) |
| BRUPeriodizationAuditTests | PASSED (6 tests) |
| BRUPeriodizationRegressionTests | PASSED (included in run) |
| EnumTests | PASSED (updated 5-case assertion) |
| BlockTemplatesTests | PASSED (new .peak row + exhaustive fix) |
| PeriodizationEngineTests | PASSED (5-row cycle table) |
| BlockDraftSaveTests | PASSED (5 tests) |
| DeloadVolumeApplicationTests | PASSED (6 tests) |

**Total: 171 tests passed, 0 failed.**

## Extra Exhaustive-Switch Sites Surfaced by Compiler

The build was clean — no unexpected exhaustive-switch errors surfaced beyond the recon list. Two files (`MesocycleWeekPage.swift:86` and `BlockPhaseEditorRow.swift:199`) use multi-case patterns with `default:` arms and were unaffected by the new `.peak` case, exactly as predicted by the plan.

## Stock Template Arrays: Unchanged

`BlockTemplates.generic.phases`, `BlockTemplates.hypertrophy.phases`, and `BlockTemplates.powerliftingPeak.phases` are bit-identical to their pre-change values. The existing `.realization` rows in those arrays still use `.realization` (now the "TEST MAXES" semantics). The `d10MultipliersVerbatim` test adds `case .peak: break` only to satisfy compiler exhaustiveness — the loop body never actually hits `.peak` because no stock template inserts it.

## Deviations from Plan

None — plan executed exactly as written. The `BlockTemplatesTests.swift` exhaustive switch fix was anticipated in the plan's action for Task 2.

## Repo Hygiene Confirmation

- `git add -A` was never used.
- Only the 10 files listed in `files_modified` were staged across the two commits (`1e8b18f` and `608d123`).
- Pre-existing WIP files (`.planning/config.json`, `.planning/research/STACK.md`, `CLAUDE.md`, `fitbodTests/NewBlockBuilderFidelityTests.swift`) remain unstaged.

## Self-Check

**Commits:**
- `1e8b18f` — feat: Task 1 source changes (7 files)
- `608d123` — test: Task 2 test changes (3 files)
