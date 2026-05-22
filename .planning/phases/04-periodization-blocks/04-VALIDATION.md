---
phase: 04
slug: periodization-blocks
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-22
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
| **Estimated runtime** | ~60s quick, ~3–4 min full |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -only-testing fitbodTests/<relevant suite>` (~30–60s)
- **After every plan wave:** Run full `fitbodTests` (~3–4 min)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~60 seconds

---

## Per-Task Verification Map

Populated by planner per task. Each plan task carries an `<automated>` block with the exact `-only-testing` target. Coverage matrix is owned by the executor's commit log; this file pre-declares the suites that must exist before execution.

---

## Wave 0 Requirements

Test suites that must be scaffolded (empty `@Suite` skeletons + Wave 0 ModelContainer fixtures) before downstream production-code plans land:

- [ ] `fitbodTests/PeriodizationEngineTests.swift` — covers `phase(for:on:)`, `weekIndex(for:on:)`, `recommendedNextKind(after:)`
- [ ] `fitbodTests/BlockPeriodizedStrategyTests.swift` — covers PRES-05
- [ ] `fitbodTests/HybridStrategyTests.swift` — covers PRES-06
- [ ] `fitbodTests/BlockDraftSaveTests.swift` — covers BLOCK-01 + single-active invariant
- [ ] `fitbodTests/SingleActiveBlockInvariantTests.swift` — covers D-05 transactional invariant
- [ ] `fitbodTests/SessionBlockSnapshotTests.swift` — covers D-20 snapshot extension
- [ ] `fitbodTests/DeloadVolumeApplicationTests.swift` — covers BLOCK-04 + D-12
- [ ] `fitbodTests/BlockReviewMathTests.swift` — covers BLOCK-07 + D-22 totals/deltas
- [ ] `fitbodTests/FatigueAdvisoryCanonicalityTests.swift` — covers BLOCK-08 + D-25 type-level enforcement
- [ ] `fitbodTests/BlockTemplatesTests.swift` — covers D-03 stock templates
- [ ] `fitbodTests/SchemaV4MigrationTests.swift` (only if SchemaV4 path taken per D-26) — covers `Block.reviewedAt` migration
- [ ] `fitbodTests/BlockBuilderViewCopyTests.swift` — UI-SPEC verbatim copy anchors

---

## Property-Based Invariants

| Invariant | Test target |
|-----------|-------------|
| Deload week always cuts volume to `floor(targetSets * 0.5)` clamped ≥1 | `DeloadVolumeApplicationTests` |
| Block week count = sum of phase weeks | `PeriodizationEngineTests` |
| Hybrid never exceeds block ceiling — `Hybrid ≤ Block` for any input | `HybridStrategyTests` |
| Single active block — `Block.isActive == true` count is ≤1 after any save | `SingleActiveBlockInvariantTests` |
| Phase-end review renders 4 sections regardless of data | `BlockReviewMathTests` |
| `FatigueAdvisory` protocol cannot mutate `Block` (type-level) | `FatigueAdvisoryCanonicalityTests` |
| `recommendedNextKind(.deload) == .accumulation` (deterministic across 4 inputs) | `PeriodizationEngineTests` |
| e1RM delta sign matches weight direction | `BlockReviewMathTests` |

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
