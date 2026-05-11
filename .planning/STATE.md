---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: Exercise dataset vendored (873 raw rows pinned to upstream `acd61f7`); ExerciseDTO + EquipmentMapper + MuscleRegionMap shipped; 9 DTODecodingTests anchor LIB-01 + LIB-06 at the unit-test level
last_updated: "2026-05-11T06:38:39.800Z"
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 12
  completed_plans: 6
  percent: 50
---

# Project State: Fitbod

**Last updated:** 2026-05-11

---

## Project Reference

**Core value:** Granular, prescriptive workout sessions — every set is intentionally specified (intent, target reps, target RPE, smart-progressed weight), and progress is visible at the resolution serious lifters actually train at.

**Stack:** SwiftUI + SwiftData, iOS 18+, local-only, phone-only v1, zero third-party dependencies.

**Mode:** MVP — every phase delivers an end-to-end vertical slice (not a horizontal layer).

**Granularity:** standard (5–8 phases).

---

## Current Position

**Phase:** 1 — Foundation & Exercise Library (in progress)
**Plan:** 02-01 complete (Wave 2, sequence 1 of 2) — next: 02-02
**Status:** Exercise dataset vendored (873 raw rows pinned to upstream `acd61f7`); ExerciseDTO + EquipmentMapper + MuscleRegionMap shipped; 9 DTODecodingTests anchor LIB-01 + LIB-06 at the unit-test level
**Progress:** [█████░░░░░] 50%

### Phase Outlook

| # | Phase | Reqs | Status |
|---|-------|-----:|--------|
| 1 | Foundation & Exercise Library | 14 | In progress (Wave 2 in flight; 02-01 done) |
| 2 | Core Loop (Routines + Sessions) | 20 | Not started |
| 3 | Smart Prescription & Warm-ups | 15 | Not started |
| 4 | Periodization & Blocks | 10 | Not started |
| 5 | Fatigue Model & Plateau Detection | 10 | Not started |
| 6 | Progress Views, Export & Polish | 11 | Not started |

**Coverage:** 80 / 80 v1 requirements mapped.

---

## Performance Metrics

Phase 1 in flight; metrics roll up at phase completion. Per-plan duration table:

| Phase | Plan | Duration (s) | Tasks | Files | Notes |
|-------|------|-------------:|------:|------:|-------|
| 1 | 00-01 | 240 (approx) | 3 | 12 | Project hygiene — delete Item.swift, bump Swift 6, scaffold folders |
| 1 | 00-02 | 180 (approx) | 2 | 3 | Asset catalog — AccentColor + placeholder AppIcon |
| 1 | 01-01 | 480 | 1 | 23 | 12 entity models + 11 enums |
| 1 | 01-02 | 68 | 2 | 4 | SchemaV1 + FitbodSchemaMigrationPlan + fitbodApp rewire + RootView stub |
| 1 | 01-03 | 240 | 3 | 10 | PreviewModelContainer + 5 Swift Testing suites (48 @Test funcs / 49+ parameterised invocations) |
| 1 | 02-01 | 216 | 3 | 8 | Vendor free-exercise-db JSON (873 rows, ~1.0 MB, SHA `acd61f7`) + ExerciseDTO + EquipmentMapper + MuscleRegionMap + 9 DTODecodingTests |

---

## Accumulated Context

### Key Decisions (from PROJECT.md, locked in)

- iOS native SwiftUI + SwiftData (Xcode template already created)
- Single-user, local-only v1 (no auth, no cloud, no backend)
- Per-exercise prescription as the core unit
- User-selectable progression model (4 options: RPE/RIR autoreg, double progression, block-periodized, hybrid)
- RP-style weekly volume tracking against MEV/MAV/MRV
- Deload: scheduled by default + advisory fatigue alert (block schedule is canonical)
- 1000+ exercise library seeded from `yuhonas/free-exercise-db` (Unlicense, ~800 exercises)
- Auto warm-up ramp on first compound only
- Phone-only v1 (no Watch, no HealthKit, no VBT)

### Architectural Stance (from research/ARCHITECTURE.md)

1. **MV-VM-lite** — Views bind to `@Model` directly via `@Query` / `@Bindable`. No parallel ViewModel layer mirrors the schema.
2. **Template vs Instance via snapshot** — `SessionFactory.start(...)` copies prescription fields from `RoutineExercise` (template) to `SessionExercise` (instance) at session-start. Template edits never rewrite history.
3. **Progression and fatigue as pure stateless services behind protocols** — `ProgressionStrategy` has four conforming value types; `FatigueModel`, `PlateauDetector`, `PeriodizationEngine` are pure functions over plain inputs. Trivially unit-testable without `ModelContainer`.

### Load-Bearing Pitfalls (from research/PITFALLS.md)

These drive phase ordering and are mitigated by phase placement:

| # | Pitfall | Mitigated in |
|---|---------|--------------|
| 1 | Collapsing template and instance | Phase 1 (schema) + Phase 2 (snapshot proven end-to-end) |
| 2 | Missing `VersionedSchema` in v1 | Phase 1 (FOUND-01) |
| 3 | Volume math correct but UX doesn't drive a decision | Phase 5 (verb labels, not just numbers) |
| 4 | Rest timer drifts/stops on lock | Phase 2 (`Date` + `UNUserNotification`, never foreground `Timer`) |
| 5 | RPE-to-weight back-calc uses population averages | Phase 3 (Tuchscherer as prior; per-lifter calibration after ≥10 sets) |
| 9 | Codable enums on @Model types crash; *Raw String + computed accessor is the workaround | Phase 1 (FOUND-03 anchored at unit-test level via EnumPersistenceTests) |

### Open Research Items (deferred to plan-phase time)

- **Phase 3:** Tuchscherer RPE table cell values + per-exercise per-lifter calibration algorithm (linear vs locally-weighted; min-points threshold)
- **Phase 4:** Block phase curve multipliers (default volume/intensity per accumulation/intensification/realization/deload) confirmed against current RP/RTS literature
- **Phase 5:** Stimulus-weighting table for the ~50 main compound lifts (beyond 1.0/0.5 defaults) + RP-published MEV/MAV/MRV seed values per muscle

### Todos

- [x] `/gsd-plan-phase 1` — decompose Phase 1 into executable plans (PLAN-INDEX.md created)
- [x] Confirm `Item.swift` template model is removed before any seed import (plan 00-01 deleted it; plan 01-02 removed all `Item.self` references)
- [x] Plan 01-03 — `PreviewModelContainer.make()` + first batch of SchemaV1 unit tests (Wave 1 complete)
- [x] Plan 02-01 — `ExerciseDTO` + EquipmentMapper + MuscleRegionMap + vendored exercises.json (Wave 2, seq 1)
- [ ] Plan 02-02 — `ExerciseLibraryImporter` `@ModelActor` (Wave 2, seq 2)
- [ ] Plans 03-01 / 03-02 / 03-03 / 03-04 — RootView TabView + ExerciseLibraryView + custom exercise editor (Wave 3)

### Phase 1 Plans Completed

- **00-01** (Wave 0): Project hygiene — deleted `Item.swift`, bumped Swift 6 + strict concurrency, scaffolded feature-organized folders. Commits: `24ac4e0` / `8a16c96` / `40d9531` / `fa32cf2`.
- **00-02** (Wave 0, parallel): Asset catalog — AccentColor `#0E7C86` / `#3FBFC9`, placeholder AppIcon. Commits: `a1df0f3` / `e0c68d4`.
- **01-01** (Wave 1, seq 1): 12 `@Model` entities + 11 String-backed enums + 23 files. Commits: `cb27292` / `6aed051` / `8e35c93` / `adf8a7b` / `a4c5991`.
- **01-02** (Wave 1, seq 2): `SchemaV1: VersionedSchema` + `FitbodSchemaMigrationPlan` + `fitbodApp` rewire + interim `RootView` stub. Commits: `28795c8` / `58ea362`. Closes FOUND-01.
- **01-03** (Wave 1, seq 3): `PreviewModelContainer.make()` + `Exercise.previewSample` + `InMemoryContainer` helper + 5 Swift Testing suites (SchemaV1Tests, CascadeRuleTests, EnumPersistenceTests, EnumTests, UserSettingsTests). 48 `@Test` funcs anchoring FOUND-01..03, LIB-05/06, SET-01. Commits: `38d975b` / `5369cb7`. Closes the Wave 1 testing-infrastructure bar.
- **02-01** (Wave 2, seq 1): Vendored `yuhonas/free-exercise-db` `exercises.json` (873 raw rows, ~1.0 MB, pinned to upstream SHA `acd61f7`, Unlicense / public domain). Authored `SEED_VERSION.txt` = 1 + `SOURCE.md` (provenance + 5-step refresh procedure). Created `ExerciseDTO` (plain Codable struct, 11 fields), `EquipmentMapper` (LIB-06 anchor: 12+ raw → 9-case Equipment, plus `shouldImport(category:)` strength filter), `MuscleRegionMap` (RESEARCH Open Q #3: 17 slugs → 10/6/1 region split + `displayName(for:)` + `allSlugs: [String]`). Added 9 `DTODecodingTests` (15-input parameterised equipment-mapping + exhaustive coverage over actual bundled JSON + region bucket sizes + Codable round-trip). Commits: `f7279bb` / `3d21e20` / `fa33433`. Closes LIB-01.

### Blockers

None.

---

## Session Continuity

### Last Action

Executed plan 02-01 (vendor exercise dataset). Pinned to upstream commit `acd61f7` of `yuhonas/free-exercise-db` (873 raw rows, ~1.0 MB, public domain). Authored `ExerciseDTO` + `EquipmentMapper` (LIB-06 anchor) + `MuscleRegionMap` and a 9-test `DTODecodingTests` suite. `xcrun swiftc -parse` over all 37 Swift files exits 0; bundle resources auto-registered via `PBXFileSystemSynchronizedRootGroup`. LIB-01 marked complete.

### Next Action

`/gsd-execute-phase 02-02` — authors `ExerciseLibraryImporter` as a `@ModelActor` that reads the bundled JSON, upserts 17 `MuscleGroup` rows from `MuscleRegionMap.allSlugs`, inserts ~675 strength-filtered `Exercise` rows (using `EquipmentMapper.shouldImport(category:)` + `EquipmentMapper.map(_:)`), creates `ExerciseMuscleStimulus` join rows (primary → 1.0 / secondary → 0.5), and stamps `UserDefaults["exercise_seed_version"]`. Performance target: <2s on cold launch.

### Open Questions

- None at this layer. The full test suite will be run on the user's machine in Xcode when next opened; the parse-clean state means every `@Test` is expected to pass on that first run.

### Key Decisions Accumulated (Phase 1)

- **Plan 01-01 D-1**: Public access modifiers throughout (test target reaches via `@testable import`)
- **Plan 01-01 D-2**: snake_case rawValues for multi-word enum cases (matches `yuhonas/free-exercise-db` wire format)
- **Plan 01-01 D-3**: `@Relationship(inverse:)` declared on owning side only (single canonical place per relationship)
- **Plan 01-02 D-1**: `enum FitbodSchemaMigrationPlan: SchemaMigrationPlan` (not `class`) — Apple-canonical form
- **Plan 01-02 D-2**: `let container: ModelContainer` (not `lazy var`) — Sendable-friendly under Swift 6 strict concurrency
- **Plan 01-02 D-4**: Interim `RootView` stays in `ContentView.swift` for this plan; renamed + moved to `App/RootView.swift` by plan 03-01 as a single pbxproj edit
- **Plan 01-03 D-1**: `PreviewModelContainer` is an `enum` (not `struct` or `class`) — namespace-only type, matches SchemaV1 / FitbodSchemaMigrationPlan style
- **Plan 01-03 D-3**: `InMemoryContainer.makeEmpty()` throws (vs `make()`'s `try!`) — tests surface ModelContainer init errors verbatim, previews fatalError
- **Plan 01-03 D-4**: Twelve separate per-entity default-init `@Test` funcs (not one parameterised loop) — clearer failure messages for FOUND-02 regressions
- **Plan 01-03 D-5/D-6**: `EnumPersistenceTests` parameterises over `Enum.allCases` (auto-covers new cases); `EnumTests` asserts case count AND the full rawValue `Set<String>` (catches renames + additions)
- **Plan 01-03 D-7**: `Exercise.previewSample` lives in the main target (not test target) so `#Preview` blocks reach it without `@testable` ceremony
- **Plan 02-01 D-1**: Pinned upstream SHA `acd61f7` recorded in `SOURCE.md`; future refresh follows the 5-step procedure
- **Plan 02-01 D-2**: Did NOT pre-filter at vendor time — bundled JSON is the full 873-row upstream dataset byte-for-byte; the strength filter is a runtime predicate (`EquipmentMapper.shouldImport(category:)`), preserves diff-against-upstream traceability
- **Plan 02-01 D-3**: `e-z curl bar → .barbell` (not `.other`) — UX-driven mapping so 9 E-Z curl exercises stay discoverable under the "barbell" filter chip
- **Plan 02-01 D-7**: `MuscleRegionMap.allSlugs` exposed as `public static let [String]` so plan 02-02 has a single source of truth for the canonical 17-slug list

---

*State initialized: 2026-05-10 after roadmap creation. Updated: 2026-05-11 after plan 02-01 (Wave 2 seq 1 complete; LIB-01 closed).*
