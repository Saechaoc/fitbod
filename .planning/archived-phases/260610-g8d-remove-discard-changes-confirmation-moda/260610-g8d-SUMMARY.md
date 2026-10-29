---
phase: 260610-g8d
plan: "01"
subsystem: periodization/new-block
tags: [ui, modal, friction-reduction, swiftui]
dependency_graph:
  requires: []
  provides: [direct-back-navigation-from-new-block]
  affects: [fitbod/Periodization/BlockBuilderView.swift]
tech_stack:
  added: []
  patterns: [swiftui-confirmationDialog-removal]
key_files:
  created: []
  modified:
    - fitbod/Periodization/BlockBuilderView.swift
    - fitbodTests/BlockBuilderViewCopyTests.swift
decisions:
  - "Removed discard confirmation modal entirely — back/cancel now calls dismiss() directly regardless of unsaved state"
  - "Deleted all four supporting symbols: presentingDiscardConfirm, initialSnapshot, hasUnsavedChanges, snapshotHash()"
  - "Kept @Environment(\\.dismiss) in place — still used by both cancel() and saveIfValid()"
  - "Kept the selectedPreset clause in .onAppear — only the initialSnapshot clause removed"
  - "Did not touch the unrelated Apply Preset? confirmationDialog or its supporting state"
metrics:
  duration_minutes: 8
  completed_date: "2026-06-10"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
---

# Phase 260610-g8d Plan 01: Remove Discard Changes Confirmation Modal Summary

Surgical removal of the "Discard Changes?" confirmation dialog from the New Block editor — back/cancel now dismisses immediately with no unsaved-state branch.

## What Was Built

Removed the discard confirmation modal from `BlockBuilderView` along with all four symbols that existed solely to support it (`presentingDiscardConfirm`, `initialSnapshot`, `hasUnsavedChanges`, `snapshotHash()`). Both the `< PROGRAM` back button and the bottom-bar `CANCEL` button route through the same `cancel()` handler, which now contains a single `dismiss()` call. The unrelated "Apply Preset?" confirmation dialog and all its supporting state are untouched. Three stale discard assertions removed from `BlockBuilderViewCopyTests`.

## Tasks

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Remove discard confirmation modal and its dead support code; update copy guardrail | 7c4c169 | BlockBuilderView.swift, BlockBuilderViewCopyTests.swift |
| 2 | Clean simulator build + full New Block guardrail suite green | (verify only — no source edits) | — |

## Verification Results

- `rg "presentingDiscardConfirm|initialSnapshot|snapshotHash|hasUnsavedChanges|Discard Changes|Keep Editing" fitbod/Periodization/BlockBuilderView.swift` — zero matches
- `rg -q "Apply Preset" fitbod/Periodization/BlockBuilderView.swift` — FOUND (unrelated dialog intact)
- `rg -q "private func cancel" fitbod/Periodization/BlockBuilderView.swift` — FOUND
- iOS simulator build: BUILD SUCCEEDED
- BlockBuilderViewCopyTests — PASSED
- NewBlockBuilderFidelityTests — PASSED (6 tests)
- BlockBuilderViewActivationTests — PASSED (3 tests)
- NewBlockProgressionChartTests — PASSED (5 tests)
- Overall: TEST SUCCEEDED (0 failures)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. Pure local UI-state removal with no new network, persistence, or input surface.

## Self-Check: PASSED

- `fitbod/Periodization/BlockBuilderView.swift` — exists, modified
- `fitbodTests/BlockBuilderViewCopyTests.swift` — exists, modified
- Commit `7c4c169` — verified in git log
- All four guardrail suites green — TEST SUCCEEDED
