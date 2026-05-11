---
phase: 01
plan: 01-02
wave: 1
slug: schema-versioning-and-container
complexity: M
requirements: ["FOUND-01"]
covers_pitfalls: ["#2 (VersionedSchema Day 1)", "#2 corollary (Item.swift removed from schema)"]
depends_on: ["01-01"]
files_modified:
  - fitbod/Persistence/SchemaV1.swift  # NEW
  - fitbod/Persistence/FitbodSchemaMigrationPlan.swift  # NEW
  - fitbod/fitbodApp.swift  # rewire
  - fitbod/ContentView.swift  # replaced by interim RootView stub
created: 2026-05-10
---

# Plan 01-02 — Schema Versioning and Container

> **Wave 1 / Sequence 2.** Wraps the 12 entities from plan `01-01` in `SchemaV1: VersionedSchema`, creates the empty `FitbodSchemaMigrationPlan`, and rewires `fitbodApp.swift` to use them — making the project compile again after the Wave 0 `Item.swift` deletion. Closes FOUND-01.

## Goal

Stand up the load-bearing pitfall fix: `enum SchemaV1: VersionedSchema` listing all 12 entities + an empty `FitbodSchemaMigrationPlan: SchemaMigrationPlan` attached to the `ModelContainer` in `fitbodApp.swift`. Replace the stock `ContentView` with an interim `RootView` stub so the project compiles end-to-end after this plan.

## Requirements Covered

- **FOUND-01**: "Schema wrapped in `SchemaV1: VersionedSchema` with `SchemaMigrationPlan` scaffold from day 1." This plan creates both. The migration plan has `static var stages: [MigrationStage] = []` per `01-CONTEXT.md` Area 4 — empty stages is intentional and not a bug.

## Files to Create / Modify

### Create
- `fitbod/Persistence/SchemaV1.swift`
  ```
  import SwiftData

  enum SchemaV1: VersionedSchema {
      static let versionIdentifier = Schema.Version(1, 0, 0)
      static var models: [any PersistentModel.Type] {
          [
              Exercise.self,
              MuscleGroup.self,
              ExerciseMuscleStimulus.self,
              Routine.self,
              RoutineExercise.self,
              Session.self,
              SessionExercise.self,
              SetEntry.self,
              Block.self,
              BlockPhase.self,
              UserSettings.self,
              MuscleVolumeTarget.self,
          ]
      }
  }
  ```

- `fitbod/Persistence/FitbodSchemaMigrationPlan.swift`
  ```
  import SwiftData

  enum FitbodSchemaMigrationPlan: SchemaMigrationPlan {
      static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
      static var stages: [MigrationStage] { [] }   # empty for v1; future versions add stages here
  }
  ```

### Modify
- `fitbod/fitbodApp.swift` — rewrite to use the versioned schema + migration plan + interim `RootView`:
  ```
  import SwiftUI
  import SwiftData

  @main
  struct fitbodApp: App {
      let container: ModelContainer

      init() {
          let schema = Schema(SchemaV1.models)
          let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
          do {
              container = try ModelContainer(
                  for: schema,
                  migrationPlan: FitbodSchemaMigrationPlan.self,
                  configurations: config
              )
          } catch {
              fatalError("Failed to create ModelContainer: \(error)")
          }
      }

      var body: some Scene {
          WindowGroup { RootView() }
              .modelContainer(container)
      }
  }
  ```

  Diff from current state (line numbers refer to existing `fitbodApp.swift`):
  - Line 12 `var sharedModelContainer` → `let container` (move into `init`)
  - Line 14 `Schema([Item.self,])` → `Schema(SchemaV1.models)`
  - Line 18 `try ModelContainer(for: schema, configurations: [modelConfiguration])` → `try ModelContainer(for: schema, migrationPlan: FitbodSchemaMigrationPlan.self, configurations: config)`
  - Line 28 `ContentView()` → `RootView()`

### Replace
- `fitbod/ContentView.swift` — **replace contents** with an interim `RootView` stub:
  ```
  import SwiftUI

  struct RootView: View {
      var body: some View {
          VStack(spacing: 16) {
              Image(systemName: "dumbbell")
                  .font(.system(size: 64))
                  .foregroundStyle(.accent)
              Text("Fitbod")
                  .font(.title2.weight(.semibold))
              Text("Wave 3 fills this in.")
                  .font(.callout)
                  .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
  }

  #Preview { RootView() }
  ```

  Note: the file remains named `ContentView.swift` for this plan to minimize project-file thrash. **Plan `01-PLAN-03-01` renames the file** to `fitbod/App/RootView.swift` and moves it into the `App/` folder when the real `RootView` ships. (Rationale: a single `Move + Rename` in the pbxproj is cheaper than splitting it across two plans.)

## Acceptance Criteria

1. `fitbod/Persistence/SchemaV1.swift` exists and `SchemaV1.models.count == 12`.
2. `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` exists with `static var stages: [MigrationStage] { [] }`.
3. `fitbodApp.swift` references `Schema(SchemaV1.models)` and `migrationPlan: FitbodSchemaMigrationPlan.self`. Verified by:
   ```bash
   grep -c 'Schema(SchemaV1.models)' fitbod/fitbodApp.swift  # == 1
   grep -c 'migrationPlan: FitbodSchemaMigrationPlan.self' fitbod/fitbodApp.swift  # == 1
   ```
4. `fitbodApp.swift` does NOT reference `Item.self` anywhere: `grep -c 'Item\.self' fitbod/fitbodApp.swift` == 0.
5. `fitbod/ContentView.swift` contains a `struct RootView: View` declaration (interim stub).
6. The project compiles cleanly: `xcodebuild -project fitbod.xcodeproj -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' build` exits 0 with no warnings related to `Item` or schema.
7. Launching the app on the simulator shows the placeholder `"Fitbod / Wave 3 fills this in."` view — no crashes, no fatalError from the container init.

## Test Expectations

This plan does not introduce new tests. The compile-success + clean launch are the immediate validation; the deeper schema tests land in plan `01-PLAN-01-03`.

**Sanity check command (not a Swift Test, but a build check):**
```bash
xcodebuild -project fitbod.xcodeproj -scheme fitbod \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 \
  | grep -E 'error:' || echo "BUILD OK"
```

The plan is complete iff the output is `BUILD OK`.

## Decisions Honored

- **C-5 (CONTEXT.md Area 4 — `VersionedSchema` from Day 1):** Even with empty `stages: []`, the wrapper is non-negotiable. Cost of skipping per PITFALLS.md #2: data loss on first rename. Wrapper is in place.
- **C-6 (CONTEXT.md Area 4 — `ModelContainer` config):** Single shared container in `fitbodApp.swift`, on-disk store (NOT `isStoredInMemoryOnly: true` for production), SwiftUI views consume via `.modelContainer(_)` injection.
- **R-6 (RESEARCH § Code Examples / Example 1):** The exact `init` body verbatim from research.

## Anti-Patterns Avoided

- **Not** keeping the stock `Item.self` in the schema array (PITFALLS.md #2 corollary). The file was deleted in plan `00-01`; this plan removes the reference.
- **Not** using `Schema([Exercise.self, MuscleGroup.self, ...])` inline at the call site (would scatter the entity list and require updating two places on every schema change). The list lives in `SchemaV1.models` only.
- **Not** placing `let container = ...` outside an `init` block — the synchronous init pattern is the documented Apple pattern for `ModelContainer` (RESEARCH Code Example 1).

## Out of Scope (handled by later plans)

- A `TabView`-based `RootView` with placeholder tabs → plan `01-PLAN-03-01`.
- Triggering the seed import on launch → plan `01-PLAN-03-01`.
- Moving `ContentView.swift` to `fitbod/App/RootView.swift` (rename + folder move) → plan `01-PLAN-03-01`.
- `PreviewModelContainer.make()` helper → plan `01-PLAN-01-03`.
- Schema-versioning tests → plan `01-PLAN-01-03`.

## Commit Message Template

```
feat(01): wrap entities in SchemaV1 + empty FitbodSchemaMigrationPlan

- Persistence/SchemaV1.swift: enum SchemaV1: VersionedSchema listing all 12
  entities; versionIdentifier = 1.0.0
- Persistence/FitbodSchemaMigrationPlan.swift: empty stages [] (Day-1 scaffold
  per FOUND-01, PITFALLS #2 — non-negotiable even with no migrations yet)
- fitbodApp.swift: rewire ModelContainer to use Schema(SchemaV1.models) and
  migrationPlan: FitbodSchemaMigrationPlan.self
- ContentView.swift: replace with interim RootView stub; real TabView lands
  in plan 03-01 (file renamed and moved to App/RootView.swift then)

Closes FOUND-01. Project compiles cleanly after this plan — Item.swift
references are gone.
```
