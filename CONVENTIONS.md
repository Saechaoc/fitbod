# Conventions

## State & Reactivity

- Use `@Observable` + `@State`/`@Bindable`/`.environment(_:)` for all new code. Never use `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject` — they are legacy property wrappers.
- `@Query` lives directly in views with predicates and sort descriptors. Never wrap `@Query` in a view model — SwiftUI dependency tracking breaks.
- View models are `@Observable` classes owned by their view with `@State`, holding only non-persistent UI state.
- Cross-view ephemeral state (e.g., current active session) passes via `.environment(_:)` on an `@Observable` object.

## Navigation

- One `NavigationStack` per tab. Never wrap `TabView` in a parent `NavigationStack` — tab state collapses on switch.
- Use typed navigation paths (`NavigationPath` per tab, or a custom enum-based `Path`).
- Tap-to-pop-to-root: clear the tab's `NavigationPath` when the tab is re-tapped.
- Exercise library search: `.searchable(text:)` with a `Predicate<Exercise>` driving `@Query`. Compose filters in the predicate, not in memory.

## What Not to Use

- No `Core Data` directly — SwiftData is the supported API and already chosen.
- No `Realm`, `GRDB`, or `SQLite.swift` — redundant against SwiftData for v1 workload.
- No `DGCharts` or the legacy `Charts` SPM name — use Swift Charts.
- No `RxSwift` / `ReactiveSwift` / Combine-only architectures — `@Observable` + `AsyncSequence` covers the ground natively.
- No `CloudKit` / iCloud sync — local-only per PROJECT.md. SwiftData+CloudKit forces every property optional, a real architectural cost.
- No `HealthKit` or `WeightTrainingWorkout` — out of scope, defer to v2+.
- No MVVM view models that wrap `@Query` — they break reactivity.

## Testing

- Unit tests: Swift Testing (`@Test`, `#expect`) in `fitbodTests/`.
- UI tests: XCTest with `XCUIApplication` in `fitbodUITests/`. Swift Testing does not support UI automation — this is an Apple-confirmed gap.
- SwiftData model tests: Swift Testing with in-memory `ModelContainer` in `fitbodTests/`.

## SwiftData Patterns

- Don't assign relationships in initializers — insert into context first, then set relationships.
- `@Attribute(.unique)` on `Exercise.externalID` prevents duplicate seeds.
- `#Index` (iOS 18) on hot query paths: `Session.date`, `Exercise.name`.
- Versioned schemas from day one: wrap initial schema in `VersionedSchema` + `SchemaMigrationPlan`.
- No `Codable` on `@Model` types — decode into DTO structs, map to `@Model` types explicitly.
- Cascade rules: Session→SessionExercise→SetLog cascade; Exercise→everything else nullify (use `isArchived` for soft-delete).

## Charting

- Swift Charts for all data charts. `Canvas` + custom SVG-derived paths for the muscle heatmap body silhouette — that is custom UI, not a chart.
