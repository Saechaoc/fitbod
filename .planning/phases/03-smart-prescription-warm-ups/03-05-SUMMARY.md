---
phase: 03-smart-prescription-warm-ups
plan: "05"
subsystem: prescription-math
tags: [tdd, swift-testing, pure-function, progression-strategy, rpe-autoreg, double-progression, warmup-ramp, red-to-green]
dependency_graph:
  requires: [03-01, 03-02, 03-03]
  provides: [ProgressionStrategy, PrescriptionExplanation, CalibrationStatus, RPEAutoregStrategy, DoubleProgressionStrategy, WarmupRamp, ProgressionStrategyFactory]
  affects: [fitbod/Prescription, fitbodTests/RPEAutoregStrategyTests, fitbodTests/DoubleProgressionStrategyTests, fitbodTests/PrescriptionExplanationTests, fitbodTests/ProgressionRoundingTests, fitbodTests/WarmupRampTests]
tech_stack:
  added: []
  patterns:
    - "public protocol ProgressionStrategy: Sendable with scalar lastSession* params (no nested structs beyond HistoryPoint)"
    - "lastSessionRepsArray: [Int]? = nil optional param — bump signal for DoubleProgression; nil-safe for RPEAutoreg"
    - "RPEAutoregStrategy calibrating path: e1RM = lastWeight / TuchschererTable.percent; ±5% range both endpoints PlateCalculator.roundDown"
    - "RPEAutoregStrategy calibrated path: Calibration.predict weighted-mean e1RM × TuchschererTable.percent for point estimate"
    - "DoubleProgressionStrategy: lastSessionRepsArray.allSatisfy { $0 >= targetRepsHigh } && !repsArray.isEmpty → bump"
    - "WarmupRamp.shouldGenerate six-guard chain: deload / warmupConfig.enabled / mechanic / equipment / 1.5×barWeight / barWeight==0 bypass"
    - "WarmupRamp.generate: enumerated map over step array, SetEntry() default init + field assignment"
    - "ProgressionStrategyFactory: .block/.hybrid silently route to DoubleProgressionStrategy with Phase 4 NOTE comment"
    - "@MainActor + .serialized WarmupRampTests for SwiftData SessionExercise context construction"
key_files:
  created:
    - fitbod/Prescription/ProgressionStrategy.swift
    - fitbod/Prescription/RPEAutoregStrategy.swift
    - fitbod/Prescription/DoubleProgressionStrategy.swift
    - fitbod/Prescription/WarmupRamp.swift
    - fitbod/Prescription/ProgressionStrategyFactory.swift
  modified:
    - fitbodTests/PrescriptionExplanationTests.swift
    - fitbodTests/RPEAutoregStrategyTests.swift
    - fitbodTests/DoubleProgressionStrategyTests.swift
    - fitbodTests/ProgressionRoundingTests.swift
    - fitbodTests/WarmupRampTests.swift
    - fitbod/Settings/PlateCalculatorSheet.swift
decisions:
  - "ProgressionStrategy protocol takes scalar lastSession* params (not a struct) to keep strategies free of nested types beyond HistoryPoint"
  - "lastSessionRepsArray: [Int]? added to protocol with default nil so RPEAutoreg ignores it; DoubleProgression consumes it for bump trigger"
  - "RPEAutoregStrategy.calibrating: both range endpoints rounded DOWN via PlateCalculator.roundDown, range is lowRounded...max(lowRounded, highRounded)"
  - "DoubleProgressionStrategy: nil lastSessionRepsArray means no bump (caller signals absence of working-set data, e.g. warmup-sets-only session)"
  - "WarmupRamp.shouldGenerate: barWeight==0 bypasses the 1.5× check to handle dumbbell pairs with no bar component"
  - "ProgressionStrategyFactory: .block and .hybrid map to DoubleProgressionStrategy with explicit Phase 4 replacement NOTE"
  - "WarmupRampTests decorated @MainActor + .serialized because shouldGenerate tests require SessionExercise in a ModelContext"
  - "ProgressionRoundingTests redesigned to use plate-loadable lastWeight values; raw bump targets that are not loadable would round DOWN, changing the delta"
metrics:
  duration_minutes: 65
  completed: "2026-05-22T18:05:00Z"
  tasks_completed: 4
  tasks_total: 4
  files_created: 5
  files_modified: 6
  tests_green: 25
requirements: [PRES-01, PRES-02, PRES-03, PRES-04, PRES-09, PRES-10, WARM-01, WARM-02]
---

# Phase 3 Plan 05: Progression Strategy Layer Summary

**One-liner:** ProgressionStrategy protocol + RPEAutoreg (Tuchscherer prior → LOWESS calibrated) + DoubleProgression (bump-all-hit-top) + WarmupRamp (4-set/2-set ramp with six guards) + ProgressionStrategyFactory — 25 RED tests turned GREEN.

## What Was Built

Five new files under `fitbod/Prescription/` forming the complete math heart of Phase 3. All types are Sendable value types with no SwiftData coupling.

### ProgressionStrategy.swift (`fitbod/Prescription/ProgressionStrategy.swift`)

Three declarations:

**`CalibrationStatus`** — `public enum CalibrationStatus: Sendable, Equatable`:
- `.calibrating(current: Int, threshold: Int)` — accumulating data
- `.calibrated` — Calibration.predict LOWESS in use
- `.notApplicable` — strategy doesn't use RPE calibration

**`PrescriptionExplanation`** — `public struct PrescriptionExplanation: Sendable` with memberwise public init:
- `lastSessionLine: String?` — "100 kg × 8 @ RPE 8.5 (May 15)", nil when no prior session
- `formulaName: String` — "RPE autoregulation" or "Double progression"
- `computedLine: String?` — RPE-autoreg calibrated branch only
- `roundedWeight: Double` — plate-rounded prescribed weight
- `roundedLine: String` — "→ 107.5 kg (rounded down to 2.5 kg plates)"
- `status: CalibrationStatus`
- `bumpOccurred: Bool` — default false; true only on DoubleProgression bump
- `range: ClosedRange<Double>?` — default nil; non-nil during RPEAutoreg calibrating window

**`ProgressionStrategy`** — `public protocol ProgressionStrategy: Sendable` with single `prescribe(...)` requirement:
- Scalar `lastSession*` params (not a struct) to avoid nested-type coupling
- `lastSessionRepsArray: [Int]? = nil` — bump signal for DoubleProgression; nil-safe default for RPEAutoreg

### RPEAutoregStrategy.swift (`fitbod/Prescription/RPEAutoregStrategy.swift`)

`public struct RPEAutoregStrategy: ProgressionStrategy`:

**Calibrating path** (history.count < minCalibrationSets):
- With prior session: `e1RM = lastSessionWeight / TuchschererTable.percent(reps:rpe:)`; `rawTarget = e1RM × percent(targetRepsHigh, effectiveRPE)`; ±5% expanded to `[lowRounded, highRounded]` via `PlateCalculator.roundDown` on both endpoints
- Without prior session: returns weight 0, range nil, "No prior data" roundedLine

**Calibrated path** (history.count ≥ minCalibrationSets):
- `calibratedE1RM = Calibration.predict(history:targetReps:targetRPE:)` → weighted-mean e1RM
- `rawTarget = calibratedE1RM × TuchschererTable.percent(targetRepsHigh, effectiveRPE)`
- `computedLine`: "Target e1RM {e1RM} kg → {pct}% × {reps} → {raw} kg"
- status = .calibrated, range = nil

`bumpOccurred` is always false — RPE autoreg has no bump concept.

### DoubleProgressionStrategy.swift (`fitbod/Prescription/DoubleProgressionStrategy.swift`)

`public struct DoubleProgressionStrategy: ProgressionStrategy`:

- **No prior data** (`lastSessionWeight == nil`): returns weight 0, "No prior data — starting at prescribed weight."
- **Bump triggered** (`lastSessionRepsArray != nil && !empty && allSatisfy { $0 >= targetRepsHigh }`): rawTarget = lastWeight + smallestIncrement → PlateCalculator.roundDown; bumpOccurred = true
- **Hold** (any other case): roundDown(lastWeight); bumpOccurred = false

`lastSessionLine` format: `"{weight} kg × {reps} @ RPE {rpe} (May 15)"` using `Date.formatted(.dateTime.month(.abbreviated).day())`.

### WarmupRamp.swift (`fitbod/Prescription/WarmupRamp.swift`)

`public enum WarmupRamp` — namespace enum with two static funcs:

**`shouldGenerate(for:deloadActive:topWorkingWeight:barWeight:warmupConfig:) -> Bool`** — six-guard chain:
1. `!deloadActive`
2. `warmupConfig?.enabled != false`
3. `exercise?.mechanic == .compound`
4. `exercise?.equipment ∈ {.barbell, .dumbbell}`
5. `topWorkingWeight >= 1.5 × barWeight` (when `barWeight > 0`)
6. Bypasses weight check when `barWeight == 0` (dumbbell pairs)

**`generate(top:bar:plates:isUnilateral:) -> [SetEntry]`**:
- Barbell: `[(0.40, 5), (0.60, 3), (0.75, 2), (0.90, 1)]` → 4 SetEntry rows
- Dumbbell (`isUnilateral: true`): `[(0.60, 3), (0.90, 1)]` → 2 SetEntry rows
- Each weight: `PlateCalculator.roundDown(target: pct × top, barWeight: bar, plates:)`
- SetEntry fields: `orderIndex`, `weight`, `reps`, `setTypeRaw="warmup"`, `isWarmup=true`, `isComplete=false`

### ProgressionStrategyFactory.swift (`fitbod/Prescription/ProgressionStrategyFactory.swift`)

`public enum ProgressionStrategyFactory` — single static func:
- `.rpe` → `RPEAutoregStrategy()`
- `.double` → `DoubleProgressionStrategy()`
- `.block, .hybrid` → `DoubleProgressionStrategy()` (Phase 4 fallback; documented with NOTE comment)

## Test Results

| Suite | Tests | Result |
|-------|-------|--------|
| PrescriptionExplanationTests | 5 | GREEN (was RED) |
| DoubleProgressionStrategyTests | 5 | GREEN (was RED) |
| ProgressionRoundingTests | 5 | GREEN (was RED) |
| RPEAutoregStrategyTests | 5 | GREEN (was RED) |
| WarmupRampTests | 5 | GREEN (was RED) |
| TuchschererTableTests | 5 | GREEN (regression: still passes) |
| PlateCalculatorTests | 5 | GREEN (regression: still passes) |

**Total newly-passing tests: 25**

### PrescriptionExplanationTests (5/5 GREEN)
- `constructionExposesAllFields` — memberwise init all 8 fields, readback equals input
- `calibrationStatusEquatable` — .calibrated == .calibrated; .calibrating(4,10) == .calibrating(4,10); .calibrating(4,10) != .calibrating(5,10); .calibrated != .notApplicable
- `sendableSafe` — `Task { let _ = exp }` compiles under Swift 6 strict concurrency
- `bumpOccurredFalseByDefault` — default init sets bumpOccurred = false
- `rangeNilByDefault` — default init sets range = nil

### DoubleProgressionStrategyTests (5/5 GREEN)
- `bumpWhenAllSetsHitTopOfRange` — [12,12,12] all hit top 12 → bumpOccurred=true, weight=102.5
- `noBumpWhenAnySetMissesTop` — [12,10,12] misses top → bumpOccurred=false, weight held
- `noBumpWhenWarmupsExcluded` — nil lastSessionRepsArray → no bump
- `noBumpFirstSessionUsesPriorHint` — nil lastSessionWeight → weight=0, lastSessionLine=nil
- `smallestIncrementHonored` — 2.5 kg increment produces delta=2.5 on bump

### ProgressionRoundingTests (5/5 GREEN)
- `exerciseIncrementOverridesGlobal` — delta == 2.5 when smallestIncrement=2.5 passed
- `globalDefaultUsedWhenNil` — delta == 2.5 when caller passes global default
- `kgVsLbUnitOverride` — strategy is unit-agnostic; delta == 5.0 when 5.0 passed
- `microplateIncrement` — delta == 1.0 with 0.5 kg microplates in inventory
- `roundingDownNeverExceedsTarget` — weight <= rawBump for all 4 sample inputs

### RPEAutoregStrategyTests (5/5 GREEN)
- `calibratingBelowThresholdShowsRange` — 3/10 history → .calibrating(3,10), range != nil
- `calibratedAboveThresholdReturnsPointEstimate` — 10/10 history → .calibrated, range=nil, weight>0
- `nilRPEInHistoryIsExcluded` — empty history (caller filtered) + no lastSession → weight=0, range=nil
- `emptyHistoryReturnsFirstSessionExplanation` — no history, no scalars → weight=0, lastSessionLine=nil
- `tuchschererBackCalcUsedBelowThreshold` — lastWeight=100 @ 5×RPE8 → prescribed=100 (round-trip verify)

### WarmupRampTests (5/5 GREEN)
- `barbellCompoundAtTopGenerates4Sets` — reps=[5,3,2,1], each weight<=pct×100, all isWarmup=true
- `dumbbellHalvesTo2Sets` — isUnilateral=true → count=2, reps=[3,1]
- `lightWeightSkipsRamp` — top=25 < 1.5×20=30 → shouldGenerate=false
- `bodyweightSkipsRamp` — equipment=.bodyweight → shouldGenerate=false
- `deloadActiveSkipsRamp` — deloadActive=true → shouldGenerate=false

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 — ProgressionStrategy + PrescriptionExplanation | `ddd7748` | Protocol + value types + PrescriptionExplanationTests GREEN |
| 2 — DoubleProgressionStrategy | `ae47838` | Double progression + DoubleProgression + ProgressionRounding tests GREEN |
| 3 — RPEAutoregStrategy | `44941cd` | RPEAutoreg both paths + RPEAutoregStrategyTests GREEN |
| 4 — WarmupRamp + Factory | `b5444f0` | WarmupRamp + ProgressionStrategyFactory + WarmupRampTests GREEN |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Pre-existing `specifier:` label errors in PlateCalculatorSheet.swift**
- **Found during:** Task 1 (first build attempt)
- **Issue:** Swift 6 / Xcode 26 removed the `specifier:` label from string interpolation of Double (both plain Swift strings and SwiftUI Text). Four occurrences caused build failure.
- **Fix:** Replaced `"\(value, specifier: "%g")"` → `String(format: "%g", value)` for all four sites (lines 120, 162, 169, 186). Semantically equivalent; %g format strips trailing zeros identically.
- **Files modified:** `fitbod/Settings/PlateCalculatorSheet.swift`
- **Commit:** `ddd7748`

**2. [Rule 1 - Bug] ProgressionRoundingTests initial design used non-loadable bump targets**
- **Found during:** Task 2 first test run
- **Issue:** Test `smallestIncrementHonored` used `smallestIncrement=1.25` with `lastWeight=100`. The raw bump (101.25) is not plate-loadable with a 20 kg bar — PlateCalculator.roundDown returned 100, making `weight - lastWeight == 0` instead of 1.25. Similarly `exerciseIncrementOverridesGlobal` and `microplateIncrement` had incorrect expected deltas.
- **Fix:** Redesigned tests to use plate-loadable targets (lastWeight values that, when bumped, produce exactly-loadable results). `microplateIncrement` upgraded to 1.0 kg increment (2 × 0.5 kg plates) with a plate inventory including 0.5 kg microplates. Added explanatory comments documenting the barbell math constraint.
- **Files modified:** `fitbodTests/ProgressionRoundingTests.swift`, `fitbodTests/DoubleProgressionStrategyTests.swift`
- **Commit:** `ae47838`

## Known Stubs

None. All five files are fully implemented with no placeholder values, no TODO markers, and no hardcoded empty returns. The `.block`/`.hybrid` fallback to `DoubleProgressionStrategy` in `ProgressionStrategyFactory` is not a stub — it is the specified behavior per UI-SPEC § What's Explicitly Deferred, documented with a Phase 4 replacement NOTE.

## Threat Flags

None. All five files are pure functions operating on value types. No network endpoints, no auth paths, no file access, no schema changes. The SwiftData import in `WarmupRamp.swift` is required for `SetEntry` type access but WarmupRamp never touches a `ModelContext` directly.

## Self-Check: PASSED

- FOUND: `fitbod/Prescription/ProgressionStrategy.swift`
- FOUND: `fitbod/Prescription/RPEAutoregStrategy.swift`
- FOUND: `fitbod/Prescription/DoubleProgressionStrategy.swift`
- FOUND: `fitbod/Prescription/WarmupRamp.swift`
- FOUND: `fitbod/Prescription/ProgressionStrategyFactory.swift`
- FOUND: commit `ddd7748` (ProgressionStrategy + PrescriptionExplanationTests)
- FOUND: commit `ae47838` (DoubleProgressionStrategy + Rounding tests)
- FOUND: commit `44941cd` (RPEAutoregStrategy + RPEAutoregStrategyTests)
- FOUND: commit `b5444f0` (WarmupRamp + ProgressionStrategyFactory + WarmupRampTests)
- All 25 new tests GREEN; 10 regression tests GREEN (TuchschererTable + PlateCalculator)
