# Conventions

## State & Reactivity

- Use `@Observable` + `@State`/`@Bindable`/`.environment(_:)` for all new code. Never use `ObservableObject`, `@Published`, `@StateObject`, or `@ObservedObject` — they are legacy property wrappers.
- `@Query` lives directly in views with predicates and sort descriptors. Never wrap `@Query` in a view model — SwiftUI dependency tracking breaks.
- View models are `@Observable` classes owned by their view with `@State`, holding only non-persistent UI state.
- Cross-view ephemeral state (e.g., current active session) passes via `.environment(_:)` on an `@Observable` object.
- Never rewrite a text field's text while it is being typed in, such as from an `onChange` that sets the text it observes: a digit typed just after the rewrite can show in the field and never reach its text. Format the text once editing ends, as the time fields do (RM-062).

## Navigation

- One `NavigationStack` per tab. Never wrap `TabView` in a parent `NavigationStack` — tab state collapses on switch.
- Use typed navigation paths (`NavigationPath` per tab, or a custom enum-based `Path`).
- Tap-to-pop-to-root: clear the tab's `NavigationPath` when the tab is re-tapped.
- Exercise library search: the list's `@Query` fetches every exercise; apply facets in memory through `applyPostFetchFilters(to:)`, then search what is left with `ExerciseSearch`, which matches word prefixes across name, family, aliases, brand and equipment and ranks the results. `applyPostFetchFilters(to:)` also drops the rows curation hides, so every list of exercises goes through it. Keep facets and search out of `#Predicate`: the guarded multi-facet shape fails to type-check or translate, and a predicate cannot rank.

## What Not to Use

- No `Core Data` directly — SwiftData is the supported API and already chosen.
  The one exception is `FitbodModelContainer`, which asks Core Data, read-only, why a store did not open, because SwiftData does not say.
- No `Realm`, `GRDB`, or `SQLite.swift` — redundant against SwiftData for v1 workload.
- No `DGCharts` or the legacy `Charts` SPM name — use Swift Charts.
- No `RxSwift` / `ReactiveSwift` / Combine-only architectures — `@Observable` + `AsyncSequence` covers the ground natively.
- No `CloudKit` / iCloud sync in v1 — scope and future work live in [the roadmap](docs/ROADMAP.md#rm-042).
- No `HealthKit` or `WeightTrainingWorkout` — out of scope, defer to v2+.
- No MVVM view models that wrap `@Query` — they break reactivity.

## Testing

- Effort/completion policy: [DEVELOPMENT.md](docs/DEVELOPMENT.md); build/runner commands: [SETUP.md](docs/SETUP.md). The agent runs routine checks and records results in the owning roadmap entry; personal sign-off is not a routine gate.
- Unit tests: Swift Testing (`@Test`, `#expect`) in `fitbodTests/`.
- UI tests: XCTest with `XCUIApplication` in `fitbodUITests/`. Swift Testing does not support UI automation — this is an Apple-confirmed gap.
- SwiftData model tests: Swift Testing with in-memory `ModelContainer` in `fitbodTests/`.
- Persistence/recovery tests use a disk store and relaunch when stored behavior changes. Calculation logic needs unit coverage; changed routes/interactions use affected UI checks. Broader accessibility/layout checks return at workflow stability, the full matrix at release.

## SwiftData Patterns

- Don't assign relationships in initializers — insert into context first, then set relationships.
- `@Attribute(.unique)` on `Exercise.externalID` prevents duplicate seeds.
- Use `#Index` on hot query paths, such as `Session.startedAt` and `Exercise.canonicalName`.
- `SchemaV7` is the sole baseline, with no historical migration chain; build containers through `FitbodModelContainer`.
- No `Codable` on `@Model` types — decode into DTO structs, map to `@Model` types explicitly.
- Cascade rules: Session→SessionExercise→SetEntry cascade; historical references nullify. Delete exercises through `ExerciseDeletion.delete` so history/template links are explicitly cleared first. See [architecture](ARCHITECTURE.md#deletion-and-ordering) for slot and block rules.

## Charting

- Swift Charts for all data charts. `Canvas` + custom SVG-derived paths for the muscle heatmap body silhouette — that is custom UI, not a chart.
