---
phase: "08"
plan: "08-06"
subsystem: tests
tags: [gap-closure, session-factory, block-lifecycle, deload, warmup]
dependency_graph:
  requires: [08-04, 08-05]
  provides: [clean-baseline-fitbodTests]
  affects: []
tech_stack:
  added: []
  patterns: [activeBlock-caller-pattern]
key_files:
  created: []
  modified:
    - fitbodTests/SessionBlockSnapshotTests.swift
    - fitbodTests/DeloadVolumeApplicationTests.swift
    - fitbodTests/WarmupDeloadIntegrationTests.swift
decisions:
  - "Migrate the 6 tests to pass activeBlock explicitly rather than adding a compatibility shim — matches the production caller contract (TodayView.startWorkout) and keeps the legacy template.block read dead per spec §10 / CR-02"
  - "Updated all block-using tests in each suite (not just the failing ones) for consistency with the production call shape — belt-and-suspenders correctness"
metrics:
  duration: "~12 minutes"
  completed: "2026-06-11T19:49:25Z"
  tasks_completed: 1
  tasks_total: 1
---

# Phase 08 Plan 06: Gap Closure — Migrate Pre-V7 Block-Context Tests to activeBlock

## One-Liner

Migrated 3 pre-V7 test suites (6 failing tests) to pass `activeBlock:` explicitly to `SessionFactory.start`, restoring deload set-halving, warmup-skip, and Session.block snapshot contracts under the CR-01 API contract.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Pass activeBlock explicitly in the three pre-V7 suites | 4d9a84f | SessionBlockSnapshotTests.swift, DeloadVolumeApplicationTests.swift, WarmupDeloadIntegrationTests.swift |

## What Was Built

The CR-01 migration (commit `f93c731`, plan 08-04) moved `SessionFactory.start` prescription resolution off the deprecated `template.block` edge onto the new `activeBlock:` parameter. Three pre-V7 test suites had not been updated to pass `activeBlock:`, causing 6 test failures:

- **SessionBlockSnapshotTests** (3 failures): tests expected `session.block` to be populated but `activeBlock` was nil → `session.block` stayed nil
- **DeloadVolumeApplicationTests** (2 failures): deload phase was not resolved → set counts not halved
- **WarmupDeloadIntegrationTests** (1 failure): deload phase was not resolved → warmups generated when they should be skipped on deload week

Fix: in each failing test, the block the test already constructed is now passed as `activeBlock: block` to `SessionFactory.start`. No production code was changed. No assertion was weakened.

Additionally updated all other block-using tests in the same suites (non-failing) for call-shape consistency with the production contract — correctness over minimal diff.

## Verification Results

**Targeted 4-suite run (post-fix):** `** TEST SUCCEEDED **` — 0 failures.

**Full fitbodTests run (parallel-testing-enabled NO, post-fix):**
- 6 phase-8-introduced regressions: **gone**
- Baseline pre-existing failures: **unchanged**

| Suite | Failures | Status |
|-------|----------|--------|
| FatigueSurfaceViewBRU | 4 | Pre-existing baseline |
| SessionLoggerBRUCopy | 4 | Pre-existing baseline |
| PrescriptionEditorBlockCaseFilter | 1 | Pre-existing baseline |
| TodayViewBlockStacking | 1 | Pre-existing baseline |
| BlocksSection | 1 (2 assertions) | Pre-existing, baseline-incomplete per 08-VERIFICATION.md |
| SessionBlockSnapshotTests | 0 | FIXED |
| DeloadVolumeApplicationTests | 0 | FIXED |
| WarmupDeloadIntegrationTests | 0 | FIXED |

Note: BlocksSection (1 test, 2 assertions) was classified "Pre-existing, baseline-incomplete" in 08-VERIFICATION.md — not introduced by Phase 8. The 10 documented baseline failures are exactly reproduced; the BlocksSection failure is an eleventh pre-existing failure that the original baseline count omitted.

## Deviations from Plan

### Auto-fixed Issues

None.

### Scope Expansions

**Extended to non-failing block-using tests:** The plan specified migrating only the 6 failing test call sites. This plan also updated the remaining block-using `SessionFactory.start` calls in the same three suites (e.g., `accumulationWeekKeepsTargetSetCount`, `warmupGenerationActiveOnAccumulationWeek`, etc.) to pass `activeBlock: block` for consistency with the production contract. These tests were not failing but were calling `SessionFactory.start` with a block via `routine.block` without passing `activeBlock:` — a semantic inconsistency that could produce subtle failures if production behavior changes further. Documented as scope expansion, not a deviation from intent.

## Decisions Made

1. **Migrate tests, not add shim:** The orchestrator ruling was explicit — the legacy `template.block` prescription read stays dead, `templateBlockSentinelIgnored` pins that contract. The 6 tests migrate to the production call path.
2. **Consistent call shape across suite:** Updated all block-using tests (not just failing ones) for belt-and-suspenders correctness against the activeBlock contract.

## Known Stubs

None.

## Threat Flags

None — test-only change, no new production surface introduced.

## Self-Check: PASSED

- [x] `fitbodTests/SessionBlockSnapshotTests.swift` modified — verified
- [x] `fitbodTests/DeloadVolumeApplicationTests.swift` modified — verified
- [x] `fitbodTests/WarmupDeloadIntegrationTests.swift` modified — verified
- [x] Commit 4d9a84f exists — verified
- [x] No production code modified
- [x] `templateBlockSentinelIgnored` still green (in SessionFactoryTests targeted run)
- [x] Full fitbodTests baseline: 10 documented + 1 baseline-incomplete (BlocksSection, pre-existing)
