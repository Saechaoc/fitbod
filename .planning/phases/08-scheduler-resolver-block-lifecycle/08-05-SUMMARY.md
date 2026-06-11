---
phase: 08-scheduler-resolver-block-lifecycle
plan: "05"
subsystem: today-tab-wiring
tags: [today-resolver, block-overview, session-membership, tdd]
dependency_graph:
  requires: ["08-01", "08-04"]
  provides: ["SPEC-8-TODAY"]
  affects: ["TodayView", "BlockOverviewScreen", "BlockOverviewScreenWeekCarouselTests"]
tech_stack:
  added: []
  patterns: ["TodayResolver.resolve wired to TodayView.todaysRoutine", "slot-primary OR block-ID fallback membership predicate"]
key_files:
  created: []
  modified:
    - fitbod/Views/TodayView.swift
    - fitbod/Periodization/BlockOverviewScreen.swift
    - fitbodTests/BlockOverviewScreenWeekCarouselTests.swift
decisions:
  - ".emptySplit preserved as distinct case with Phase 9 TODO — never collapsed into restDay"
  - "MesocycleWeekPage.scheduledSlots already wired to (block.split?.slots ?? []).sorted — no change needed (Phase 9 deferred)"
  - "Slot-based predicate ordered FIRST in all three BlockOverviewScreen membership ORs; block-ID remains fallback for pre-resolver sessions"
metrics:
  duration: "~4 minutes"
  completed: "2026-06-11"
  tasks_completed: 2
  files_changed: 3
---

# Phase 08 Plan 05: TodayView + BlockOverviewScreen Wiring Summary

SPEC-8-TODAY shipped: TodayResolver wired into TodayView.todaysRoutine; startWorkout passes activeBlock to SessionFactory; BlockOverviewScreen membership checks refined to slot-primary OR block-ID fallback with Phase 8 TODOs resolved; dual-path carousel tests added and passing.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Wire TodayView.todaysRoutine to TodayResolver + pass activeBlock to startWorkout | `aad28da` | fitbod/Views/TodayView.swift |
| 2 | Confirm/refine BlockOverviewScreen membership checks + resolve TODOs + membership assertion test | `dc71317` | fitbod/Periodization/BlockOverviewScreen.swift, fitbodTests/BlockOverviewScreenWeekCarouselTests.swift |

## What Was Built

### Task 1 — TodayView wiring

Replaced the `todaysRoutine` nil stub with a four-branch switch on `TodayResolver.resolve(block:context:)`:

- `.session(let slot)` → returns `slot.sessionTemplate` (BlackSlabCTA renders)
- `.restDay`, `.noBlock` → `nil` (falls through to existing empty/start-block states)
- `.emptySplit` → `nil` with a `// TODO Phase 9` comment (distinct case, not collapsed into restDay)

Resume-state branch ordering (`if let active = activeSessions.first`) is unchanged — it still precedes the `else if let routine = todaysRoutine` branch in `body`, preserving the CTA precedence guarantee from spec §5 (threat T-08-09 mitigated).

`startWorkout(_:)` updated to pass `activeBlock: activeBlocks.first` so `SessionFactory.start` can resolve prescription from the active block (08-04 migration).

### Task 2 — BlockOverviewScreen membership refinement

All three membership OR predicates reordered to `session.slot?.split?.id == block.split?.id || session.block?.id == block.id` (slot-based primary, block-ID fallback). The three `// TODO Phase 8` comments were replaced with the resolved Phase 8 rationale comment.

Two new `@Test` assertions added to `BlockOverviewScreenWeekCarouselTests`:

- `slotBasedPathAloneMarksDone` — builds a Session with `slot` wired to the block's split but `session.block = nil`; proves the primary OR branch alone recognises membership (threat T-08-10 mitigated).
- `blockIDFallbackPathAloneMarksDone` — builds a legacy Session with `session.slot = nil` but `session.block = block`; proves the fallback OR branch alone recognises membership.

Both use `SchemaV7.models` + `FitbodSchemaMigrationPlan` in-memory containers, mirroring the pattern from `TodayResolverTests`.

### MesocycleWeekPage confirmation

`MesocycleWeekPage.scheduledSlots(for:)` at line 106–108 of `MesocycleWeekPage.swift` already returns `(block.split?.slots ?? []).sorted { $0.position < $1.position }`. No changes needed. This confirms RESEARCH note "already wired via block.split?.slots". Full Phase 9 split-picker component tracked in Phase 9 per plan note.

## Verification

- `BlockOverviewScreenWeekCarouselTests` suite: **6/6 passed** (4 pre-existing + 2 new)
- App build: **BUILD SUCCEEDED**
- `rg -c "slot?.split?.id == block.split?.id" BlockOverviewScreen.swift` → **3** (all three sites)
- `rg -n "TODO Phase 8" BlockOverviewScreen.swift` → **empty** (all resolved)
- `rg -n "TodayResolver.resolve(block:" TodayView.swift` → line 368 (wired)
- `rg -n "activeBlock: activeBlocks.first" TodayView.swift` → line 400 (wired)

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None introduced by this plan. The `.emptySplit` case intentionally returns `nil` with a Phase 9 TODO; this is not a stub — it is the specified behavior per RESEARCH Open Question 1 and spec §5.

## Self-Check: PASSED

- `fitbod/Views/TodayView.swift` — modified, exists
- `fitbod/Periodization/BlockOverviewScreen.swift` — modified, exists
- `fitbodTests/BlockOverviewScreenWeekCarouselTests.swift` — modified, exists
- Commit `aad28da` — verified in git log
- Commit `dc71317` — verified in git log
