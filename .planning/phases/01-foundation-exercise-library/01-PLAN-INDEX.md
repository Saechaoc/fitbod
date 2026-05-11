---
phase: 01
slug: foundation-exercise-library
mode: mvp
created: 2026-05-10
total_plans: 12
---

# Phase 1 — Plan Index

> Atomic, commit-sized plans for the foundation + exercise library phase. Built around the LOCKED decisions in `01-CONTEXT.md`, `01-UI-SPEC.md`, and `01-RESEARCH.md`. Every plan maps to ≥1 requirement; every requirement is covered by ≥1 plan.

## Phase Goal (MVP User Story)

**As a** serious lifter setting up Fitbod for the first time, **I want to** browse, filter, search, and create custom exercises in a comprehensive library that lives on a stable, versioned data foundation, **so that** every later phase composes on schema, persistence, and library decisions that never need to be retrofitted.

## Vertical Slice — Definition of Done

After Wave 4 ships, a real user can:
1. Open the app on a fresh install; the bundled ~800-exercise library seeds in <2s on a background `@ModelActor`.
2. Tap the "Library" tab; see all seeded exercises alphabetized.
3. Type "bench" in the search bar; results filter type-ahead with no perceptible keystroke lag.
4. Tap the Muscle filter chip; multi-select "chest" + "triceps"; results AND-filter to compound matches.
5. Tap a built-in exercise; see its read-only detail (muscles with stimulus %, equipment, mechanic, instructions).
6. Tap "Copy as Custom Exercise" on the detail view; edit it in the custom-exercise editor.
7. Tap "+" in the toolbar; create a brand-new custom exercise. Save is disabled until ≥1 primary muscle with stimulus ≥0.5 is mapped.
8. Tap the "Settings" tab; toggle lb/kg; the setting persists.

## Wave Structure

```
Wave 0 — Scaffolding (independent, parallelizable)
   ├── 00-01 project-hygiene (Swift 6 + folder layout + Item.swift deletion)
   └── 00-02 asset-catalog (AccentColor #0E7C86/#3FBFC9 + placeholder AppIcon)

         ↓

Wave 1 — Schema foundation (depends on Wave 0)
   ├── 01-01 entity-models-and-enums (12 @Model entities + enums-as-Raw)
   ├── 01-02 schema-versioning-and-container (SchemaV1 + FitbodSchemaMigrationPlan + ModelContainer wiring + Item.swift removal from app)
   └── 01-03 preview-container-and-schema-tests (PreviewModelContainer + Swift Testing schema round-trip)

         ↓

Wave 2 — Library seed (depends on Wave 1)
   ├── 02-01 vendor-exercise-dataset (exercises.json + ExerciseDTO + dataset filtering)
   └── 02-02 library-seed-actor (ExerciseLibraryImporter @ModelActor + idempotency + tests)

         ↓

Wave 3 — Library UI (depends on Wave 2)
   ├── 03-01 root-tabview-and-seed-trigger (RootView + TabView + placeholder tabs + seed-on-launch)
   ├── 03-02 library-list-with-filter-and-search (ExerciseLibraryView + FilterState + chip bar + .searchable)
   ├── 03-03 exercise-detail-and-copy-as-custom (ExerciseDetailView + "Copy as Custom" sheet)
   └── 03-04 custom-exercise-editor (CustomExerciseEditor + CustomExerciseDraft + PhotosPicker + validation)

         ↓

Wave 4 — Settings + polish (depends on Wave 3)
   └── 04-01 settings-units-and-polish (SettingsView with lb/kg toggle + empty states + accessibility pass)
```

## Plan Manifest

| Plan ID | Wave | Slug | Goal | Requirements | Complexity | Depends On |
|---------|------|------|------|--------------|------------|------------|
| 01-PLAN-00-01 | 0 | project-hygiene | Bump Swift to 6.0 strict, set up folder hierarchy, delete `Item.swift` model file (app wiring still references it — fixed in 01-02) | — (enables FOUND-01..07) | S | none |
| 01-PLAN-00-02 | 0 | asset-catalog | Populate `AccentColor.colorset` with teal values; generate placeholder `AppIcon` | — (enables UI-SPEC) | S | none |
| 01-PLAN-01-01 | 1 | entity-models-and-enums | Author 12 `@Model` entities + 10 enums-as-`*Raw: String` per ARCHITECTURE.md | FOUND-02, FOUND-03, FOUND-04, LIB-06 | L | 00-01 |
| 01-PLAN-01-02 | 1 | schema-versioning-and-container | Wrap entities in `SchemaV1: VersionedSchema`; create `FitbodSchemaMigrationPlan` (empty stages); rewire `fitbodApp.swift`; **delete `Item.swift` from schema array + replace ContentView with RootView stub** | FOUND-01 | M | 01-01 |
| 01-PLAN-01-03 | 1 | preview-container-and-schema-tests | `PreviewModelContainer.make()` + first Swift Testing suite (`SchemaV1Tests`, `CascadeRuleTests`, `EnumPersistenceTests`, `UserSettingsTests`) | FOUND-01, FOUND-02, FOUND-03, LIB-05, SET-01 | M | 01-02 |
| 01-PLAN-02-01 | 2 | vendor-exercise-dataset | Vendor `exercises.json` from `yuhonas/free-exercise-db` (commit-pinned); add `ExerciseDTO` Codable struct; `DTODecodingTests` | LIB-01 (data source), LIB-06 (equipment mapping table) | M | 01-03 |
| 01-PLAN-02-02 | 2 | library-seed-actor | `ExerciseLibraryImporter` `@ModelActor`: idempotency via `UserDefaults`, category filter, MuscleGroup upsert, Exercise + stimulus inserts in 100-row batches, region taxonomy, denormalized `primaryMuscleSlugsJoined`, `os_log` telemetry, `SeedTests` (idempotent, count, <2s perf) | FOUND-05, LIB-01 | L | 02-01 |
| 01-PLAN-03-01 | 3 | root-tabview-and-seed-trigger | `RootView` with `TabView` (5 tabs, 3 placeholders); `PlaceholderTabView`; trigger `ExerciseLibraryImporter.seedIfNeeded()` from `RootView.task`; "Preparing library…" splash while seed runs | FOUND-05 (UI integration), LIB-01 (entry surface) | M | 02-02, 00-02 |
| 01-PLAN-03-02 | 3 | library-list-with-filter-and-search | `ExerciseLibraryView` (`@Query` + `.searchable` + sectioned `List` + Custom tag); `ExerciseFilterBar` + `FilterChip` + `FilterPickerSheet`; `FilterState` `@Observable` with predicate; `.task(id:)` 150ms debounce; `FilterStatePredicateTests`, `IndexedQueryTests` | LIB-01, LIB-02, LIB-03, FOUND-04, FOUND-06 | L | 03-01 |
| 01-PLAN-03-03 | 3 | exercise-detail-and-copy-as-custom | `ExerciseDetailView` (read-only for built-in: instructions, muscles w/ stimulus %, equipment, mechanic); "Copy as Custom Exercise" action that hydrates a `CustomExerciseDraft` and presents the editor (defined in 03-04) | LIB-01, LIB-06 | M | 03-02 |
| 01-PLAN-03-04 | 3 | custom-exercise-editor | `CustomExerciseEditor` Form; `CustomExerciseDraft` `@Observable` (validation); `MusclePickerSheet`; `MuscleWeightRow` slider; `PhotosPicker` for optional image; nullify-on-delete confirmed; `CustomExerciseDraftTests` | LIB-04, LIB-05, LIB-06, FOUND-06, FOUND-07 | L | 03-02 |
| 01-PLAN-04-01 | 4 | settings-units-and-polish | `SettingsView` with units toggle bound to `UserSettings.unitsRaw`; library empty states ("No exercises match" / "No exercises match \"{query}\""); accessibility-label sweep on icon-only actions; copy verbatim from UI-SPEC.md | SET-01, FOUND-06 | M | 03-02, 03-04 |

**Plan count:** 12 atomic plans, distributed S=2 / M=6 / L=4.

## Requirements → Plans Coverage Map

Every Phase 1 requirement is touched by ≥1 plan task. No orphans.

| Req ID | Covered By | Notes |
|--------|-----------|-------|
| FOUND-01 | 01-02, 01-03 | `SchemaV1: VersionedSchema` + `FitbodSchemaMigrationPlan` (empty stages) → tested in `SchemaV1Tests/containerBuilds` |
| FOUND-02 | 01-01, 01-03 | Every property optional/defaulted on every entity → tested in `SchemaV1Tests/allPropertiesOptionalOrDefaulted` |
| FOUND-03 | 01-01, 01-03 | Every enum persisted as `*Raw: String` with computed accessor → tested in `EnumPersistenceTests` |
| FOUND-04 | 01-01, 03-02 | `#Index` on `Exercise.canonicalName / equipmentRaw / mechanicRaw / isCustom / primaryMuscleSlugsJoined`, `Session.startedAt / sourceRoutineID`, `SessionExercise.intentRaw` → verified by `IndexedQueryTests` |
| FOUND-05 | 02-02, 03-01 | `ExerciseLibraryImporter @ModelActor`, idempotent, version-stamped, <2s → tested in `SeedTests/idempotent`, `SeedTests/coldLaunchUnder2s` |
| FOUND-06 | 03-02, 03-04, 04-01 | All views bind to `@Model` directly via `@Query` / `@Bindable`; only ephemeral `@Observable` state (`FilterState`, `CustomExerciseDraft`) exists |
| FOUND-07 | 03-04, 01-03 | `CustomExerciseDraft.isValid` validates without `ModelContainer` → tested in `CustomExerciseDraftTests` |
| LIB-01 | 02-01, 02-02, 03-01, 03-02 | Browse the seeded ~800-exercise bundled library |
| LIB-02 | 03-02 | Multi-facet filter chips (muscle / equipment / mechanic / pattern) |
| LIB-03 | 03-02 | `.searchable` with 150ms debounce + `#Index([\.canonicalName])` |
| LIB-04 | 03-04 | Custom exercise creation with required primary muscle + optional `PhotosPicker` image |
| LIB-05 | 01-01, 01-03, 03-04 | Cascade `Exercise → SessionExercise: nullify` confirmed in `CascadeRuleTests` |
| LIB-06 | 01-01, 02-01, 03-04 | `Equipment` enum has all 8 cases (bodyweight, weighted_bodyweight, machine, dumbbell, barbell, cable, bands, other) |
| SET-01 | 01-01, 04-01 | `UserSettings.unitsRaw` singleton + Settings toggle |

## Pitfalls → Plans Mapping (PITFALLS.md load-bearing)

| Pitfall | Phase 1 prevention | Plan |
|---------|--------------------|------|
| #1 Template/Instance collapse | `Session*` field set lives in schema from Day 1 (snapshot fields present even though Phase 2 uses them) | 01-01 |
| #2 Missing `VersionedSchema` | `SchemaV1` + `FitbodSchemaMigrationPlan` (empty stages) from Day 1 | 01-02 |
| #5 Custom-exercise muscle mapping silently optional | `CustomExerciseDraft.isValid` requires primary muscle ≥0.5; Save disabled | 03-04 |
| #6 Main-thread bulk insert | Seed runs on `@ModelActor` with batched saves (every 100 rows) | 02-02 |
| #7 Library filter without indexes | `#Index` on hot fields + denormalized `primaryMuscleSlugsJoined` | 01-01, 03-02 |
| #9 Enum `RawValue` evolution traps | Every enum stored as `*Raw: String` with computed accessor | 01-01 |
| #2 corollary: `Item.swift` left in schema | Deleted in 00-01 (file removed); `fitbodApp.swift` schema array rewired in 01-02 | 00-01, 01-02 |

## Test Stack

- **Unit:** Swift Testing (`@Test`, `#expect`, `@Suite`) — coexists with XCTest in `fitbodTests/` target. New file: `fitbodTests/TestSupport/InMemoryContainer.swift` shared helper.
- **UI:** XCTest in `fitbodUITests/` — Phase 1 ships unit-heavy; deferred UI smoke to Phase 2 where workflows are stateful.
- **Performance:** Swift Testing with `withKnownIssue` patterns for `coldLaunchUnder2s` (skip if simulator is cold). Real metric tracked in commit message after Plan 02-02 lands.
- **Run command:** `xcodebuild test -project fitbod.xcodeproj -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'`

## Execution Order

Strict wave order: 0 → 1 → 2 → 3 → 4.

Within Wave 0: 00-01 and 00-02 are independent and can be commit-ordered either way (no shared files).

Within Wave 1: 01-01 → 01-02 → 01-03 sequential (each builds on the prior).

Within Wave 2: 02-01 → 02-02 sequential (importer needs the DTO).

Within Wave 3: 03-01 first, then 03-02 (gates library tab population). 03-03 and 03-04 depend on 03-02 (need the list + draft pattern) and can be commit-ordered either way. They share the `ExerciseLibrary/` folder but touch distinct files, so file-conflict-free parallel work is fine for a single developer.

Within Wave 4: only one plan.

---

*Plan index created: 2026-05-10*
