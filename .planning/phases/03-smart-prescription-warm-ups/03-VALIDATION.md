---
phase: 3
slug: smart-prescription-warm-ups
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-22
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Suite`, `@Test`, `#expect`) — unit/model tests; XCTest retained for `fitbodUITests` |
| **Config file** | none — Xcode test scheme `fitbod` |
| **Quick run command** | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing fitbodTests/<SuiteName> 2>&1 \| grep -E 'PASS\|FAIL\|error'` |
| **Full suite command** | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | ~45s quick, ~3 min full |

---

## Sampling Rate

- **After every task commit:** Run quick command targeting the relevant suite
- **After every plan wave:** Run full `fitbodTests` suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** ~60s

---

## Per-Task Verification Map

> Plan-level mapping; per-task IDs assigned by planner. Suites below are the Wave-0 deliverables that downstream tasks attach to.

| Suite | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|-------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TuchschererTableTests | 0 | PRES-03 | — | N/A | unit (parameterized snapshot of 90 cells) | `xcodebuild test -only-testing fitbodTests/TuchschererTableTests` | ❌ W0 | ⬜ pending |
| RPEAutoregStrategyTests | 1 | PRES-01, PRES-03 | — | N/A | unit | `xcodebuild test -only-testing fitbodTests/RPEAutoregStrategyTests` | ❌ W0 | ⬜ pending |
| DoubleProgressionStrategyTests | 1 | PRES-04, PRES-10 | — | N/A | unit | `xcodebuild test -only-testing fitbodTests/DoubleProgressionStrategyTests` | ❌ W0 | ⬜ pending |
| PrescriptionExplanationTests | 1 | PRES-02 | — | N/A | unit | `xcodebuild test -only-testing fitbodTests/PrescriptionExplanationTests` | ❌ W0 | ⬜ pending |
| ProgressionRoundingTests | 1 | PRES-09, SET-04 | — | N/A | unit | `xcodebuild test -only-testing fitbodTests/ProgressionRoundingTests` | ❌ W0 | ⬜ pending |
| PlateCalculatorTests | 1 | PRES-08 | — | N/A | unit (parameterized + epsilon-edge) | `xcodebuild test -only-testing fitbodTests/PlateCalculatorTests` | ❌ W0 | ⬜ pending |
| WarmupRampTests | 1 | WARM-01, WARM-02 | — | N/A | unit (parameterized edge cases) | `xcodebuild test -only-testing fitbodTests/WarmupRampTests` | ❌ W0 | ⬜ pending |
| WarmupConfigTests | 1 | WARM-03 | — | N/A | unit (Data round-trip + skipNextSession reset) | `xcodebuild test -only-testing fitbodTests/WarmupConfigTests` | ❌ W0 | ⬜ pending |
| SchemaV3MigrationTests | 0 | SET-02, SET-03 | — | N/A | unit (in-memory ModelContainer with SchemaV3) | `xcodebuild test -only-testing fitbodTests/SchemaV3MigrationTests` | ❌ W0 | ⬜ pending |
| PlateInventoryTests | 1 | SET-03 | — | N/A | unit (in-memory ModelContainer + JSON round-trip) | `xcodebuild test -only-testing fitbodTests/PlateInventoryTests` | ❌ W0 | ⬜ pending |
| ManualOverrideTests | 2 | PRES-07, SET-07 | — | N/A | unit (override flag + next-session calc reads actual) | `xcodebuild test -only-testing fitbodTests/ManualOverrideTests` | ❌ W0 | ⬜ pending |
| SessionFactoryPhase3Tests | 2 | PRES-01, WARM-01 | — | N/A | unit (in-memory ModelContainer) | `xcodebuild test -only-testing fitbodTests/SessionFactoryPhase3Tests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `fitbodTests/TuchschererTableTests.swift` — 90-cell snapshot, covers PRES-03
- [ ] `fitbodTests/RPEAutoregStrategyTests.swift` — calibrating/calibrated mode switch, nil-RPE history, first-session nil, covers PRES-01/PRES-03
- [ ] `fitbodTests/DoubleProgressionStrategyTests.swift` — bump trigger (all sets hit top), no-bump (partial), no-prior-data, covers PRES-04/PRES-10
- [ ] `fitbodTests/PrescriptionExplanationTests.swift` — construction + field correctness, covers PRES-02
- [ ] `fitbodTests/ProgressionRoundingTests.swift` — per-exercise increment overrides global default, covers PRES-09/SET-04
- [ ] `fitbodTests/PlateCalculatorTests.swift` — known-target → expected stack, float-epsilon edge cases, no-solution case, covers PRES-08
- [ ] `fitbodTests/WarmupRampTests.swift` — 4-set ramp %, dumbbell halving, skip threshold, bodyweight skip, covers WARM-01/WARM-02
- [ ] `fitbodTests/WarmupConfigTests.swift` — Data encode/decode round-trip, nil semantics, skipNextSession reset, covers WARM-03
- [ ] `fitbodTests/SchemaV3MigrationTests.swift` — mirrors `SchemaV2MigrationTests.swift`, covers SchemaV3 + lightweight migration + PlateInventory entity, covers SET-02/SET-03
- [ ] `fitbodTests/PlateInventoryTests.swift` — JSON `[PlateSpec]` round-trip via `Data` accessor, covers SET-03
- [ ] `fitbodTests/ManualOverrideTests.swift` — `wasManualOverride` flag set when actual diverges from rounded, next session reads actual, covers PRES-07/SET-07
- [ ] `fitbodTests/SessionFactoryPhase3Tests.swift` — `prescribedWeight` set on `SessionExercise`, warm-up `SetEntry` rows inserted at correct `orderIndex`, covers PRES-01/WARM-01

All suites use `@MainActor + .serialized` over in-memory `ModelContainer` with `Schema(SchemaV3.models)` + `FitbodSchemaMigrationPlan`, matching the `PreviousMatchingIntentTests` fixture pattern from Phase 2.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| "Why this weight?" sheet opens on `info.circle` tap and renders all rows | PRES-02 | SwiftUI sheet presentation + visual layout | Start session → tap `info.circle` next to a prescribed-weight cell → confirm bottom sheet with last-session line, formula, computed %, rounded target, status badge |
| Bump banner appears at start of next session after qualifying performance | PRES-04, PRES-10 | Cross-session UI state | Log session hitting all working sets at top of rep range → start next session → confirm banner is visible above the exercise card |
| Plate stack inline disclosure animates open <200ms with no layout shift on adjacent rows | PRES-08 | Animation/visual judgment | Tap a prescribed weight cell → observe animation; tap an adjacent set's weight cell → confirm prior cell collapses |
| `PlateInventoryEditor` reset-to-defaults alert correctly restores per-equipment defaults | SET-03 | Destructive confirmation flow | Settings → Plate Inventory → modify a tab → "Reset to Defaults" → confirm alert → verify plates restored |
| Per-exercise unit override affects new entries only, not historical display | (cross-cutting) | Subtle backwards-compat behavior | Set unit override on an exercise with prior history → verify history still renders in original unit; log a new session → verify new entries render in new unit |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-05-22
