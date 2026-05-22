---
phase: 03-smart-prescription-warm-ups
plan: "01"
subsystem: persistence
tags: [schema, swiftdata, migration, models, plate-inventory]
dependency_graph:
  requires: [02-00-02]
  provides: [SchemaV3, PlateInventory, PlateSpec, WarmupConfig, PlateEquipmentKind, additive-phase3-fields]
  affects: [fitbodApp, PreviewModelContainer, Exercise, RoutineExercise, SetEntry, UserSettings]
tech_stack:
  added: []
  patterns:
    - "@Model with computed Codable accessor (JSON Data field + computed accessor)"
    - "VersionedSchema composition (SchemaV3.models = SchemaV2.models + [PlateInventory.self])"
    - "MigrationStage.lightweight for additive-only schema delta"
    - "Enum-as-String persistence (PlateEquipmentKind via equipmentKindRaw)"
key_files:
  created:
    - fitbod/Models/Enums/EquipmentKind.swift
    - fitbod/Models/PlateSpec.swift
    - fitbod/Models/WarmupConfig.swift
    - fitbod/Models/PlateInventory.swift
    - fitbod/Persistence/SchemaV3.swift
  modified:
    - fitbod/Models/Exercise.swift
    - fitbod/Models/RoutineExercise.swift
    - fitbod/Models/SetEntry.swift
    - fitbod/Models/UserSettings.swift
    - fitbod/Persistence/FitbodSchemaMigrationPlan.swift
    - fitbod/Persistence/PreviewModelContainer.swift
    - fitbod/fitbodApp.swift
decisions:
  - "PlateInventory as @Model entity (not a UserSettings codable field) — one row per PlateEquipmentKind, queried by PlateInventoryEditor via @Query; consistent with PATTERNS.md singleton-ish @Model analog"
  - "WarmupConfig stored as JSON Data? on RoutineExercise (not a separate entity) — nil = default auto-warm-up behavior per RESEARCH Pitfall 5; avoids extra entity/relationship complexity"
  - "SchemaV3.models = SchemaV2.models + [PlateInventory.self] — composition not re-listing; single source of truth for model catalog"
metrics:
  duration_seconds: 198
  completed_date: "2026-05-22"
  tasks_completed: 3
  files_created: 5
  files_modified: 7
requirements: [SET-02, SET-03, SET-04, SET-07, PRES-07, WARM-03]
---

# Phase 3 Plan 01: SchemaV3 Scaffold Summary

**One-liner:** SchemaV3 additive delta — PlateInventory @Model + PlateSpec/WarmupConfig/PlateEquipmentKind types + 7 additive fields on 4 existing entities + lightweight V2→V3 migration wiring.

---

## What Was Built

### Task 1 — New Types (commit `70e4691`)

Four new files:

**`fitbod/Models/Enums/EquipmentKind.swift`**
- `public enum PlateEquipmentKind: String, CaseIterable, Sendable`
- 4 cases: `barbell`, `dumbbell`, `ezBar = "ez_bar"`, `trapBar = "trap_bar"`
- No `default` static property — inventory editor renders all 4 tabs unconditionally

**`fitbod/Models/PlateSpec.swift`**
- `public struct PlateSpec: Codable, Sendable, Equatable, Hashable`
- Fields: `weight: Double`, `countPerSide: Int`, `color: String?`
- Memberwise `public init(weight:countPerSide:color:)` with `color` defaulted to `nil`

**`fitbod/Models/WarmupConfig.swift`**
- `public struct WarmupConfig: Codable, Sendable, Equatable`
- Fields: `var enabled: Bool = true`, `var skipNextSession: Bool = false` (`var` for SessionFactory mutation)
- Memberwise `public init(enabled:skipNextSession:)` with both defaulted

**`fitbod/Models/PlateInventory.swift`**
- `@Model public final class PlateInventory` with 6 default-valued stored fields:
  - `id: UUID = UUID()` (`@Attribute(.unique)`)
  - `equipmentKindRaw: String = "barbell"`
  - `barWeight: Double = 20.0`
  - `availablePlatesData: Data = Data()`
  - `createdAt: Date = Date.now`
  - `updatedAt: Date = Date.now`
- `public init() {}`
- Extension with two computed accessors:
  - `equipmentKind: PlateEquipmentKind` — get falls back to `.barbell` on bad raw; set writes raw
  - `availablePlates: [PlateSpec]` — get decodes JSON (failure → `[]`); set encodes JSON (failure → `Data()`)

### Task 2 — Additive Fields on Existing Entities (commit `3db5f72`)

**`fitbod/Models/Exercise.swift`** — 3 new stored fields + 1 computed accessor:
- `var smallestIncrement: Double? = nil`
- `var barWeightOverride: Double? = nil`
- `var unitOverrideRaw: String? = nil`
- `var unitOverride: WeightUnit?` computed accessor in extension (`flatMap(WeightUnit.init(rawValue:))` / `?.rawValue`)

**`fitbod/Models/RoutineExercise.swift`** — 1 new stored field + 1 computed accessor:
- `var warmupOverrideData: Data? = nil` (nil = default auto-warm-up behavior)
- `var warmupOverride: WarmupConfig?` computed accessor — get guards on nil data, decodes JSON; set encodes JSON via `try?`

**`fitbod/Models/SetEntry.swift`** — 1 new stored field:
- `var wasManualOverride: Bool = false` (grouped with `isComplete` per Phase 2 additive pattern)

**`fitbod/Models/UserSettings.swift`** — 2 new stored fields:
- `var defaultIncrementKg: Double = 2.5`
- `var minCalibrationSets: Int = 10`

All 7 new fields carry literal default values. No existing field renamed, retyped, removed, or default-changed.

### Task 3 — SchemaV3 + Migration Plan + Container Wiring (commit `096256e`)

**`fitbod/Persistence/SchemaV3.swift`** (new):
- `public enum SchemaV3: VersionedSchema` with `versionIdentifier = Schema.Version(3, 0, 0)`
- `models = SchemaV2.models + [PlateInventory.self]`

**`fitbod/Persistence/FitbodSchemaMigrationPlan.swift`** (modified):
- `schemas` → `[SchemaV1.self, SchemaV2.self, SchemaV3.self]`
- `stages` → `[migrateV1toV2, migrateV2toV3]`
- New `migrateV2toV3 = MigrationStage.lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)`

**`fitbod/fitbodApp.swift`** (modified):
- `Schema(SchemaV2.models)` → `Schema(SchemaV3.models)`

**`fitbod/Persistence/PreviewModelContainer.swift`** (modified):
- `Schema(SchemaV2.models)` → `Schema(SchemaV3.models)` — in-memory previews and test containers use V3

---

## Commits

| Hash | Type | Description |
|------|------|-------------|
| `70e4691` | feat | 4 new files: PlateInventory @Model, PlateSpec, WarmupConfig, PlateEquipmentKind |
| `3db5f72` | feat | 7 additive fields across Exercise, RoutineExercise, SetEntry, UserSettings |
| `096256e` | feat | SchemaV3 + lightweight V2→V3 migration stage + fitbodApp + PreviewModelContainer wiring |

---

## Verification Results

- `xcrun swiftc -parse` over all `fitbod/*.swift` — 0 error lines (all 3 tasks)
- All 9 Task 2 grep checks — each returned 1
- All 6 Task 3 grep checks — each returned ≥1 (SchemaV3.self appears twice in migration plan: schemas array + stage declaration; migrateV2toV3 appears twice: stages array + let declaration — expected)
- `grep -RnE 'Schema\(SchemaV2\.models\)' fitbod/` — 0 matches (no straggler V2 references in production code)
- `git diff -U0 Exercise.swift RoutineExercise.swift SetEntry.swift UserSettings.swift | grep -E '^-[^-]'` — 0 deletion lines (strictly additive)

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Known Stubs

None — this plan adds schema scaffold only (no business logic, no UI). All new fields and types are wired correctly; downstream plans (03-05 strategies, 03-06 session UI, 03-08 integration) will populate and consume them.

---

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or trust-boundary schema changes. `PlateInventory` is local SwiftData storage, consistent with the project's local-only stance.

---

## Self-Check: PASSED

- `fitbod/Models/Enums/EquipmentKind.swift` — FOUND
- `fitbod/Models/PlateSpec.swift` — FOUND
- `fitbod/Models/WarmupConfig.swift` — FOUND
- `fitbod/Models/PlateInventory.swift` — FOUND
- `fitbod/Persistence/SchemaV3.swift` — FOUND
- Commits `70e4691`, `3db5f72`, `096256e` — all present in `git log --oneline -5`
