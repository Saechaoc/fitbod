---
phase: 09-program-surfaces
plan: "03"
subsystem: today-view
tags: [swiftui, navigation, bru, copy-pins, fix-it-surface]
dependency_graph:
  requires:
    - fitbod/Periodization/SplitDetailRoute.swift  # from 09-01
    - fitbod/Periodization/SplitDetailView.swift    # from 09-01
    - fitbod/Models/Block.swift
    - fitbod/Models/Split.swift
    - fitbod/Design/BRUButton.swift
    - fitbod/Design/BRUFont.swift
    - fitbod/Design/Color+BRU.swift
  provides:
    - fitbod/Views/TodayView.swift  # EmptySplitFixIt + SplitDetailRoute destination
  affects:
    - TodayView .emptySplit branch — now points to EmptySplitFixIt instead of placeholder
tech_stack:
  added: []
  patterns:
    - "Fix-it surface factored into fileprivate struct taking onGoToRoutine: () -> Void closure — stack-agnostic, caller threads navigationPath.append"
    - "SplitDetailRoute destination on Today's own NavigationStack — UUID-FetchDescriptor fetch mirrors BlockOverviewRoute pattern"
    - "Defensive fallback: if activeBlocks.first?.split is nil in .emptySplit branch, render noWorkoutScheduledEmptyState rather than crash"
key_files:
  created: []
  modified:
    - fitbod/Views/TodayView.swift
    - fitbodTests/TodayViewBRUCopyTests.swift
decisions:
  - "EmptySplitFixIt factored as fileprivate struct (not inline @ViewBuilder) to keep TodayView body readable and allow isolated copy testing"
  - "Accessibility label on EmptySplitFixIt uses .accessibilityElement(children: .combine) per UI-SPEC Accessibility Contract §EmptySplitFixIt"
metrics:
  duration_seconds: 420
  completed_date: "2026-06-11"
  tasks_completed: 2
  files_created: 0
  files_modified: 2
---

# Phase 9 Plan 03: EmptySplitFixIt + SplitDetailRoute on Today's Stack Summary

**One-liner:** EmptySplitFixIt view with verbatim BRU copy ("ROUTINE HAS NO SESSIONS" / body / "GO TO ROUTINE ▸") wired to SplitDetailRoute destination on Today's own NavigationStack, replacing the Phase 8 placeholder.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | EmptySplitFixIt view + SplitDetailRoute destination on Today's stack | 5b6fd68 | TodayView.swift |
| 2 | TodayViewBRUCopyTests — pin emptySplit fix-it copy, assert rest-day copy still present | 124344f | TodayViewBRUCopyTests.swift |

---

## What Was Built

### TodayView.swift — emptySplitFixItState replaced

The Phase 8 placeholder `emptySplitFixItState` (which showed a stale informal "Routine has no sessions / Add sessions in the Program tab." message) was replaced with a call to a new `EmptySplitFixIt` fileprivate struct. The call site guards `activeBlocks.first?.split` — if nil (defensive, should not occur given the resolver contract), falls back to `noWorkoutScheduledEmptyState`.

### fileprivate struct EmptySplitFixIt

Anatomy per UI-SPEC §8 and Copywriting Contract:
- `Text("ROUTINE HAS NO SESSIONS")` — `BRUFont.bodyEmphasis`, `.textCase(.uppercase)`, `.tracking(1.2)`, `Color.bruInk`
- `Text("The routine linked to this block has no sessions scheduled. Add a session to continue.")` — `BRUFont.bodyDefault`, `Color.bruMuted`
- `BRUButton("GO TO ROUTINE ▸", kind: .ghost)` — calls `onGoToRoutine()` closure
- Padding: `.horizontal 16`, `.vertical 24`; `.frame(maxWidth: .infinity, alignment: .leading)`; `.background(Color.bruPaper)`
- Accessibility: `.accessibilityElement(children: .combine)` + combined label per UI-SPEC Accessibility Contract

### SplitDetailRoute destination on Today's NavigationStack

Registered `.navigationDestination(for: SplitDetailRoute.self)` alongside the existing `BlockOverviewRoute` destination (line ~208). Pattern mirrors `BlockOverviewRoute`: resolves `Split` by UUID via `FetchDescriptor`, presents `SplitDetailView(split:)`, fallback `Text("Routine not found")` if UUID not found. No cross-tab navigation.

### TodayViewBRUCopyTests.swift — 3 new tests

Added under `// MARK: - 9. emptySplit fix-it copy (Phase 9 Plan 03)`:

1. `emptySplitFixItCopyVerbatim` — pins all three verbatim strings: heading, body, CTA
2. `emptySplitFixItNavigationPattern` — pins `navigationPath.append(SplitDetailRoute.detail(splitID:` and `navigationDestination(for: SplitDetailRoute.self)`
3. `restDayEmptyStateCopyPreserved` — asserts `"No workout scheduled"` and `"Build a routine or pick one from your library."` still present (rest-day copy untouched)

All 23 `TodayViewBRUCopyTests` pass (20 pre-existing + 3 new).

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Known Stubs

None. The fix-it surface is fully wired: copy is verbatim, navigation pushes a real `SplitDetailView`, and the destination is registered on Today's own stack.

---

## Threat Surface Scan

No new network endpoints, auth paths, or trust-boundary schema changes. Threat mitigations addressed:
- **T-09-07**: `.emptySplit` now renders `EmptySplitFixIt` (not `noWorkoutScheduledEmptyState`); copy pins assert the distinct heading — mitigated.
- **T-09-08**: `navigationDestination(for: SplitDetailRoute.self)` registered on Today's stack; `activeBlocks.first?.split` guard prevents pushing with a nil split — mitigated.

---

## Self-Check: PASSED

- [x] `fitbod/Views/TodayView.swift` modified — EmptySplitFixIt struct present, SplitDetailRoute destination registered
- [x] `fitbodTests/TodayViewBRUCopyTests.swift` modified — 3 new tests added
- [x] Commit 5b6fd68 exists (Task 1)
- [x] Commit 124344f exists (Task 2)
- [x] Build: SUCCEEDED
- [x] TodayViewBRUCopyTests: 23/23 PASSED
- [x] `.restDay` / `.noBlock` branches and `noWorkoutScheduledEmptyState` byte-unchanged
- [x] CTA navigates on Today's own stack (SplitDetailRoute on Today's NavigationStack)
