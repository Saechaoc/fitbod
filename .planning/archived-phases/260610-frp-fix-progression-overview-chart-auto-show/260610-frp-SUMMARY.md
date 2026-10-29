---
phase: quick-260610-frp
plan: 01
subsystem: Periodization / NewBlockProgressionChart
tags: [bugfix, swift-charts, selection-state, progression-overview]
dependency_graph:
  requires: []
  provides: [BUGFIX-PROGRESSION-CHART-AUTO-SELECT]
  affects: [fitbod/Periodization/BlockBuilderView.swift]
tech_stack:
  added: []
  patterns: [Swift Charts chartXSelection Optional binding, SwiftUI @State nil-default]
key_files:
  created: []
  modified:
    - fitbod/Periodization/BlockBuilderView.swift
decisions:
  - "Remove .onAppear force-select entirely rather than guarding it; no legitimate reason to auto-select week 1 on chart appear"
  - "Re-gate ring PointMark with if-let binding rather than ?? 1 fallback to keep the nil path clean"
  - "Accessibility label uses Optional.map so the at-rest string is unambiguous (No week selected.) without a numeric week"
metrics:
  duration: "~5 min"
  completed: "2026-06-10"
  tasks_completed: 2
  files_changed: 1
---

# Phase quick-260610-frp Plan 01: Fix Progression Overview Chart Auto-Show Summary

**One-liner:** Removed four week-1 hard-wires from `NewBlockProgressionChart` so the chart opens clean with nil selection and chrome appears only after user interaction.

## What Was Built

`NewBlockProgressionChart` in `BlockBuilderView.swift` was auto-showing a Week 1 selected-point ring + "WK 1 — INT 75% — VOL Hold" callout pill the moment the New Block screen opened. Four source locations conspired to produce this:

1. `.onAppear` block force-setting `selectedWeek = 1` when nil.
2. Ring `PointMark` gated on `pt.week == (selectedWeek ?? 1)` — rendered around W1 even at rest.
3. `accessibilityLabel` ending with `Selected week \(selectedWeek ?? 1).` — announced "Selected week 1" at rest.
4. Stale comment claiming the state "Defaults to week 1 on appear."

All four were corrected in a single atomic commit.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Gate selection chrome behind user interaction (nil at rest) | d6d10d8 | fitbod/Periodization/BlockBuilderView.swift |
| 2 | Build + run all four New Block guardrail suites | (no new files) | — |

## Changes Made

### Task 1 — Four targeted edits to `NewBlockProgressionChart`

1. **Deleted `.onAppear` block** (primary fix): removed the 4-line modifier that ran `selectedWeek = 1` whenever the chart appeared with a nil selection and non-empty phases.

2. **Ring PointMark re-gated**: changed `if pt.week == (selectedWeek ?? 1)` → `if let sel = selectedWeek, pt.week == sel`. The ring now only renders when an actual selection exists.

3. **Accessibility label fixed**: changed trailing clause from `Selected week \(selectedWeek ?? 1).` → `\(selectedWeek.map { "Selected week \($0)." } ?? "No week selected.")`. At rest, VoiceOver announces "No week selected." After a tap, it announces "Selected week N."

4. **Comment updated**: corrected "Defaults to week 1 on appear." to accurately describe nil-start behavior and when chrome appears.

### Task 2 — All four guardrail suites GREEN

Ran on iPhone 17 Pro simulator (iPhone 16 Pro unavailable in this environment). xcodebuild reported `** TEST SUCCEEDED **` for all four suites:
- `NewBlockBuilderFidelityTests` — source-introspection fidelity (includes pre-existing uncommitted drag/swipe assertions)
- `BlockBuilderViewCopyTests` — verbatim copy guardrail
- `BlockBuilderViewActivationTests` — activation guardrail
- `NewBlockProgressionChartTests` — chart structure (RuleMark, chartXSelection, sensoryFeedback, AreaMark, copy strings, struct name)

## Deviations from Plan

None — plan executed exactly as written. All four edits matched the plan's precise instructions. The callout-pill clamp math, `chartXSelection`, `sensoryFeedback`, axis-label `?? -1` emphasis, and the `if let sel` RuleMark guard were all left intact.

## Known Stubs

None.

## Threat Flags

None — this change removes state mutation from a chart view. No new network endpoints, auth paths, file access patterns, or schema changes.

## Self-Check

### Files exist
- `fitbod/Periodization/BlockBuilderView.swift` — modified, not a new file. Confirmed by commit diff (1 file changed, 4 insertions, 8 deletions).

### Commits exist
- `d6d10d8` — fix(quick-260610-frp): gate progression chart selection chrome behind user interaction

## Self-Check: PASSED
