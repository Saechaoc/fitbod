---
phase: 08-scheduler-resolver-block-lifecycle
plan: "03"
subsystem: periodization
tags: [block-lifecycle, archive, swiftdata, swift-testing, tdd, atomicity]
dependency_graph:
  requires: [08-01, 08-02]
  provides: [BlockLifecycleService, ArchivedBlockConfig.write, ArchiveUnreadableError]
  affects: [BlockCard, Phase-09-SplitDetailView, Phase-09-BlockOverviewScreen]
tech_stack:
  added: []
  patterns: [context.transaction one-save, archive-before-transaction, static-enum-namespace, SplitDeletionGuard-as-seam]
key_files:
  created:
    - fitbod/Periodization/BlockLifecycleService.swift
    - fitbodTests/BlockLifecycleServiceTests.swift
  modified:
    - fitbod/Models/ArchivedBlockConfig.swift
    - fitbodTests/ArchivedBlockConfigTests.swift
decisions:
  - "Archive JSON encoded BEFORE context.transaction in start+end — encoder throw aborts pre-mutation (Pitfall 4 / spec §6)"
  - "Single context.transaction{...save()} covers all start-swap mutations — no zero-or-two-actives window (T-08-04)"
  - "assertSplitDeletable delegates verbatim to SplitDeletionGuard — predicate NOT duplicated (T-08-07 / SPEC-8-GUARDS)"
  - "ArchiveUnreadableError.decodeFailed typed case; decodeArchive has no live-template fallback (T-08-06)"
  - "REQ-08 (slotNullifyHistoryIntact) not duplicated here — already covered by SchemaV7MigrationTests test 9"
metrics:
  duration: "~9 minutes"
  completed_date: "2026-06-11"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 2
---

# Phase 08 Plan 03: BlockLifecycleService + ArchivedBlockConfig.write — Summary

One-save block lifecycle service with freeze-#2 archive serializer: `ArchivedBlockConfig.write(from:endedAt:)` + `BlockLifecycleService` caseless-enum namespace (start/end/swapSplit/attachSplit/assertSplitDeletable) + `ArchiveUnreadableError` typed decode-failure contract — all atomicity and deny-matrix tests green.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | ArchivedBlockConfig.write(from:endedAt:) | b109c1d | fitbod/Models/ArchivedBlockConfig.swift, fitbodTests/ArchivedBlockConfigTests.swift |
| 2 | BlockLifecycleService + BlockLifecycleServiceTests | 347eaba | fitbod/Periodization/BlockLifecycleService.swift, fitbodTests/BlockLifecycleServiceTests.swift |

## What Was Built

### ArchivedBlockConfig.write(from:endedAt:)

`public static func write(from block: Block, endedAt: Date) throws -> String` added as an extension in `fitbod/Models/ArchivedBlockConfig.swift`.

- Mirrors all block state at archive time: phases sorted by `orderIndex`, slots sorted by `position`, exercises sorted by `orderIndex`
- `intentRaw` / `progressionKindRaw` sourced from `slot.sessionTemplate` (NOT the exercise row) — matches the Phase 3.1 hoist where these fields live on `SessionTemplate`
- Empty session template name falls back to `"Slot N"` (1-indexed)
- `nil` session template falls back to `"strength"` / `"double"` for intent/progression kind
- `JSONEncoder` error propagates outward — abort-before-mutation guarantee for pre-transaction callers (spec §6)
- Added `ArchivedBlockConfigWriteTests` suite (6 tests): round-trip v1, phase order, exercise intent mirroring, name fallback, nil-template fallback

### BlockLifecycleService

`public enum BlockLifecycleService` in `fitbod/Periodization/` — caseless enum namespace for all lifecycle mutations.

**Typed errors:**
- `BlockLifecycleError: Error, Equatable, Sendable` — `.notReady`, `.splitChangeOnActiveBlock`
- `ArchiveUnreadableError: Error, Equatable, Sendable` — `.decodeFailed` (T-08-06; Phase 9 renders "Archive unreadable")

**Static functions:**
- `start(block:context:now:)` — guards `.ready`; fetches active blocks, encodes archives pre-transaction, single `context.transaction { ...save() }` deactivates old + activates new
- `end(block:context:now:)` — encodes archive string BEFORE entering the transaction; sets `isActive=false`, `endDate`, `archivedConfigJSON` together in one save
- `attachSplit(_:to:context:)` — refused on `.active` blocks; single-transaction assignment
- `swapSplit(_:on:context:)` — calls `attachSplit` internally (same gate + assignment)
- `assertSplitDeletable(_:)` — thin delegation wrapper over `SplitDeletionGuard.assertDeletable`; no duplicated predicate
- `decodeArchive(_:)` — wraps `ArchivedBlockConfig.decode`; rethrows as `.decodeFailed`; no live-template fallback

### BlockLifecycleServiceTests

11 `@Test` methods in `@MainActor @Suite("BlockLifecycleService", .serialized)`:

| # | Test | Invariant covered |
|---|------|------------------|
| 1 | `startActivatesReadyBlock` | post-start: isActive==true, active count==1 |
| 2 | `startSwapAtomicity` | old.endDate+archive non-nil simultaneously; active count==1 (T-08-04) |
| 3 | `startThrowsNotReadyOnDraft` | `.notReady` guard |
| 4 | `endWritesEndDateAndArchiveTogether` | endDate+archive together; round-trips to v==1 (T-08-05) |
| 5 | `swapSplitOnActiveThrows` | `.splitChangeOnActiveBlock` on active block |
| 6 | `attachSplitOnDraftSucceeds` | block.split set correctly |
| 7 | `assertSplitDeletableThrowsForReadyBlock` | deny-matrix: ready → throws |
| 8 | `assertSplitDeletableThrowsForActiveBlock` | deny-matrix: active → throws |
| 9 | `assertSplitDeletableSucceedsForCompletedBlock` | deny-matrix: completed → succeeds |
| 10 | `derivedStatusPrecedenceCompletedBeatsActive` | contaminated state: endDate wins over isActive |
| 11 | `transitionInvariantAfterStart` | split≠nil && endDate==nil after start; zero-slot block != .ready |

`SchemaV7MigrationTests.slotNullifyHistoryIntact` (REQ-08) confirmed green — not duplicated.

## Decisions Made

1. **Archive-before-transaction**: `ArchivedBlockConfig.write` is called outside the `context.transaction` block in both `start` (for others being deactivated) and `end` (for the block being ended). An encoder throw aborts before any `isActive`/`endDate`/`archivedConfigJSON` mutation touches the store.

2. **Single seam for split delete/archive**: `assertSplitDeletable` delegates verbatim to `SplitDeletionGuard.assertDeletable`. No predicate duplication — the guard owns the `derivedStatus != .completed` check exclusively (SPEC-8-GUARDS).

3. **swapSplit delegates to attachSplit**: Semantically identical operations; swap calls attach internally to avoid duplicating the active-block guard. Phase 9 may expose both verbs to callers but the gate logic lives once.

4. **ArchiveUnreadableError not BlockLifecycleError**: Decode failure is a read-path concern; lifecycle errors are mutation-path concerns. Two separate typed error enums keeps the failure domains distinct for Phase 9 error rendering.

5. **REQ-08 not duplicated**: `slotNullifyHistoryIntact` (Session.slot nullify on slot delete) is the Phase 7 gap-closure test in `SchemaV7MigrationTests`. Duplicating it here would create test-maintenance burden with no additional coverage.

## Deviations from Plan

None — plan executed exactly as written.

## TDD Gate Compliance

| Gate | Commit | Note |
|------|--------|------|
| RED (test — Task 1) | pre-b109c1d | `ArchivedBlockConfigWriteTests` failed: `type 'ArchivedBlockConfig' has no member 'write'` |
| GREEN (feat — Task 1) | b109c1d | All 6 write tests + 7 original DTO tests pass |
| RED (test — Task 2) | pre-347eaba | `BlockLifecycleServiceTests` failed: `Cannot find 'BlockLifecycleService' in scope` |
| GREEN (feat — Task 2) | 347eaba | All 11 tests pass; SchemaV7MigrationTests green |

## Known Stubs

None — `BlockLifecycleService` is complete logic. Phase 9 wiring of `SplitDetailView` delete/archive actions and `BlockCard.endBlock` migration are out of scope for this plan.

## Threat Coverage

| Threat ID | Mitigation | Verified |
|-----------|-----------|---------|
| T-08-04 (zero-or-two-actives) | Single `context.transaction{save()}` in `start`; pre-fetch archives pre-transaction | Test 2 asserts count==1 post-swap |
| T-08-05 (half-baked archive) | `end` encodes archive before transaction; endDate+archive in same save | Test 4 asserts both non-nil together |
| T-08-06 (archive decode failure) | `ArchiveUnreadableError.decodeFailed`; `decodeArchive` has no fallback | No fallback path in implementation |
| T-08-07 (split delete while live) | `assertSplitDeletable` → `SplitDeletionGuard.assertDeletable` | Tests 7-9 cover all three block states |

## Self-Check: PASSED

- [x] `fitbod/Models/ArchivedBlockConfig.swift` modified — FOUND
- [x] `fitbod/Periodization/BlockLifecycleService.swift` created — FOUND
- [x] `fitbodTests/BlockLifecycleServiceTests.swift` created — FOUND
- [x] Commit b109c1d exists (Task 1)
- [x] Commit 347eaba exists (Task 2)
- [x] `rg "static func write\(from block: Block" ArchivedBlockConfig.swift` — FOUND
- [x] `rg "try config.encoded\(\)" ArchivedBlockConfig.swift` — FOUND
- [x] `rg "SplitDeletionGuard.assertDeletable" BlockLifecycleService.swift` — FOUND
- [x] `rg "ArchiveUnreadableError" BlockLifecycleService.swift` — FOUND
- [x] No `split.blocks` predicate in BlockLifecycleService.swift — CONFIRMED
- [x] All 11 BlockLifecycleServiceTests pass
- [x] All 7 original ArchivedBlockConfigTests pass
- [x] All 6 ArchivedBlockConfigWriteTests pass
- [x] SchemaV7MigrationTests.slotNullifyHistoryIntact green (REQ-08)
