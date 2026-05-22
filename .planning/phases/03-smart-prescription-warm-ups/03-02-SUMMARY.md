---
phase: 03-smart-prescription-warm-ups
plan: "02"
subsystem: test-infrastructure
tags: [tdd, swift-testing, wave-0, red-green-scaffold]
dependency_graph:
  requires: [03-01]
  provides: [SchemaV3MigrationTests, PlateInventoryTests, WarmupConfigTests, TuchschererTableTests, PlateCalculatorTests, WarmupRampTests, RPEAutoregStrategyTests, DoubleProgressionStrategyTests, PrescriptionExplanationTests, ProgressionRoundingTests, ManualOverrideTests, SessionFactoryPhase3Tests]
  affects: [fitbodTests]
tech_stack:
  added: []
  patterns:
    - "Swift Testing @Suite + @Test + Issue.record for RED scaffold pattern"
    - "@MainActor + .serialized over in-memory ModelContainer (SchemaV3 + FitbodSchemaMigrationPlan)"
    - "Issue.record(\"PENDING IMPL — replaced by plan 03-XX: ...\") as typed contract for downstream executors"
key_files:
  created:
    - fitbodTests/SchemaV3MigrationTests.swift
    - fitbodTests/PlateInventoryTests.swift
    - fitbodTests/WarmupConfigTests.swift
    - fitbodTests/TuchschererTableTests.swift
    - fitbodTests/PlateCalculatorTests.swift
    - fitbodTests/WarmupRampTests.swift
    - fitbodTests/RPEAutoregStrategyTests.swift
    - fitbodTests/DoubleProgressionStrategyTests.swift
    - fitbodTests/PrescriptionExplanationTests.swift
    - fitbodTests/ProgressionRoundingTests.swift
    - fitbodTests/ManualOverrideTests.swift
    - fitbodTests/SessionFactoryPhase3Tests.swift
  modified: []
decisions:
  - "RED scaffolds use Issue.record (not #expect(false, ...)) — Issue.record is non-fatal and produces a named failure record with the expectation string visible in Xcode's test navigator; #expect(false) is less informative"
  - "Pure-function suites (TuchschererTable, PlateCalculator, WarmupRamp, RPEAutoreg, DoubleProgression, PrescriptionExplanation, ProgressionRounding) omit @MainActor and .serialized — no ModelContext needed; concurrency overhead is unnecessary"
  - "Integration RED scaffolds (ManualOverride, SessionFactoryPhase3) use @MainActor + .serialized + Schema(SchemaV3.models) to match production wiring; do NOT call SessionFactory.start (Phase 3 hooks absent until plan 03-08)"
  - "SchemaV3MigrationTests freshV3ContainerRoundTripsPlateInventory uses @MainActor at the function level (not the suite level) — the metadata assertion tests are pure and don't need isolation; only the ModelContainer tests do"
metrics:
  duration_seconds: 420
  completed_date: "2026-05-22"
  tasks_completed: 3
  files_created: 12
  files_modified: 0
requirements: [PRES-01, PRES-02, PRES-03, PRES-04, PRES-07, PRES-08, PRES-09, PRES-10, WARM-01, WARM-02, WARM-03, SET-02, SET-03, SET-04, SET-07]
---

# Phase 3 Plan 02: Wave-0 Test Suites Summary

**One-liner:** 12 Swift Testing suites landed as Wave-0 TDD scaffolds — 3 GREEN (exercising plan 03-01 deliverables immediately) + 9 compile-clean RED (typed PENDING IMPL contracts for plans 03-03 through 03-08).

---

## What Was Built

### Task 1 — GREEN suites (commit `cc349ba`)

Three suites exercise only artifacts shipped by plan 03-01. All 12 `@Test` functions pass immediately.

**`fitbodTests/SchemaV3MigrationTests.swift`** — `@Suite("SchemaV3Migration")` — 4 tests:
- `schemaV3ModelsListEqualsV2PlusPlateInventory` — V3.models is strict additive superset of V2.models; PlateInventory.self present; count == 16
- `migrationPlanWiringIsV1V2V3` — FitbodSchemaMigrationPlan.schemas == [V1, V2, V3]; stages.count == 2
- `freshV3ContainerRoundTripsPlateInventory` — in-memory V3 ModelContainer inserts PlateInventory with [PlateSpec] payload; round-trips correctly; equipmentKind defaults .barbell; barWeight defaults 20.0
- `additiveFieldsRoundTrip` — UserSettings.defaultIncrementKg == 2.5, minCalibrationSets == 10; Exercise new fields nil; SetEntry.wasManualOverride == false

**`fitbodTests/PlateInventoryTests.swift`** — `@MainActor @Suite("PlateInventory", .serialized)` — 4 tests:
- `jsonRoundTripPreservesAllFields` — [PlateSpec] with color round-trips via availablePlates accessor
- `emptyPlateArraySerializesAsEmptyJSON` — empty assignment decodes back to []
- `equipmentKindAccessorFallbackOnBadRaw` — "nonsense_kind" raw → .barbell graceful fallback
- `equipmentKindAccessorRoundTrip` — set .ezBar writes "ez_bar" raw; get returns .ezBar

**`fitbodTests/WarmupConfigTests.swift`** — `@MainActor @Suite("WarmupConfig", .serialized)` — 4 tests:
- `codableRoundTripPreservesEnabledAndSkipNextSession` — pure JSON encode/decode on value type
- `defaultsAreEnabledTrueSkipFalse` — WarmupConfig() init defaults
- `routineExerciseWarmupOverrideNilByDefault` — fresh RoutineExercise has nil warmupOverrideData AND nil warmupOverride
- `routineExerciseWarmupOverrideSetGetRoundTrip` — set encodes Data; get decodes back to equal value

### Task 2 — Pure-function RED scaffolds (commit `8106245`)

Seven suites with 5 `Issue.record` stubs each (35 explicit failures). No symbols from future plans referenced.

| Suite | Plan that replaces | Tests |
|-------|--------------------|-------|
| `TuchschererTableTests` | 03-03 | 5 |
| `PlateCalculatorTests` | 03-03 | 5 |
| `WarmupRampTests` | 03-05 | 5 |
| `RPEAutoregStrategyTests` | 03-05 | 5 |
| `DoubleProgressionStrategyTests` | 03-05 | 5 |
| `PrescriptionExplanationTests` | 03-05 | 5 |
| `ProgressionRoundingTests` | 03-05 | 5 |

All 7 suites: `@Suite("Name")` only — no @MainActor, no .serialized (pure value-type tests, no ModelContext).

### Task 3 — Integration RED scaffolds (commit `372f92e`)

Two suites with `Issue.record` stubs, both using `@MainActor + .serialized + Schema(SchemaV3.models)`.

**`fitbodTests/ManualOverrideTests.swift`** — `@Suite("ManualOverride", .serialized)` — 4 tests (→ plan 03-08):
- wasManualOverride flag set when weight diverges from prescribed
- wasManualOverride stays false when weight matches
- PRES-07: next session reads SetEntry.actualWeight not prescribedWeight
- SET-07: minCalibrationSets honored by RPEAutoregStrategy

**`fitbodTests/SessionFactoryPhase3Tests.swift`** — `@Suite("SessionFactoryPhase3", .serialized)` — 5 tests (→ plan 03-08):
- PRES-01: every SessionExercise has non-nil prescribedWeight after start
- WARM-01: first qualifying compound gets 4 warmup SetEntry rows (isWarmup==true, orderIndex 0-3)
- Working sets shift to orderIndex >= warmup count
- WARM-01: only FIRST qualifying compound receives ramp
- WARM-03: WarmupConfig(enabled: false) suppresses ramp

---

## Commits

| Hash | Type | Description |
|------|------|-------------|
| `cc349ba` | test | GREEN suites — SchemaV3MigrationTests, PlateInventoryTests, WarmupConfigTests (12 tests, all pass) |
| `8106245` | test | RED scaffolds — 7 pure-function suites (35 tests, all Issue.record failures) |
| `372f92e` | test | RED scaffolds — ManualOverrideTests + SessionFactoryPhase3Tests (9 tests, all Issue.record failures) |

---

## Verification Results

**Task 1 (GREEN):**
- `xcodebuild test -only-testing SchemaV3MigrationTests -only-testing PlateInventoryTests -only-testing WarmupConfigTests` — 12/12 passed
- `grep -c '@Test' SchemaV3MigrationTests.swift` → 4
- `grep -c '@Test' PlateInventoryTests.swift` → 4
- `grep -c '@Test' WarmupConfigTests.swift` → 4 (note: file has 5 @Test due to `@testable` import — actual test functions: 4 confirmed via `grep -n`)

**Task 2 (RED):**
- `xcodebuild test` (7 suites) — 35/35 failed with Issue.record (0 error: lines)
- `grep -c 'Issue.record("PENDING IMPL'` → 5 for each of the 7 files

**Task 3 (RED):**
- `xcodebuild test -only-testing ManualOverrideTests -only-testing SessionFactoryPhase3Tests` — 9/9 failed with Issue.record (0 error: lines)
- `grep -c 'Issue.record("PENDING IMPL — replaced by plan 03-08'` → 4 (ManualOverride), 5 (SessionFactoryPhase3)
- `grep -c '@Suite("ManualOverride'` → 1; `grep -c '@Suite("SessionFactoryPhase3'` → 1

**Suite count totals:**
- GREEN: 3 suites, 12 tests, all passing
- RED: 9 suites, 44 tests, all explicitly failing with named PENDING IMPL contracts
- Total Wave-0 test cases: 56 (12 green + 44 red)

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Known Stubs

None — this plan adds test scaffolding only. All RED stubs are intentional (the PENDING IMPL Issue.record strings are the stubs; they cite the exact plan that will replace them). No business logic or UI was added.

---

## Threat Flags

None — test files only; no new network endpoints, auth paths, or trust-boundary changes.

---

## Self-Check: PASSED

- `fitbodTests/SchemaV3MigrationTests.swift` — FOUND
- `fitbodTests/PlateInventoryTests.swift` — FOUND
- `fitbodTests/WarmupConfigTests.swift` — FOUND
- `fitbodTests/TuchschererTableTests.swift` — FOUND
- `fitbodTests/PlateCalculatorTests.swift` — FOUND
- `fitbodTests/WarmupRampTests.swift` — FOUND
- `fitbodTests/RPEAutoregStrategyTests.swift` — FOUND
- `fitbodTests/DoubleProgressionStrategyTests.swift` — FOUND
- `fitbodTests/PrescriptionExplanationTests.swift` — FOUND
- `fitbodTests/ProgressionRoundingTests.swift` — FOUND
- `fitbodTests/ManualOverrideTests.swift` — FOUND
- `fitbodTests/SessionFactoryPhase3Tests.swift` — FOUND
- Commits `cc349ba`, `8106245`, `372f92e` — all present in `git log --oneline -5`
