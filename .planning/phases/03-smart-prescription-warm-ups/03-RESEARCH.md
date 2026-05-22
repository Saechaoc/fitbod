# Phase 3: Smart Prescription & Warm-ups - Research

**Researched:** 2026-05-22
**Domain:** Progression algorithms, RPE calibration, plate-loading math, SwiftData schema evolution, Swift Testing
**Confidence:** HIGH (codebase verified; Tuchscherer table verified from live calculator; SwiftData patterns cross-referenced from Apple docs and fatbobman)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area 1 — RPE Autoreg Strategy**
- `TuchschererTable` as a Swift `enum` with `static let percentFor: [Int: [Double: Double]]` (`[reps: [rpe: percent]]`). File: `fitbod/Prescription/TuchschererTable.swift`. Range: reps 1–12 × RPE 6.0–10.0 in 0.5 increments.
- Calibration: locally-weighted linear regression (LOWESS-style) on `(actualReps, actualRPE) → estimated1RM` per `(exercise, intent)` pair. Gaussian kernel on time-distance (recent sets count more). Implemented as pure function `Calibration.predict(history:targetReps:targetRPE:) -> Double`.
- Min-sets threshold: 10 logged working sets (`UserSettings.minCalibrationSets: Int`, default 10). Below → Tuchscherer prior + "calibrating" badge.
- Calibrating range width: ±5% of point estimate, rounded to plate-loadable increments on each side.

**Area 2 — Double Progression Strategy**
- Bump trigger: ALL working sets must hit top of rep range.
- Increment: `Exercise.smallestIncrement: Double?` (NEW field); falls back to `UserSettings.defaultIncrementKg: Double` (default 2.5 kg / 5 lb) when nil.
- "You earned the weight bump" banner: at START of next session. Dismissed on first set tap.
- Missed top: hold weight indefinitely.

**Area 3 — Warm-up Ramp Generator**
- 4-set ramp: 40% × 5, 60% × 3, 75% × 2, 90% × 1 of top working weight.
- Round each ramp set DOWN to loadable plates.
- First qualifying compound: first `SessionExercise` with `mechanic == .compound` AND `equipment ∈ {.barbell, .dumbbell}`.
- Pure function `WarmupRamp.shouldGenerate(for:in:) -> Bool`.
- Unilateral (.dumbbell): halve to 2 sets (60% × 3, 90% × 1).
- Skip threshold: working weight < 1.5 × bar weight.
- User override: `RoutineExercise.warmupOverride: WarmupConfig?` (NEW field).

**Area 4 — Plate Calculator & Inventory**
- `PlateInventory` entity, one row per `EquipmentKind` (`.barbell`, `.dumbbell`, `.ezBar`, `.trapBar`).
- Fields: `barWeight: Double`, `availablePlates: [PlateSpec]` (codable struct: `weight: Double, countPerSide: Int, color: String?`).
- Default seeded on first launch based on `UserSettings.unitSystem`:
  - kg barbell: 25×4, 20×2, 15×2, 10×2, 5×2, 2.5×2, 1.25×2
  - lb barbell: 45×4, 35×2, 25×2, 10×2, 5×2, 2.5×2, 1.25×2
- Bar weight per `EquipmentKind`, plus `Exercise.barWeightOverride: Double?` (NEW field) for specialty bars.
- Inline disclosure: tap weight cell → horizontal plate stack visualization.
- Manual override: `SetEntry.wasManualOverride: Bool` (NEW field, default false).

**Area 5 — "Why this weight?" Disclosure**
- `info.circle` icon taps open `WhyThisWeightSheet` (bottom sheet `.medium` detent).
- `PrescriptionExplanation` value type emitted by every strategy.

**Area 6 — Settings surface**
- `PlateInventoryEditor` (tabbed by `EquipmentKind`) in `SettingsView`.
- `Exercise.unitOverride: UnitSystem?` (NEW field) in `ExerciseDetailView`.
- `UserSettings.minCalibrationSets: Int` stepper in settings.

### Claude's Discretion
- Exact bottom-sheet vs inline-disclosure form factor — resolved by UI-SPEC (`.medium` detent sheet).
- Plate visualization styling — resolved by UI-SPEC (`HStack` of `Rectangle` shapes, semantic colors).
- Whether `PlateInventory` is a SwiftData `@Model` or a single `UserSettings` codable field — **research resolves this: separate `@Model` entity is recommended** (see Architecture Patterns section).
- Whether `WarmupConfig` is a separate entity vs JSON-encoded transformable — **research resolves this: JSON-encoded as `[PlateSpec]`-array approach applies; separate entity is overkill for a two-field config struct**.

### Deferred Ideas (OUT OF SCOPE)
- Block-periodized and hybrid strategy implementations (Phase 4).
- Deload-week-aware warm-up scaling (Phase 4 — flag stub wired but always false).
- Plateau detection (Phase 5).
- "M" badge in history rows (Phase 6).
- Smart-rounding heuristics.
- Velocity-based loading.
- `PlateCalculatorSheet` as standalone top-level destination.
- Custom progression strategies.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PRES-01 | At session start, each working exercise displays a recommended weight computed by its progression model | `SessionFactory.start(...)` hook point identified; pure-function `ProgressionStrategy` protocol design verified |
| PRES-02 | User can expand "Why this weight?" to see calculation breakdown | `WhyThisWeightSheet` + `PrescriptionExplanation` value type design confirmed; `.medium` detent sheet pattern from Phase 2 `DecimalRPEPickerSheet` |
| PRES-03 | `RPEAutoregStrategy` back-calculates from prior RPE + reps using Tuchscherer table; switches to per-lifter calibration after ≥10 sets | Complete Tuchscherer table (1–10 reps × RPE 6–10) verified; LOWESS algorithm spec documented |
| PRES-04 | `DoubleProgressionStrategy` advances by smallest increment when all working sets hit top of rep range | Algorithm trivial; bump-detection logic documented; `wasManualOverride` flag schema addition identified |
| PRES-07 | Manual override recorded as actual performance, feeds next calculation | Existing `SetEntry.actualWeight` field used; new `wasManualOverride: Bool` field added |
| PRES-08 | Integrated plate calculator: given target weight + bar weight, output a plate stack | Greedy algorithm (heaviest-first, round DOWN) verified correct for canonical metric/lb plate sets |
| PRES-09 | All progression rounding respects per-exercise smallest weight increment | `Exercise.smallestIncrement: Double?` field addition + `PlateCalculator.roundDown(target:bar:plates:)` pure function |
| PRES-10 | "You earned the weight bump" banner at double progression trigger | `BumpBanner` view + `bumpOccurred: Bool` flag in `PrescriptionExplanation` |
| WARM-01 | First compound auto-generates a warm-up ramp plate-rounded to plate inventory | `WarmupRamp.generate(top:bar:plates:) -> [SetEntry]` pure function; 4-set ramp shape |
| WARM-02 | Edge cases: deload weeks (skip), unilateral (halve), light weight (skip), bodyweight (skip) | Each handled by `WarmupRamp.shouldGenerate(for:in:)` boolean guards |
| WARM-03 | User can override warm-up scheme or disable per exercise | `RoutineExercise.warmupOverride: WarmupConfig?` NEW field; `WarmupConfigSheet` view |
| SET-02 | Per-exercise weight unit override | `Exercise.unitOverride: UnitSystem?` NEW field; `ExerciseDetailView` "Prescription Settings" section |
| SET-03 | User defines plate inventory per equipment type | `PlateInventory @Model` entity + `PlateInventoryEditor` view |
| SET-04 | User defines smallest weight increment per equipment type | `Exercise.smallestIncrement: Double?` + `UserSettings.defaultIncrementKg: Double` fallback |
| SET-07 | User-tunable RPE-autoreg calibration window | `UserSettings.minCalibrationSets: Int` stepper in settings |
</phase_requirements>

---

## Summary

Phase 3 builds on Phases 1 and 2's stable SwiftData schema and `SessionFactory.start(...)` snapshot pattern to add transparent prescription: every working set gets a weight recommendation from a pluggable `ProgressionStrategy` protocol, two concrete implementations ship (RPE autoreg and double progression), the first qualifying compound gets a plate-rounded warm-up ramp, and an inline plate calculator surfaces actual loading.

The research reveals three non-obvious implementation decisions. First, the complete Tuchscherer RPE table (reps 1–10 × RPE 6.0–10.0 in 0.5 increments) is publicly documented and can be hardcoded verbatim — the table values are stable and consensus-verified. Second, storing `PlateInventory` as a separate `@Model` entity (rather than a JSON blob inside `UserSettings`) is strongly preferred in this codebase: the existing pattern is `@Model` entities for anything with a lifecycle, and the array-ordering randomness pitfall from SwiftData relationships is mitigated by the `orderIndex`-per-element pattern already established for `RoutineExercise` and `SetEntry`. Third, `[PlateSpec]` arrays stored directly on a `@Model` as `var availablePlates: [PlateSpec] = []` (where `PlateSpec: Codable`) are safe for SwiftData lightweight migration when the array is the entire value — the field behaves as a binary BLOB, not as a composite attribute, which means adding new properties to `PlateSpec` in a future phase does NOT break lightweight migration.

The warm-up ramp and plate calculator are pure functions over value types — no SwiftData coupling — making them trivially testable. The LOWESS calibration is similarly a pure function, accepting a `[HistoryPoint]` array and returning a `Double`. All progression logic is isolated from `ModelContext` per FOUND-07 and the existing Phase 2 architecture.

**Primary recommendation:** Hook `ProgressionStrategy.prescribe(...)` into `SessionFactory.start(...)` immediately after `PreviousMatchingIntent.fetchTopWorkingSet(...)`, then invoke `WarmupRamp.generate(...)` for the first qualifying exercise. Add `SchemaV3` with additive-only fields on three existing entities (`Exercise`, `RoutineExercise`, `SetEntry`) plus one new entity (`PlateInventory`).

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Progression strategy computation | Pure service layer (value type) | Invoked by `SessionFactory` (session start) | FOUND-07 — progression is pure math over logged history; no `ModelContext` coupling |
| Tuchscherer table lookup | Compile-time constant (enum) | Consumed by `RPEAutoregStrategy` | Immutable reference data; inline for zero latency, trivially snapshot-testable |
| LOWESS calibration | Pure function | Invoked by `RPEAutoregStrategy` | Accepts `[HistoryPoint]`; no persistence; testable in isolation |
| Warm-up ramp generation | Pure service layer (value type) | Invoked by `SessionFactory` | Same rationale as progression — math over `PlateInventory` + working weight |
| Plate calculator | Pure function | Consumed by ramp generator and UI disclosure | `PlateCalculator.roundDown(target:bar:plates:) -> Double?` returns nearest loadable weight |
| Plate inventory persistence | SwiftData `@Model` entity | Edited via `PlateInventoryEditor` in Settings | Has a lifecycle (create, default-seed, user-edit, reset); needs `@Query` reactivity |
| `PlateInventory` seeding | `SessionFactory` or app launch | Run once, guarded by `UserDefaults` flag | Same pattern as exercise seed (Phase 1 `FOUND-05`) |
| Prescription explanation UI | `WhyThisWeightSheet` (`.medium` detent) | `PrescriptionWeightCell` (trigger) | Presentation layer; reads `PrescriptionExplanation` value type from strategy |
| Bump banner | `BumpBanner` view inside `SessionExerciseCard` | Driven by `PrescriptionExplanation.bumpOccurred` | Ephemeral — local `@State var bannerDismissed` on the card |
| Calibrating badge | `CalibratingBadge` view inside `SessionExerciseCard` | Driven by calibration status | Pure display; no persistence |
| Warm-up set rows UI | `WarmupRampRows` view | Inside `SessionExerciseCard` | Renders pre-generated `SetEntry` rows where `isWarmup == true` |
| Settings persistence | `UserSettings @Model` (new fields) | Edited via `SettingsView` | Additive to existing singleton — new fields only |
| Per-exercise settings | `Exercise @Model` (new fields) | Edited via `ExerciseDetailView` | `smallestIncrement`, `barWeightOverride`, `unitOverride` — additive |

---

## Standard Stack

### Core (all Apple-native — zero third-party dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | iOS 18 API | Persistence for `PlateInventory`, schema V3 | Locked by project; `#Index`, `#Unique` available |
| SwiftUI | iOS 18 SDK | All UI surfaces (sheets, forms, disclosure groups) | Locked by project |
| Swift Testing | Xcode 16+ | Pure-function unit tests, Tuchscherer table snapshot tests | Project convention; Swift Testing for all new `fitbodTests/` tests |
| Swift 6 (strict concurrency) | Xcode 16 | Compilation mode; `@MainActor` everywhere except `@ModelActor` | Project requirement; concurrency errors caught at compile time |

No new SPM packages. The project explicitly prohibits third-party dependencies (`REQUIREMENTS.md` Out of Scope table, `CLAUDE.md` "What NOT to Use").

**Installation:** No install commands — entire stack is Apple-native.

### Package Legitimacy Audit

No external packages are introduced in Phase 3. The registry safety gate is not applicable. All code is Apple-native Swift.

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| (none) | — | — | — | — | — | Not applicable |

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
SessionFactory.start(routine:on:context:)
         │
         ├─► for each RoutineExercise (sorted by orderIndex):
         │       │
         │       ├─► PreviousMatchingIntent.fetchTopWorkingSet(...)
         │       │       └─► returns PreviousMatchingIntentHit? (weight, reps, rpe, date)
         │       │
         │       ├─► ProgressionStrategy.prescribe(history:targetReps:targetRPE:inventory:)
         │       │       ├─► RPEAutoregStrategy
         │       │       │       ├─► count working sets for (exercise, intent)
         │       │       │       ├─► if count < minCalibrationSets:
         │       │       │       │       └─► TuchschererTable.percent(reps:rpe:)
         │       │       │       │               → e1RM → target weight → roundDown(inventory)
         │       │       │       └─► else:
         │       │       │               └─► Calibration.predict(history:targetReps:targetRPE:)
         │       │       │                       → calibrated e1RM → target weight → roundDown(inventory)
         │       │       └─► DoubleProgressionStrategy
         │       │               ├─► check: did all working sets hit targetRepsHigh last time?
         │       │               ├─► if yes: bump = lastWeight + smallestIncrement
         │       │               └─► PrescriptionExplanation(bumpOccurred: true, ...)
         │       │
         │       ├─► SessionExercise.prescribedWeight = explanation.roundedWeight
         │       │
         │       └─► [first qualifying compound only]
         │               WarmupRamp.shouldGenerate(for:in:) → Bool
         │               WarmupRamp.generate(top:bar:plates:) → [SetEntry]
         │               → inserted before working SetEntry rows (orderIndex 0,1,2,3...)
         │
         └─► context.save()  ← single transaction (all-or-nothing)

SessionLoggerView (Phase 2, extended in Phase 3)
         │
         ├─► SessionExerciseCard
         │       ├─► BumpBanner (if PrescriptionExplanation.bumpOccurred)
         │       ├─► CalibratingBadge (if RPE autoreg + < minCalibrationSets)
         │       ├─► WarmupRampRows (SetEntry rows where isWarmup == true)
         │       └─► for each working SetEntry:
         │               PrescriptionWeightCell
         │               ├─► TextField (weight entry / override)
         │               ├─► info.circle button → WhyThisWeightSheet
         │               └─► onTap → PlateStackDisclosure (slides in below row)
         │
         └─► WhyThisWeightSheet
                 └─► renders PrescriptionExplanation value type

Settings
         └─► SettingsView → "Smart Progression" section
                 ├─► NavigationLink → PlateInventoryEditor
                 │       └─► @Query<PlateInventory> (one row per EquipmentKind)
                 ├─► Stepper: defaultIncrementKg
                 └─► Stepper: minCalibrationSets
```

### Recommended Project Structure

```
fitbod/
├── Prescription/               ← NEW: Phase 3 additions
│   ├── ProgressionStrategy.swift       # protocol + PrescriptionExplanation + CalibrationStatus
│   ├── TuchschererTable.swift          # enum with static let percentFor table
│   ├── RPEAutoregStrategy.swift        # RPEAutoregStrategy: ProgressionStrategy
│   ├── DoubleProgressionStrategy.swift # DoubleProgressionStrategy: ProgressionStrategy
│   ├── Calibration.swift               # LOWESS pure function
│   ├── PlateCalculator.swift           # roundDown(target:bar:plates:) pure function
│   └── WarmupRamp.swift                # shouldGenerate + generate pure functions
├── Models/
│   ├── PlateInventory.swift    ← NEW @Model entity
│   ├── PlateSpec.swift         ← NEW Codable struct (or nest in PlateInventory.swift)
│   ├── WarmupConfig.swift      ← NEW Codable struct (stored on RoutineExercise)
│   ├── Enums/
│   │   └── EquipmentKind.swift ← NEW enum (.barbell, .dumbbell, .ezBar, .trapBar)
│   └── ...existing models with additive fields
├── Sessions/
│   ├── WhyThisWeightSheet.swift        ← NEW
│   ├── PrescriptionWeightCell.swift    ← NEW
│   ├── PlateStackDisclosure.swift      ← NEW
│   ├── BumpBanner.swift                ← NEW
│   ├── CalibratingBadge.swift          ← NEW
│   ├── WarmupRampRows.swift            ← NEW
│   └── ...existing Phase 2 session views (modified)
├── Routines/
│   └── WarmupConfigSheet.swift         ← NEW
├── Settings/
│   ├── PlateInventoryEditor.swift      ← NEW
│   ├── PlateCalculatorSheet.swift      ← NEW
│   └── PlateInventory+Defaults.swift   ← NEW (pure defaults factory)
└── Persistence/
    └── SchemaV3.swift                  ← NEW (additive-only delta from V2)
```

---

## Key Algorithm Specifications

### 1. Tuchscherer RPE Table

**Source:** Mike Tuchscherer, Reactive Training Systems (2009); values independently verified against the fitnessvolt.com RPE calculator which cites RTS + Zourdos et al. (2016). [CITED: https://fitnessvolt.com/rpe-training/rpe-to-percentage-calculator/]

The table maps `(reps: Int, rpe: Double) → percent: Double` where `percent` is a fraction of estimated 1RM (e.g., `0.922` means 92.2%).

**Complete verified table (reps 1–10, RPE 6.0–10.0 in 0.5 increments):**

| Reps | RPE 10 | RPE 9.5 | RPE 9 | RPE 8.5 | RPE 8 | RPE 7.5 | RPE 7 | RPE 6.5 | RPE 6 |
|------|--------|---------|-------|---------|-------|---------|-------|---------|-------|
| 1    | 1.000  | 0.978   | 0.955 | 0.939   | 0.922 | 0.907   | 0.892 | 0.878   | 0.863 |
| 2    | 0.955  | 0.939   | 0.922 | 0.907   | 0.892 | 0.878   | 0.863 | 0.850   | 0.837 |
| 3    | 0.922  | 0.907   | 0.892 | 0.878   | 0.863 | 0.850   | 0.837 | 0.824   | 0.811 |
| 4    | 0.892  | 0.878   | 0.863 | 0.850   | 0.837 | 0.824   | 0.811 | 0.799   | 0.786 |
| 5    | 0.863  | 0.850   | 0.837 | 0.824   | 0.811 | 0.799   | 0.786 | 0.774   | 0.762 |
| 6    | 0.837  | 0.824   | 0.811 | 0.799   | 0.786 | 0.774   | 0.762 | 0.751   | 0.739 |
| 7    | 0.811  | 0.799   | 0.786 | 0.774   | 0.762 | 0.751   | 0.739 | 0.728   | 0.717 |
| 8    | 0.786  | 0.774   | 0.762 | 0.751   | 0.739 | 0.728   | 0.717 | 0.707   | 0.696 |
| 9    | 0.762  | 0.751   | 0.739 | 0.728   | 0.717 | 0.707   | 0.696 | 0.686   | 0.676 |
| 10   | 0.739  | 0.728   | 0.717 | 0.707   | 0.696 | 0.686   | 0.676 | 0.666   | 0.656 |

**Reps 11–12:** Not in the original Tuchscherer table (the table covers 1–10). [ASSUMED] For reps 11 and 12, the planner may either (a) interpolate using the same ~2% per-rep decrement visible in rows 9–10, or (b) clamp the lookup to rep 10 with a cap note, or (c) omit reps 11–12 from RPE autoreg entirely (double progression is more appropriate for >10 rep ranges). **Recommended: clamp at reps=10 for the RPE-autoreg path; high-rep ranges are better served by double progression.**

**Swift implementation pattern:**
```swift
// Source: TuchschererTable.swift
enum TuchschererTable {
    // Keyed as percentFor[reps][rpe] → percent fraction of e1RM
    // rpe keys: 6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0
    static let percentFor: [Int: [Double: Double]] = [
        1: [10.0: 1.000, 9.5: 0.978, 9.0: 0.955, 8.5: 0.939,
            8.0: 0.922, 7.5: 0.907, 7.0: 0.892, 6.5: 0.878, 6.0: 0.863],
        2: [10.0: 0.955, 9.5: 0.939, 9.0: 0.922, 8.5: 0.907,
            8.0: 0.892, 7.5: 0.878, 7.0: 0.863, 6.5: 0.850, 6.0: 0.837],
        // ... rows 3–10
    ]

    /// Nearest-RPE lookup: finds the closest 0.5-step RPE key.
    static func percent(reps: Int, rpe: Double) -> Double? {
        let clampedReps = max(1, min(10, reps))
        let roundedRPE = (rpe * 2).rounded() / 2  // snap to nearest 0.5
        return percentFor[clampedReps]?[roundedRPE]
    }
}
```

### 2. RPE Back-Calculation to Target Weight

The strategy computes:
1. **From prior data:** `e1RM = actualWeight / TuchschererTable.percent(reps: actualReps, rpe: actualRPE)`
2. **Target weight:** `targetWeight = e1RM * TuchschererTable.percent(reps: targetReps, rpe: targetRPE)`
3. **Round down to plates:** `prescribedWeight = PlateCalculator.roundDown(target: targetWeight, bar: barWeight, plates: inventory)`

When `actualRPE` is nil (user didn't log RPE), fall back to assuming RPE 8.0 (a conservative middle estimate). [ASSUMED] This is a reasonable default but the user should see the calibrating badge regardless.

### 3. LOWESS Calibration Algorithm

**Algorithm:** Locally-weighted linear regression on the set `{(e1RM_i, date_i)}` where each `e1RM_i = actualWeight_i / TuchschererTable.percent(reps: actualReps_i, rpe: actualRPE_i)`. [ASSUMED — standard LOWESS methodology; no strength-specific citation found]

**Pure function signature:**
```swift
// Source: Calibration.swift
struct HistoryPoint {
    let e1RM: Double      // back-calculated from (weight, reps, rpe)
    let date: Date        // for time-kernel weighting
}

enum Calibration {
    /// Predict calibrated e1RM for a given (targetReps, targetRPE) pair.
    /// Returns nil when history is empty or all weights are zero.
    static func predict(
        history: [HistoryPoint],
        targetReps: Int,
        targetRPE: Double
    ) -> Double?
}
```

**Kernel and bandwidth:**
- Kernel: Gaussian `w_i = exp(-(Δt_i / bandwidth)²)` where `Δt_i` is days since the set was logged and `bandwidth` is a tunable half-life.
- **Recommended bandwidth:** 30 days (sets older than ~60 days receive < 1% weight). [ASSUMED — standard recommendation for sports performance time-series; fast enough for a lifter who trains 3–4x/week]
- **Numerical stability:** When the sum of weights `Σw_i < 1e-9`, return `nil` (not enough signal — should not happen if `minCalibrationSets` threshold is enforced first).
- **Minimum points check:** The caller (`RPEAutoregStrategy`) must confirm `count(workingSets for exercise+intent) >= minCalibrationSets` BEFORE calling `Calibration.predict(...)`. The function assumes enough data exists.
- **Linear model:** Fit `e1RM = a + b * (daysFromNow)` weighted by the Gaussian kernel; use the `daysFromNow = 0` intercept `a` as the predicted current e1RM. A weighted least squares closed-form solution is numerically stable for N ≤ a few thousand points.

**Simplified version for Phase 3 (recommended):** Since the lifter has ≥10 but likely < 100 sets per exercise at Phase 3 maturity, the calibration can use the **weighted mean e1RM** rather than weighted linear regression, with time-kernel weights. This is simpler to implement and test, and is statistically equivalent when e1RM is roughly stable (which it will be for a single training block). The planner may upgrade to full LOWESS in Phase 5 when more data exists. Specifically:
```
calibratedE1RM = Σ(w_i * e1RM_i) / Σ(w_i)
```
This is documented as a simplification. The CONTEXT.md says "LOWESS-style" — weighted mean IS a degenerate case of LOWESS where the polynomial degree is 0.

### 4. Plate Calculator Algorithm

**Algorithm:** Greedy, heaviest-plate-first. [CITED: tommyodland.com via published analysis of the coin-change equivalence]

Standard metric (kg) and lb plate sets form **canonical coin systems**, meaning greedy always produces the minimal-plate solution. The algorithm is:
1. Compute `weightPerSide = (target - barWeight) / 2.0`
2. Sort available plates descending by weight
3. For each plate type (heaviest first), use as many as possible (`floor(remaining / plateWeight)`) without exceeding `remaining` and without exceeding `countPerSide`
4. Subtract from `remaining`; continue to next plate
5. Return `nil` if `remaining > 0.001` after all plates are exhausted (no solution)
6. Return `bar + 2 * platesUsedPerSide` as `totalWeight`

**Round DOWN means:** use `floor(...)` not `round(...)` in step 3. Warm-up sets should always under-load; the target weight is a ceiling.

```swift
// Source: PlateCalculator.swift
struct PlateStack {
    let platesPerSide: [(weight: Double, count: Int)]  // heaviest first
    let totalWeight: Double
}

enum PlateCalculator {
    static func solve(
        target: Double,
        barWeight: Double,
        plates: [(weight: Double, countPerSide: Int)]
    ) -> PlateStack?

    /// Round target DOWN to the nearest plate-loadable weight.
    /// Returns barWeight if target < barWeight (can't load below bar).
    static func roundDown(
        target: Double,
        barWeight: Double,
        plates: [(weight: Double, countPerSide: Int)]
    ) -> Double
}
```

**Edge cases:**
- `target < barWeight`: return `barWeight` (log as bar-only; warm-up skip threshold 1.5× prevents this for warm-up paths)
- `target == barWeight`: return `barWeight` (bar only, zero plates)
- Non-canonical plate set (user adds unusual plates like 7 kg): greedy may not be optimal; acceptable for v1 since the default sets are canonical. Document this in comments.

### 5. SessionFactory Hook Point

`SessionFactory.start(...)` is the integration point. Phase 3 extends the existing loop (lines 106–165 in `SessionFactory.swift`) with two additional steps after `PreviousMatchingIntent.fetchTopWorkingSet(...)`:

```swift
// Phase 3 addition — after PreviousMatchingIntent.fetchTopWorkingSet:
// Step A: Run progression strategy
let strategy = ProgressionStrategyFactory.make(for: se.progressionKind)
let (explanation, prescribedWeight) = strategy.prescribe(
    exercise: re.exercise,
    intent: se.intent,
    targetRepsLow: se.targetRepsLow,
    targetRepsHigh: se.targetRepsHigh,
    targetRPE: se.targetRPE,
    inventory: plateInventory(for: re.exercise?.equipment, context: context),
    context: context
)
se.prescribedWeight = prescribedWeight

// Step B: Warm-up ramp (first qualifying compound only, tracked with a Bool flag)
if !warmupGenerated && WarmupRamp.shouldGenerate(for: se, deloadActive: false) {
    let warmupSets = WarmupRamp.generate(
        top: prescribedWeight,
        bar: barWeight(for: se.exercise, context: context),
        plates: availablePlates(for: re.exercise?.equipment, context: context)
    )
    for (idx, warmup) in warmupSets.enumerated() {
        warmup.sessionExercise = se
        warmup.orderIndex = idx
        context.insert(warmup)
    }
    // Shift working SetEntry orderIndex to start after warm-up rows
    for (workIdx, workEntry) in workingEntries.enumerated() {
        workEntry.orderIndex = warmupSets.count + workIdx
    }
    warmupGenerated = true
}
```

**Important:** The progression strategy needs access to `ModelContext` to query historical `SetEntry` rows. This creates a tension with the pure-function goal (FOUND-07). Resolution: the strategy receives a pre-fetched `[HistoryPoint]` array (fetched by `SessionFactory` from the context), keeping the strategy itself pure. `SessionFactory` is already context-aware — it's the right place to do the SwiftData query.

---

## Schema Evolution: SchemaV3

Phase 3 requires a new `SchemaV3: VersionedSchema` with a `MigrationStage.lightweight` migration from V2. All changes are additive.

### New Entity

```swift
// PlateInventory.swift — NEW @Model entity
@Model
final class PlateInventory {
    @Attribute(.unique) var id: UUID = UUID()
    var equipmentKindRaw: String = "barbell"   // keyed by EquipmentKind
    var barWeight: Double = 20.0               // kg default for barbell
    // [PlateSpec] stored as binary BLOB (Codable array) — migration safe
    // per fatbobman.com analysis: array of Codable = BLOB, not composite attribute
    var availablePlatesData: Data = Data()     // manual JSON encode/decode for full control
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    // ... computed: var availablePlates: [PlateSpec] { get/set via JSON }
}
```

**PlateInventory storage decision:** Store `[PlateSpec]` as `Data` (manual JSON encode/decode) rather than as a bare `var availablePlates: [PlateSpec]` array. Rationale: the fatbobman.com analysis confirms Codable arrays become BLOBs and are migration-safe, but recent Apple Developer Forum posts document unexpected migrations for Codable arrays on iOS 18. Using an explicit `Data` field with a computed `var availablePlates: [PlateSpec]` accessor eliminates all ambiguity and gives full control over serialization. This pattern is used by this project for `clusterSubRepsJoined: String?` (manual encoding). It is safe for lightweight migration and predictable across OS versions. [CITED: https://fatbobman.com/en/posts/considerations-for-using-codable-and-enums-in-swiftdata-models/ / https://developer.apple.com/forums/thread/808530]

### Additive Fields on Existing Entities

```swift
// Exercise.swift additions
var smallestIncrement: Double? = nil      // kg in kg mode, lb in lb mode
var barWeightOverride: Double? = nil      // for specialty bars
var unitOverrideRaw: String? = nil        // nil = system default

// RoutineExercise.swift additions
var warmupOverrideData: Data? = nil       // nil = use default auto-warm-up behavior
// computed: var warmupOverride: WarmupConfig? { get/set via JSON }

// SetEntry.swift additions
var prescribedWeight: Double? = nil       // Phase 3 fills this (was nil in Phase 2)
var wasManualOverride: Bool = false       // set when actualWeight diverges from prescription

// UserSettings.swift additions
var defaultIncrementKg: Double = 2.5     // fallback when Exercise.smallestIncrement is nil
var minCalibrationSets: Int = 10         // RPE autoreg threshold
```

**Note on `SetEntry.prescribedWeight`:** This field ALREADY EXISTS on `SessionExercise` but NOT on `SetEntry`. The current `SessionExercise.prescribedWeight` is the exercise-level prescribed weight. Phase 3 sets this from the strategy. Individual set rows in the UI display `SessionExercise.prescribedWeight` as the suggestion. The planner must decide whether `SetEntry` also needs `prescribedWeight` (for per-set-override tracking) — based on the CONTEXT.md, the prescription is at the exercise level, not per-set, so `SessionExercise.prescribedWeight` is sufficient. `SetEntry.wasManualOverride: Bool` is the new addition on `SetEntry`.

### SchemaV3 Migration Plan

```swift
// SchemaV3.swift
public enum SchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)
    public static var models: [any PersistentModel.Type] {
        // All 15 from SchemaV2 + PlateInventory (new)
        SchemaV2.models + [PlateInventory.self]
    }
}

// FitbodSchemaMigrationPlan.swift — add migrateV2toV3
public static let migrateV2toV3 = MigrationStage.lightweight(
    fromVersion: SchemaV2.self,
    toVersion: SchemaV3.self
)
public static var stages: [MigrationStage] {
    [migrateV1toV2, migrateV2toV3]
}
public static var schemas: [any VersionedSchema.Type] {
    [SchemaV1.self, SchemaV2.self, SchemaV3.self]
}
```

All new fields have default values → lightweight migration is valid. [CITED: developer.apple.com/documentation/swiftdata/migrationstage/lightweight — additive-only changes eligible]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| RPE → %1RM conversion | Custom curve fitting | `TuchschererTable` hardcoded enum | Table is empirically established; curve-fitting from scratch adds error |
| Plate loading algorithm | Custom backtracking search | Greedy heaviest-first | Canonical plate sets are provably greedy-optimal; backtracking is unnecessary complexity |
| LOWESS calibration for N < 100 points | Full LOESS library | Weighted-mean e1RM with Gaussian time kernel | Overkill at Phase 3 scale; weighted mean is equivalent for stable-strength periods |
| JSON serialization for `[PlateSpec]` | NSCoding / NSKeyedArchiver / Transformable | `JSONEncoder`/`JSONDecoder` on `Data` field | Codable + Data is transparent, debuggable, migration-safe, and the project already uses this for `clusterSubRepsJoined` |
| Array ordering in SwiftData relationship | Relying on insertion order | `orderIndex: Int` per element | SwiftData randomly reorders relationship arrays on reload; `orderIndex` is the established project pattern [CITED: wadetregaskis.com/swiftdata-pitfalls/] |

**Key insight:** The plate calculator and RPE table are the "looks complex, is actually simple" cases in this phase. The real complexity is in the SessionFactory hook point threading and the Swift 6 sendability of the strategy types.

---

## Common Pitfalls

### Pitfall 1: ProgressionStrategy Types Must Be `Sendable`
**What goes wrong:** Swift 6 strict concurrency rejects strategy types that hold any non-`Sendable` state. If `RPEAutoregStrategy` or `DoubleProgressionStrategy` are structs with closures or mutable reference-type fields, the compiler will error.
**Why it happens:** `SessionFactory.start(...)` runs on `@MainActor`; the strategy types are passed across actor boundaries if used in async contexts.
**How to avoid:** Make strategy types `struct` (value types are implicitly `Sendable`) with no mutable stored properties. All inputs go in via function parameters; no captured state. The CONTEXT.md's "pure function" design is the correct approach.
**Warning signs:** Compiler error "Type 'X' does not conform to 'Sendable'" when the strategy is referenced inside a `Task` or across `await`.

### Pitfall 2: SwiftData Relationship Array Random Ordering
**What goes wrong:** After a session is saved and reloaded, `sessionExercise.sets` may return warm-up `SetEntry` rows interleaved with working sets in random order, breaking the warm-up-then-working visual layout.
**Why it happens:** SwiftData uses random integer row IDs; relationship arrays lose insertion order on reload. [CITED: wadetregaskis.com/swiftdata-pitfalls/]
**How to avoid:** The project already uses `orderIndex: Int` on `SetEntry`. Ensure the `SessionExerciseCard` sorts `sets` by `orderIndex` before rendering. Confirm warm-up rows get `orderIndex 0, 1, 2, 3` and working rows get `orderIndex 4, 5, 6...` in `SessionFactory.start(...)`.
**Warning signs:** Warm-up rows appear after working sets in the UI on second app launch.

### Pitfall 3: `#Predicate` with Related-Entity ID Compare
**What goes wrong:** Querying historical `SetEntry` rows for a specific `exercise.id` inside a `#Predicate` produces empty results on iOS 17/18 when the comparison is done inline against a related entity's ID.
**Why it happens:** Known SwiftData footgun — the predicate compiler can't resolve the optional chain `se.exercise?.id == someID` correctly.
**How to avoid:** Extract the UUID to a `let` constant BEFORE the `#Predicate` body, exactly as done in `PreviousMatchingIntent.fetchTopWorkingSet(...)`. The progression strategy's history-fetch query must apply the same pattern.
**Warning signs:** History fetch returns empty arrays even when data exists in the store.

### Pitfall 4: Floating-Point Plate Arithmetic
**What goes wrong:** `100.0 - 45.0 - 45.0 - 10.0` evaluates to `0.0000000000000142...` in IEEE 754 Double, causing the "no plate solution found" error state to appear for achievable weights.
**Why it happens:** Accumulation of floating-point rounding errors in the plate calculator's greedy subtraction loop.
**How to avoid:** Use an epsilon comparison (`remaining < 0.001`) instead of `remaining == 0` to determine "done". Round `weightPerSide` to 3 decimal places before the greedy loop. The project uses `Double` for weights — this is fine as long as epsilon comparisons are consistent.
**Warning signs:** Plate calculator shows "No combination found" for round weights like 100 kg.

### Pitfall 5: WarmupConfig Stored as Data — Nil Semantics
**What goes wrong:** `RoutineExercise.warmupOverrideData: Data? = nil` means "use default behavior" but `warmupOverrideData = Data()` (empty Data) or bad JSON could incorrectly decode as a disabled WarmupConfig.
**Why it happens:** Manual JSON encode/decode requires careful nil ↔ "no override" distinction.
**How to avoid:** Only write `warmupOverrideData` when the user explicitly saves a custom config. Read: if `warmupOverrideData == nil`, use the default warm-up behavior (auto-detect compound, 4-set ramp). If non-nil, decode and apply. Treat JSON decode failure as "no override" (log a warning, fall through to default). Mirrors the `notes != nil → empty string → nil` normalization pattern from Phase 2 notes persistence.
**Warning signs:** All exercises show "warm-up disabled" after the first save, or config is lost after app restart.

### Pitfall 6: SessionFactory Growing Unmanageably
**What goes wrong:** `SessionFactory.start(...)` is already 175 lines (as shipped). Adding progression strategy invocation and warm-up generation inline makes it a 350-line God function.
**Why it happens:** The factory is the natural integration point but shouldn't own the logic.
**How to avoid:** Keep `SessionFactory.start(...)` as the coordinator only. Extract:
- `ProgressionStrategyFactory.make(for:)` → returns the strategy
- `PlateInventoryStore.current(for:context:)` → fetches `PlateInventory` for an equipment kind
- `WarmupRamp.shouldGenerate(for:deloadActive:)` and `WarmupRamp.generate(top:bar:plates:)` → pure functions
The factory calls these; none of the math lives in the factory itself.
**Warning signs:** `SessionFactory.swift` exceeds 300 lines.

### Pitfall 7: RPE-Autoreg with Missing Prior RPE
**What goes wrong:** User logs reps and weight but omits RPE. `RPEAutoregStrategy` receives `actualRPE = nil` and cannot back-calculate e1RM from the Tuchscherer table.
**Why it happens:** RPE is optional on `SetEntry`; not every lifter logs it.
**How to avoid:** When `actualRPE == nil`, skip that set when building the history array. Do NOT assume a default RPE for back-calculation (this would silently corrupt the calibration). If after filtering nil-RPE sets the history count falls below `minCalibrationSets`, stay in calibrating mode. Surface this in the "Why this weight?" sheet: "Calibrating ({n} / {threshold} sets with RPE logged)."
**Warning signs:** Calibration count appears stuck even though the user has logged many sets.

### Pitfall 8: Swift 6 Concurrency in `PlateInventory` Seeding
**What goes wrong:** `PlateInventory` default seeding at app launch (or first session start) may trigger "Expression is 'async' but is not marked with 'await'" or actor-isolation errors if run on `@MainActor` with a `ModelContext` that's not actor-isolated.
**Why it happens:** Swift 6 enforces that `ModelContext` operations on the main actor use the main-actor context; seeding is a write operation.
**How to avoid:** Seed `PlateInventory` defaults inside `SessionFactory.start(...)` (already on `@MainActor`, already has a `ModelContext`) by checking `UserDefaults.bool(forKey: "plateInventorySeeded")` before every session start. Cost: one UserDefaults read per session start — negligible. Alternatively, seed in `fitbodApp.swift`'s `.task {}` block alongside the exercise seed, using the `@MainActor`-owned `sharedModelContainer.mainContext`.
**Warning signs:** "Mutation of captured var in concurrently-executing code" compile error in seeding code.

---

## Code Examples

### ProgressionStrategy Protocol

```swift
// Source: Prescription/ProgressionStrategy.swift
// Pattern: pure protocol, value-type conformers (FOUND-07)

struct PrescriptionExplanation {
    var lastSessionLine: String?        // "100 kg × 8 @ RPE 8.5 (May 15)"
    var formulaName: String             // "RPE autoregulation" / "Double progression"
    var computedLine: String?           // RPE autoreg only
    var roundedWeight: Double           // final plate-rounded prescription
    var roundedLine: String             // "→ 107.5 kg (rounded down to 1.25 kg plates × 2)"
    var status: CalibrationStatus
    var bumpOccurred: Bool = false      // Double progression triggered a bump
    var range: ClosedRange<Double>?     // calibrating mode only: low...high
}

enum CalibrationStatus {
    case calibrating(current: Int, threshold: Int)
    case calibrated
    case notApplicable  // double progression — no calibration concept
}

protocol ProgressionStrategy: Sendable {
    func prescribe(
        history: [HistoryPoint],          // pre-fetched by SessionFactory
        targetRepsLow: Int,
        targetRepsHigh: Int,
        targetRPE: Double?,
        smallestIncrement: Double,         // resolved from exercise or settings
        inventory: PlateInventory?,
        barWeight: Double,
        minCalibrationSets: Int
    ) -> (weight: Double, explanation: PrescriptionExplanation)
}
```

### WarmupConfig Codable Struct

```swift
// Source: Models/WarmupConfig.swift
struct WarmupConfig: Codable {
    var enabled: Bool = true
    var skipNextSession: Bool = false    // reset to false by SessionFactory after use
}

// On RoutineExercise:
// var warmupOverrideData: Data? = nil
// computed accessor:
var warmupOverride: WarmupConfig? {
    get {
        guard let data = warmupOverrideData else { return nil }
        return try? JSONDecoder().decode(WarmupConfig.self, from: data)
    }
    set {
        warmupOverrideData = try? JSONEncoder().encode(newValue)
    }
}
```

### Plate Calculator Core

```swift
// Source: Prescription/PlateCalculator.swift
enum PlateCalculator {
    static func roundDown(
        target: Double,
        barWeight: Double,
        plates: [(weight: Double, countPerSide: Int)]
    ) -> Double {
        guard target >= barWeight else { return barWeight }
        var remaining = ((target - barWeight) / 2.0).rounded(toPlaces: 3)
        var usedPerSide: [(weight: Double, count: Int)] = []
        let sortedPlates = plates.sorted { $0.weight > $1.weight }
        for plate in sortedPlates {
            let maxUsable = min(plate.countPerSide, Int(remaining / plate.weight))
            if maxUsable > 0 {
                usedPerSide.append((plate.weight, maxUsable))
                remaining -= plate.weight * Double(maxUsable)
                remaining = remaining.rounded(toPlaces: 3)  // float drift guard
            }
        }
        let totalPerSide = usedPerSide.reduce(0.0) { $0 + $1.weight * Double($1.count) }
        return barWeight + 2.0 * totalPerSide
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
```

### Swift Testing Table Snapshot for Tuchscherer

```swift
// Source: fitbodTests/Prescription/TuchschererTableTests.swift
@Suite("TuchschererTable snapshot")
struct TuchschererTableTests {

    // Parameterized: spot-check known canonical values
    @Test("known cell values", arguments: zip(
        [(1, 10.0), (1, 8.0), (5, 8.0), (10, 6.0)],
        [1.000,     0.922,    0.811,     0.656]
    ))
    func knownCellValues(input: (reps: Int, rpe: Double), expected: Double) {
        #expect(TuchschererTable.percent(reps: input.reps, rpe: input.rpe) == expected)
    }

    @Test("row 1 sum matches expected")
    func rowOneSumMatchesExpected() {
        // Row 1 values sum: 1.000+0.978+0.955+0.939+0.922+0.907+0.892+0.878+0.863 = 8.334
        let rpeLevels: [Double] = [10.0, 9.5, 9.0, 8.5, 8.0, 7.5, 7.0, 6.5, 6.0]
        let sum = rpeLevels.compactMap { TuchschererTable.percent(reps: 1, rpe: $0) }.reduce(0, +)
        #expect(abs(sum - 8.334) < 0.001)
    }

    @Test("clamps reps above 10 to 10")
    func clampRepsAboveTen() {
        let p10 = TuchschererTable.percent(reps: 10, rpe: 8.0)
        let p12 = TuchschererTable.percent(reps: 12, rpe: 8.0)
        #expect(p10 == p12)   // both return 0.696
    }
}
```

---

## Runtime State Inventory

> This is a greenfield phase (adding new features to an existing codebase, not a rename/refactor). No runtime state migration is required. This section is included as confirmation.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `PlateInventory` entity does not exist yet — no records to migrate | Insert new entity in SchemaV3; seed defaults on first access |
| Live service config | No external services | None |
| OS-registered state | None | None |
| Secrets/env vars | None relevant | None |
| Build artifacts | None relevant | None |

**Nothing found in any category** — verified by codebase inspection (SchemaV2 confirmed; no `PlateInventory` model file exists).

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 16.x | Swift 6, Swift Testing, swift-format | ✓ (assumed — project already uses these) | 16.x | None — required |
| iOS 18 simulator / device | `#Index`, `#Unique`, `@Previewable` | ✓ (deployment target confirmed iOS 18.0) | 18.0+ | — |
| SwiftData (system framework) | Persistence | ✓ | iOS 18 API | — |
| Swift Testing (system framework) | Unit tests | ✓ | Xcode 16+ | — |

Step 2.6: No external CLI tools or services required. Phase 3 is pure code/schema changes.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Suite`, `@Test`, `#expect`) |
| Config file | None — uses Xcode test scheme |
| Quick run command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing fitbodTests 2>&1 \| grep -E 'PASS\|FAIL\|error'` |
| Full suite command | `xcodebuild test -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` |

UI tests: `fitbodUITests` remains XCTest-only per project policy.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PRES-01 | Prescription computed at session start | unit | `fitbodTests -only-testing fitbodTests/ProgressionStrategyTests` | ❌ Wave 0 |
| PRES-02 | "Why this weight?" sheet shows correct data | unit (PrescriptionExplanation construction) | `fitbodTests -only-testing fitbodTests/PrescriptionExplanationTests` | ❌ Wave 0 |
| PRES-03 | Tuchscherer table values correct + calibration switches at threshold | unit (parameterized) | `fitbodTests -only-testing fitbodTests/TuchschererTableTests` + `fitbodTests/RPEAutoregStrategyTests` | ❌ Wave 0 |
| PRES-04 | Double progression bumps when all sets hit top of range | unit | `fitbodTests -only-testing fitbodTests/DoubleProgressionStrategyTests` | ❌ Wave 0 |
| PRES-07 | Manual override recorded as actual, feeds next calculation | unit | `fitbodTests -only-testing fitbodTests/ManualOverrideTests` | ❌ Wave 0 |
| PRES-08 | Plate calculator finds correct stack for known target weights | unit (parameterized) | `fitbodTests -only-testing fitbodTests/PlateCalculatorTests` | ❌ Wave 0 |
| PRES-09 | Smallest increment applied in progression rounding | unit | `fitbodTests -only-testing fitbodTests/ProgressionRoundingTests` | ❌ Wave 0 |
| PRES-10 | Bump banner triggered only when all sets hit top of range | unit | covered by DoubleProgressionStrategyTests | ❌ Wave 0 |
| WARM-01 | Warm-up ramp generates correct 4 sets at correct percentages | unit | `fitbodTests -only-testing fitbodTests/WarmupRampTests` | ❌ Wave 0 |
| WARM-02 | Edge cases handled (unilateral=2 sets, light weight=skip, bodyweight=skip) | unit (parameterized) | `fitbodTests -only-testing fitbodTests/WarmupRampTests` | ❌ Wave 0 |
| WARM-03 | WarmupConfig stored/retrieved correctly; skipNextSession resets | unit (in-memory ModelContainer) | `fitbodTests -only-testing fitbodTests/WarmupConfigTests` | ❌ Wave 0 |
| SET-03 | PlateInventory persists and reloads | unit (in-memory ModelContainer + SchemaV3) | `fitbodTests -only-testing fitbodTests/PlateInventoryTests` | ❌ Wave 0 |
| SET-04 | Smallest increment per exercise persists and overrides global default | unit | covered by ProgressionRoundingTests | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -only-testing fitbodTests/[relevant suite]`
- **Per wave merge:** Full `fitbodTests` suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `fitbodTests/Prescription/TuchschererTableTests.swift` — parameterized snapshot of all 90 table cells; covers PRES-03
- [ ] `fitbodTests/Prescription/RPEAutoregStrategyTests.swift` — calibrating/calibrated mode switch; nil-RPE history; first-session nil behavior; covers PRES-01, PRES-03
- [ ] `fitbodTests/Prescription/DoubleProgressionStrategyTests.swift` — bump trigger (all sets hit top), no bump (partial), no prior data; covers PRES-04, PRES-10
- [ ] `fitbodTests/Prescription/PlateCalculatorTests.swift` — parameterized: known target → expected plate stack + total weight; float-epsilon edge cases; no-solution case; covers PRES-08, PRES-09
- [ ] `fitbodTests/Prescription/WarmupRampTests.swift` — 4-set ramp percentages; dumbbell halving; skip threshold; skip for bodyweight; covers WARM-01, WARM-02
- [ ] `fitbodTests/Sessions/WarmupConfigTests.swift` — Data encode/decode round-trip; nil semantics; skipNextSession reset; covers WARM-03
- [ ] `fitbodTests/Persistence/SchemaV3MigrationTests.swift` — mirrors `SchemaV2MigrationTests.swift`; covers SchemaV3 + lightweight migration + PlateInventory entity; covers SET-03
- [ ] `fitbodTests/Sessions/SessionFactoryPhase3Tests.swift` — confirms prescribedWeight is set on SessionExercise after start(); confirms warm-up SetEntry rows are inserted with correct orderIndex; covers PRES-01, WARM-01

All suites use `@MainActor + .serialized` over in-memory `ModelContainer` with `Schema(SchemaV3.models)` + `FitbodSchemaMigrationPlan`, matching the `PreviousMatchingIntentTests` fixture pattern.

---

## Security Domain

> `security_enforcement` is not explicitly set to false in config.json — treating as enabled.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Single-user local app; no auth |
| V3 Session Management | No | No user sessions |
| V4 Access Control | No | No multi-user |
| V5 Input Validation | Yes | Plate weight values are user-entered; validate > 0, < 1000 (reasonable physical bounds); smallest increment must be > 0 |
| V6 Cryptography | No | Local-only; no sensitive data in plate inventory |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Negative plate weight input crashes plate calculator | Tampering | Guard: `plateWeight > 0` before inserting into inventory; `target > 0` before calling PlateCalculator |
| Zero `smallestIncrement` causes division-by-zero in progression rounding | Tampering | Guard: use `max(0.25, smallestIncrement)` in rounding math; validate in settings stepper (min 0.25 kg / 0.5 lb) |
| Corrupt `availablePlatesData` causes infinite loop in greedy algorithm | Tampering | JSON decode failure → use empty plate list; greedy loop terminates in O(n) regardless of input |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `ObservableObject` + `@Published` | `@Observable` macro | WWDC23 (iOS 17) | Finer-grained re-renders; project uses `@Observable` exclusively for new code |
| `#Predicate` inline related-entity ID compare | Extract to local `let` before `#Predicate` | iOS 17 bug discovered, workaround established in Phase 2 | All new queries must apply the local-capture pattern |
| Codable arrays as direct `@Model` properties | `Data` field + computed `[T]` accessor | iOS 18 forum reports of unexpected migrations | Explicit `Data` field is safer and already used in this project (`clusterSubRepsJoined`) |
| SwiftData `@Attribute(.transformable)` for custom types | Direct `Codable` array as BLOB OR manual `Data` | iOS 17+ | Both approaches work; manual `Data` is more explicit and avoids transformer registration ceremony |

**Deprecated/outdated:**
- `@Attribute(.transformable(by:))` with custom `ValueTransformer` subclass: still works but requires transformer registration before `ModelContainer` init. Not needed for simple `Codable` types. Avoid for this phase.
- `NSSecureCoding` transformers: legacy pattern; not applicable to new SwiftData code.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | RPE 11–12 rows not in original Tuchscherer table — recommendation to clamp at 10 | Tuchscherer Table | Low — CONTEXT.md intends reps 1–12 coverage; if official table has 11–12 values, update `TuchschererTable` without changing the protocol |
| A2 | Bandwidth of 30 days for LOWESS time kernel | LOWESS Algorithm | Low — calibration is advisory; wrong bandwidth shifts the calibrated weight ±5–10% which the user can override |
| A3 | Simplified weighted-mean vs full LOWESS is equivalent at Phase 3 data scale | LOWESS Algorithm | Low — Phase 3 users have < 100 sets; difference between weighted mean and full LOWESS is < 2% on small datasets |
| A4 | RPE = nil sets are excluded from calibration history (rather than assuming a default) | Pitfall 7 | Medium — if most of the user's history has no RPE logged, calibration never triggers; user should see the "calibrating" badge with the note about RPE logging |
| A5 | Non-canonical plate sets (unusual user-added weights) may not be solved optimally by greedy | Plate Calculator | Low — default plate sets are canonical; pathological user plate sets are edge cases |
| A6 | `PlateInventory` seeding runs in `SessionFactory.start(...)` gated by `UserDefaults` flag | SchemaV3 / Environment | Low — alternative is app launch `.task` block; either works; planner chooses |

---

## Open Questions

1. **Tuchscherer rows 11–12**
   - What we know: the verified table covers reps 1–10
   - What's unclear: whether the original Tuchscherer table extends to 12 reps (CONTEXT.md says "reps 1–12")
   - Recommendation: Implement rows 1–10 from the verified table; add rows 11 and 12 as extrapolated values using the ~2% per-rep decrement pattern (row 11 ≈ row 10 minus 2.3%, row 12 ≈ row 11 minus 2.3%). Annotate these rows as `[ASSUMED]` in code comments. The planner should surface this to the user for confirmation.

2. **`EquipmentKind` enum for `PlateInventory`**
   - What we know: CONTEXT.md specifies `.barbell`, `.dumbbell`, `.ezBar`, `.trapBar`
   - What's unclear: Whether this is a separate `EquipmentKind` enum or reuses the existing `Equipment` enum (which has more cases)
   - Recommendation: Introduce a new `PlateEquipmentKind` enum with exactly the 4 cases needed for `PlateInventory`. Reusing `Equipment` would include `machine`, `cable`, `bands` etc. which don't need plate inventory — confusing. New enum; persisted as `equipmentKindRaw: String` on `PlateInventory`.

3. **`PlateInventory` seeding — when exactly?**
   - What we know: Should happen once; guarded by a `UserDefaults` key
   - What's unclear: Whether it should happen in `fitbodApp.swift` `.task {}` (at app launch) or lazily in `SessionFactory.start(...)` (at first session start)
   - Recommendation: App-launch `.task {}` alongside the exercise seed check. Users expect settings to be available before starting their first session — seeding at app launch prevents the "no plates configured" empty state on first session.

---

## Sources

### Primary (HIGH confidence)

- Codebase direct inspection — `SessionFactory.swift`, `PreviousMatchingIntent.swift`, `SchemaV2.swift`, `SetEntry.swift`, `Exercise.swift`, `RoutineExercise.swift`, `UserSettings.swift`, `SessionExercise.swift`, `Equipment.swift`, `ProgressionKind.swift`, `Intent.swift` — all read directly [VERIFIED]
- [fitnessvolt.com RPE to %1RM Calculator](https://fitnessvolt.com/rpe-training/rpe-to-percentage-calculator/) — Tuchscherer table values (1–10 reps × RPE 6–10) verified from live calculator citing RTS + Zourdos et al. (2016) [CITED]
- [fatbobman.com: Considerations for Using Codable and Enums in SwiftData Models](https://fatbobman.com/en/posts/considerations-for-using-codable-and-enums-in-swiftdata-models/) — Codable arrays stored as BLOB (migration-safe); single Codable objects stored as composite attribute (NOT migration-safe) [CITED]
- [wadetregaskis.com: SwiftData Pitfalls](https://wadetregaskis.com/swiftdata-pitfalls/) — relationship array random ordering confirmed; `orderIndex` workaround verified [CITED]
- [tommyodland.com: Loading a barbell with as few plates as possible](https://tommyodland.com/articles/2020/loading-a-barbell-with-as-few-plates-as-possible/index.html) — canonical coin system analysis; greedy correctness proof for standard plate sets [CITED]
- [Apple Developer Documentation: MigrationStage.lightweight](https://developer.apple.com/documentation/swiftdata/migrationstage/lightweight) — additive-only changes eligible for lightweight migration [CITED]

### Secondary (MEDIUM confidence)

- [Apple Developer Forums: Best approach to prevent SwiftData migration issues](https://developer.apple.com/forums/thread/808530) — iOS 18 Codable array migration edge cases; explicit `Data` field recommendation [CITED]
- [swiftwithmajid.com: Swift Testing Parameterized Tests](https://swiftwithmajid.com/2024/11/12/introducing-swift-testing-parameterized-tests/) — `zip()` pattern for paired-argument parameterized tests [CITED]
- Phase 2 CONTEXT.md and completed plan summaries (STATE.md) — `SessionFactory.start(...)` hook points, `PreviousMatchingIntent` query patterns, established test conventions

### Tertiary (LOW confidence — flagged in Assumptions Log)

- LOWESS bandwidth recommendation (30 days): standard statistics practice, not strength-specific citation [ASSUMED: A2]
- Tuchscherer rows 11–12 extrapolation [ASSUMED: A1]
- RPE nil fallback behavior [ASSUMED: A4]

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Apple-native only; zero ambiguity
- Tuchscherer table values: HIGH — verified from live calculator citing authoritative source
- Architecture / SessionFactory hook: HIGH — read actual source code
- SwiftData `Data` field pattern: HIGH — cited from fatbobman + Apple Developer Forums
- Plate calculator algorithm: HIGH — mathematical proof cited
- LOWESS algorithm spec: MEDIUM — standard statistics; bandwidth is [ASSUMED]
- Tuchscherer rows 11–12: LOW — extrapolated; needs confirmation

**Research date:** 2026-05-22
**Valid until:** 2026-07-22 (60 days — stable stack; SwiftData behavior is mature on iOS 18)
