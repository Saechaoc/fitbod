---
phase: 03-smart-prescription-warm-ups
plan: "03"
subsystem: prescription-math
tags: [tdd, swift-testing, pure-function, tuchscherer, plate-calculator, calibration, red-to-green]
dependency_graph:
  requires: [03-01, 03-02]
  provides: [TuchschererTable, PlateCalculator, PlateStack, Calibration, HistoryPoint]
  affects: [fitbod/Prescription, fitbodTests/TuchschererTableTests, fitbodTests/PlateCalculatorTests]
tech_stack:
  added: []
  patterns:
    - "public enum namespace with static let + static func — zero-init, implicitly Sendable pure-function pattern"
    - "Hardcoded compile-time constant table keyed [Int: [Double: Double]] for O(1) RPE lookup"
    - "Greedy heaviest-plate-first (coin-system equivalence — canonical kg/lb sets are greedy-optimal)"
    - "Float-drift guard: rounded(toPlaces: 3) after each subtraction + epsilon < 0.001 comparison"
    - "Private file-local Double.rounded(toPlaces:) extension — no shared Extensions layer"
    - "Manual Equatable conformance for PlateStack (tuple arrays prevent synthesis)"
    - "Injectable now: Date = Date() parameter on Calibration.predict for deterministic testing"
    - "Gaussian time kernel: w = exp(-(days/30)²) — 30-day bandwidth"
key_files:
  created:
    - fitbod/Prescription/TuchschererTable.swift
    - fitbod/Prescription/PlateCalculator.swift
    - fitbod/Prescription/Calibration.swift
  modified:
    - fitbodTests/TuchschererTableTests.swift
    - fitbodTests/PlateCalculatorTests.swift
decisions:
  - "PlateStack.== implemented manually — Swift cannot synthesize Equatable for structs containing [(weight: Double, count: Int)] named-tuple arrays"
  - "Calibration.predict accepts targetReps/targetRPE but leaves them unused — signature matches the planned full-LOWESS upgrade in Phase 5 without changing call sites"
  - "Tuchscherer table covers reps 1–10 only; reps > 10 clamp to row 10 per CONTEXT.md Area 1 lock (revised 2026-05-22). High-rep ranges use DoubleProgressionStrategy."
  - "Calibration uses weighted mean (polynomial-degree-0 LOWESS) rather than full linear LOWESS — equivalent for stable-strength blocks, upgradable in Phase 5"
metrics:
  duration_minutes: 25
  completed: "2026-05-22T23:56:00Z"
  tasks_completed: 3
  tasks_total: 3
  files_created: 3
  files_modified: 2
  tests_green: 10
---

# Phase 3 Plan 03: Pure-Function Prescription Utilities Summary

**One-liner:** Hardcoded 90-cell Tuchscherer table + greedy PlateCalculator (epsilon-guarded) + Gaussian-weighted Calibration — 10 RED tests turned GREEN.

## What Was Built

Three pure-function utilities under `fitbod/Prescription/` that form the leaf-level math every progression strategy and warm-up generator composes from. All three are Sendable value types with no SwiftData coupling and no `@MainActor`.

### TuchschererTable (`fitbod/Prescription/TuchschererTable.swift`)

`public enum TuchschererTable` with a 90-cell compile-time constant (`static let percentFor: [Int: [Double: Double]]`):
- 10 rep rows × 9 RPE columns (6.0–10.0 in 0.5 steps)
- All values verified against the RTS / Zourdos et al. (2016) source via fitnessvolt.com
- `percent(reps:rpe:)` clamps reps to [1, 10] and snaps RPE to nearest 0.5 step via `(rpe * 2).rounded() / 2`
- Returns nil when snapped RPE falls outside [6.0, 10.0]

### PlateCalculator (`fitbod/Prescription/PlateCalculator.swift`)

`public struct PlateStack: Sendable, Equatable` — plates per side (heaviest-first) + total weight.

`public enum PlateCalculator` with two static functions:
- `solve(target:barWeight:plates:) -> PlateStack?` — exact match or nil
- `roundDown(target:barWeight:plates:) -> Double` — always succeeds, returns ≤ target

Both use greedy heaviest-plate-first with:
- `rounded(toPlaces: 3)` after each subtraction (float drift guard)
- Epsilon `< 0.001` instead of `== 0` to handle IEEE 754 accumulation (RESEARCH §Pitfall 4)
- Division-by-zero guard for zero-weight plates

### Calibration (`fitbod/Prescription/Calibration.swift`)

`public struct HistoryPoint: Sendable, Equatable` — `e1RM: Double` + `date: Date`.

`public enum Calibration` with `predict(history:targetReps:targetRPE:now:) -> Double?`:
- Gaussian time kernel: `w = exp(-(daysFromNow / 30.0)²)`
- Returns weighted-mean e1RM: `Σ(w·e1RM) / Σw`
- Returns nil for empty history or `Σw < 1e-9`
- `now: Date = Date()` is injectable for deterministic testing

## Test Results

| Suite | Tests | Result |
|-------|-------|--------|
| TuchschererTableTests | 5 | GREEN (was RED) |
| PlateCalculatorTests | 5 | GREEN (was RED) |
| Calibration | — | No dedicated suite (covered by RPEAutoregStrategyTests in plan 03-05) |

**Total newly-passing tests: 10**

### TuchschererTableTests (5/5 GREEN)
- `rpe10reps1Returns1_000` — spot-check canonical table corner (1.000)
- `rpe8reps5Returns0_811` — mid-table value
- `rpe6reps10Returns0_656` — bottom-right corner (lowest RPE, highest reps)
- `clampRepsAboveTen` — reps=12 returns same as reps=10 (0.696 @ RPE 8)
- `nearestRPESnap` — RPE 8.3 snaps to 8.5 (0.824 @ 5 reps)

### PlateCalculatorTests (5/5 GREEN)
- `solve100kgWith20kgBar` — 100 kg / 20 kg bar → [(25,1),(15,1)] per side, totalWeight=100
- `roundDown102_5kgWith2_5kgIncrement` — 102.5 not loadable without 1.25 plates → 100.0
- `belowBarReturnsBar` — target 15 < bar 20 → returns 20.0
- `epsilonFloatDriftGuard` — 97.4999 resolves same as 97.5 (both → 97.5)
- `noSolutionReturnsNil` — 1000 kg with only 20 kg plates (max 100 kg) → nil

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 — TuchschererTable + tests | `f35c9e6` | TuchschererTable 90-cell table + TuchschererTableTests GREEN |
| 2 — PlateCalculator + tests | `a4683d3` | PlateCalculator greedy solver + PlateCalculatorTests GREEN |
| 3 — Calibration | `5bb2821` | Calibration Gaussian weighted-mean predictor |

## Deviations from Plan

None — plan executed exactly as written.

The one implementation note: `PlateStack.==` was implemented manually (explicit `static func ==`) rather than via `Equatable` synthesis. Swift cannot synthesize `Equatable` for structs whose stored properties include `[(weight: Double, count: Int)]` named-tuple arrays because named tuples are not `Equatable`. The manual implementation compares `totalWeight` and element-wise `platesPerSide` — semantically identical to what synthesis would produce.

## Known Stubs

None. All three files are fully implemented — no placeholder values, no TODO markers, no hardcoded empty returns.

## Threat Flags

None. All three files are pure functions with no network endpoints, no auth paths, no file access, and no schema changes. They operate entirely on value types passed in by the caller.

## Self-Check: PASSED

- FOUND: fitbod/Prescription/TuchschererTable.swift
- FOUND: fitbod/Prescription/PlateCalculator.swift
- FOUND: fitbod/Prescription/Calibration.swift
- FOUND: commit f35c9e6 (TuchschererTable)
- FOUND: commit a4683d3 (PlateCalculator)
- FOUND: commit 5bb2821 (Calibration)
