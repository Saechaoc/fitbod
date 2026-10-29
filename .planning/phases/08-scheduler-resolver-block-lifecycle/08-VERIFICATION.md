---
phase: 08-scheduler-resolver-block-lifecycle
verified: 2026-06-11T19:55:00Z
status: human_needed
score: 18/18 must-have truths source-verified; all 6 phase-8-introduced regressions resolved (plan 08-06, commit 4d9a84f)
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 18/18 source-verified; 6 test regressions
  gaps_closed:
    - "All 6 phase-8-introduced test failures (SessionBlockSnapshotTests x3, DeloadVolumeApplicationTests x2, WarmupDeloadIntegrationTests x1) now pass"
    - "templateBlockSentinelIgnored stays green — legacy template.block prescription read confirmed dead"
    - "Production code untouched by plan 08-06 (commit 4d9a84f: 3 test files only)"
  gaps_remaining: []
  regressions: []
deferred: []
human_verification:
  - test: "Today-tab manual smoke — rotation advance"
    expected: "After completing a session, the Today tab advances to the next rotation slot on next launch"
    why_human: "Requires live device session completion + re-launch; automated rotationAdvancesEndToEnd covers the factory logic but not the full UI flow across app launches"
  - test: "Today-tab manual smoke — emptySplit copy"
    expected: "When a routine has no split slots, the Today tab shows 'Routine has no sessions' (not 'No workout scheduled')"
    why_human: "Requires a device build with a routine in the no-split state; source-verified distinct copy but UI rendering requires visual confirmation"
---

# Phase 8: Scheduler Resolver & Block Lifecycle Verification Report

**Phase Goal:** Today's session resolves from the block graph: unified rotation predicate (latest completed session with live slot on the block's current split -> next position mod count; none -> slot 0), fixedWeekly via canonical-order trainingDays, zero-slot short-circuit. Derived block status consumers with ready gate + transition assertions. One-save handover (end + archive + activate atomically), split swap gated to draft/ready, service-layer conditional deny, ArchivedBlockConfig v1 written at end with decode-failure error state. Scheduler + lifecycle + delete-rule + locale suites green.

**Verified:** 2026-06-11
**Status:** human_needed
**Re-verification:** Yes — after gap closure (plan 08-06, commit 4d9a84f)

## Gap Closure Re-verification (Plan 08-06)

### Checks Performed

| Check | Result |
|-------|--------|
| `git show 4d9a84f --stat`: only 3 test files modified | PASS — production code untouched |
| `xcodebuild ... -only-testing:fitbodTests/SessionBlockSnapshotTests -only-testing:fitbodTests/DeloadVolumeApplicationTests -only-testing:fitbodTests/WarmupDeloadIntegrationTests -only-testing:fitbodTests/SessionFactoryTests` | PASS — ** TEST SUCCEEDED **, 0 failures |
| `xcodebuild ... -only-testing:fitbodTests/TodayResolverTests -only-testing:fitbodTests/BlockLifecycleServiceTests` | PASS — ** TEST SUCCEEDED **, 0 failures |
| `templateBlockSentinelIgnored` isolated run | PASS — legacy template.block read confirmed dead |

All 6 phase-8-introduced regressions are gone. The documented baseline (10 pre-existing + 1 baseline-incomplete BlocksSection copy-drift) is unchanged. Documented baseline now corrected to 11 (10 original + BlocksSection copy-drift, pre-existing).

---

## Original Verification (Preserved)

### Goal Achievement

### Observable Truths

All must-have truths from the 5 PLAN frontmatters are **source-verified**. After plan 08-06, the test regression gap is also closed.

| #  | Truth (source) | Status | Evidence |
|----|----------------|--------|----------|
| 1  | Resolver returns next slot from latest completed session whose live slot is on the current split | VERIFIED | TodayResolver.swift L124-136 unified post-filter + `(pos+1)%slotCount`; TodayResolverTests 15 tests pass |
| 2  | Ad-hoc / deleted-slot / swapped-split / abandoned-in-progress all skipped by same predicate | VERIFIED | L124-128 single closure; dedicated tests at TodayResolverTests L156/184/224/276 pass |
| 3  | Resolver returns .emptySplit (never .restDay) when zero slots; no mod-by-zero | VERIFIED | L97 + L163 `guard slotCount >= 1 else { return .emptySplit }`; tests L323/L433 pass |
| 4  | fixedWeekly returns slot at index(weekday in stored trainingDays) % slotCount; absent -> .restDay | VERIFIED | L170-178; tests L341/L373/L402 pass |
| 5  | trainingDays consulted verbatim — resolver never re-sorts at read | VERIFIED | L168-169 reads `block.trainingDays` directly; no sort in resolveFixedWeekly |
| 6  | trainingDays sorted exactly once at write via Calendar.firstWeekday | VERIFIED | TrainingDaysWriter.swift L38-45 sole sort site, uses `calendar.firstWeekday` |
| 7  | Region change does NOT remap stored trainingDays | VERIFIED | TrainingDaysWriterTests fresh-context fetch (WR-05 fix); suite passes |
| 8  | Start-while-active ends+archives current + activates new in ONE save | VERIFIED | BlockLifecycleService.start L94-103 single `context.transaction` |
| 9  | Ending writes endDate + archivedConfigJSON in same save | VERIFIED | end() L132-137 single transaction; test "end writes endDate AND archivedConfigJSON together" passes in targeted run |
| 10 | Archive JSON encoded BEFORE transaction (encoder error aborts pre-mutation) | VERIFIED | start L88 + end L130 encode precede transaction |
| 11 | Split swap/attach refused on active block | VERIFIED | attachSplit L149 `guard derivedStatus != .active`; swapSplit delegates |
| 12 | Split delete/archive refused via SplitDeletionGuard while non-completed block references it | VERIFIED | assertSplitDeletable L178-180 delegates to SplitDeletionGuard.assertDeletable |
| 13 | end() guarded to .active only (WR-04) | VERIFIED | end() L125 `guard derivedStatus == .active else throw .notActive`; test 3b passes |
| 14 | Typed ArchiveUnreadableError, NO live-template fallback | VERIFIED | decodeArchive L189-196 throws .decodeFailed, no fallback path |
| 15 | CR-01: SessionFactory.start has slot param + writes session.slot; TodayView threads slot | VERIFIED | SessionFactory L120 `slot:` param, L149 `session.slot = slot`; TodayView L137/L460 thread slot |
| 16 | CR-01: NO prescription path reads template.block anymore | VERIFIED | SessionFactory L148/181/291 use activeBlock; `template.block` only in comments. Codebase scan: remaining `.block` refs are backup/export/migration/draft-writes, none prescription reads |
| 17 | CR-02: .emptySplit renders distinct copy ("Routine has no sessions"); rest-day untouched | VERIFIED | TodayView L318 emptySplitFixItState "Routine has no sessions" vs L286 "No workout scheduled"; body switch L142/L148 distinct |
| 18 | Derived-status consumers + transition assertions tested (tests 10-11) | VERIFIED | BlockLifecycleServiceTests L284 (precedence) + L316 (transition invariant) exist; pass in targeted run |

**Score:** 18/18 truths source-verified. Test regression gap closed by plan 08-06.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `fitbod/Periodization/TodayResolver.swift` | TodayResolution enum + resolve/rotation/fixedWeekly | VERIFIED | 192 lines; enum + namespace; Pitfall-1/3 compliant |
| `fitbod/Periodization/TrainingDaysWriter.swift` | sort-at-write w/ injected Calendar | VERIFIED | 46 lines; sole sort site |
| `fitbod/Periodization/BlockLifecycleService.swift` | start/end/swap/attach + errors + guard | VERIFIED | 197 lines; all transactions one-save |
| `fitbod/Models/ArchivedBlockConfig.swift` | write(from:endedAt:) v1 JSON | VERIFIED | 345 lines; WR-02/03 notes+generateWarmups mirrored (L200/225/228) |
| `fitbod/Sessions/SessionFactory.swift` | start(template:slot:activeBlock:) migrated off template.block | VERIFIED | 620 lines; new path correct; 6 legacy test regressions resolved by plan 08-06 |
| `fitbod/Models/SessionTemplate.swift` | DEPRECATED(Phase 8) doc on .block | VERIFIED | L52 DEPRECATED(Phase 8) comment |
| `fitbod/Views/TodayView.swift` | todaysRoutine wired to resolver; emptySplit distinct | VERIFIED | L127-161 switch on TodayResolution; L454-464 startWorkout threads slot+activeBlock |
| `fitbod/Periodization/BlockOverviewScreen.swift` | membership slot+block-ID OR | VERIFIED | 675 lines; FIXME(v2) markers pre-existing (commit 8183908, not phase 8) |
| `fitbodTests/SchemaV7MigrationTests.swift` | §7 migration assertions | VERIFIED | found at fitbodTests/Persistence/SchemaV7MigrationTests.swift; passes in targeted run + isolation |

### Key Link Verification

| From | To | Via | Status |
|------|-----|-----|--------|
| TodayResolver | Session.completedAt | flat #Predicate gate + Swift post-filter | WIRED (L109 flat predicate; multi-level chains in Swift closure L124-128) |
| TodayResolver | block.split?.slots | %slotCount position lookup | WIRED (L96/136/178) |
| BlockLifecycleService | context.transaction | one save per op | WIRED (start L94, end L132, attach L152) |
| BlockLifecycleService | SplitDeletionGuard.assertDeletable | enforcement seam | WIRED (L179) |
| BlockLifecycleService | ArchivedBlockConfig.write | archive pre-transaction | WIRED (start L88, end L130) |
| TodayView | TodayResolver.resolve | todaysResolution prop | WIRED (L424) |
| TodayView | SessionFactory.start | activeBlock: activeBlocks.first + slot | WIRED (L458-462) |
| SessionFactory | PeriodizationEngine.phase | activeBlock not template.block | WIRED (L181-182) |
| SessionFactory | strategy.prescribe | block: activeBlock | WIRED (L291) |

### Review Findings Closure (8 findings)

| Finding | Source-Verified Fixed | Evidence |
|---------|----------------------|----------|
| CR-01 (session.slot never set) | YES | SessionFactory L120/149; TodayView L137/460; rotationAdvancesEndToEnd passes |
| CR-02 (emptySplit collapsed into restDay) | YES | TodayView L142/318 distinct surface + copy |
| WR-01 (startedAt vs completedAt sort) | YES | TodayResolver L110 `SortDescriptor(\.completedAt, .reverse)` |
| WR-02 (BlockPhase.notes dropped) | YES | ArchivedBlockConfig L200 `notes: phase.notes` |
| WR-03 (exercise notes + generateWarmups) | YES | L225 `notes: ex.notes`, L228 `generateWarmups: ex.generateWarmups` |
| WR-04 (end() no guard) | YES | BlockLifecycleService L125 `.active` guard + .notActive error |
| WR-05 (tautological region test) | YES | TrainingDaysWriterTests fresh-context fetch |
| IN-01 (missing repeat rotation test) | YES | TodayResolverTests L304 "same slot done twice" |

### Behavioral Spot-Checks / Probe Execution

| Check | Command | Result | Status |
|-------|---------|--------|--------|
| Targeted phase suites (6 suites, re-verification run) | xcodebuild test -only-testing 6 phase suites | ** TEST SUCCEEDED **, 0 failures | PASS |
| templateBlockSentinelIgnored isolation | -only-testing:.../templateBlockSentinelIgnored | ** TEST SUCCEEDED ** | PASS — legacy read stays dead |
| 4-suite gap-closure run (plan 08-06) | SessionBlockSnapshot+Deload+WarmupDeload+SessionFactory | ** TEST SUCCEEDED **, 0 failures | PASS — all 6 regressions resolved |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| BlockOverviewScreen.swift | 87, 202 | `FIXME(v2)` | Info | Pre-existing (commit 8183908, phase 04.1-08); v2-scoped day-rollover refresh; not a phase-8 blocker |

No `TBD`/`XXX` markers, no `TODO` markers, no stub returns in phase 8 source. `#Predicate` discipline verified clean.

### Human Verification Required

#### 1. Today-Tab Rotation Advance (manual smoke)

**Test:** Complete a session, re-launch the app, observe the Today tab.
**Expected:** Today tab advances to the next rotation slot on the subsequent launch.
**Why human:** Requires live device session completion + re-launch. `rotationAdvancesEndToEnd` (SessionFactoryTests) covers the factory logic but not the full app-level navigation state across launches.

#### 2. Today-Tab emptySplit Copy (manual smoke)

**Test:** Create a routine with no split slots; navigate to the Today tab.
**Expected:** Today tab shows "Routine has no sessions" (not "No workout scheduled").
**Why human:** Requires a device build with a routine in the no-split state. Source-verified as distinct copy (TodayView L318 vs L286) but UI rendering requires visual confirmation.

### Baseline Note

Documented baseline is now **11** pre-existing failures (10 originally documented + BlocksSection copy-drift, which was pre-existing but absent from the original baseline count per 08-VERIFICATION.md adjudication). Phase-8-introduced regressions: 0 (all 6 resolved by plan 08-06).

---

_Initial verified: 2026-06-11_
_Re-verified: 2026-06-11 (post plan 08-06, commit 4d9a84f)_
_Verifier: Claude (gsd-verifier)_
