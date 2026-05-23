---
phase: 06
plan: 01
subsystem: progress-views
tags: ["e1rm", "kernel", "PROG-02"]
requires: ["Phase 5 OneRepMaxEstimator (Brzycki/Epley/suppress kernel)"]
provides:
  - "fitbod.OneRepMax (Phase 6 canonical e1RM facade)"
  - "Negative-weight guard on OneRepMaxEstimator (Pitfall 5)"
affects:
  - "Phase 6 Wave 2 ExerciseProgressView (will consume OneRepMax.estimate)"
  - "Phase 6 Wave 2 PRDetector (will consume OneRepMax.estimate for e1RM PR bucket)"
  - "Phase 5 PlateauDetector / DeloadAdvisor / WeeklyRecapSheet (continue calling OneRepMaxEstimator — same math)"
tech-stack:
  added: []
  patterns:
    - "Facade + delegate pattern — single implementation, two canonical names — prevents drift"
key-files:
  created:
    - "fitbod/Progress/OneRepMax.swift"
    - "fitbodTests/Phase6/OneRepMaxTests.swift"
  modified:
    - "fitbod/Prescription/OneRepMaxEstimator.swift"
decisions:
  - "Did not duplicate the formula kernel — Phase 5 already shipped OneRepMaxEstimator with identical Brzycki/Epley/suppression math. Created a thin @inlinable facade at fitbod/Progress/OneRepMax.swift that delegates so Phase 6 charting code reads against the planned name without forking the math."
  - "Brzycki at reps == 1 already collapses to weight × 36/36 == weight, so the Pitfall 4 identity contract is satisfied by the existing Brzycki branch — no separate identity case needed."
  - "Added a defensive weight > 0 guard to OneRepMaxEstimator (Pitfall 5) — assisted-bodyweight machines that encode negative effective load would otherwise emit a nonsense negative e1RM downstream."
metrics:
  duration: "~10 min"
  completed: "2026-05-23"
  files_created: 2
  files_modified: 1
  tasks_completed: 2
---

# Phase 6 Plan 01: OneRepMax Kernel Summary

JWT-style facade — Phase 6 charts call `OneRepMax.estimate(weight:reps:)`; the implementation lives in Phase 5's `OneRepMaxEstimator` so the two surfaces share one formula.

## What shipped

### `fitbod/Progress/OneRepMax.swift`

```swift
public enum OneRepMax {
    @inlinable
    public static func estimate(weight: Double, reps: Int) -> Double? {
        OneRepMaxEstimator.estimate(weight: weight, reps: reps)
    }
}
```

Behavior table (CONTEXT D-04 + Pitfall 4/5):

| Input | Output |
| ----- | ------ |
| `reps == 1`, `weight > 0` | `weight` (Brzycki collapses to identity) |
| `2 ≤ reps ≤ 6`, `weight > 0` | Brzycki: `weight × 36 / (37 - reps)` |
| `7 ≤ reps ≤ 10`, `weight > 0` | Epley: `weight × (1 + reps / 30)` |
| `reps > 10` | `nil` (PROG-02 suppression) |
| `reps ≤ 0` | `nil` (defensive) |
| `weight ≤ 0` | `nil` (Pitfall 5 — bodyweight-assist guard, NEW in this plan) |

### `fitbod/Prescription/OneRepMaxEstimator.swift` (modified)

Added the `weight > 0` short-circuit at the top of the guard. Existing
`OneRepMaxEstimatorTests` (Phase 5) still pass — they only assert positive
weights — and the new guard is exercised by `OneRepMaxTests.handlesNegativeWeight`.

### `fitbodTests/Phase6/OneRepMaxTests.swift`

`@MainActor @Suite("OneRepMax (PROG-02 + CONTEXT D-04)")` with 6 `@Test`
functions (3 parameterized, 3 non-parameterized):

| Test | Arguments | Coverage |
| ---- | --------- | -------- |
| `identityAtOneRep` | none | reps == 1 returns weight verbatim |
| `brzyckiRange` | 6 (weight, reps, expected) tuples reps 2..6 | Brzycki branch within 0.1 tolerance |
| `epleyRange` | 5 (weight, reps, expected) tuples reps 7..10 | Epley branch within 0.1 tolerance |
| `suppressesHighRep` | reps 11, 12, 15, 20, 50 | PROG-02 suppression |
| `nilOnNonPositiveInputs` | none | reps ≤ 0 and weight == 0 both nil |
| `handlesNegativeWeight` | none | Pitfall 5 negative-weight guard |

All tests GREEN on iPhone 17 simulator under `xcodebuild test -only-testing:fitbodTests/OneRepMaxTests`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Architectural reconciliation] OneRepMaxEstimator already existed in Phase 5**

- **Found during:** Task 1 read-first scan
- **Issue:** Phase 5 plan 05-01 shipped `fitbod/Prescription/OneRepMaxEstimator.swift` with the same Brzycki/Epley/suppression math the plan calls for. The plan's literal "create `fitbod/Progress/OneRepMax.swift` with a self-contained enum + switch body" would have produced a second copy of the formula that could silently drift from the Phase 5 kernel.
- **Fix:** Created a thin `@inlinable` facade that delegates to `OneRepMaxEstimator.estimate`. Single source of truth; Phase 6 reads against the canonical short name; no math drift.
- **Files modified:** `fitbod/Progress/OneRepMax.swift` (new — facade body), `fitbod/Prescription/OneRepMaxEstimator.swift` (added `weight > 0` guard).
- **Commit:** `6e2f75c`

**2. [Rule 2 - Auto-add missing critical functionality] Negative-weight guard**

- **Found during:** Reconciling the plan's `handlesNegativeWeight` truth against the existing kernel.
- **Issue:** `OneRepMaxEstimator` only guarded `reps > 0`. Assisted-bodyweight machines (e.g. assisted pull-ups encoded as `-20` kg of assistance) would emit a nonsense negative e1RM that the chart would then plot.
- **Fix:** Tightened the guard to `reps > 0, weight > 0`.
- **Files modified:** `fitbod/Prescription/OneRepMaxEstimator.swift`.
- **Commit:** `6e2f75c`

## Auth Gates

None — pure-function plan with no external services.

## Threat Flags

None — pure-function kernel; no new network surface, auth path, or schema change.

## Commits

| Hash | Type | Description |
| ---- | ---- | ----------- |
| `6e2f75c` | `feat(06-01)` | OneRepMax facade + Pitfall 5 negative-weight guard on OneRepMaxEstimator |
| `fece55f` | `test(06-01)` | OneRepMaxTests parameterized boundary coverage (6 @Test funcs) |

## Self-Check: PASSED

- `fitbod/Progress/OneRepMax.swift` — FOUND
- `fitbodTests/Phase6/OneRepMaxTests.swift` — FOUND
- `fitbod/Prescription/OneRepMaxEstimator.swift` modification — FOUND
- Commit `6e2f75c` — FOUND
- Commit `fece55f` — FOUND
- `xcodebuild build` — BUILD SUCCEEDED
- `xcodebuild test -only-testing:fitbodTests/OneRepMaxTests` — all 6 PASS
