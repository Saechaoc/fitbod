---
phase: 04
slug: periodization-blocks
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-22
revised: 2026-05-22
---

# Phase 04 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Sourced from `04-RESEARCH.md` § Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Suite`, `@Test`, `#expect`) — unit/model tests; XCTest retained for `fitbodUITests` |
| **Config file** | none — Xcode test scheme `fitbod` |
| **Quick run command** | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing fitbodTests/<SuiteName> 2>&1 \| grep -E 'PASS\|FAIL\|error'` |
| **Full suite command** | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~30–60s quick (single -only-testing target), ~3–4 min full |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -only-testing fitbodTests/<relevant suite>` (~30–60s — confirmed under the ~60s feedback latency budget)
- **After every plan wave:** Run full `fitbodTests` (~3–4 min)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds (one-shot `xcodebuild test`; no watch-mode flags anywhere in the plan set)

---

## Per-Task Verification Map

Populated by planner per task. Each plan task carries an `<automated>` block with the exact `-only-testing` target. Coverage matrix is owned by the executor's commit log; this file pre-declares the suites that must exist before execution.

---

## Wave 0 Requirements

Test suites that must be scaffolded (empty `@Suite` skeletons + Wave 0 ModelContainer fixtures) before downstream production-code plans land:

- [x] `fitbodTests/PeriodizationEngineTests.swift` — covers `phase(for:on:)`, `weekIndex(for:on:)`, `weekContext(for:weekIndex:on:)`, `recommendedNextKind(after:)`. GREEN this plan (04-01 Task 2).
- [x] `fitbodTests/BlockPeriodizedStrategyTests.swift` — covers PRES-05 + D-17 baseline chain. Skeleton in 04-01 Task 3 (RED); flipped GREEN by plan 04-06 Task 2.
- [x] `fitbodTests/HybridStrategyTests.swift` — covers PRES-06 + BLOCK-08 spirit (block ceiling never exceeded). Skeleton in 04-01 Task 3 (RED); flipped GREEN by plan 04-06 Task 3.
- [x] `fitbodTests/BlockDraftSaveTests.swift` — covers BLOCK-01 + single-active invariant. Skeleton in 04-01 Task 3 (RED); flipped GREEN by plan 04-02 Task 1.
- [x] `fitbodTests/SingleActiveBlockInvariantTests.swift` — covers D-05 transactional invariant. Skeleton in 04-01 Task 3 (RED); flipped GREEN by plan 04-02 Task 1.
- [x] `fitbodTests/SessionBlockSnapshotTests.swift` — covers D-20 snapshot extension. Skeleton in 04-01 Task 3 (RED); flipped GREEN by plan 04-07 Task 2.
- [x] `fitbodTests/DeloadVolumeApplicationTests.swift` — covers BLOCK-04 + D-12. Skeleton in 04-01 Task 3 (RED); flipped GREEN by plan 04-07 Task 2.
- [x] `fitbodTests/BlockReviewMathTests.swift` — covers BLOCK-07 + D-22 totals/deltas. Skeleton in 04-01 Task 3 (RED); flipped GREEN by plan 04-08 Task 3.
- [x] `fitbodTests/FatigueAdvisoryCanonicalityTests.swift` — covers BLOCK-06a + BLOCK-08 + D-25 type-level enforcement. GREEN this plan (04-01 Task 3).
- [x] `fitbodTests/BlockTemplatesTests.swift` — covers D-03 stock templates. GREEN this plan (04-01 Task 3).
- [x] `fitbodTests/SchemaV4MigrationTests.swift` — covers `Block.reviewedAt` AND `RoutineExercise.prescribedWeight` migration (per D-17 / blocker #4 resolution). GREEN this plan (04-01 Task 1).
- [x] `fitbodTests/BlockBuilderViewCopyTests.swift` — UI-SPEC verbatim copy anchors. Skeleton in 04-01 Task 3 (RED); flipped GREEN by plan 04-02 Task 2.
- [x] `fitbodTests/WarmupDeloadIntegrationTests.swift` — covers WARM-02 deload-skip end-to-end (SessionFactory + WarmupRamp.deloadActive integration). Added per checker warning #10. Skeleton in 04-01 Task 3 (RED); flipped GREEN by plan 04-07 Task 3. HARD PREREQUISITE: Phase 3 plan 03-08's WarmupRamp.deloadActive: param must ship (encoded as prerequisite_phase_plans in 04-07 frontmatter).

**Total: 13 Wave-0 test suites — all 13 scaffolded in plan 04-01; 4 GREEN this plan, 9 RED with `Issue.record` placeholders flipped GREEN by downstream plans.**

---

## Property-Based Invariants

| Invariant | Test target |
|-----------|-------------|
| Deload week always cuts WORKING set count to `floor(targetSets * 0.5)` clamped >=1 (warmups independently skipped) | `DeloadVolumeApplicationTests` |
| Block week count = sum of phase weeks | `PeriodizationEngineTests` |
| Hybrid never exceeds block ceiling — `Hybrid <= Block` for any input | `HybridStrategyTests` |
| Single active block — `Block.isActive == true` count is <=1 after any save | `SingleActiveBlockInvariantTests` |
| Phase-end review renders 4 sections regardless of data | `BlockReviewMathTests` |
| `FatigueAdvisory` protocol cannot mutate `Block` (type-level) | `FatigueAdvisoryCanonicalityTests` |
| `recommendedNextKind(.deload) == .accumulation` (deterministic across 4 inputs) | `PeriodizationEngineTests` |
| e1RM delta sign matches weight direction | `BlockReviewMathTests` |
| Baseline resolution honors D-17 chain: prescribedWeight > lastSessionWeight > 0 | `BlockPeriodizedStrategyTests` |
| MesocycleWeekContext is a Sendable value snapshot — consumers read scalar fields only | `PeriodizationEngineTests` (`weekContextSnapshotFieldsMatchPhase`) |
| Warm-up generation skipped on deload weeks (WARM-02 + D-12 integration) | `WarmupDeloadIntegrationTests` |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Phase color tokens render correctly | BLOCK-02 visual | Visual judgment | Run in simulator; visually confirm phase chip color matches UI-SPEC tokens |
| Week-swipe gesture feels right | BLOCK-02 navigation | System gesture; subjective feel | Manually swipe between weeks on home; confirm haptic + animation feel natural |
| Deload banner copy readability | BLOCK-04 UI | Subjective tone | Visually verify deload banner copy matches UI-SPEC verbatim |

---

## What Should NOT Be Tested

- `.tabViewStyle(.page)` slide animation — SwiftUI built-in
- `BlockPhaseColors` hex values — UI-SPEC tokens, not behavior
- TabView swipe gesture mechanics — system-provided
- Modal sheet `.large` detent — SwiftUI built-in

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify blocks (confirmed by scanning every `<verify>` in plans 04-01 through 04-08 — each contains an `<automated>xcodebuild ...</automated>` block).
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (confirmed — every task in every plan has `<automated>`; the longest unbroken automated-verify streak is the full Phase 4 task set).
- [x] Wave 0 covers all MISSING references — 13 suites enumerated above, matches plan 04-01 Task 3 + Task 1 + Task 2 outputs. (Per checker warning #10, `WarmupDeloadIntegrationTests` is the 13th scaffold; per blocker #4, `SchemaV4MigrationTests` now covers BOTH `Block.reviewedAt` and `RoutineExercise.prescribedWeight`.)
- [x] No watch-mode flags — every `<automated>` block uses one-shot `xcodebuild test ... -only-testing fitbodTests/<Suite>` with no `-watch` / `--watch` / continuous flags.
- [x] Feedback latency < 60s — the quick command targets a single suite (~30–60s on M-series Mac; well within budget).
- [x] `nyquist_compliant: true` set in frontmatter.

**Approval:** approved 2026-05-22
