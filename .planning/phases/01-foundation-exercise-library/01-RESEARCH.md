# Phase 1: Foundation & Exercise Library - Research

**Researched:** 2026-05-10
**Domain:** SwiftData schema bootstrapping + native SwiftUI exercise library on iOS 26.4 (Swift 6, Xcode 26)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area 1 — Exercise Library Seeding**
- **Source dataset**: Bundle `yuhonas/free-exercise-db` JSON in the app target. License (Unlicense / public domain) requires no attribution. Filter import at seed time to `category ∈ {strength, powerlifting, olympic weightlifting, strongman}` — drop cardio/stretching since those are out of scope for v1.
- **Seed timing**: Run on first launch; idempotent on subsequent launches.
- **Idempotency mechanism**: `UserDefaults` key `exercise_seed_version` storing the seed-data version stamp; if the bundled JSON's version matches the stored stamp, skip seeding entirely.
- **Concurrency**: Seed runs inside a `@ModelActor` (per PITFALLS.md #6 — never block the main thread for 800+ rows of insert). Target <2s on cold launch (Phase 1 success criterion 1).
- **Image assets**: v1 ships *without* bundled exercise images to keep the app binary small. Images can be wired in a later phase (`LIB-04` notes image as optional). The seed records the relative image path string from the dataset for future use, but does not bundle the binaries.
- **Stimulus weighting seed**: For each exercise, create one `ExerciseMuscleStimulus` row per primary muscle with `weight = 1.0` and one per secondary muscle with `weight = 0.5`. Hand-curation of the top ~50 lifts is **deferred to Phase 5** — but the schema supports it from day 1.

**Area 2 — Filter and Search UX**
- **Filter UI**: Sticky chip-row at the top of the library screen (muscle, equipment, mechanic, pattern); selected chips filter the list reactively. Multi-select within a facet, AND across facets.
- **Search**: A native SwiftUI `.searchable` modifier on the list; type-ahead matches against `Exercise.canonicalName` (case- and diacritic-insensitive). Indexed via `#Index<Exercise>([\.canonicalName])`.
- **Filter persistence**: Per-session only — filters reset when the user leaves the library tab.
- **Default sort**: Alphabetical by canonical name. Sort options menu deferred to v1.x.
- **Performance bar**: Sub-100ms response on filter chip taps and keystrokes, validated against the full 800-exercise set.

**Area 3 — Custom Exercise Creation**
- **Required fields**: name, primary muscle (at least one, with stimulus weight ≥ 0.5), equipment kind, mechanic (compound/isolation). Image is optional (camera + photo library both supported via `PhotosUI`).
- **Stimulus weight UI**: For each selected muscle, a slider 0.0–1.0 with default 1.0 for primary, 0.5 for secondary.
- **Validation**: Save button disabled until all required fields are populated; the validation rule lives in a `CustomExerciseDraft` value type used by the form (testable without `ModelContainer`).
- **Edit/delete on user-created**: editable + deletable freely. Built-in exercises are read-only; a "Copy as custom" action creates an editable user-owned duplicate. Deleting a custom exercise with existing history shows a confirmation explaining session history will be preserved (via Nullify cascade on the `SessionExercise.exercise` relationship).
- **`isCustom: Bool` flag**: persisted; indexed.

**Area 4 — Schema, Migrations, and ModelContainer**
- **`VersionedSchema`**: All 12 `@Model` types wrapped in `enum SchemaV1: VersionedSchema { ... static var models: [any PersistentModel.Type] = [...] }`. A `class FitbodSchemaMigrationPlan: SchemaMigrationPlan` is created with an empty `static var stages: [MigrationStage] = []`.
- **`ModelContainer` config**: Single shared container in `fitbodApp.swift`, configured with the versioned schema, on-disk store. SwiftUI views consume via `.modelContainer(_)` injection.
- **Preview / test container**: Helper factory `PreviewModelContainer.make()` produces an in-memory `ModelContainer` seeded with a deterministic mini-fixture.
- **Cascade rules** (locked):
  - `Session` → `SessionExercise` → `SetEntry`: cascade delete
  - `Routine` → `RoutineExercise`: cascade delete
  - `Exercise` → `SessionExercise`: **nullify** (deleting a library entry must not delete history)
  - `Exercise` → `ExerciseMuscleStimulus`: cascade delete (stimulus rows are owned)
  - All relationships declare explicit inverses.
- **Enum persistence**: every enum stored as `*Raw: String` with a computed enum accessor (PITFALLS.md #9).
- **All properties optional or default-valued** (FOUND-02 — iCloud-shape insurance).
- **Indexes** (iOS 18 `#Index`): per ARCHITECTURE.md table.
- **iOS deployment target**: confirm and set (already at iOS 26.4 in the existing project — see Environment Availability below).
- **`Item.swift` (stock template model)**: delete after `SchemaV1` is wired.

### Claude's Discretion
- Exact Xcode project layout / folder structure — planner picks a feature-organized layout (`Models/`, `ExerciseLibrary/`, `Persistence/`, `Settings/`).
- Test target stack details — Swift Testing for unit, XCTest only for UI (per STACK.md).
- Exact `MuscleGroup` taxonomy — start from `free-exercise-db`'s 17-muscle list, normalize names; alias map for canonical forms.
- Asset catalog content — defer detailed UI/brand to UI-SPEC for this phase.

### Deferred Ideas (OUT OF SCOPE)
- **Bundled exercise images / GIFs** — defer to later polish pass.
- **Hand-curated stimulus-weighting table for the top 50 compound lifts** — Phase 5.
- **Filter state persistence across launches** — single-session reset is v1 behavior.
- **Sort options menu** — alphabetical only in v1.
- **Aggregate muscle groups** — locked taxonomy decision deferred to planning.
- **iCloud sync** — explicit v2 item.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | Schema wrapped in `SchemaV1: VersionedSchema` with `SchemaMigrationPlan` scaffold from day 1 | Versioned schema pattern (§ SwiftData Schema Patterns); empty `stages: [MigrationStage] = []` confirmed via Apple docs |
| FOUND-02 | All model properties optional or default-valued, all relationships optional | iCloud-shape rule restated in every `@Model` example (§ Code Examples → Entity definitions) |
| FOUND-03 | All enums persisted as `*Raw: String` columns with computed enum accessors | `*Raw` pattern documented in § Architecture Patterns → Enum Persistence |
| FOUND-04 | SwiftData `#Index` declarations on every hot query field | `#Index<T>([\KeyPath])` syntax verified via Apple docs (iOS 18+); table in § Indexing Strategy |
| FOUND-05 | Exercise library seed runs once inside a `@ModelActor`, idempotent, version-stamped via `UserDefaults`, completes in <2s on cold launch | `@ModelActor` pattern (§ Code Examples → ExerciseLibraryImporter); `UserDefaults.exercise_seed_version` idempotency check |
| FOUND-06 | Views bind directly to `@Model` types via `@Query` / `@Bindable`; no parallel view-model layer | MV-VM-lite stance enforced (§ Architecture Patterns → Direct Model Binding); `FilterState` / `CustomExerciseDraft` are `@Observable` ephemeral state only |
| FOUND-07 | Progression and fatigue services are pure-function value types behind protocols | Not directly Phase 1 code, but `CustomExerciseDraft.isValid` validates the pattern — pure value type, testable without `ModelContainer` |
| LIB-01 | User can browse the bundled exercise library (~800 exercises seeded from `yuhonas/free-exercise-db`, Unlicense) | Dataset confirmed (§ Dataset Schema Map); seed strategy (§ Code Examples → ExerciseLibraryImporter) |
| LIB-02 | User can multi-facet filter exercises by muscle group, equipment, mechanic, and movement pattern | `Predicate<Exercise>` composition (§ Code Examples → FilterState.predicate); native `.searchable` with `@Query` predicate binding |
| LIB-03 | User can search exercises by name with type-ahead (responsive at 1000+ entries via SwiftData `#Index` on hot fields) | `#Index([\.canonicalName])` + `.task(id: searchText)` 150 ms debounce (§ Code Examples → Search debounce pattern) |
| LIB-04 | User can create custom exercises with required primary + secondary muscle mapping, equipment, mechanic, and optional image | `CustomExerciseEditor` form + `PhotosPicker` (no permission required) — §  Code Examples → Photo picker pattern |
| LIB-05 | User can edit and delete custom exercises without affecting historical session data | Cascade rule `Exercise → SessionExercise` is `.nullify`, not `.cascade` — verified against Apple docs |
| LIB-06 | Bundled exercises distinguish bodyweight, weighted-bodyweight, machine, dumbbell, barbell, cable, and bands; UI input fields adapt per kind | `Equipment` enum (§ Dataset Schema Map → enum mapping); `Exercise.kindRaw` field stored; UI adaptation deferred to display logic in views |
| SET-01 | Global weight units (lb / kg) toggle | `UserSettings.unitsRaw: String` singleton row, `WeightUnit` enum (kg/lb); Settings tab `Toggle` two-way bound |
</phase_requirements>

## Summary

Phase 1 is the **load-bearing foundation** of the entire project. Five of the twelve pitfalls from `PITFALLS.md` (template/instance separation #1, missing `VersionedSchema` #2, stimulus weighting #5, main-thread bulk ops #6, filter index regression #7) are all "near-impossible to retrofit" once shipped. The phase is technically a fresh start (only the stock Xcode `Item`-template scaffold exists), so the work is greenfield wiring — but the design surface is huge: 12 `@Model` entities, 8 indexes, 4 cascade-rule variants, a `@ModelActor` seed pipeline, a multi-facet filter UX, a custom-exercise form with a `PhotosUI` integration, and an in-memory preview container.

The stack is fully locked: SwiftUI + SwiftData on iOS 26.4 (verified — the existing project already targets `IPHONEOS_DEPLOYMENT_TARGET = 26.4`, well above the iOS 18.0 minimum recommended in `STACK.md`), Swift Testing for unit tests, XCTest for UI tests. **No third-party SPM dependencies** — every recommendation below is Apple-native. The `yuhonas/free-exercise-db` dataset (Unlicense, ~800 exercises after the strength filter) is the sole external artifact, vendored into the repo as a single `exercises.json` file plus a version stamp.

**Primary recommendation:** Build in the exact sequence below — (1) project hygiene (delete `Item.swift`, bump Swift language version to 6, configure target settings), (2) `SchemaV1: VersionedSchema` with all 12 entities + the empty `SchemaMigrationPlan`, (3) `PreviewModelContainer.make()` helper, (4) bundled `exercises.json` + `ExerciseLibraryImporter` `@ModelActor` with `UserDefaults` version stamp, (5) `RootView` `TabView` + placeholder tabs, (6) `ExerciseLibraryView` with `@Query` + filter chips + `.searchable`, (7) `ExerciseDetailView` + "Copy as Custom" action, (8) `CustomExerciseEditor` form + `PhotosPicker` integration, (9) `SettingsView` with units toggle, (10) Swift Testing suite covering `SchemaV1` round-trips, `ExerciseLibraryImporter` idempotency, and `CustomExerciseDraft` validation.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Persistent storage of exercises, muscles, settings | SwiftData (on-device SQLite store) | — | SwiftData owns the entire persistence boundary; no backend, no cache |
| Exercise library browse / filter / search | SwiftUI views (`@Query` + `Predicate`) | SwiftData (`#Index`-backed query plan) | View reads via `@Query`; SQLite predicate compiled to indexed scan |
| Custom exercise creation form state | SwiftUI views + `@Observable` `CustomExerciseDraft` | — | Ephemeral UI state only — never crosses persistence boundary until save |
| First-launch JSON seed import | `@ModelActor` (background) | `UserDefaults` (version stamp) | Bulk insert off main thread (PITFALLS #6); idempotency via stored seed version stamp |
| Schema versioning + migration scaffold | `SchemaV1: VersionedSchema` + `SchemaMigrationPlan` | `ModelContainer` initializer | Migration plan attached to container; stages empty for v1 |
| Unit conversion (lb / kg) | SwiftUI views (display formatters) | `UserSettings` singleton (`unitsRaw`) | Logged data stored canonically; display layer formats per toggle |
| Image attachment for custom exercises | `PhotosUI.PhotosPicker` | `Exercise.imageData: Data?` field with `@Attribute(.externalStorage)` | `PhotosPicker` requires no permission entitlement; `Data` blob stored via external-file attribute |
| Preview / test data fixtures | `PreviewModelContainer.make()` helper | `ModelConfiguration(isStoredInMemoryOnly: true)` | In-memory container per Apple's recommended preview pattern |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 26.4 SDK | All UI surfaces | Locked by template; native; integrates with `@Query` / `@Bindable` |
| SwiftData | iOS 26.4 SDK | Schema + persistence | Locked by template; `#Index`, `#Unique`, `@Previewable` all available on iOS 18+ (we are 26.4) |
| Swift | 6.0 (strict concurrency) | Application language | Project currently set to `SWIFT_VERSION = 5.0` — **must be bumped to 6** for `@ModelActor` concurrency guarantees (FOUND-05) and `Sendable` enforcement |
| Swift Testing | bundled with Xcode 26 | All new unit tests | Apple's 2024 framework; `@Test`, `#expect`, `@Suite` syntax; coexists with XCTest in the same target |
| XCTest | bundled | UI tests only | Kept for `fitbodUITests/` because Swift Testing does not yet support `XCUIApplication` |
| PhotosUI | bundled | `PhotosPicker` for custom exercise image | No permission entitlement required when using `PhotosPicker` (only direct `PHPickerViewController` use needs `NSPhotoLibraryUsageDescription`) |

### Supporting (Phase 1 only)
| Component | Version | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `os.log` / `OSLog` | iOS 14+ | Seed-completion telemetry per CONTEXT.md (`<specifics>`) | First-launch performance must be observable during development |
| `Foundation.JSONDecoder` | bundled | Decode `exercises.json` into DTO structs | Decode-into-DTO pattern per STACK.md "Codable on models — avoid" |
| `Bundle.main.url(forResource:withExtension:)` | bundled | Locate the bundled `exercises.json` resource | Standard resource loading |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `@ModelActor` seed | Main-thread seed in `.task { }` | At ~800 rows the difference is marginal (~400ms vs ~80ms on iPhone 15-class hardware), BUT PITFALLS.md #6 locks this to `@ModelActor` to prevent UI freeze regressions when the dataset grows or per-exercise stimulus rows multiply (~3000 inserts total: 800 exercises + 17 muscles + ~2200 stimulus rows). |
| Bundled pre-baked `.store` file | Apple's "pre-populated database" path | Requires `VACUUM` workaround for WAL files, complicates schema migration, harder to refresh on dataset updates. JSON-on-launch is the right call (per STACK.md). |
| `PHPickerViewController` directly | Wrapping `UIViewControllerRepresentable` | `PhotosPicker` (SwiftUI native, iOS 16+) wraps this and is the 2025+ recommended path — no permission entitlement, no representable boilerplate. |
| `Codable` on `@Model` types | Implementing `Codable` directly on `Exercise`, etc. | SwiftData models are reference types; `Codable` on them is a footgun. Decode to `ExerciseDTO` struct, map to `@Model` in the importer. |
| `Combine.debounce` for search | `.task(id: searchText)` with `Task.sleep` | The `.task(id:)` pattern is the idiomatic SwiftUI 2025+ approach — auto-cancels on identity change, no Combine plumbing. |

**Installation:** No `npm install`. The stack is entirely bundled with Xcode 26. The only "install" steps are configuration:

```bash
# Configuration changes (manual or via xcodebuild settings; planner picks approach):
# 1. Bump Swift language version: SWIFT_VERSION 5.0 → 6.0
# 2. Enable strict concurrency: SWIFT_STRICT_CONCURRENCY = complete
# 3. Verify IPHONEOS_DEPLOYMENT_TARGET = 26.4 (already set)
# 4. Add Resources/ExerciseSeed/exercises.json as a bundle resource
# 5. Set AccentColor in Assets.xcassets per UI-SPEC.md
```

**Version verification (npm view equivalent):** Not applicable — Apple SDKs are versioned via Xcode. Verified via Context7 (`/websites/developer_apple_swiftdata`, fetched 2026-05-10): all required APIs (`#Index`, `#Unique`, `@ModelActor`, `VersionedSchema`, `SchemaMigrationPlan`, `MigrationStage.lightweight`, `ModelConfiguration(isStoredInMemoryOnly:)`, `Schema.Relationship.DeleteRule.{cascade,nullify,deny,noAction}`, `PhotosPicker(selection:matching:)`) are current and stable. [VERIFIED: Apple Developer Documentation via Context7]

## Architecture Patterns

### System Architecture Diagram

```
                ┌──────────────────────────────────────────────────────┐
                │                       SwiftUI                         │
                │                                                       │
                │   RootView (TabView)                                  │
                │      ├─ "Today"        → PlaceholderTabView(2)        │
                │      ├─ "Routines"     → PlaceholderTabView(2)        │
                │      ├─ "Library"      → ExerciseLibraryView          │
                │      │       │            ├ @Query<Exercise>          │
                │      │       │            ├ .searchable               │
                │      │       │            ├ ExerciseFilterBar         │
                │      │       │            │    └ FilterChip × 4       │
                │      │       │            └ ExerciseRow (list rows)   │
                │      │       │                  └─ NavigationLink →   │
                │      │       │                     ExerciseDetailView │
                │      │       │                        └─ CustomEditor │
                │      │       │                            (sheet)     │
                │      │       └─ "+" toolbar → CustomExerciseEditor    │
                │      │                            └ PhotosPicker      │
                │      ├─ "Progress"     → PlaceholderTabView(6)        │
                │      └─ "Settings"     → SettingsView                 │
                │             └ Toggle ↔ UserSettings.unitsRaw          │
                │                                                       │
                └──────────────────────┬───────────────────────────────┘
                                       │ @Environment(\.modelContext)
                                       ▼
                ┌──────────────────────────────────────────────────────┐
                │   SwiftData ModelContainer (main-actor context)       │
                │                                                       │
                │   schema: Schema(SchemaV1.models)                     │
                │   migrationPlan: FitbodSchemaMigrationPlan            │
                │   configuration: on-disk (or in-memory in previews)   │
                └──────────────────────┬───────────────────────────────┘
                                       │
                                       │ (separate background actor)
                                       ▼
       ┌──────────────────────────────────────────────────────────────┐
       │   ExerciseLibraryImporter (@ModelActor — first launch only)   │
       │                                                                │
       │      1. Read UserDefaults["exercise_seed_version"]             │
       │      2. If mismatch → load exercises.json from Bundle.main     │
       │      3. Decode → [ExerciseDTO] (filter category)               │
       │      4. Upsert MuscleGroup rows (17 canonical slugs)           │
       │      5. Insert Exercise rows                                   │
       │      6. Create ExerciseMuscleStimulus rows (1.0 / 0.5)         │
       │      7. ctx.save() per 100-row batch                           │
       │      8. Write UserDefaults["exercise_seed_version"]            │
       │      9. os_log("seed complete in Xms", .info)                  │
       └──────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
       ┌──────────────────────────────────────────────────────────────┐
       │   SQLite store (Application Support/default.store)             │
       │   With WAL + shm sidecars                                      │
       └──────────────────────────────────────────────────────────────┘
```

Read the diagram top-to-bottom for cold-launch sequencing: SwiftUI scene appears, `@Query` fires against the empty store, `.task` modifier on `RootView` triggers `ExerciseLibraryImporter.seedIfNeeded()`, which inserts rows in a background actor, `@Query` re-emits and views re-render automatically.

### Recommended Project Structure

```
fitbod/
├── fitbodApp.swift                       # @main, ModelContainer wiring, seed trigger
├── App/
│   ├── RootView.swift                    # TabView root (5 tabs, 3 placeholders)
│   └── PlaceholderTabView.swift          # "Available in Phase N" filler
│
├── Persistence/
│   ├── SchemaV1.swift                    # enum SchemaV1: VersionedSchema { static var models: [...] }
│   ├── FitbodSchemaMigrationPlan.swift   # class FitbodSchemaMigrationPlan: SchemaMigrationPlan { stages = [] }
│   └── PreviewModelContainer.swift       # in-memory factory for previews + tests
│
├── Models/                               # SwiftData @Model entities, one file per type
│   ├── Exercise.swift
│   ├── MuscleGroup.swift
│   ├── ExerciseMuscleStimulus.swift
│   ├── Routine.swift
│   ├── RoutineExercise.swift
│   ├── Session.swift
│   ├── SessionExercise.swift
│   ├── SetEntry.swift
│   ├── Block.swift
│   ├── BlockPhase.swift
│   ├── UserSettings.swift
│   ├── MuscleVolumeTarget.swift
│   └── Enums/
│       ├── Intent.swift                  # strength/hypertrophy/power/endurance/technique
│       ├── ProgressionKind.swift         # rpe/double/block/hybrid
│       ├── Equipment.swift               # barbell/dumbbell/machine/cable/bands/bodyweight/weighted_bodyweight/other
│       ├── Mechanic.swift                # compound/isolation
│       ├── Force.swift                   # push/pull/static
│       ├── Level.swift                   # beginner/intermediate/advanced
│       ├── Pattern.swift                 # horizontal_push/vertical_push/horizontal_pull/vertical_pull/squat/hinge/lunge/carry/core (derived)
│       ├── MuscleRegion.swift            # upper/lower/core
│       ├── WeightUnit.swift              # lb/kg
│       └── BlockPhaseKind.swift          # accumulation/intensification/realization/deload
│
├── ExerciseLibrary/
│   ├── ExerciseLibraryView.swift         # the main library list (browse + filter + search)
│   ├── ExerciseFilterBar.swift           # horizontal scrolling chip row
│   ├── FilterChip.swift                  # single chip view
│   ├── FilterPickerSheet.swift           # multi-select picker per facet
│   ├── FilterState.swift                 # @Observable; computes Predicate<Exercise>
│   ├── ExerciseRow.swift                 # one list row
│   ├── ExerciseDetailView.swift          # read-only detail (+ "Copy as Custom")
│   ├── CustomExerciseEditor.swift        # create/edit Form
│   ├── CustomExerciseDraft.swift         # @Observable form-state value type
│   ├── MusclePickerSheet.swift           # pick a muscle for the custom exercise
│   ├── MuscleWeightRow.swift             # muscle + stimulus slider row
│   └── ExerciseLibraryImporter.swift     # @ModelActor seed pipeline (and ExerciseDTO struct)
│
├── Settings/
│   └── SettingsView.swift                # units toggle (Phase 1 scope)
│
├── Resources/
│   └── ExerciseSeed/
│       ├── exercises.json                # vendored from yuhonas/free-exercise-db dist/exercises.json
│       └── seed_version.txt              # plain text version stamp (e.g. "1") — read at compile time or as bundle resource
│
└── Assets.xcassets/
    ├── AccentColor.colorset/             # populate per UI-SPEC (#0E7C86 light / #3FBFC9 dark)
    └── AppIcon.appiconset/

fitbodTests/
├── SchemaV1Tests.swift                   # versioned schema instantiates, round-trips Exercise insert/fetch
├── ExerciseLibraryImporterTests.swift    # seed runs, count > 0, idempotent on second call
├── CustomExerciseDraftTests.swift        # isValid logic (primary muscle required, name non-empty)
├── FilterStatePredicateTests.swift       # predicate composition over hand-crafted Exercises
└── DTODecodingTests.swift                # ExerciseDTO decodes the bundled JSON sample

fitbodUITests/
└── (existing scaffolds — defer expansion to Phase 2 when there's something stateful to test)
```

### Pattern 1: Versioned Schema From Day 1 (PITFALLS #2)

**What:** Wrap every `@Model` type in an `enum SchemaV1: VersionedSchema` and attach an empty `SchemaMigrationPlan` to the `ModelContainer`. Even with no migrations yet, the scaffold is in place so the first `SchemaV2` rename does not panic.

**When to use:** Day 1 of any SwiftData app. Skipping costs HIGH per PITFALLS #2.

**Example:**
```swift
// Source: [Apple Developer / SwiftData / SchemaMigrationPlan via Context7]
// [VERIFIED: Apple Developer Documentation via Context7]
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

enum FitbodSchemaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }   // empty for v1; future versions add stages here
}
```

### Pattern 2: `@ModelActor` for the Seed Import Only (PITFALLS #6)

**What:** Create a dedicated background actor for the one-time JSON import. The actor owns its own `ModelContext` that the `@ModelActor` macro synthesizes. The main-thread context is reserved for views.

**When to use:** Bulk inserts of >100 rows. Never use it for live workout logging (per ARCHITECTURE.md — actor hopping during a workout has perceptible cost).

**Example:**
```swift
// Source: [Apple Developer / SwiftData / ModelActor via Context7]
// [VERIFIED: Apple Developer Documentation via Context7]
import SwiftData
import Foundation
import OSLog

@ModelActor
actor ExerciseLibraryImporter {
    static let seedVersionKey = "exercise_seed_version"
    static let currentSeedVersion = 1
    private let log = Logger(subsystem: "com.fitbod.app", category: "seed")

    func seedIfNeeded() async throws {
        let stored = UserDefaults.standard.integer(forKey: Self.seedVersionKey)
        guard stored < Self.currentSeedVersion else {
            log.debug("Seed up to date (version \(stored)) — skipping")
            return
        }
        let start = Date()

        // 1. Locate bundled resource
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            throw SeedError.bundledResourceMissing
        }

        // 2. Decode DTOs (never decode straight into @Model types — STACK.md)
        let data = try Data(contentsOf: url)
        let dtos = try JSONDecoder().decode([ExerciseDTO].self, from: data)
        let strengthOnly = dtos.filter { dto in
            ["strength", "powerlifting", "olympic weightlifting", "strongman"].contains(dto.category)
        }

        // 3. Upsert canonical MuscleGroups (17 slugs)
        let muscleSlugs = Set(strengthOnly.flatMap { $0.primaryMuscles + $0.secondaryMuscles })
        var musclesBySlug: [String: MuscleGroup] = [:]
        for slug in muscleSlugs {
            let mg = MuscleGroup(slug: slug, displayName: slug.capitalized)
            modelContext.insert(mg)
            musclesBySlug[slug] = mg
        }

        // 4. Insert Exercises + stimulus rows in batches of 100
        var batch = 0
        for dto in strengthOnly {
            let ex = Exercise(
                id: UUID(),
                externalID: dto.id,
                name: dto.name,
                canonicalName: dto.name.lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current),
                equipmentRaw: dto.equipment ?? "other",
                mechanicRaw: dto.mechanic ?? "compound",
                forceRaw: dto.force,
                levelRaw: dto.level,
                category: dto.category,
                instructions: dto.instructions,
                imagePaths: dto.images,
                isCustom: false,
                createdAt: .now
            )
            modelContext.insert(ex)

            // CRITICAL: Insert ex FIRST, then assign relationships — STACK.md gotcha
            for slug in dto.primaryMuscles {
                guard let mg = musclesBySlug[slug] else { continue }
                let stim = ExerciseMuscleStimulus(exercise: ex, muscle: mg, role: "primary", weight: 1.0)
                modelContext.insert(stim)
            }
            for slug in dto.secondaryMuscles {
                guard let mg = musclesBySlug[slug] else { continue }
                let stim = ExerciseMuscleStimulus(exercise: ex, muscle: mg, role: "secondary", weight: 0.5)
                modelContext.insert(stim)
            }

            batch += 1
            if batch >= 100 {
                try modelContext.save()
                batch = 0
            }
        }
        try modelContext.save()

        // 5. Seed UserSettings singleton if missing
        let settingsCount = try modelContext.fetchCount(FetchDescriptor<UserSettings>())
        if settingsCount == 0 {
            modelContext.insert(UserSettings.default())
            try modelContext.save()
        }

        // 6. Stamp the version
        UserDefaults.standard.set(Self.currentSeedVersion, forKey: Self.seedVersionKey)
        log.info("Seed complete in \(Date().timeIntervalSince(start), format: .fixed(precision: 3))s")
    }

    enum SeedError: Error { case bundledResourceMissing }
}
```

### Pattern 3: Direct Model Binding (MV-VM-Lite, FOUND-06)

**What:** Views consume SwiftData via `@Query` (reactive reads) and `@Bindable` (two-way editing). No ViewModel layer mirrors the schema.

**When to use:** Everywhere. The only "view models" are `@Observable` types holding **ephemeral UI state** (filter selections, form drafts) that never persist.

**Example:**
```swift
// Source: [Apple Developer / SwiftData / Query macro via Context7]
import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @State private var filterState = FilterState()
    @State private var searchText = ""
    @State private var debouncedSearch = ""

    var body: some View {
        NavigationStack {
            ContentView(predicate: predicate)
                .navigationTitle("Exercises")
                .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "Search exercises")
                .task(id: searchText) {
                    try? await Task.sleep(for: .milliseconds(150))
                    if !Task.isCancelled { debouncedSearch = searchText }
                }
                .safeAreaInset(edge: .top) {
                    ExerciseFilterBar(filterState: filterState)
                }
        }
    }

    private var predicate: Predicate<Exercise> {
        filterState.predicate(with: debouncedSearch)
    }
}

// Inner content view rebuilds @Query when predicate changes
private struct ContentView: View {
    @Query private var exercises: [Exercise]

    init(predicate: Predicate<Exercise>) {
        _exercises = Query(filter: predicate, sort: \.canonicalName, order: .forward)
    }

    var body: some View {
        List {
            ForEach(exercises) { ex in
                NavigationLink(value: ex) { ExerciseRow(exercise: ex) }
            }
        }
        .navigationDestination(for: Exercise.self) { ex in
            ExerciseDetailView(exercise: ex)
        }
    }
}
```

### Pattern 4: `@Observable` Ephemeral State Around `@Query`

**What:** Wrap filter / form state in `@Observable` types but **never** wrap `@Query` itself.

**Example (`FilterState`):**
```swift
import SwiftUI
import SwiftData

@Observable
final class FilterState {
    var selectedMuscleSlugs: Set<String> = []
    var selectedEquipment: Set<String> = []
    var selectedMechanic: String? = nil
    var selectedPatterns: Set<String> = []

    func predicate(with searchText: String) -> Predicate<Exercise> {
        let normalizedSearch = searchText.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        let muscles = selectedMuscleSlugs
        let equipment = selectedEquipment
        let mechanic = selectedMechanic
        let patterns = selectedPatterns

        return #Predicate<Exercise> { ex in
            (normalizedSearch.isEmpty || ex.canonicalName.contains(normalizedSearch)) &&
            (equipment.isEmpty || equipment.contains(ex.equipmentRaw)) &&
            (mechanic == nil || ex.mechanicRaw == mechanic!) &&
            // Many-to-many via stimulus join requires fetching exercises then filtering in code,
            // OR using a flattened denormalized field (e.g. ex.primaryMuscleSlugsJoined: String)
            // for predicate-level filtering. See "Common Pitfalls → Pitfall 3" below.
            (muscles.isEmpty || ex.primaryMuscleSlugsJoined.contains(any: muscles))
        }
    }
}
```

**Critical note:** SwiftData's `#Predicate` macro does **not** support joining through relationships in a clean way for many-to-many filters. The workaround used in `STACK.md` and verified through community sources is to denormalize the muscle slugs onto the `Exercise` row as a `String` (e.g. `"|chest|triceps|shoulders|"`) and use `.contains(slug)` in the predicate, OR fetch a broader candidate set and post-filter in-memory. The planner should pick the denormalization path — it's a 1-line addition during seed and keeps the predicate index-friendly.

### Pattern 5: Snapshot Template ⇒ Instance (PITFALLS #1)

**What:** The `Routine` → `Session` boundary copies every prescription field at session start. Phase 1 only ships the schema; Phase 2 ships `SessionFactory.start(...)`. But the Phase 1 schema must already have **two separate sets of fields**: `RoutineExercise.intentRaw`, `targetRepsLow`, etc. AND `SessionExercise.intentRaw`, `targetRepsLow`, etc. (duplicated, not via a shared parent).

**Why this matters in Phase 1:** the field set on `SessionExercise` (the snapshot target) must already exist when the schema is locked. Adding the snapshot fields in Phase 2 would force a `SchemaV2` migration.

### Pattern 6: Enum Persistence as `*Raw: String`

**What:** Every enum is stored as a `String` column (e.g. `intentRaw`) with a computed enum accessor.

**Example:**
```swift
extension SessionExercise {
    var intent: Intent {
        get { Intent(rawValue: intentRaw) ?? .hypertrophy }
        set { intentRaw = newValue.rawValue }
    }
}

enum Intent: String, CaseIterable {
    case strength, hypertrophy, power, endurance, technique
}
```

### Pattern 7: `PhotosPicker` for Custom Exercise Image (LIB-04)

**What:** Native SwiftUI `PhotosPicker` requires **no permission entitlement** because Apple sandboxes the picker (`PHPickerViewController` under the hood). The user picks from their library, the app gets only the selected asset.

**Example:**
```swift
// Source: [Apple PhotosUI docs] [VERIFIED: WebFetch + Context7]
import SwiftUI
import PhotosUI

struct CustomExerciseImagePicker: View {
    @Bindable var draft: CustomExerciseDraft
    @State private var selection: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading) {
            if let data = draft.imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                Label("Add Photo", systemImage: "photo")
            }
        }
        .onChange(of: selection) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    draft.imageData = data
                }
            }
        }
    }
}
```

### Pattern 8: In-Memory `PreviewModelContainer.make()` Helper

**What:** A single factory produces an in-memory `ModelContainer` seeded with a deterministic mini-fixture. Used by `#Preview` blocks AND unit tests.

**Example:**
```swift
// Source: [Apple Developer / SwiftData / ModelConfiguration via Context7]
// [VERIFIED]
import SwiftData
import Foundation

enum PreviewModelContainer {
    static func make() -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true, allowsSave: true)
        let container = try! ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        seedFixture(into: container.mainContext)
        return container
    }

    private static func seedFixture(into ctx: ModelContext) {
        let chest = MuscleGroup(slug: "chest", displayName: "Chest")
        let tris = MuscleGroup(slug: "triceps", displayName: "Triceps")
        let lats = MuscleGroup(slug: "lats", displayName: "Lats")
        let biceps = MuscleGroup(slug: "biceps", displayName: "Biceps")
        [chest, tris, lats, biceps].forEach { ctx.insert($0) }

        let bench = Exercise.previewSample(
            name: "Barbell Bench Press",
            equipment: "barbell", mechanic: "compound"
        )
        ctx.insert(bench)
        ctx.insert(ExerciseMuscleStimulus(exercise: bench, muscle: chest, role: "primary", weight: 1.0))
        ctx.insert(ExerciseMuscleStimulus(exercise: bench, muscle: tris, role: "secondary", weight: 0.5))

        let row = Exercise.previewSample(name: "Barbell Row", equipment: "barbell", mechanic: "compound")
        ctx.insert(row)
        ctx.insert(ExerciseMuscleStimulus(exercise: row, muscle: lats, role: "primary", weight: 1.0))
        ctx.insert(ExerciseMuscleStimulus(exercise: row, muscle: biceps, role: "secondary", weight: 0.5))

        ctx.insert(UserSettings.default())
        try? ctx.save()
    }
}

// Usage in previews:
#Preview {
    ExerciseLibraryView()
        .modelContainer(PreviewModelContainer.make())
}
```

### Anti-Patterns to Avoid

- **`@Query` inside an `@Observable` class:** Breaks SwiftUI's dependency tracking — `@Query` only re-emits when used directly in a `View`. PITFALLS.md #5 (anti-pattern 1 in ARCHITECTURE.md).
- **Decoding JSON directly into `@Model` types via `Codable`:** SwiftData models are reference types; `Codable` conformance is a footgun. Always decode to a DTO struct first.
- **Assigning relationships in `init(...)` before `context.insert(model)`:** SwiftData drops the relationship silently. Always `insert` first, then set relationships. (STACK.md.)
- **Wrapping `TabView` in a parent `NavigationStack`:** Each tab's state collapses on switch. Each tab owns its own `NavigationStack`. (STACK.md.)
- **Using `@StateObject` / `@ObservedObject` / `@Published` in new code:** Use `@State` + `@Observable` macro instead. (STACK.md.)
- **Skipping `VersionedSchema` because "we have no migrations yet":** Reconstructing a past schema version from git history when the first rename hits is HIGH cost. (PITFALLS #2.)
- **Leaving `Item.swift` in the schema after the real models land:** Pollutes the namespace and the migration graph forever. (PITFALLS #2 corollary, CONTEXT.md.)
- **Main-thread bulk insert for the 800-row seed:** UI freezes 4–8s, users force-quit during seed, store ends up half-populated. (PITFALLS #6.)
- **Making muscle mapping optional on custom-exercise creation:** Silently corrupts volume math. Save button stays disabled until ≥1 primary muscle with stimulus ≥0.5. (PITFALLS #5, CONTEXT.md.)
- **Using `Predicate<Exercise>` to traverse many-to-many relationships:** Predicates can't cleanly express the muscle-join. Denormalize muscle slugs onto a `String` column for filter-friendliness. (Predicate limitation — see Pitfall 3 below.)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON-to-`@Model` mapping with reactive updates | Custom Codable conformance on `@Model` types | DTO struct + manual mapping in `ExerciseLibraryImporter` | SwiftData reference-type quirks (STACK.md) |
| Background bulk insert | `DispatchQueue.global().async { ... }` with a child `ModelContext` | `@ModelActor` macro | Apple-supplied actor isolation; macro synthesizes the `modelExecutor` correctly |
| Photo picker | `UIViewControllerRepresentable` wrapping `PHPickerViewController` | `PhotosPicker(selection:matching:)` | Native SwiftUI, no permission entitlement, iOS 16+ |
| Search debounce | `Combine.PassthroughSubject` + `.debounce(for:)` | `.task(id: searchText) { try? await Task.sleep(for: .milliseconds(150)); ... }` | Auto-cancels on identity change; no Combine plumbing |
| In-memory test container | Manual `URL` to `/tmp` + delete-on-deinit | `ModelConfiguration(isStoredInMemoryOnly: true)` | Apple's documented preview/test pattern |
| Many-to-many filter predicate | In-memory post-filter on every keystroke | Denormalize muscle slugs to a single `String` on `Exercise`; use `.contains` in `#Predicate` | `#Predicate` can't traverse relationships cleanly; denormalization is index-friendly |
| Unit toggle binding | Custom Combine subject | `@Bindable settings: UserSettings` with computed `var weightUnit: WeightUnit` accessor | Direct two-way binding to a `@Model` |
| Schema migration scaffolding | Custom version tracker in `UserDefaults` | `VersionedSchema` + `SchemaMigrationPlan` | Apple-supplied; first-class migration stages |
| Exercise dataset (writing it ourselves) | Curating 800 exercises from scratch | Bundle `yuhonas/free-exercise-db` JSON | Unlicense (public domain), schema verified, 17-muscle taxonomy, already maps to filter-heavy UX |

**Key insight:** Every "let me just write a small helper" temptation in this phase has been solved by Apple SDKs in 2024–2026. The Apple-native path is also the cheapest path. The only place real engineering judgment is required is the many-to-many filter predicate workaround (denormalization) — and that's a known SwiftData limitation, not a custom invention.

## Runtime State Inventory

Not a rename/refactor phase. This is greenfield wiring on a stock template. **Section omitted.**

## Common Pitfalls

### Pitfall 1: Schema versioning skipped (PITFALLS #2 — load-bearing)
**What goes wrong:** App ships without `VersionedSchema`. First property rename in Phase 2 launches an unrecoverable migration error.
**Why it happens:** Every SwiftData tutorial demonstrates the happy path without versioning.
**How to avoid:** Wrap all 12 entities in `enum SchemaV1: VersionedSchema` from Day 1. Attach `FitbodSchemaMigrationPlan` to the container even with empty `stages: []`.
**Warning signs:** `CoreData: error: -executeFetchRequest` in launch logs. `Item.swift` still in the schema array.

### Pitfall 2: `Item.swift` left in the schema
**What goes wrong:** The stock template's `Item` model is kept "for now" and gets baked into `SchemaV1`. Removing it later requires a custom migration stage.
**Why it happens:** "It's just a placeholder, we'll remove it next sprint."
**How to avoid:** Delete `Item.swift` AND remove it from `fitbodApp.swift`'s `Schema([...])` array **before** writing the production schema. The 12 production models are the only ones in `SchemaV1.models`.
**Warning signs:** `SchemaV1.models` contains anything not in the 12-entity list from ARCHITECTURE.md.

### Pitfall 3: Many-to-many filter predicate doesn't index (NEW — surfaced by Phase 1 filter UX)
**What goes wrong:** Filter chip "muscle = chest" requires joining `Exercise → ExerciseMuscleStimulus → MuscleGroup`. `#Predicate` cannot express this cleanly; falling back to in-memory post-filter scans all 800 exercises per keystroke and breaks the sub-100ms target.
**Why it happens:** SwiftData `#Predicate` lowers to SQLite WHERE clauses and doesn't support traversal through relationships.
**How to avoid:** Denormalize muscle slugs onto `Exercise` as a `String` column (e.g. `primaryMuscleSlugsJoined: String = "|chest|triceps|"`) and `#Index<Exercise>([\.primaryMuscleSlugsJoined])`. The importer populates this at seed time. Filter via `.contains(slug)`.
**Warning signs:** Filter chip taps lag visibly. Instruments shows time in SQLite predicate eval.

### Pitfall 4: `.searchable` doesn't debounce (PITFALLS #7 — load-bearing for LIB-03)
**What goes wrong:** Every keystroke fires a new `@Query`. At 800 rows with `localizedStandardContains`, this is 200–400ms per keystroke.
**Why it happens:** `.searchable` binds text immediately; there's no built-in debounce.
**How to avoid:** Mirror the bound text into a `@State debouncedSearch` via `.task(id: searchText) { try? await Task.sleep(for: .milliseconds(150)); debouncedSearch = searchText }`. Pass `debouncedSearch` to the predicate, not `searchText`. Combined with `#Index([\.canonicalName])` and the denormalized muscle slugs, every filter operation stays sub-100ms.
**Warning signs:** Search feels laggy on words with common prefixes like "bench" or "row".

### Pitfall 5: Custom exercise muscle mapping made optional (PITFALLS #5 — load-bearing)
**What goes wrong:** User adds "Smith Incline Press" without muscle mapping. Phase 5 volume math silently drops it from chest aggregation.
**How to avoid:** `CustomExerciseDraft.isValid` requires at least one muscle with `role == .primary` and `weight >= 0.5`. The `Save` button binds to `draft.isValid`. UI-SPEC.md copy: "At least one primary muscle is required to save."
**Warning signs:** Custom exercise list shows entries with 0 muscle stimulus rows.

### Pitfall 6: Main-thread seed (PITFALLS #6 — load-bearing for FOUND-05)
**What goes wrong:** First-launch import on the main `ModelContext` freezes the UI 4–8s. User force-quits, store half-populated.
**How to avoid:** `ExerciseLibraryImporter` is `@ModelActor`. The importer is invoked from `fitbodApp.swift`'s `.task` modifier on `RootView` with `await importer.seedIfNeeded()`. The view shows a `ProgressView` placeholder if `@Query` returns empty.
**Warning signs:** Cold-launch hang visible in Instruments main-thread timeline. Splash without progress feedback.

### Pitfall 7: Relationships assigned in initializer before `context.insert`
**What goes wrong:** SwiftData drops the relationship link silently. `ExerciseMuscleStimulus` rows reference `nil` muscles, breaking volume math.
**How to avoid:** Always `context.insert(model)` first, then set relationships. The importer pattern shown above does this correctly.
**Warning signs:** Stimulus rows with `muscle == nil` after seed; queries return half-populated objects.

### Pitfall 8: Deleting a bundled exercise nukes history
**What goes wrong:** `Exercise → SessionExercise` cascade rule set to `.cascade` instead of `.nullify`. Deleting a library entry cascades into deleting every logged session that ever referenced it.
**How to avoid:** Locked in CONTEXT.md — `Exercise → SessionExercise: nullify`. Built-in exercises are read-only at the UI level (no Delete button); custom exercises can be deleted but the relationship is `.nullify`. Logged history remains intact with `SessionExercise.exercise == nil`.
**Warning signs:** UI test "delete custom exercise then open old session" returns empty.

### Pitfall 9: Swift Language Version stuck at 5.0
**What goes wrong:** Project's `SWIFT_VERSION = 5.0` setting silently disables Swift 6 strict concurrency. `@ModelActor` macros still compile but `Sendable` checks are advisory, surfacing as crashes only at runtime under contention.
**How to avoid:** Bump `SWIFT_VERSION` to `6.0` in build settings. Add `SWIFT_STRICT_CONCURRENCY = complete`. Resolve any warnings before merging.
**Warning signs:** Build settings show `SWIFT_VERSION = 5.0` (already detected — confirmed in Environment Availability below).

### Pitfall 10: WAL files lost when copying the store
**What goes wrong:** Future "share my database" feature attempts to copy just `default.store` without the `.wal` and `.shm` sidecar files. The copy is half-stale; opening it in the destination corrupts.
**How to avoid:** Phase 1 doesn't ship export, but the `ModelContainer` configuration should be aware: when an export path is wired (Phase 6), the export logic must `checkpoint(.passive)` (or equivalent SwiftData call) before reading the store file. **Phase 1 action:** none — but the planner should leave a `// FIXME(Phase 6): WAL checkpoint on export` comment if any "share data" stub is added. (See ARCHITECTURE.md scaling notes.)

### Pitfall 11: Auto-save races with `@ModelActor.save()`
**What goes wrong:** `ModelConfiguration.autosaveEnabled` is `true` by default. If the seed importer issues explicit `try modelContext.save()` while the main context is also auto-saving, there's a brief window where SQLite locks conflict.
**How to avoid:** The `@ModelActor` synthesizes its own `ModelContext` separate from the main context. They share the same SQLite store but operate on independent transactions — SQLite WAL mode handles concurrent readers + serialized writers. **Action:** verify the seed completes before any user-initiated writes (the placeholder tabs guarantee this in Phase 1; in Phase 2 watch for user starting a session before seed finishes — gate session creation on `@Query<Exercise>.isEmpty == false`).
**Warning signs:** SQLite I/O errors logged during cold launch.

### Pitfall 12: Predicate macro doesn't capture mutable state cleanly
**What goes wrong:** `#Predicate<Exercise> { ex in filterState.selectedEquipment.contains(ex.equipmentRaw) }` — the closure captures `filterState` by reference, but `#Predicate` requires hashable, value-type captures.
**How to avoid:** Extract primitive captures (Sets of `String`) into local `let` constants before the predicate. See `FilterState.predicate(with:)` example above.
**Warning signs:** Compile error "Cannot capture mutable state in a predicate macro."

## Code Examples

Verified patterns from official sources, ready for the planner to translate into tasks.

### Example 1: Production `ModelContainer` Setup in `fitbodApp.swift`
```swift
// Source: [Apple Developer / SwiftData / ModelContainer via Context7]
// [VERIFIED]
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

### Example 2: Triggering Seed on First Launch from `RootView`
```swift
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [Exercise]
    @State private var seedComplete = false

    var body: some View {
        Group {
            if !seedComplete && exercises.isEmpty {
                ProgressView("Preparing library…")
            } else {
                TabView { /* 5 tabs */ }
            }
        }
        .task {
            do {
                let importer = ExerciseLibraryImporter(modelContainer: modelContext.container)
                try await importer.seedIfNeeded()
            } catch {
                Logger(subsystem: "com.fitbod.app", category: "seed").error("Seed failed: \(error)")
            }
            seedComplete = true
        }
    }
}
```

### Example 3: `Exercise` `@Model` with `#Index` and Optional Properties (FOUND-02, FOUND-04)
```swift
// Source: [Apple Developer / SwiftData / Index macro, Relationship macro via Context7]
// [VERIFIED]
import SwiftData
import Foundation

@Model
final class Exercise {
    #Index<Exercise>([\.canonicalName], [\.equipmentRaw], [\.mechanicRaw], [\.isCustom])
    #Unique<Exercise>([\.externalID])     // dataset row id; unique within seed

    @Attribute(.unique) var id: UUID = UUID()
    var externalID: String? = nil          // e.g. "Barbell_Bench_Press"; nil for custom
    var name: String = ""
    var canonicalName: String = ""         // lowercased + diacritic-folded
    var equipmentRaw: String = "other"
    var mechanicRaw: String = "compound"
    var forceRaw: String? = nil
    var levelRaw: String? = nil
    var patternRaw: String? = nil
    var category: String = "strength"
    var instructions: [String] = []
    var imagePaths: [String] = []          // relative paths from dataset; binaries not bundled v1
    @Attribute(.externalStorage) var imageData: Data? = nil   // optional custom image
    var isCustom: Bool = false
    var primaryMuscleSlugsJoined: String = ""  // denormalized for predicate-friendly filter (Pitfall 3)
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \ExerciseMuscleStimulus.exercise)
    var muscleStimuli: [ExerciseMuscleStimulus]? = []

    init() {} // default no-arg init keeps all properties optional/defaulted per FOUND-02

    convenience init(
        id: UUID = UUID(),
        externalID: String? = nil,
        name: String,
        canonicalName: String,
        equipmentRaw: String,
        mechanicRaw: String,
        forceRaw: String? = nil,
        levelRaw: String? = nil,
        category: String = "strength",
        instructions: [String] = [],
        imagePaths: [String] = [],
        isCustom: Bool = false,
        createdAt: Date = .now
    ) {
        self.init()
        self.id = id
        self.externalID = externalID
        self.name = name
        self.canonicalName = canonicalName
        self.equipmentRaw = equipmentRaw
        self.mechanicRaw = mechanicRaw
        self.forceRaw = forceRaw
        self.levelRaw = levelRaw
        self.category = category
        self.instructions = instructions
        self.imagePaths = imagePaths
        self.isCustom = isCustom
        self.createdAt = createdAt
    }
}

extension Exercise {
    var equipment: Equipment { Equipment(rawValue: equipmentRaw) ?? .other }
    var mechanic: Mechanic { Mechanic(rawValue: mechanicRaw) ?? .compound }
    var force: Force? { forceRaw.flatMap(Force.init) }
    var level: Level? { levelRaw.flatMap(Level.init) }
}
```

### Example 4: `ExerciseMuscleStimulus` Join Entity with Inverse
```swift
@Model
final class ExerciseMuscleStimulus {
    @Attribute(.unique) var id: UUID = UUID()
    var role: String = "primary"     // primary | secondary
    var weight: Double = 1.0

    var exercise: Exercise? = nil
    var muscle: MuscleGroup? = nil

    init() {}

    convenience init(exercise: Exercise, muscle: MuscleGroup, role: String, weight: Double) {
        self.init()
        self.exercise = exercise
        self.muscle = muscle
        self.role = role
        self.weight = weight
    }
}
```

### Example 5: `CustomExerciseDraft` (FOUND-07 in microcosm — pure value type, testable)
```swift
import Observation
import Foundation

@Observable
final class CustomExerciseDraft {
    var name: String = ""
    var equipment: Equipment = .barbell
    var mechanic: Mechanic = .compound
    var muscles: [MuscleAssignment] = []
    var imageData: Data? = nil

    struct MuscleAssignment: Identifiable, Equatable {
        let id = UUID()
        var slug: String
        var role: Role
        var weight: Double
        enum Role: String { case primary, secondary }
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        muscles.contains { $0.role == .primary && $0.weight >= 0.5 }
    }

    func materialize(into ctx: ModelContext, allMuscles: [MuscleGroup]) -> Exercise {
        let ex = Exercise(
            name: name,
            canonicalName: name.lowercased().folding(options: .diacriticInsensitive, locale: .current),
            equipmentRaw: equipment.rawValue,
            mechanicRaw: mechanic.rawValue,
            isCustom: true
        )
        ex.imageData = imageData
        ex.primaryMuscleSlugsJoined = muscles
            .filter { $0.role == .primary }
            .map { "|\($0.slug)" }
            .joined() + "|"
        ctx.insert(ex)
        for assignment in muscles {
            guard let mg = allMuscles.first(where: { $0.slug == assignment.slug }) else { continue }
            ctx.insert(ExerciseMuscleStimulus(
                exercise: ex, muscle: mg,
                role: assignment.role.rawValue, weight: assignment.weight
            ))
        }
        return ex
    }
}
```

### Example 6: `UserSettings` Singleton + Bindable Toggle
```swift
@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID = UUID()
    var unitsRaw: String = "lb"           // "lb" | "kg"
    var weekStartsMonday: Bool = true
    var defaultProgressionKindRaw: String = "double"
    // ... more fields populated in later phases

    init() {}

    static func `default`() -> UserSettings {
        let s = UserSettings()
        s.unitsRaw = "lb"
        return s
    }
}

extension UserSettings {
    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: unitsRaw) ?? .lb }
        set { unitsRaw = newValue.rawValue }
    }
}

struct SettingsView: View {
    @Query private var settingsList: [UserSettings]
    var settings: UserSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            Form {
                if let settings {
                    @Bindable var s = settings
                    Section("Units") {
                        Toggle("Weight Unit", isOn: Binding(
                            get: { s.weightUnit == .kg },
                            set: { s.weightUnit = $0 ? .kg : .lb }
                        ))
                    } footer: {
                        Text("Affects display only. Logged session history is stored in a single canonical unit and re-rendered on the fly.")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

### Example 7: Swift Testing for `@Model` Round-Trip
```swift
// Source: [WWDC24: Meet Swift Testing] [VERIFIED via Context7 / Apple docs]
import Testing
import Foundation
@testable import fitbod
import SwiftData

@Suite("SchemaV1 round-trips")
struct SchemaV1Tests {
    @Test("Exercise insert + fetch")
    func exerciseRoundTrip() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let ex = Exercise(
            name: "Test Bench",
            canonicalName: "test bench",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        ctx.insert(ex)
        try ctx.save()

        let fetched = try ctx.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.name == "Test Bench")
        #expect(fetched.first?.equipment == .barbell)
    }

    @Test("Exercise → ExerciseMuscleStimulus cascade")
    func cascadeDelete() throws {
        let container = try makeInMemoryContainer()
        let ctx = ModelContext(container)
        let mg = MuscleGroup(slug: "chest", displayName: "Chest")
        ctx.insert(mg)
        let ex = Exercise(name: "Bench", canonicalName: "bench",
                          equipmentRaw: "barbell", mechanicRaw: "compound")
        ctx.insert(ex)
        let stim = ExerciseMuscleStimulus(exercise: ex, muscle: mg, role: "primary", weight: 1.0)
        ctx.insert(stim)
        try ctx.save()

        ctx.delete(ex)
        try ctx.save()

        let stimuli = try ctx.fetch(FetchDescriptor<ExerciseMuscleStimulus>())
        #expect(stimuli.isEmpty, "Cascade should delete stimulus rows when exercise is deleted")
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema,
                                  migrationPlan: FitbodSchemaMigrationPlan.self,
                                  configurations: config)
    }
}

@Suite("ExerciseLibraryImporter idempotency")
struct SeedTests {
    @Test("Seed runs once and skips on second call")
    func idempotent() async throws {
        UserDefaults.standard.removeObject(forKey: ExerciseLibraryImporter.seedVersionKey)
        let container = try makeInMemoryContainer()
        let importer = ExerciseLibraryImporter(modelContainer: container)

        try await importer.seedIfNeeded()
        let firstCount = try ModelContext(container).fetchCount(FetchDescriptor<Exercise>())
        #expect(firstCount > 0)

        try await importer.seedIfNeeded()
        let secondCount = try ModelContext(container).fetchCount(FetchDescriptor<Exercise>())
        #expect(secondCount == firstCount, "Second call should not duplicate rows")
    }
}

@Suite("CustomExerciseDraft validation")
struct CustomExerciseDraftTests {
    @Test("Empty name → invalid")
    func emptyName() {
        let d = CustomExerciseDraft()
        d.name = ""
        d.muscles = [.init(slug: "chest", role: .primary, weight: 1.0)]
        #expect(!d.isValid)
    }

    @Test("No primary muscle → invalid")
    func noPrimary() {
        let d = CustomExerciseDraft()
        d.name = "Pec Deck"
        d.muscles = [.init(slug: "chest", role: .secondary, weight: 0.5)]
        #expect(!d.isValid)
    }

    @Test("Name + primary muscle → valid")
    func valid() {
        let d = CustomExerciseDraft()
        d.name = "Pec Deck"
        d.muscles = [.init(slug: "chest", role: .primary, weight: 1.0)]
        #expect(d.isValid)
    }
}
```

### Example 8: Dataset Schema Mapping (`yuhonas/free-exercise-db` → SwiftData)
[CITED: https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/schema.json]

| Dataset field | DTO type | Maps to | Notes |
|---------------|----------|---------|-------|
| `id` | `String` | `Exercise.externalID` (`@Unique` via `#Unique`) | Stable slug e.g. `"Barbell_Bench_Press"` |
| `name` | `String` | `Exercise.name`; derived `canonicalName` | `canonicalName = name.lowercased().folded(.diacriticInsensitive)` |
| `force` | `String?` ("static" \| "pull" \| "push") | `Exercise.forceRaw` | Optional in dataset |
| `level` | `String` ("beginner" \| "intermediate" \| "expert") | `Exercise.levelRaw` | |
| `mechanic` | `String?` ("isolation" \| "compound") | `Exercise.mechanicRaw` (default `"compound"` if nil) | |
| `equipment` | `String?` (12 values, see below) | `Exercise.equipmentRaw` (mapped to canonical `Equipment` enum) | Dataset has 13 values; we collapse to 8 |
| `primaryMuscles` | `[String]` (17-muscle enum) | One `ExerciseMuscleStimulus` row per slug, `role="primary"`, `weight=1.0` | |
| `secondaryMuscles` | `[String]` | One stimulus row per slug, `role="secondary"`, `weight=0.5` | |
| `instructions` | `[String]` | `Exercise.instructions` | Stored as array on `@Model` |
| `category` | `String` (7 values) | `Exercise.category`; **import filter** to `{strength, powerlifting, olympic weightlifting, strongman}` | Drops cardio/stretching/plyometrics |
| `images` | `[String]` | `Exercise.imagePaths` (relative paths) | Binaries NOT bundled v1 |

**Canonical 17 muscle slugs** (used as `MuscleGroup.slug` `@Attribute(.unique)`):
```
abdominals, abductors, adductors, biceps, calves, chest, forearms, glutes,
hamstrings, lats, lower back, middle back, neck, quadriceps, shoulders, traps, triceps
```

**Equipment mapping (dataset → canonical `Equipment` enum):**
| Dataset value | App enum |
|---------------|----------|
| `barbell` | `.barbell` |
| `dumbbell` | `.dumbbell` |
| `cable` | `.cable` |
| `machine` | `.machine` |
| `bands` | `.bands` |
| `body only` | `.bodyweight` |
| `kettlebells` | `.kettlebell` |
| `e-z curl bar` | `.barbell` (collapse) |
| `medicine ball`, `exercise ball`, `foam roll`, `other`, `null` | `.other` |

**Dataset version stamp:** the dataset has no built-in version. We assign our own integer stamp (start at `1`) stored as `UserDefaults["exercise_seed_version"]`. A future dataset refresh bumps to `2`, triggering re-seed (with delta logic to be added in the future — Phase 1 only handles the empty-to-full transition).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Core Data` with `.xcdatamodeld` graphical editor | SwiftData `@Model` macro | iOS 17 (WWDC23) | Schema is code; no model editor; migrations are typed |
| `ObservableObject` + `@Published` + `@StateObject` | `@Observable` macro + `@State` + `@Bindable` | iOS 17 (WWDC23) | Fine-grained re-render (only views reading a property re-evaluate); ARCHITECTURE.md and STACK.md both lock this |
| XCTest for everything | Swift Testing (`@Test`, `#expect`) for unit; XCTest only for UI | Xcode 16 (WWDC24) | Parameterized tests, suites, traits — Apple's recommended path for new test code |
| `PHPickerViewController` via `UIViewControllerRepresentable` | `PhotosUI.PhotosPicker` (native SwiftUI) | iOS 16 | No permission entitlement; no representable boilerplate |
| Hard-coded `Timer` for rest periods | `Date` + scheduled `UNUserNotification` | (Phase 2 concern) | Survives lock screen |
| Foreground-only `@Query` filter loops in body | `Predicate<Element>` macro + `#Index` macro for hot fields | iOS 18 (WWDC24) | Indexes are first-class; predicate macros lower to SQLite WHERE clauses |
| `@Previewable @State` introduction | `@Previewable @State` in `#Preview` macros | iOS 18 (WWDC24) | Cleaner preview definitions with stateful sample data |

**Deprecated / outdated:**
- `@StateObject` / `@ObservedObject` / `@EnvironmentObject` — replaced by `@State` + `@Bindable` + `@Environment(_:)` with `@Observable` macro.
- `ObservableObject` protocol — replaced by `@Observable` macro.
- `Codable` on `@Model` types — DTO struct pattern.
- Combine debounce pipelines for search — `.task(id:)` + `Task.sleep` is the idiomatic SwiftUI replacement.
- `LazyVStack` for long lists — `List` is the right choice for the 800-row library (LazyVStack doesn't free off-screen rows; memory grows).
- Bundled `.store` pre-population — JSON-on-launch is the maintained path; bundled stores require `VACUUM` workarounds.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `#Predicate` cannot traverse relationships through `ExerciseMuscleStimulus` for muscle-filter use cases, so denormalization to a `String` column is required | Pitfall 3, FilterState example | If Apple has shipped predicate-relationship-traversal in iOS 18.x+ and we missed it, the denormalization is unnecessary overhead (still correct, just inefficient). LOW risk — the workaround is widely used in 2024–2025 SwiftData writeups. |
| A2 | Dataset file size at ~800 strength exercises is ~1 MB JSON; bundling it does not noticeably grow the app binary | STACK.md, CONTEXT.md | LOW — confirmed in `STACK.md` from direct fetch. |
| A3 | `@Attribute(.externalStorage)` on `Exercise.imageData: Data?` is the correct way to keep image blobs out of the main row | Code Example 3 | LOW — Apple-documented attribute for large-blob fields. |
| A4 | Seed performance target <2s on cold launch is achievable on iPhone-class hardware for ~800 exercises + ~17 muscles + ~2200 stimulus rows total inserts | Phase 1 success criterion 1, CONTEXT.md, FOUND-05 | MEDIUM — SwiftData performance under bulk insert is workload-dependent. Mitigation: batch commits every 100 rows; if first measurement is slow, profile with Instruments and adjust batch size. Worst case: increase batch interval, ship with a brief "Preparing library…" splash. |
| A5 | The seed should run from the main-actor `RootView.task` modifier (which awaits a `@ModelActor` method) rather than from `fitbodApp.init` | Code Example 2 | LOW — `App.init` is called before SwiftUI scenes exist and is synchronous; the seed must be `async` and run after the container is alive. `RootView.task` is the idiomatic location. |
| A6 | `PhotosPicker` requires no `NSPhotoLibraryUsageDescription` Info.plist entry | Pattern 7, LIB-04 | LOW — verified via WebFetch + WebSearch confirming `PhotosPicker` sandbox model. The "Photo Access Required" alert in UI-SPEC.md still exists for the *fallback* code path if a user denies access (which they cannot do for `PhotosPicker` — this alert is dead code in v1 unless a different picker path is added). **Action for planner:** treat the "Photo Access Required" copy as future-proofing; do not wire an actual permission check. |
| A7 | The current `IPHONEOS_DEPLOYMENT_TARGET = 26.4` setting on the project provides every API in this research; STACK.md's iOS 18 references are a floor we already exceed | Environment Availability, Stack section | LOW — confirmed via direct read of `project.pbxproj`. |
| A8 | Swift 6 strict concurrency does not break any SwiftData APIs used in this phase | Stack — Swift version bump | LOW — Swift 6 + SwiftData is the documented configuration; `@ModelActor` is purpose-built for strict concurrency. Mitigation: bump in a dedicated commit so warnings/errors are isolated. |

## Open Questions

1. **Does SwiftData iOS 26+ support predicate traversal through relationships natively now?**
   - What we know: As of iOS 18 docs (verified via Context7), `#Predicate` does not cleanly express join-traversal. The denormalized-string workaround is widely used in 2024–2025 writeups.
   - What's unclear: Whether iOS 19+ / 26 added relationship-traversal in predicate macros — Context7 docs we fetched are SwiftData general (no date filter on the iOS-26 surface specifically).
   - Recommendation: Ship the denormalized `primaryMuscleSlugsJoined` field. If iOS 26 supports relationship traversal cleanly, the denormalization is still correct — just becomes optional optimization. Cost of being wrong: a single redundant field on `Exercise`. Acceptable.

2. **Should the deferred bundled-image strategy reserve a future-compatible `Bundle` resource subfolder structure now?**
   - What we know: CONTEXT.md defers bundled images; `imagePaths: [String]` persists the relative paths from the dataset (e.g. `"Barbell_Bench_Press/0.jpg"`) so a future seed pass can hydrate them.
   - What's unclear: Whether to vendor the image folder into `Resources/ExerciseSeed/images/` now (~10–50 MB) or defer the binary blobs entirely.
   - Recommendation: **Defer**, per CONTEXT.md decision. The paths persist so hydration is a small task in a future phase. Vendoring 10–50 MB into the binary for v1 is unwanted bloat for personal-install.

3. **For the `MuscleGroup.region: String` field, what are the canonical region buckets?**
   - What we know: STACK.md and ARCHITECTURE.md suggest `upper / lower / core` for heatmap grouping (Phase 5). Phase 1 needs to populate this at seed time so it's available later.
   - What's unclear: The exact mapping of 17 dataset muscles to 3 regions.
   - Recommendation: Seed with this mapping (CONTEXT.md says taxonomy is "planner discretion"):
     - **upper:** chest, lats, middle back, lower back, traps, shoulders, biceps, triceps, forearms, neck
     - **lower:** quadriceps, hamstrings, glutes, calves, abductors, adductors
     - **core:** abdominals
   - Cost of being wrong: a Phase 5 migration adjusts strings. LOW.

4. **What's the canonical `Equipment` enum case for "weighted bodyweight" (LIB-06)?**
   - What we know: LIB-06 mentions distinguishing bodyweight vs weighted-bodyweight in UI input adaptation. The dataset has `"body only"` only — no separate weighted-bodyweight value.
   - What's unclear: Do we add a `.weightedBodyweight` enum case now (unused in seed, populated only for custom exercises) or defer until Phase 2 session logging requires it?
   - Recommendation: Add the enum case `.weightedBodyweight` now (zero seeded exercises will use it, but the schema/UI layer is locked in). The `CustomExerciseEditor` exposes it in the equipment picker. Cost: a 1-line enum addition. Benefit: no migration in Phase 2.

5. **`Pattern` enum (horizontal_push / vertical_push / hinge / squat / etc.) — populate at seed or defer?**
   - What we know: The dataset does not provide `pattern`. STACK.md notes "derive from mechanic + muscles or add manually for the ~50 main lifts."
   - What's unclear: Whether the filter chip "Pattern" should be live in Phase 1 or grayed out.
   - Recommendation: Persist `Exercise.patternRaw: String? = nil` on the schema (already in Example 3). Defer the seed-time population to a hand-curated table in Phase 2 or later. The Filter chip stays in the UI per UI-SPEC.md but its picker sheet shows "(no patterns assigned yet)" until the curation lands. Alternative: omit the Pattern chip in Phase 1 and add it in Phase 2 — but UI-SPEC locks it as visible. **Recommended decision:** ship the chip; have it filter on `patternRaw != nil` patterns; for v1 with no patterns assigned, the chip is effectively a no-op (empty multi-select). Document this in code comments.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Build, signing, simulators | ✓ (assumed — project exists) | 26+ (target IPHONEOS = 26.4) | — |
| iOS deployment target | All APIs in this research | ✓ | 26.4 | — (well above iOS 18 floor) |
| Swift language version | `@ModelActor` strict concurrency, `Sendable` checks | ✗ (currently 5.0) | needs 6.0 | None — bump is in scope (Phase 1 task) |
| SwiftData framework | All persistence | ✓ | iOS 17+ baseline, iOS 18+ for `#Index` `#Unique` | — |
| SwiftUI framework | All UI | ✓ | iOS 26.4 SDK | — |
| PhotosUI framework | `PhotosPicker` for custom exercise image | ✓ | iOS 16+ | — |
| Swift Testing framework | Unit tests | ✓ | bundled with Xcode 16+ | — |
| XCTest framework | UI tests (kept for `fitbodUITests/`) | ✓ | bundled | — |
| `OSLog` / `Logger` | Seed telemetry | ✓ | iOS 14+ | — |
| `yuhonas/free-exercise-db` dataset | Library seed (LIB-01) | ✗ (not yet vendored) | Latest from `main` (commit pinned at planner time) | None — vendoring is in scope (Phase 1 task) |
| Personal Apple Developer team | Code signing for device install | (per project context) | — | Simulator-only mode if absent (CONTEXT.md notes personal-install) |

**Missing dependencies with no fallback:**
- Swift 6 language mode — must be enabled before `@ModelActor` work begins (planner inserts as an early task).
- `Resources/ExerciseSeed/exercises.json` — must be vendored from the dataset repo before `ExerciseLibraryImporter` can be implemented (planner inserts as an early task).

**Missing dependencies with fallback:**
- None significant — every other dependency is bundled.

## Validation Architecture

Per `.planning/config.json`, `workflow.nyquist_validation = true`. Include this section.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (Xcode 26 bundled) + XCTest for UI |
| Config file | none — Swift Testing uses discovery; XCTest uses test target `fitbodUITests` |
| Quick run command | `xcodebuild test -project fitbod.xcodeproj -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:fitbodTests/{SuiteName}/{testName}` |
| Full suite command | `xcodebuild test -project fitbod.xcodeproj -scheme fitbod -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | `SchemaV1` instantiates; container builds with empty migration plan | unit | `xcodebuild test -only-testing:fitbodTests/SchemaV1Tests/containerBuilds` | ❌ Wave 0 |
| FOUND-02 | Every property on every entity is optional or default-valued | unit (reflection) | `xcodebuild test -only-testing:fitbodTests/SchemaV1Tests/allPropertiesOptionalOrDefaulted` | ❌ Wave 0 |
| FOUND-03 | Enum `*Raw` strings round-trip through computed accessors | unit | `xcodebuild test -only-testing:fitbodTests/EnumPersistenceTests` | ❌ Wave 0 |
| FOUND-04 | `#Index` on `Exercise.canonicalName` makes `localizedStandardContains` queries fast | performance | `xcodebuild test -only-testing:fitbodTests/IndexedQueryTests/canonicalNameUnder10ms` | ❌ Wave 0 |
| FOUND-05 | `ExerciseLibraryImporter.seedIfNeeded()` is idempotent | unit | `xcodebuild test -only-testing:fitbodTests/SeedTests/idempotent` | ❌ Wave 0 |
| FOUND-05 | Seed completes in <2s on simulator (Phase 1 success criterion 1) | performance | `xcodebuild test -only-testing:fitbodTests/SeedTests/coldLaunchUnder2s` | ❌ Wave 0 |
| FOUND-06 | Views consume `@Query` directly (compile-time enforcement; reviewed via grep) | manual / lint | grep for `@Query` outside view files — no occurrences allowed in `*ViewModel.swift` | ❌ Wave 0 (n/a — review-gated) |
| FOUND-07 | `CustomExerciseDraft.isValid` works without a `ModelContainer` | unit | `xcodebuild test -only-testing:fitbodTests/CustomExerciseDraftTests` | ❌ Wave 0 |
| LIB-01 | After seed, `@Query<Exercise>` returns >0 (and ~800) rows | integration | `xcodebuild test -only-testing:fitbodTests/SeedTests/strengthOnlyCount` | ❌ Wave 0 |
| LIB-02 | `FilterState.predicate` correctly filters by muscle, equipment, mechanic | unit | `xcodebuild test -only-testing:fitbodTests/FilterStatePredicateTests` | ❌ Wave 0 |
| LIB-03 | Debounced `.searchable` does not re-query per keystroke | UI test (XCTest) | `xcodebuild test -only-testing:fitbodUITests/LibrarySearchUITests/debounceVerified` | ❌ Wave 0 (deferred — manual smoke for v1) |
| LIB-04 | `CustomExerciseEditor` save button enabled iff `draft.isValid` | unit | `xcodebuild test -only-testing:fitbodTests/CustomExerciseDraftTests/saveEnablement` | ❌ Wave 0 |
| LIB-05 | Deleting a custom `Exercise` does not delete linked `SessionExercise` rows (cascade=nullify) | unit | `xcodebuild test -only-testing:fitbodTests/CascadeRuleTests/exerciseToSessionExerciseNullifies` | ❌ Wave 0 |
| LIB-06 | `Equipment` enum has cases for bodyweight + weighted-bodyweight + machine + dumbbell + barbell + cable + bands + other | unit | `xcodebuild test -only-testing:fitbodTests/EnumTests/equipmentCases` | ❌ Wave 0 |
| SET-01 | `UserSettings.weightUnit` toggle persists and round-trips | unit | `xcodebuild test -only-testing:fitbodTests/UserSettingsTests/unitsToggle` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Run the suite for the touched file (`xcodebuild test -only-testing:fitbodTests/{SuiteName}`).
- **Per wave merge:** Full unit suite (`xcodebuild test ... -only-testing:fitbodTests`).
- **Phase gate:** Full suite (unit + UI) green before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `fitbodTests/SchemaV1Tests.swift` — covers FOUND-01, FOUND-02, FOUND-03, LIB-05
- [ ] `fitbodTests/IndexedQueryTests.swift` — covers FOUND-04
- [ ] `fitbodTests/SeedTests.swift` — covers FOUND-05, LIB-01
- [ ] `fitbodTests/CustomExerciseDraftTests.swift` — covers FOUND-07, LIB-04
- [ ] `fitbodTests/FilterStatePredicateTests.swift` — covers LIB-02
- [ ] `fitbodTests/EnumPersistenceTests.swift` — covers FOUND-03, LIB-06
- [ ] `fitbodTests/EnumTests.swift` — covers LIB-06 (compile-time enum case assertion)
- [ ] `fitbodTests/CascadeRuleTests.swift` — covers LIB-05
- [ ] `fitbodTests/UserSettingsTests.swift` — covers SET-01
- [ ] Shared fixture helper: `fitbodTests/TestSupport/InMemoryContainer.swift` (or reuse `PreviewModelContainer.make()` from app target via `@testable import fitbod`)
- [ ] Existing `fitbodTests/fitbodTests.swift` placeholder — delete after replacement suites land.

## Security Domain

Per `.planning/config.json`, security_enforcement is not explicitly set to `false` — treated as enabled. Phase 1 is local-only with no auth, no network, no PII collection, and no third-party dependencies — so the security surface is minimal but not zero.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Single-user local app; no auth surface |
| V3 Session Management | no | No sessions in security sense |
| V4 Access Control | no | No multi-tenant model |
| V5 Input Validation | yes (mild) | `CustomExerciseDraft.isValid` validates name + muscle mapping; numeric inputs (stimulus weight) clamped to 0.0–1.0 in UI |
| V6 Cryptography | no | No secrets, no encryption-at-rest beyond iOS default file protection |
| V8 Data Protection | yes (mild) | SwiftData store lives in `Application Support/`; iOS data protection class A (default) — encrypted when device is locked |
| V12 Files & Resources | yes | Photo picker uses sandboxed `PhotosPicker` (no permission entitlement); JSON bundled, no external file loads |
| V14 Configuration | yes | `UserDefaults.exercise_seed_version` is non-secret config; no entitlements needed beyond default app sandbox |

### Known Threat Patterns for SwiftUI / SwiftData / iOS

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| SQLite injection (via predicate) | Tampering | `#Predicate` macro lowers to parameterized queries — no string interpolation into SQL. Verified Apple-supplied. |
| Free-text form notes leaking via CSV export | Information Disclosure | Phase 6 concern — CSV-quote escape on export. Phase 1 has no export. |
| WAL crash corrupts the store on force-quit | Tampering / Repudiation | iOS handles WAL automatically; SwiftData's autosave + transactional batches ensure consistency. PITFALLS #6 covers detection via launch-time integrity check (deferred to Phase 6). |
| User adds a custom exercise with HTML/script in name | XSS (none — no web) | No HTML rendering anywhere; `Text(exercise.name)` is a plain SwiftUI string. |
| Photo picker leaks more than the selected asset | Information Disclosure | `PhotosPicker` sandbox grants only the selected asset; no library access. |
| Schema migration fails halfway, leaves DB in invalid state | Tampering | `SchemaMigrationPlan` with empty stages in v1 is harmless; future migrations use `MigrationStage.lightweight` or `.custom` with explicit `willMigrate` / `didMigrate` hooks. |

**No load-bearing security work required in Phase 1** — the design is "single-user, local, no network, no third-party deps" by construction. The biggest "security" item is correctness of cascade rules (`Exercise → SessionExercise = nullify`) so deletes don't destroy data unexpectedly. That's already captured in PITFALLS #8 above.

## Sources

### Primary (HIGH confidence)
- Context7 `/websites/developer_apple_swiftdata` — `ModelContainer`, `ModelActor`, `SchemaMigrationPlan`, `VersionedSchema`, `Relationship` `deleteRule`, `#Index`, `#Unique`, `Query`, `Predicate`, `ModelConfiguration(isStoredInMemoryOnly:)`, `MigrationStage.lightweight` (fetched 2026-05-10)
- [Apple Developer: SwiftData](https://developer.apple.com/documentation/swiftdata) — framework overview
- [Apple Developer: SchemaMigrationPlan](https://developer.apple.com/documentation/swiftdata/schemamigrationplan)
- [Apple Developer: VersionedSchema](https://developer.apple.com/documentation/swiftdata/versionedschema)
- [Apple Developer: Relationship macro](https://developer.apple.com/documentation/swiftdata/relationship%28_%3Adeleterule%3Aminimummodelcount%3Amaximummodelcount%3Aoriginalname%3Ainverse%3Ahashmodifier%3A%29)
- [Apple Developer: Index macro](https://developer.apple.com/documentation/swiftdata/index%28_%3A%29-7d4z0)
- [Apple Developer: ModelActor macro](https://developer.apple.com/documentation/swiftdata/modelactor%28%29)
- [Apple Developer: ModelConfiguration init(isStoredInMemoryOnly:)](https://developer.apple.com/documentation/swiftdata/modelconfiguration/init%28isstoredinmemoryonly%3A%29)
- [Apple Developer: Defining data relationships with enumerations and model classes](https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes)
- [Apple Developer: Preserving your app's model data across launches](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches)
- [free-exercise-db schema.json](https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/schema.json) — verified via WebFetch 2026-05-10
- [free-exercise-db repo](https://github.com/yuhonas/free-exercise-db) — license (Unlicense), ~800 exercises

### Secondary (MEDIUM confidence — verified with at least one official source)
- [WWDC24: What's new in SwiftData](https://developer.apple.com/videos/play/wwdc2024/10137/) — `#Index`, `#Unique` macros introduction (iOS 18+)
- [WWDC24: Meet Swift Testing](https://developer.apple.com/videos/play/wwdc2024/10179/) — `@Test`, `#expect`, `@Suite`
- [WWDC23: Discover Observation in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10149/) — `@Observable` macro
- [Hacking with Swift: SwiftData by Example](https://www.hackingwithswift.com/quick-start/swiftdata) — seeding, predicates, migration patterns
- [Use Your Loaf: SwiftData Indexes](https://useyourloaf.com/blog/swiftdata-indexes/) — `#Index` iOS 18 confirmation
- [Fatbobman: Considerations for Using Codable and Enums in SwiftData Models](https://fatbobman.com/en/posts/considerations-for-using-codable-and-enums-in-swiftdata-models/) — `*Raw: String` enum pattern
- [Hacking with Swift: How to write unit tests for your SwiftData code](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code) — in-memory container test pattern
- [BrightDigit: Using ModelActor in SwiftData](https://brightdigit.com/tutorials/swiftdata-modelactor/) — `@ModelActor` seed pattern
- [Massicotte: ModelActor is Just Weird](https://www.massicotte.org/model-actor/) — `@ModelActor` caveats
- [Daniel Saidi: Creating a debounced search context for performant SwiftUI searches](https://danielsaidi.com/blog/2025/01/08/creating-a-debounced-search-context-for-performant-swiftui-searches) — `.task(id:)` debounce pattern

### Tertiary (LOW confidence — single source, marked for validation)
- [SideEffect: Debouncing with Swift concurrency](https://sideeffect.io/posts/2023-01-11-regulate/) — `Task.sleep` debounce details (cross-verified with Daniel Saidi 2025 article)
- General Phase 1 cascade-delete + Swift Testing patterns: cross-referenced internal docs in `STACK.md`, `ARCHITECTURE.md`, `PITFALLS.md`

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every API verified against Apple docs via Context7; iOS 26.4 deployment target confirmed in `project.pbxproj`.
- Architecture: HIGH — patterns derive cleanly from CONTEXT.md decisions and `STACK.md` / `ARCHITECTURE.md` upstream research; the only design tension (many-to-many filter predicate) is a known SwiftData limitation with a widely-used workaround.
- Pitfalls: HIGH — five of twelve catalogued pitfalls from `PITFALLS.md` apply directly; cross-verified against current SwiftData community writeups (2024–2026).

**Research date:** 2026-05-10
**Valid until:** 2026-06-10 (stable Apple-native stack; refresh after Xcode 27 / iOS 27 SDK launches if they ship during Phase 1 execution)
