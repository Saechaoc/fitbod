---
phase: 08-scheduler-resolver-block-lifecycle
plan: "01"
subsystem: periodization
tags: [resolver, scheduler, swiftdata, swift-testing, rotation, fixedWeekly]
dependency_graph:
  requires: []
  provides: [TodayResolver, TodayResolution]
  affects: [TodayView, SessionFactory, Phase-09-surfaces]
tech_stack:
  added: []
  patterns: [pitfall-1-safe-fetch, pitfall-3-guard, calendar-value-injection, static-enum-namespace]
key_files:
  created:
    - fitbod/Periodization/TodayResolver.swift
    - fitbodTests/TodayResolverTests.swift
  modified: []
decisions:
  - "Broad #Predicate gate (completedAt != nil only); all multi-level chains in Swift .first{} post-filter — Pitfall-1 compliance"
  - "guard slotCount >= 1 precedes every % slotCount — Pitfall-3 compliance"
  - "trainingDays read verbatim at resolve time; sort-at-write is 08-02 responsibility"
  - "TodayResolution.emptySplit kept distinct from .restDay — Phase 9 renders them differently"
metrics:
  duration: "~30 minutes"
  completed_date: "2026-06-11"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
---

# Phase 08 Plan 01: TodayResolver + TodayResolution — Scheduler Engine Summary

Pure scheduler engine: `TodayResolution` enum (4-case public contract for Phase 9 surfaces) + `TodayResolver` caseless-enum namespace with injectable `today`/`calendar` parameters, Pitfall-1-safe fetch, Pitfall-3 zero-slot guard, and 14-test spec §9 suite — all green.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | TodayResolver + TodayResolution enum | 3facc5a | fitbod/Periodization/TodayResolver.swift |
| 2 | TodayResolverTests spec §9 suite | d4b624d | fitbodTests/TodayResolverTests.swift |

## What Was Built

### TodayResolver.swift

`TodayResolution` enum with exactly four cases:
- `case session(SplitSessionSlot)` — a slot is scheduled; pass `slot.sessionTemplate` to `SessionFactory`
- `case restDay` — fixedWeekly mode; today's weekday is not in `trainingDays`
- `case emptySplit` — block's split has zero slots; Phase 9 surfaces a repair prompt
- `case noBlock` — `block.split == nil`

`TodayResolver` caseless-enum namespace (mirrors `PreviousMatchingIntent` shape):
- `resolve(block:context:today:calendar:)` — public entry point; branches on `schedulingMode`
- `resolveRotation` — Pitfall-1-safe broad fetch (`completedAt != nil` only in `#Predicate`); unified Swift post-filter: `block?.id == targetBlockID && slot != nil && slot?.split?.id == targetSplitID` skips ad-hoc / deleted-slot / swapped-split / in-progress sessions identically
- `resolveFixedWeekly` — reads `trainingDays` verbatim (no re-sort); `storedIndex % slotCount` as runtime guard for mid-block slot-count drift
- `sortedSlots(_:)` — shared utility; both resolvers share the same ascending-position sort

### TodayResolverTests.swift

14 `@Test` methods covering all spec §9 Phase-8 scheduler cases:

**Rotation (8 tests):**
1. `rotationNoSessionsReturnsSlot0` — fresh block → slot 0
2. `rotationAdvancesFromPosition2To3` — latest at position 2 → position 3
3. `rotationWrapsFromLastSlotToZero` — last position → wraps via `% slotCount`
4. `rotationSkipsAdHocSession` — ad-hoc (slot=nil) skipped; live-slot anchor used
5. `rotationSkapsSwappedSplitSession` — swapped-split slot skipped; falls back to slot 0
6. `rotationIgnoresInProgressSession` — `completedAt=nil` excluded entirely (Pitfall 5)
7. `rotationComputesNextAgainstCurrentPositions` — position arithmetic uses live graph
8. `rotationSkipsDeletedSlotSession` — nullified slot reads as ad-hoc → skipped

**fixedWeekly (4 tests):**
9. `fixedWeeklyWeekdayAtIndex1Returns1` — `storedIndex(day) == 1` → position 1
10. `fixedWeeklyAbsentWeekdayReturnsRestDay` — missing weekday → `.restDay`
11. `fixedWeeklyCountDriftModGuard` — 5 trainingDays / 3 slots → `4 % 3 == 1`
12. `fixedWeeklyZeroSlotsReturnsEmptySplit` — zero slots → `.emptySplit`

**Shared (2 tests):**
13. `rotationZeroSlotsReturnsEmptySplit` — rotation zero-slot guard (Pitfall 3)
14. `nilSplitReturnsNoBlock` — `block.split == nil` → `.noBlock`

Suite: `@MainActor @Suite("TodayResolver", .serialized)`, `SchemaV7` in-memory container with `FitbodSchemaMigrationPlan`, insert-before-relate convention throughout.

## Decisions Made

1. **Pitfall-1 compliance**: `#Predicate` gate is limited to the flat `completedAt != nil` check. All multi-level chains (`session.block?.id`, `session.slot?.split?.id`) live in a Swift `.first { }` post-filter. This matches the established `PreviousMatchingIntent` and `fetchHistoryPoints` patterns.

2. **Pitfall-3 compliance**: `guard slotCount >= 1 else { return .emptySplit }` precedes both `% slotCount` occurrences (one in `resolveRotation`, one in `resolveFixedWeekly`). Zero-slot splits never crash the resolver.

3. **Verbatim trainingDays read**: `resolveFixedWeekly` reads `block.trainingDays` in stored order without re-sorting. Sort-at-write is the responsibility of `TrainingDaysWriter` (plan 08-02). Re-sorting at read time would violate the locale invariant (a region change after write must not remap days to different slots).

4. **emptySplit distinct from restDay**: The two cases are never collapsed. Phase 9 needs to distinguish "no workout today by schedule" (rest day) from "the split has been emptied and needs repair" (empty split). Merging them would require a Phase 9 migration to split them back.

5. **Injectable calendar + today**: Both parameters default to `.now` and `.current` for production use, but accept injected values for tests. This follows the `MondayAtMidnight` calendar-injection precedent already in the codebase.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — `TodayResolver` is complete logic with no placeholder return values. Phase-9 wiring of `TodayView.todaysRoutine` is out of scope for this plan (plan 08-05).

## Threat Flags

No new threat surface introduced. `T-08-01` (Pitfall-3 zero-slot guard) and `T-08-02` (Pitfall-5 in-progress exclusion) from the plan's threat register are both mitigated: the `guard slotCount >= 1` precedes every modulo, and the `completedAt != nil` predicate gate excludes in-progress sessions at the fetch level.

## Self-Check: PASSED

- [x] `fitbod/Periodization/TodayResolver.swift` — created (190 lines)
- [x] `fitbodTests/TodayResolverTests.swift` — created (463 lines)
- [x] Commit 3facc5a exists (feat: TodayResolver)
- [x] Commit d4b624d exists (test: TodayResolverTests)
- [x] All 14 tests pass
- [x] BUILD SUCCEEDED
