---
phase: 08-scheduler-resolver-block-lifecycle
plan: "04"
subsystem: sessions
tags: [session-factory, block-lifecycle, prescription, cr-02, swift-testing, tdd]
dependency_graph:
  requires: [08-01, 08-02, 08-03]
  provides: [SessionFactory.start(activeBlock:), SPEC-8-FACTORY, SPEC-8-TESTS]
  affects: [TodayView (08-05), SessionLoggerView]
tech_stack:
  added: []
  patterns: [activeBlock-parameter-injection, deload-volume-multiplier, sentinel-proof-test]
key_files:
  created: []
  modified:
    - fitbod/Sessions/SessionFactory.swift
    - fitbod/Models/SessionTemplate.swift
    - fitbodTests/SessionFactoryTests.swift
decisions:
  - "activeBlock: Block? = nil default preserves backward-compat for ad-hoc/test callers"
  - "blockReferenceCopiedFromRoutine updated to pass activeBlock: explicitly — test now exercises Phase 8 path"
  - "makeDeloadBlock helper uses daysAgo=1 so .now always falls in the deload phase window"
  - "template.block sentinel test sets a distinct block on routine.block and asserts session.block != sentinel"
metrics:
  duration: "~8 minutes"
  completed_date: "2026-06-11"
  tasks_completed: 2
  tasks_total: 2
  files_created: 0
  files_modified: 3
---

# Phase 08 Plan 04: SessionFactory activeBlock Migration — Summary

CR-02 carry-over resolved: `SessionFactory.start` gains `activeBlock: Block? = nil` parameter; all three prescription-path reads of `template.block` (lines 133/165/275) replaced with `activeBlock`; legacy edge documented deprecated; three new tests prove the migration is watertight.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Migrate SessionFactory.start to activeBlock parameter + deprecate legacy edge | 2ca96df | fitbod/Sessions/SessionFactory.swift, fitbod/Models/SessionTemplate.swift, fitbodTests/SessionFactoryTests.swift |
| 2 | SessionFactoryTests — prescription uses activeBlock not template.block | ee16260 | fitbodTests/SessionFactoryTests.swift |

## What Was Built

### SessionFactory.start Migration

`public static func start(template:activeBlock:on:context:)` — new signature adds `activeBlock: Block? = nil` immediately after `template:` (default nil for backward-compatible ad-hoc sessions).

Three prescription-path reads migrated off `template.block`:

1. **Line 133 (session.block):** `session.block = activeBlock` — session snapshot now carries the injected resolver context, not the stale template edge
2. **Line 165-167 (scheduledBlockPhase):** `activeBlock.flatMap { block in PeriodizationEngine.phase(for: block, on: date) }` — block-phase resolution uses the active block
3. **Line 275 (strategy.prescribe):** `block: activeBlock` — the progression strategy receives the active block context

Doc comment updated with Phase 8 / CR-02 note.

### SessionTemplate.block Deprecation

`// DEPRECATED(Phase 8): write-orphaned for prescription resolution; SessionFactory no longer reads this edge. Removal in V8 schema migration. Non-prescription writers (RoutineDraft, RoutineDuplicator, BackupRestorer) still set it — see RESEARCH §Pattern 4 readers inventory.`

Field and `Block.legacyTemplates` inverse retained — removal deferred to V8 schema migration.

### SessionFactoryTests (3 new + 1 updated)

| Test | Invariant |
|------|-----------|
| `prescriptionResolvesFromActiveBlockNotTemplateBlock` | `session.block?.id == theBlock.id`; deload volumeMultiplier 0.5 cuts 3 sets → 1 (proves activeBlock drives PeriodizationEngine) |
| `templateBlockSentinelIgnored` | `template.block` set to sentinelBlock; session.block == theBlock (NOT sentinel) — REQ-07 / T-08-08 |
| `activeBlockNilAdHocSessionHasNilBlock` | `activeBlock=nil` default → `session.block == nil`; ad-hoc sessions unaffected |
| `blockReferenceCopiedFromRoutine` (updated) | Now calls `start(template:activeBlock:block:)` explicitly — exercises Phase 8 path |

Helper `makeDeloadBlock(ctx:daysAgo:)` builds a Block with a 1-week deload phase (volumeMultiplier=0.5) starting `daysAgo` days before `.now` so date always falls in the deload window.

**Full suite: 12 tests — all pass.**

## Decisions Made

1. **Default nil for backward compatibility**: `activeBlock: Block? = nil` means all existing callers (tests, UI) continue to compile without changes. The TodayView call-site rewire (passing the resolved activeBlock) is 08-05.

2. **Deload as the observable block-phase effect**: deload volumeMultiplier reduces planned set count — observable at the SetEntry level without needing RPE/weight history. Simpler and more deterministic than intensity-multiplier tests.

3. **Sentinel test pattern for T-08-08**: Setting `template.block` to a distinct block and asserting `session.block != sentinel` is the tightest possible proof that the legacy edge is not consulted. No workaround needed.

4. **blockReferenceCopiedFromRoutine updated**: The pre-Phase-8 test set `routine.block = block` and expected it on the session via the factory. After migration, the factory ignores `template.block`, so the test was updated to pass `activeBlock: block` explicitly — keeping the test meaningful while respecting the new contract.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated existing blockReferenceCopiedFromRoutine test**
- **Found during:** Task 1
- **Issue:** The pre-Phase-8 test set `routine.block = block` and asserted `session.block?.id == block.id` via the factory snapshot. After migration the factory ignores `template.block`, so this test would fail.
- **Fix:** Updated the test to pass `activeBlock: block` explicitly. The test now exercises the correct Phase 8 code path.
- **Files modified:** `fitbodTests/SessionFactoryTests.swift`
- **Commit:** 2ca96df (included in Task 1 commit)

## Threat Coverage

| Threat ID | Mitigation | Verified |
|-----------|-----------|---------|
| T-08-08 (wrong prescription via legacy template.block) | All three prescription reads migrated to activeBlock; sentinel test proves template.block is ignored | `templateBlockSentinelIgnored` asserts session.block != sentinel |

## Known Stubs

None.

## Self-Check: PASSED

- [x] `fitbod/Sessions/SessionFactory.swift` modified — FOUND
- [x] `fitbod/Models/SessionTemplate.swift` modified — FOUND
- [x] `fitbodTests/SessionFactoryTests.swift` modified — FOUND
- [x] Commit 2ca96df exists (Task 1)
- [x] Commit ee16260 exists (Task 2)
- [x] `rg "activeBlock: Block" fitbod/Sessions/SessionFactory.swift` — FOUND (line 112)
- [x] Zero prescription-path `template.block` reads in start(): `rg "template.block" fitbod/Sessions/SessionFactory.swift` returns only doc comment
- [x] `rg "DEPRECATED.Phase 8" fitbod/Models/SessionTemplate.swift` — FOUND (line 52)
- [x] RoutineDraft.swift, RoutineDuplicator.swift, BackupRestorer.swift NOT in diff — CONFIRMED
- [x] All 12 SessionFactoryTests pass
