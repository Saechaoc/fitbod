---
phase: 01
plan: 01-03
wave: 1
slug: preview-container-and-schema-tests
complexity: M
requirements: ["FOUND-01", "FOUND-02", "FOUND-03", "LIB-05", "LIB-06", "SET-01"]
covers_pitfalls: ["#2 (versioned schema verified)", "#9 (enum round-trips)"]
depends_on: ["01-02"]
files_modified:
  - fitbod/Persistence/PreviewModelContainer.swift  # NEW
  - fitbod/Models/Exercise+Preview.swift  # NEW (Exercise.previewSample factory)
  - fitbodTests/TestSupport/InMemoryContainer.swift  # NEW
  - fitbodTests/SchemaV1Tests.swift  # NEW
  - fitbodTests/CascadeRuleTests.swift  # NEW
  - fitbodTests/EnumPersistenceTests.swift  # NEW
  - fitbodTests/EnumTests.swift  # NEW (compile-time case-count assertions)
  - fitbodTests/UserSettingsTests.swift  # NEW
  - fitbodTests/fitbodTests.swift  # DELETED (stock placeholder)
created: 2026-05-10
---

# Plan 01-03 — Preview Container and Schema Tests

> **Wave 1 / Sequence 3.** Stands up the testing infrastructure for the whole phase: an in-memory `PreviewModelContainer.make()` factory shared by `#Preview` blocks AND unit tests, plus the first round of Swift Testing suites covering schema invariants (FOUND-01, FOUND-02, FOUND-03) and the locked cascade rules (LIB-05).

## Goal

Create `PreviewModelContainer.make()` (returns an in-memory `ModelContainer` seeded with a deterministic mini-fixture) and a shared `fitbodTests/TestSupport/InMemoryContainer.swift` helper. Author 5 Swift Testing suites that prove FOUND-01, FOUND-02, FOUND-03, LIB-05, LIB-06, and SET-01 — all without touching the on-disk store.

## Requirements Covered

- **FOUND-01**: `SchemaV1Tests/containerBuilds` — `try ModelContainer(for: Schema(SchemaV1.models), migrationPlan: FitbodSchemaMigrationPlan.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))` succeeds.
- **FOUND-02**: `SchemaV1Tests/allPropertiesOptionalOrDefaulted` — reflection-based check that round-tripping a default `init()`-constructed entity through `ctx.insert / ctx.save / ctx.fetch` succeeds for every entity.
- **FOUND-03**: `EnumPersistenceTests/*` — round-trip every `*Raw` enum value through insert + fetch; assert the computed accessor returns the expected enum case.
- **LIB-05**: `CascadeRuleTests/exerciseToSessionExerciseNullifies` — delete an `Exercise` that has a linked `SessionExercise`; assert the `SessionExercise` row still exists but its `exercise` reference is `nil`.
- **LIB-06**: `EnumTests/equipmentHasAllNineCases` — `#expect(Equipment.allCases.count == 9)`.
- **SET-01**: `UserSettingsTests/unitsToggle` — set `unitsRaw = "kg"`, save, fetch, assert `weightUnit == .kg`.

## Files to Create / Modify

### Create — Production target (`fitbod/`)

1. `fitbod/Persistence/PreviewModelContainer.swift`:
   ```
   import SwiftData
   import Foundation

   enum PreviewModelContainer {
       static func make(seedFixture: Bool = true) -> ModelContainer {
           let schema = Schema(SchemaV1.models)
           let config = ModelConfiguration(isStoredInMemoryOnly: true, allowsSave: true)
           let container = try! ModelContainer(
               for: schema,
               migrationPlan: FitbodSchemaMigrationPlan.self,
               configurations: config
           )
           if seedFixture {
               seed(into: container.mainContext)
           }
           return container
       }

       /// Deterministic mini-fixture: 4 muscles + 2 exercises + their stimuli + a UserSettings row.
       private static func seed(into ctx: ModelContext) {
           let chest = MuscleGroup(slug: "chest", displayName: "Chest", region: .upper)
           let tris  = MuscleGroup(slug: "triceps", displayName: "Triceps", region: .upper)
           let lats  = MuscleGroup(slug: "lats", displayName: "Lats", region: .upper)
           let biceps = MuscleGroup(slug: "biceps", displayName: "Biceps", region: .upper)
           [chest, tris, lats, biceps].forEach { ctx.insert($0) }

           let bench = Exercise.previewSample(
               name: "Barbell Bench Press",
               equipment: .barbell,
               mechanic: .compound,
               primaryMuscleSlugs: ["chest"]
           )
           ctx.insert(bench)
           ctx.insert(ExerciseMuscleStimulus(exercise: bench, muscle: chest, role: "primary", weight: 1.0))
           ctx.insert(ExerciseMuscleStimulus(exercise: bench, muscle: tris,  role: "secondary", weight: 0.5))

           let row = Exercise.previewSample(
               name: "Barbell Row",
               equipment: .barbell,
               mechanic: .compound,
               primaryMuscleSlugs: ["lats"]
           )
           ctx.insert(row)
           ctx.insert(ExerciseMuscleStimulus(exercise: row, muscle: lats,   role: "primary", weight: 1.0))
           ctx.insert(ExerciseMuscleStimulus(exercise: row, muscle: biceps, role: "secondary", weight: 0.5))

           ctx.insert(UserSettings.default())
           try? ctx.save()
       }
   }
   ```

2. `fitbod/Models/Exercise+Preview.swift`:
   ```
   import Foundation

   extension Exercise {
       static func previewSample(
           name: String,
           equipment: Equipment,
           mechanic: Mechanic,
           primaryMuscleSlugs: [String] = [],
           isCustom: Bool = false
       ) -> Exercise {
           let ex = Exercise(
               name: name,
               canonicalName: name.lowercased().folding(options: .diacriticInsensitive, locale: .current),
               equipmentRaw: equipment.rawValue,
               mechanicRaw: mechanic.rawValue,
               category: "strength",
               isCustom: isCustom
           )
           ex.primaryMuscleSlugsJoined = "|" + primaryMuscleSlugs.joined(separator: "|") + "|"
           return ex
       }
   }
   ```

### Create — Test target (`fitbodTests/`)

3. `fitbodTests/TestSupport/InMemoryContainer.swift`:
   ```
   import SwiftData
   import Foundation
   @testable import fitbod

   enum InMemoryContainer {
       /// Returns a fresh empty in-memory ModelContainer for hermetic tests.
       static func makeEmpty() throws -> ModelContainer {
           let schema = Schema(SchemaV1.models)
           let config = ModelConfiguration(isStoredInMemoryOnly: true, allowsSave: true)
           return try ModelContainer(for: schema,
                                     migrationPlan: FitbodSchemaMigrationPlan.self,
                                     configurations: config)
       }

       /// Pre-seeded version reusing PreviewModelContainer.make().
       static func makeWithFixture() -> ModelContainer {
           PreviewModelContainer.make(seedFixture: true)
       }
   }
   ```

4. `fitbodTests/SchemaV1Tests.swift`:
   - `@Suite("SchemaV1")` with tests:
     - `containerBuilds` — `let c = try InMemoryContainer.makeEmpty(); #expect(c.schema.entities.count == 12)`
     - `exerciseRoundTrip` — insert Exercise, save, fetch, expect 1 row
     - `allPropertiesOptionalOrDefaulted` — for each of the 12 entity types, instantiate via `init()`, insert into ctx, save — must not throw and must round-trip

5. `fitbodTests/CascadeRuleTests.swift`:
   - `@Suite("CascadeRules")` with tests:
     - `exerciseToMuscleStimulusCascades` — insert Exercise + Muscle + Stimulus, delete Exercise, fetch Stimulus → empty
     - `exerciseToSessionExerciseNullifies` — insert Exercise + Session + SessionExercise(exercise: ex), delete ex, fetch SessionExercise → 1 row with `exercise == nil` (**LIB-05 anchor**)
     - `sessionCascadesToSetEntry` — insert Session + SessionExercise + 2 SetEntries, delete Session, fetch SetEntry → empty
     - `routineCascadesToRoutineExercise` — same shape

6. `fitbodTests/EnumPersistenceTests.swift`:
   - `@Suite("EnumPersistence")` with parameterized tests (per Swift Testing `arguments:` pattern):
     - For every case of `Equipment`, `Mechanic`, `Force`, `Level`, `Pattern`, `Intent`, `ProgressionKind`, `MuscleRegion`, `WeightUnit`, `BlockPhaseKind`, `SetType`: assign `*Raw = case.rawValue`, save, fetch, assert computed accessor returns the original case.

7. `fitbodTests/EnumTests.swift`:
   - `@Suite("Enums")` with compile-time-style assertions:
     - `intentHasFiveCases` — `#expect(Intent.allCases.count == 5)`
     - `progressionKindHasFourCases`
     - `equipmentHasNineCases` — **LIB-06 anchor**, asserts the 9 cases: barbell, dumbbell, machine, cable, bands, bodyweight, weightedBodyweight, kettlebell, other
     - `mechanicHasTwoCases`
     - `forceHasThreeCases`
     - `levelHasThreeCases`
     - `patternHasNineCases`
     - `muscleRegionHasThreeCases`
     - `weightUnitHasTwoCases`
     - `blockPhaseKindHasFourCases`
     - `setTypeHasFiveCases`

8. `fitbodTests/UserSettingsTests.swift`:
   - `@Suite("UserSettings")` with:
     - `unitsToggle` — insert `UserSettings.default()` (`.lb`), set `weightUnit = .kg`, save, fetch, expect `.kg` (**SET-01 anchor**)
     - `defaultProgressionKindToggle` — same shape on `defaultProgressionKindRaw`

### Delete
- `fitbodTests/fitbodTests.swift` — stock placeholder; replaced by the new suites above.

## Acceptance Criteria

1. All 8 new files exist; the stock `fitbodTests.swift` placeholder is gone.
2. Every test suite compiles and runs:
   ```bash
   xcodebuild test -project fitbod.xcodeproj -scheme fitbod \
     -destination 'platform=iOS Simulator,name=iPhone 16' \
     -only-testing:fitbodTests/SchemaV1Tests \
     -only-testing:fitbodTests/CascadeRuleTests \
     -only-testing:fitbodTests/EnumPersistenceTests \
     -only-testing:fitbodTests/EnumTests \
     -only-testing:fitbodTests/UserSettingsTests
   ```
   exits 0.
3. All tests pass. In particular:
   - `SchemaV1Tests/containerBuilds` proves FOUND-01.
   - `SchemaV1Tests/allPropertiesOptionalOrDefaulted` proves FOUND-02 across all 12 entities.
   - `EnumPersistenceTests` proves FOUND-03 across all 11 enums.
   - `CascadeRuleTests/exerciseToSessionExerciseNullifies` proves LIB-05.
   - `EnumTests/equipmentHasNineCases` proves LIB-06 case-count.
   - `UserSettingsTests/unitsToggle` proves SET-01.
4. `PreviewModelContainer.make()` returns a container that compiles cleanly when referenced from a `#Preview` block — verified by adding (in this plan) a single `#Preview { RootView().modelContainer(PreviewModelContainer.make()) }` block to `ContentView.swift` and confirming the canvas builds.

## Test Expectations

The acceptance criteria above lists the exact Swift Testing suites and assertions. Total test count after this plan: ~30 unit tests across 5 suites.

**Run command:**
```bash
xcodebuild test -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:fitbodTests
```

Expect a `Test Succeeded` line at the bottom; expect zero failures.

## Decisions Honored

- **C-7 (CONTEXT.md Area 4 — preview / test container):** `PreviewModelContainer.make()` is the single shared factory, used by both `#Preview` blocks and Swift Testing tests. In-memory + deterministic mini-fixture.
- **C-8 (CONTEXT.md — Swift Testing for unit, XCTest for UI):** All new unit tests use the Swift Testing framework (`@Test`, `#expect`, `@Suite`). XCTest is reserved for UI tests later phases.
- **R-7 (RESEARCH § Pattern 8 — `PreviewModelContainer.make()`):** Apple's documented in-memory + fixture pattern (Code Example 8). `seedFixture: Bool = true` parameter so tests that want a truly empty container can call `make(seedFixture: false)` — or use the hermetic `InMemoryContainer.makeEmpty()` test helper.
- **R-8 (RESEARCH Code Example 7 — Swift Testing for `@Model` round-trips):** Verbatim shape.

## Anti-Patterns Avoided

- **Not** mixing fixture seeding with hermetic test setup — every test that needs an empty container uses `InMemoryContainer.makeEmpty()`; every test that needs the mini-fixture uses `makeWithFixture()`. Cross-contamination prevented.
- **Not** sharing one `ModelContainer` across tests — each test creates its own via `try` so any side effects are isolated. Swift Testing's per-test instantiation handles this naturally for `struct` suites.
- **Not** validating `FOUND-04` (`#Index` presence) at the unit level — that's an integration concern, covered in plan `03-02`'s `IndexedQueryTests`. This plan focuses on shape (FOUND-02) and cascade behavior (LIB-05).

## Out of Scope (handled by later plans)

- `IndexedQueryTests` (proves `#Index` makes filtered queries fast) → plan `01-PLAN-03-02`.
- `SeedTests` (proves `ExerciseLibraryImporter` is idempotent and <2s) → plan `01-PLAN-02-02`.
- `DTODecodingTests` (proves `ExerciseDTO` decodes the bundled JSON) → plan `01-PLAN-02-01`.
- `FilterStatePredicateTests` (proves `FilterState.predicate` filters correctly) → plan `01-PLAN-03-02`.
- `CustomExerciseDraftTests` (proves `draft.isValid` enforces LIB-04) → plan `01-PLAN-03-04`.

## Commit Message Template

```
test(01): PreviewModelContainer factory + Swift Testing suites for FOUND-01..03, LIB-05/06, SET-01

- Persistence/PreviewModelContainer.swift: in-memory factory shared by
  #Preview blocks and unit tests; deterministic 4-muscle/2-exercise fixture
- Models/Exercise+Preview.swift: previewSample factory
- fitbodTests/TestSupport/InMemoryContainer.swift: hermetic empty + fixture
  variants
- 5 Swift Testing suites covering:
  - SchemaV1Tests: container builds (FOUND-01); all-properties-optional
    reflection check (FOUND-02 across all 12 entities)
  - CascadeRuleTests: Exercise→Stimulus cascade; Exercise→SessionExercise
    nullify (LIB-05); Session→SessionExercise→SetEntry cascade chain
  - EnumPersistenceTests: round-trip every *Raw enum case (FOUND-03)
  - EnumTests: case-count assertions for all 11 enums (LIB-06 anchor)
  - UserSettingsTests: lb↔kg toggle round-trips (SET-01)
- delete fitbodTests/fitbodTests.swift (stock placeholder)

xcodebuild test exits 0 with ~30 tests passing.
```
