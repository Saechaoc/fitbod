---
phase: quick-260610-dbz
plan: 01
subsystem: periodization-ui
tags: [swiftui, chart, bru-design, new-block, visual-polish]
key-decisions:
  - "Swapped Intensity/Volume line styles so Intensity is the dominant solid ink line with dots per mockup; Volume is the faint dashed line with no dots"
  - "ADD PHASE pill rebuilt as white card capsule with two-tone Text (coral '+', ink 'ADD PHASE') plus .accessibilityLabel to preserve the quoted literal for copy tests"
  - "phaseRowDivider added as a computed property on NewBlockPhaseEditorRow returning a 1x34pt hair Rectangle; placed before WEEKS, VOL, INT but not before chevron"
  - "NewBlockReadOnlyStatColumn narrowed from width:40 to width:38 to compensate for three 1pt dividers added per row"
key-files:
  modified:
    - fitbod/Periodization/BlockBuilderView.swift
metrics:
  completed: "2026-06-10"
  tasks: 2
  files: 1
---

# Phase quick-260610-dbz Plan 01: Match New Block Screen Chart + ADD PHASE Pill Summary

**One-liner:** Restyled NewBlockProgressionChart (series swap, colored phase labels, per-week x-axis, hidden y-axis) and NewBlockPhasesHeader ADD PHASE button (white card capsule, two-tone text, hairline border, shadow) with 10pt phase-card gaps and hairline in-row stat dividers.

## Tasks Completed

| Task | Name | Commit | Key Changes |
|------|------|--------|-------------|
| 1 | Restyle progression chart | e869f53 | Series swap, title-case colored labels, weekAxisValues, .chartYAxis(.hidden), band opacity 0.18, legend swap |
| 2 | ADD PHASE pill, gap, dividers | 076b007 | White card capsule pill, spacing 6→10pt, phaseRowDivider, center-aligned stat columns width 38 |

## Changes Made

### Task 1 — NewBlockProgressionChart + NewBlockPhaseText.abbreviation

- `NewBlockPhaseText.abbreviation`: ACCUM/INTEN/PEAK/DELOAD → Accum./Intens./Peak/Deload
- Chart phase labels: `.foregroundStyle(NewBlockScreenTokens.muted)` → `.foregroundStyle(BlockPhaseColors.badgeColor(for: phase.kind))`
- Series swap: Intensity is now solid ink `lineWidth: 2` + `PointMark(symbolSize: 40)`; Volume is now dashed muted `lineWidth: 1.5, dash: [4,3]` with no PointMark
- Legend: LEFT = 8×8 `hair` `RoundedRectangle` swatch + muted "Volume"; RIGHT = ink line-dot-line glyph + ink "Intensity"
- `weekAxisValues` computed property added: every week when totalWeeks ≤ 8, strides up via `ceil(totalWeeks/8.0)` for longer blocks; `AxisTick` removed
- `.chartYAxis(.hidden)` replaces the trailing `AxisMarks` block
- Band opacity: 0.12 → 0.18

### Task 2 — ADD PHASE, gap, dividers, stat columns

- `NewBlockPhasesHeader`: single coral `Text("+ ADD PHASE")` + coral Capsule outline → two-tone `(Text("+ ").signal + Text("ADD PHASE").ink)` in white card capsule (`NewBlockScreenTokens.card` fill, `cardStroke` border `lineWidth: 0.75`, `cardShadow` `radius: 6`); `.accessibilityLabel("+ ADD PHASE")` on Button preserves the quoted literal
- Phase-cards `VStack` spacing: 6 → 10 (comment updated)
- `NewBlockPhaseEditorRow`: `phaseRowDivider` computed property (1pt × 34pt `hair` `Rectangle`) added; stat grid `HStack` spacing 12→8; divider placed before WEEKS, before VOL, before INT; no divider before chevron
- `NewBlockReadOnlyStatColumn`: `VStack(alignment: .center)`, `.frame(width: 38, alignment: .center)`, `.multilineTextAlignment(.center)` on both label and value texts

## Verification

- `xcodebuild build` succeeded with no errors
- All three guardrail suites green:
  - `NewBlockBuilderFidelityTests` — 5 tests passed (struct names, `ForEach(phases, id: \.draftID)`, copy substrings)
  - `BlockBuilderViewCopyTests` — 1 test passed (`"+ ADD PHASE"`, `"PHASES · \(phaseCount)"`, `"PROGRESSION OVERVIEW"`)
  - `BlockBuilderViewActivationTests` — 3 tests passed (Days Per Week clamp, save persists inactive, new block defaults)
- Only `fitbod/Periodization/BlockBuilderView.swift` modified
- `NewBlockMetricsBand` (TOTAL WEEKS / DAYS PER WEEK) unchanged — byte-for-byte identical
- `BlockPhaseColors.swift` not touched

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None — purely visual/layout changes to a local SwiftUI view with no network endpoints, auth paths, file access, or schema changes.

## Self-Check: PASSED

- `fitbod/Periodization/BlockBuilderView.swift` exists and is modified
- Commits `e869f53` and `076b007` exist in git log
- No other source files modified (only pre-existing untracked/modified files in git status)
- `"+ ADD PHASE"` quoted literal present via `.accessibilityLabel("+ ADD PHASE")`
- `ForEach(phases, id: \.draftID)` literal preserved in chart phase-label block
- `Text("PHASES · \(phaseCount)")` preserved unchanged
- `.chartYAxis(.hidden)` present
- `BlockPhaseColors.badgeColor(for: phase.kind)` used in phase label foregroundStyle
- Band opacity is `0.18`
- `NewBlockReadOnlyStatColumn` frame is `width: 38, alignment: .center`
- Phase-cards VStack `spacing: 10`
