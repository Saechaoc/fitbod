---
phase: 08-scheduler-resolver-block-lifecycle
verified: 2026-06-11T00:00:00Z
status: gaps_found
score: 18/18 must-have truths source-verified; BUT 6 phase-8-introduced test regressions
overrides_applied: 0
gaps:
  - truth: "SessionFactory migration off template.block must not break existing block-context resolution for callers that still rely on the routine→block edge"
    status: failed
    reason: >
      CR-01 (commit 2ca96df) migrated SessionFactory.start so prescription, scheduled
      BlockPhase, and session.block all resolve from the NEW activeBlock parameter
      (default nil) instead of template.block. The new behavior is correct and the new
      test (prescriptionResolvesFromActiveBlockNotTemplateBlock) passes. However, 6
      pre-existing tests across 3 suites that supply the block via routine.block and
      never pass activeBlock now fail. Proven by source diff: pre-migration
      (2ca96df~1) had `session.block = template.block` (L133) and
      `scheduledBlockPhase = template.block.flatMap{...}` (L165); both removed. The 6
      tests passed before Phase 8 and fail after, reproducible in isolation
      (exit code 0 build, but 7 Expectation-failed records → 6 are SessionFactory-path,
      1 is unrelated pre-existing copy drift).
    artifacts:
      - path: "fitbodTests/SessionBlockSnapshotTests.swift"
        issue: "3 tests (L86, L101, L127) expect session.block from routine.block; now nil because start() not passed activeBlock. These guard the Phase 4 Session.block snapshot contract."
      - path: "fitbodTests/DeloadVolumeApplicationTests.swift"
        issue: "2 tests (L112 deload halves set count, L225 multi-exercise deload) fail because scheduledBlockPhase no longer resolves from template.block → deload multiplier not applied."
      - path: "fitbodTests/WarmupDeloadIntegrationTests.swift"
        issue: "1 test (L149 warmup skipped on deload week) fails — deload phase not resolved without activeBlock → warmups generated when they should be skipped."
      - path: "fitbod/Sessions/SessionFactory.swift"
        issue: "start() prescription path resolves block context ONLY from activeBlock (default nil); the legacy routine.block edge is no longer consulted, with no compatibility shim or caller migration for these 3 test suites."
    missing:
      - "Decide intent: if dropping the routine.block-as-block-context path is intended (per spec SessionFactory migration + deferred V8 removal), MIGRATE the 6 tests to pass activeBlock: block into SessionFactory.start so they assert the new contract."
      - "If the Session.block snapshot relationship (SessionBlockSnapshotTests) must still populate from routine.block when no activeBlock is passed, ADD a fallback in start(): session.block = activeBlock ?? template.block, or document why the snapshot contract is intentionally dropped."
      - "Re-run all 3 suites green before closing. Goal-relevant: deload volume + warmup skip are user-visible prescription correctness, not just test hygiene."
deferred: []
---

# Phase 8: Scheduler Resolver & Block Lifecycle Verification Report

**Phase Goal:** Today's session resolves from the block graph: unified rotation predicate (latest completed session with live slot on the block's current split → next position mod count; none → slot 0), fixedWeekly via canonical-order trainingDays, zero-slot short-circuit. Derived block status consumers with ready gate + transition assertions. One-save handover (end + archive + activate atomically), split swap gated to draft/ready, service-layer conditional deny, ArchivedBlockConfig v1 written at end with decode-failure error state. Scheduler + lifecycle + delete-rule + locale suites green.

**Verified:** 2026-06-11
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

All must-have truths from the 5 PLAN frontmatters are **source-verified**. The gap is not in the new feature implementation — it is in **collateral test regressions** from the CR-01 SessionFactory migration that leave a user-visible prescription behavior (deload/warmup) and a Phase-4 snapshot contract unguarded.

| #  | Truth (source) | Status | Evidence |
|----|----------------|--------|----------|
| 1  | Resolver returns next slot from latest completed session whose live slot is on the current split | ✓ VERIFIED | TodayResolver.swift L124-136 unified post-filter + `(pos+1)%slotCount`; TodayResolverTests 15 tests pass |
| 2  | Ad-hoc / deleted-slot / swapped-split / abandoned-in-progress all skipped by same predicate | ✓ VERIFIED | L124-128 single closure; dedicated tests at TodayResolverTests L156/184/224/276 pass |
| 3  | Resolver returns .emptySplit (never .restDay) when zero slots; no mod-by-zero | ✓ VERIFIED | L97 + L163 `guard slotCount >= 1 else { return .emptySplit }`; tests L323/L433 pass |
| 4  | fixedWeekly returns slot at index(weekday in stored trainingDays) % slotCount; absent → .restDay | ✓ VERIFIED | L170-178; tests L341/L373/L402 pass |
| 5  | trainingDays consulted verbatim — resolver never re-sorts at read | ✓ VERIFIED | L168-169 reads `block.trainingDays` directly; no sort in resolveFixedWeekly |
| 6  | trainingDays sorted exactly once at write via Calendar.firstWeekday | ✓ VERIFIED | TrainingDaysWriter.swift L38-45 sole sort site, uses `calendar.firstWeekday` |
| 7  | Region change does NOT remap stored trainingDays | ✓ VERIFIED | TrainingDaysWriterTests fresh-context fetch (WR-05 fix); suite passes |
| 8  | Start-while-active ends+archives current + activates new in ONE save | ✓ VERIFIED | BlockLifecycleService.start L94-103 single `context.transaction` |
| 9  | Ending writes endDate + archivedConfigJSON in same save | ✓ VERIFIED | end() L132-137 single transaction; test "end writes endDate AND archivedConfigJSON together" passes in targeted run |
| 10 | Archive JSON encoded BEFORE transaction (encoder error aborts pre-mutation) | ✓ VERIFIED | start L88 + end L130 encode precede transaction |
| 11 | Split swap/attach refused on active block | ✓ VERIFIED | attachSplit L149 `guard derivedStatus != .active`; swapSplit delegates |
| 12 | Split delete/archive refused via SplitDeletionGuard while non-completed block references it | ✓ VERIFIED | assertSplitDeletable L178-180 delegates to SplitDeletionGuard.assertDeletable |
| 13 | end() guarded to .active only (WR-04) | ✓ VERIFIED | end() L125 `guard derivedStatus == .active else throw .notActive`; test 3b passes |
| 14 | Typed ArchiveUnreadableError, NO live-template fallback | ✓ VERIFIED | decodeArchive L189-196 throws .decodeFailed, no fallback path |
| 15 | CR-01: SessionFactory.start has slot param + writes session.slot; TodayView threads slot | ✓ VERIFIED | SessionFactory L120 `slot:` param, L149 `session.slot = slot`; TodayView L137/L460 thread slot |
| 16 | CR-01: NO prescription path reads template.block anymore | ✓ VERIFIED | SessionFactory L148/181/291 use activeBlock; `template.block` only in comments. Codebase scan: remaining `.block` refs are backup/export/migration/draft-writes, none prescription reads |
| 17 | CR-02: .emptySplit renders distinct copy ("Routine has no sessions"); rest-day untouched | ✓ VERIFIED | TodayView L318 emptySplitFixItState "Routine has no sessions" vs L286 "No workout scheduled"; body switch L142/L148 distinct |
| 18 | Derived-status consumers + transition assertions tested (tests 10-11) | ✓ VERIFIED | BlockLifecycleServiceTests L284 (precedence) + L316 (transition invariant) exist; pass in targeted run |

**Score:** 18/18 truths source-verified. **Status downgraded to gaps_found due to 6 phase-8-introduced test regressions (below).**

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `fitbod/Periodization/TodayResolver.swift` | TodayResolution enum + resolve/rotation/fixedWeekly | ✓ VERIFIED | 192 lines; enum + namespace; Pitfall-1/3 compliant |
| `fitbod/Periodization/TrainingDaysWriter.swift` | sort-at-write w/ injected Calendar | ✓ VERIFIED | 46 lines; sole sort site |
| `fitbod/Periodization/BlockLifecycleService.swift` | start/end/swap/attach + errors + guard | ✓ VERIFIED | 197 lines; all transactions one-save |
| `fitbod/Models/ArchivedBlockConfig.swift` | write(from:endedAt:) v1 JSON | ✓ VERIFIED | 345 lines; WR-02/03 notes+generateWarmups mirrored (L200/225/228) |
| `fitbod/Sessions/SessionFactory.swift` | start(template:slot:activeBlock:) migrated off template.block | ⚠️ VERIFIED (with regression) | 620 lines; new path correct; 6 legacy tests left asserting old path |
| `fitbod/Models/SessionTemplate.swift` | DEPRECATED(Phase 8) doc on .block | ✓ VERIFIED | L52 DEPRECATED(Phase 8) comment |
| `fitbod/Views/TodayView.swift` | todaysRoutine wired to resolver; emptySplit distinct | ✓ VERIFIED | L127-161 switch on TodayResolution; L454-464 startWorkout threads slot+activeBlock |
| `fitbod/Periodization/BlockOverviewScreen.swift` | membership slot+block-ID OR | ✓ VERIFIED | 675 lines; FIXME(v2) markers pre-existing (commit 8183908, not phase 8) |
| `fitbodTests/SchemaV7MigrationTests.swift` | §7 migration assertions | ✓ VERIFIED | found at fitbodTests/Persistence/SchemaV7MigrationTests.swift; passes in targeted run + isolation |

### Key Link Verification

| From | To | Via | Status |
|------|-----|-----|--------|
| TodayResolver | Session.completedAt | flat #Predicate gate + Swift post-filter | ✓ WIRED (L109 flat predicate; multi-level chains in Swift closure L124-128) |
| TodayResolver | block.split?.slots | %slotCount position lookup | ✓ WIRED (L96/136/178) |
| BlockLifecycleService | context.transaction | one save per op | ✓ WIRED (start L94, end L132, attach L152) |
| BlockLifecycleService | SplitDeletionGuard.assertDeletable | enforcement seam | ✓ WIRED (L179) |
| BlockLifecycleService | ArchivedBlockConfig.write | archive pre-transaction | ✓ WIRED (start L88, end L130) |
| TodayView | TodayResolver.resolve | todaysResolution prop | ✓ WIRED (L424) |
| TodayView | SessionFactory.start | activeBlock: activeBlocks.first + slot | ✓ WIRED (L458-462) |
| SessionFactory | PeriodizationEngine.phase | activeBlock not template.block | ✓ WIRED (L181-182) |
| SessionFactory | strategy.prescribe | block: activeBlock | ✓ WIRED (L291) |

### Review Findings Closure (8 findings)

| Finding | Source-Verified Fixed | Evidence |
|---------|----------------------|----------|
| CR-01 (session.slot never set) | ✓ | SessionFactory L120/149; TodayView L137/460; rotationAdvancesEndToEnd passes |
| CR-02 (emptySplit collapsed into restDay) | ✓ | TodayView L142/318 distinct surface + copy |
| WR-01 (startedAt vs completedAt sort) | ✓ | TodayResolver L110 `SortDescriptor(\.completedAt, .reverse)` |
| WR-02 (BlockPhase.notes dropped) | ✓ | ArchivedBlockConfig L200 `notes: phase.notes` |
| WR-03 (exercise notes + generateWarmups) | ✓ | L225 `notes: ex.notes`, L228 `generateWarmups: ex.generateWarmups` |
| WR-04 (end() no guard) | ✓ | BlockLifecycleService L125 `.active` guard + .notActive error |
| WR-05 (tautological region test) | ✓ | TrainingDaysWriterTests fresh-context fetch |
| IN-01 (missing repeat rotation test) | ✓ | TodayResolverTests L304 "same slot done twice" |

### Behavioral Spot-Checks / Probe Execution

| Check | Command | Result | Status |
|-------|---------|--------|--------|
| Targeted phase suites | xcodebuild test -only-testing 6 phase suites | exit 0, ** TEST SUCCEEDED **, 67/67 logic pass | ✓ PASS |
| refRemapping() isolation | -only-testing:.../refRemapping | ** TEST SUCCEEDED **, exit 0 | ✓ PASS (launch flake only under parallelism) |
| Full target | -only-testing:fitbodTests | exit 0; 200 "failed" — 129 crash-cascade from refRemapping host crash + 71 trap | ⚠️ see analysis |
| Suspect suites isolation | SessionBlockSnapshot+Deload+WarmupDeload+BlocksSection | 21/28 pass, 7 genuine Expectation-failed | ✗ FAIL (6 phase-8 + 1 pre-existing) |
| rotationAdvancesEndToEnd | (in SessionFactoryTests, targeted run) | Passed | ✓ PASS — covers Today rotation advance e2e |

### Full-Target Failure Analysis: New vs Baseline

The full `-only-testing:fitbodTests` run reported 929 total / 728 passed / **200 failed** with exit code 0. Investigation: `SchemaV7MigrationTests.refRemapping()` **crashed the test host** (`Crash: fitbod at SchemaV7MigrationTests.refRemapping()` / `FBSOpenApplicationServiceErrorDomain` "Simulator device failed to launch") under parallel execution; that crash marked **129 unrelated tests** as failed-by-association (verified passing in targeted + isolation runs). After filtering crash-cascade artifacts, **17 genuine `Expectation failed` assertion failures** remain. Each was re-run in isolation to classify:

| Suite | # | In documented baseline? | Phase-8-introduced? | Classification |
|-------|---|------------------------|--------------------|----------------|
| FatigueSurfaceViewBRU | 4 | YES (4) | No | Pre-existing baseline |
| SessionLoggerBRUCopy | 4 | YES (4) | No | Pre-existing baseline |
| PrescriptionEditorBlockCaseFilter | 1 | YES (1) | No | Pre-existing baseline |
| TodayViewBlockStacking | 1 | YES (1) | No | Pre-existing baseline |
| **SessionBlockSnapshot** | **3** | **NO** | **YES** | **NEW — CR-01 regression** |
| **DeloadVolumeApplication** | **2** | **NO** | **YES** | **NEW — CR-01 regression** |
| **WarmupDeloadIntegration** | **1** | **NO** | **YES** | **NEW — CR-01 regression** |
| BlocksSection | 1 | NO | No (RoutinesListView not touched by phase 8; copy drift from 04.1-04) | Pre-existing, baseline-incomplete |

**Baseline match:** 10/10 documented pre-existing failures reproduced exactly.
**NEW phase-8-introduced failures: 6** (SessionBlockSnapshot ×3, DeloadVolumeApplication ×2, WarmupDeloadIntegration ×1).
**Additional pre-existing (not in baseline, not phase-8): 1** (BlocksSection copy drift — informational; orchestrator baseline was incomplete by one).

**Root-cause proof (source diff, commit 2ca96df "migrate SessionFactory.start to activeBlock"):**
- Pre-migration `2ca96df~1`: `session.block = template.block` (L133), `scheduledBlockPhase = template.block.flatMap{...}` (L165), `strategy.prescribe(block: template.block)` (L275).
- Post-migration (HEAD): all three resolve from `activeBlock` (default nil). The 6 failing tests pass the block via `routine.block` and never supply `activeBlock`, so `session.block` is nil and the deload/warmup phase is not resolved → set counts not halved, warmups not skipped.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| BlockOverviewScreen.swift | 87, 202 | `FIXME(v2)` | ℹ️ Info | Pre-existing (commit 8183908, phase 04.1-08); v2-scoped day-rollover refresh; not a phase-8 blocker |

No `TBD`/`XXX` markers, no `TODO` markers, no stub returns in phase 8 source. `#Predicate` discipline verified clean (flat gates only; multi-level chains in Swift closures — Pitfall-1 satisfied).

### Human Verification Required

None gating. The orchestrator flagged a Today-tab manual smoke (rotation advance + emptySplit copy). Per verdict rule, the automated `rotationAdvancesEndToEnd` e2e test (SessionFactoryTests:536, passes) plus the 15-test TodayResolver suite plus the CR-02 source-verified distinct copy provide sufficient automated coverage of the scheduler logic. Manual UI smoke is optional polish, not a verification gate.

### Gaps Summary

The Phase 8 feature implementation is **structurally complete and correct** — all 18 must-have truths source-verify, all 8 review findings are genuinely fixed, the new resolver/lifecycle/archive code is substantive, wired, and data flows correctly, and the targeted phase suites are green (67/67 logic).

However, the phase goal includes "**Scheduler + lifecycle + delete-rule + locale suites green**" and, more broadly, the SessionFactory migration is a behavioral change that must not regress the rest of the suite. The CR-01 migration off `template.block` introduced **6 reproducible test regressions** in 3 existing suites that were green before Phase 8. Two of these (DeloadVolumeApplication, WarmupDeloadIntegration) cover **user-visible prescription correctness** (deload set-count halving, warmup skipping on deload weeks) — they now fail because the deload phase no longer resolves when callers use the legacy `routine.block` edge without passing `activeBlock`. The third (SessionBlockSnapshot ×3) guards the Phase-4 `Session.block` snapshot contract, now broken for the no-activeBlock path.

The phase author migrated the production prescription path and added a new passing test, but did not migrate these 3 existing test suites (or add a `template.block` compatibility fallback). This must be resolved before proceeding: decide whether the legacy `routine.block`-as-context path is intentionally dropped (then migrate the 6 tests to pass `activeBlock`) or must be preserved (then add `session.block = activeBlock ?? template.block` and resolve the phase from the same fallback).

---

_Verified: 2026-06-11_
_Verifier: Claude (gsd-verifier)_
