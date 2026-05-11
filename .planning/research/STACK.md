# Stack Research

**Domain:** Personal iOS bodybuilding / weight-training tracker (SwiftUI + SwiftData, local-only, single-user, phone-only)
**Researched:** 2026-05-10
**Confidence:** HIGH on core stack (Apple-native, Context7-verified). HIGH on exercise dataset (schema fetched and verified). MEDIUM on chart performance ceilings (forum/community evidence, not Apple-documented numbers).

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Xcode | 16.x (or 26 if available on macOS) | IDE, build system, simulator, signing | Mandatory for iOS. 16.x ships `swift-format` in the toolchain and full Swift Testing support. No alternative exists. |
| Swift | 6.x (Swift 6 language mode on, strict concurrency) | Application language | Concurrency is enforced by the compiler; Swift 6 mode prevents whole classes of `@MainActor` / SwiftData threading bugs that bit early adopters in 2024. |
| SwiftUI | iOS 17 SDK baseline | UI framework | Locked by PROJECT.md. Native, declarative, integrates directly with `@Observable` and SwiftData's `@Query`. |
| SwiftData | iOS 17 SDK baseline | Persistence | Locked by PROJECT.md. By 2026 SwiftData is considered production-ready for new apps; relationship / migration regressions from 2023–2024 have been addressed. Use the `iOS 17` API surface (no `#Index`) for portability OR `iOS 18+` to unlock `#Index` — see deployment-target decision below. |
| iOS deployment target | **iOS 18.0** (recommended) — fall back to iOS 17.0 only if there's a concrete reason | OS API surface | The user is the only user; there is no install base to support. iOS 18 unlocks `#Index`, `#Unique` macros, `@Previewable`, improved Swift Charts (`PointPlot`), and Swift Testing maturity. There is zero cost to picking the highest reasonable target. **Recommendation: iOS 18.0** so `#Index` is available for fast exercise/session search. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **Swift Charts** | Built into iOS 17+ (no SPM URL needed) | All charts: per-exercise progress, volume bars, weekly tonnage, plateau-detection plots | Default and only chart library for v1. See "What NOT to Use" — DGCharts is unnecessary here. |
| **Swift Testing** | Built into Xcode 16+ (no SPM URL needed) | Unit tests for progression math, fatigue model, RPE/RIR back-calculation, 1RM estimation | New tests only. Apple's recommendation for new code as of WWDC24. |
| **XCTest** | Built into Xcode | UI tests, performance tests | Keep `fitbodUITests/` on XCTest — Swift Testing does **not** support `XCUIApplication` or `XCTAttachment`-based UI automation. This is an Apple-confirmed gap. |
| **swift-format** | Bundled in Xcode 16 toolchain | Code formatting (auto-fix) | Run via build phase or pre-commit. Free, official, no SPM dependency. Sufficient for a solo personal project. |
| **SwiftLint** | 0.57+ (https://github.com/realm/SwiftLint) | Style/safety linting (the parts swift-format doesn't cover) | **Optional** for a personal project. Add only if you find yourself wanting opinionated rules (force-unwraps, file length, complexity). Skippable for v1. |

**SPM URLs (only if you choose to add SwiftLint):**
- `https://github.com/realm/SwiftLint` (use as a build tool plugin via SwiftPM, not a Run Script Phase — the plugin form is the 2025+ recommended pattern)

**That's the whole dependency list.** No third-party persistence, no third-party charting, no third-party state management, no Combine wrappers, no DI framework. This is intentional — see "What NOT to Use" below.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16.x | Build, sign, install to device | Use a **Personal Team** (free Apple ID, no $99 developer program needed). Provisioning profiles issued to personal teams expire every 7 days — re-sign by re-running from Xcode. For a personal app this is acceptable; if it becomes annoying, enrolling in the Apple Developer Program is the fix. |
| iPhone (physical device) | Primary deployment target | Plug in, hit Run. No TestFlight, no App Store Connect needed. Per PROJECT.md, distribution is "personal install via Xcode." |
| Simulator | Fast iteration, edge cases | Use for non-haptic flows. Rest timers / haptics need device. |
| Xcode Previews | UI iteration | Use `@Previewable @State` (iOS 18) for ergonomic previews of stateful views. Pair previews with an in-memory `ModelContainer` configured via `ModelConfiguration(isStoredInMemoryOnly: true)` so previews don't pollute the on-disk store. |
| Git (CLI or Xcode integration) | Source control | Standard. `.gitignore` should include `*.xcuserdata*`, `xcuserstate`, build artifacts. |

## Installation

This is an iOS app — no `npm install`. The "installation" steps are:

```bash
# 1. Confirm Xcode + command-line tools
xcode-select --install
xcodebuild -version   # expect: Xcode 16.x

# 2. Set deployment target in project settings:
#    Project > fitbod target > General > Minimum Deployments: iOS 18.0

# 3. Set Swift language version to Swift 6 with strict concurrency:
#    Build Settings > Swift Compiler - Language > Swift Language Version: Swift 6

# 4. Configure signing:
#    Signing & Capabilities > Team: <your personal team>
#    Bundle Identifier: com.<your-name>.fitbod (must be unique to your team)

# 5. Seed exercise dataset (one-time, see SwiftData seeding section below):
#    Drop free-exercise-db's dist/exercises.json into the app bundle as a resource.

# 6. Run on device (cmd+R with phone selected as destination).
```

No package manager needed for v1. If you add SwiftLint later, that's the only SPM dependency.

## SwiftData Modeling Guidance (Domain-Specific)

This app has clear entities. Here is the recommended modeling stance — these are decisions, not options.

### Entity Map (Suggested)

| Entity | Role | Key Relationships |
|--------|------|-------------------|
| `Exercise` | Catalog item (seeded from free-exercise-db + user-added customs) | many-to-many `MuscleGroup` (with stimulus weighting), many `RoutineExerciseTemplate`, many `SessionExercise` |
| `MuscleGroup` | The 17 muscles from free-exercise-db, plus optional user-defined splits (e.g., "rear delts" derived from "shoulders") | many-to-many `Exercise` via a join entity carrying `weight: Double` |
| `ExerciseMuscleMapping` | Join entity carrying the stimulus weight (e.g., bench press → chest 1.0, triceps 0.4, front delts 0.5) | belongs-to `Exercise`, belongs-to `MuscleGroup`, `weight: Double`, `role: primary/secondary` |
| `Routine` | Template (the plan) | one-to-many `RoutineExerciseTemplate`, optional `Block` |
| `RoutineExerciseTemplate` | Per-exercise prescription within a routine | belongs-to `Routine`, belongs-to `Exercise`, holds `intent`, `targetReps`, `targetRPE`, `progressionModel`, `prescribedWeight` |
| `Session` | A logged instance of a routine on a date | belongs-to `Routine` (nullable — sessions can be freestanded), one-to-many `SessionExercise` |
| `SessionExercise` | Logged exercise within a session — carries the *evaluated* prescription at log time | belongs-to `Session`, belongs-to `Exercise`, one-to-many `SetLog` |
| `SetLog` | One set: weight, reps, RPE, rest, tempo, notes | belongs-to `SessionExercise`, plus `setKind: warmup/working/backoff/dropset` |
| `Block` | Periodization phase | one-to-many `Routine`, holds `phase`, `weekCount`, `deloadEveryNWeeks` |
| `VolumeLandmark` | User-tunable MEV/MAV/MRV per muscle | belongs-to `MuscleGroup`, holds `mev`, `mav`, `mrv` (weekly sets) |

### Specific SwiftData Patterns to Follow

1. **Distinguish template from instance** (your PROJECT.md calls this out). `RoutineExerciseTemplate` is a separate type from `SessionExercise`. Copy fields *at log time* — do not project from the template at read time. This is what gives you "same routine, different histories per intent" without joining mess.

2. **Use `@Relationship(deleteRule: .cascade)` deliberately.**
   - `Session` → `SessionExercise` → `SetLog`: cascade. Deleting a session deletes its logged sets.
   - `Routine` → `RoutineExerciseTemplate`: cascade.
   - `Exercise` → everything else: **nullify**, never cascade. Deleting an exercise from the library should not delete history. (Soft-delete pattern via `isArchived: Bool` is even safer.)

3. **Always declare inverses.** SwiftData requires inverses for non-trivial graphs to behave correctly. Mark them with `@Relationship(inverse: \.parent)` on one side.

4. **`@Attribute(.unique)` on `Exercise.externalID`** — the `id` string from free-exercise-db (e.g., `"Barbell_Bench_Press"`). This prevents duplicate seeds on re-launch.

5. **Use `#Index` (iOS 18) on hot query paths**:
   - `Session.date`
   - `SessionExercise.exerciseID` (or the implicit FK to `Exercise`)
   - `Exercise.name` (for the search-heavy library browser)

6. **Do NOT assign relationships in initializers.** Construct the model, insert it into the context, *then* set relationships. This is a documented SwiftData gotcha — assigning relationships before insertion silently drops the link.

7. **`@MainActor` your `ModelContext` usage in views.** Use `ModelActor` only when you need a background mutation (e.g., seeding 800 exercises on first launch — even then, a synchronous one-shot in `.task` is usually fine).

8. **Versioned schemas from day one.** Wrap your initial schema in a `VersionedSchema` enum and configure the container with a `SchemaMigrationPlan` even if it has only one version. This costs nothing now and saves a painful migration later when you add fields.

9. **Codable on models — avoid.** SwiftData models are reference types; conforming them to `Codable` for JSON imports is a footgun. Decode into separate DTO structs (e.g., `FreeExerciseDTO`) and map to `@Model` types explicitly.

### Exercise-Dataset Seeding Strategy

**Recommended: code-based seeding on first launch (not bundled .store file).**

```
1. Ship dist/exercises.json (~1 MB) as a bundle resource.
2. On app launch, fetch ModelContext, query Exercise.count.
3. If 0 → decode JSON into [FreeExerciseDTO], map to Exercise + ExerciseMuscleMapping + MuscleGroup entities, insert, save.
4. Persist a "seeded version" UserDefaults flag (e.g., "exerciseSeedVersion": 1) so future dataset updates can re-seed deltas without nuking custom exercises.
```

Apple's "pre-populated database" path (ship a `.store` file) requires the SQLite `VACUUM` workaround to strip the WAL files, complicates schema migration, and is harder to update when free-exercise-db ships new exercises. For ~800 records, JSON-on-launch is the right call. The seed runs once, takes well under a second on modern hardware.

## Charting Decision

**Use Swift Charts. Do not add DGCharts.**

| Chart Type | Swift Charts Sufficient? | Notes |
|------------|--------------------------|-------|
| Per-exercise weight/rep history (line) | Yes | Sessions per exercise will be hundreds, not tens of thousands. Trivial for Swift Charts. |
| Weekly tonnage bar chart | Yes | One bar per week. Tiny dataset. |
| Volume bars per muscle group (vs MEV/MAV/MRV) | Yes | One bar per muscle. Use `RuleMark` overlays for the threshold lines. |
| 1RM estimate over time | Yes | One point per session. |
| Plateau detection visualization | Yes | Highlight stalled points with conditional foreground style. |
| Muscle heatmap (body silhouette) | **No — Swift Charts is not the right tool.** | Use SwiftUI `Canvas` + custom SVG-derived paths. This is a custom UI, not a chart. |

**When DGCharts would be justified (not in v1):** 10K+ point real-time streaming charts (e.g., bar-velocity traces from VBT hardware). That hardware is explicitly out of scope for v1. Re-evaluate if you ever add it.

**Performance ceiling to be aware of:** Swift Charts shows lag around ~1K `PointMark`s and noticeable jank around 10K. With this app's data (≤ ~1K sets per exercise over a year), you are nowhere near the ceiling. If a specific chart ever crosses it, the answer is to *sample/decimate* before plotting, not to switch libraries.

## State Management

**Use `@Observable` (iOS 17+) for view models. Use SwiftData's `@Query` for everything fetched from the store. Do not adopt a third-party state library.**

Rules:
- View models holding non-persistent UI state → `@Observable` class, owned by the view with `@State`. Pass down with `@Bindable` for two-way binding.
- Persistent data → `@Query` directly in the view (with predicates and sort descriptors). Do not wrap `@Query` in a view model — you lose the SwiftUI dependency tracking that makes `@Query` reactive.
- Cross-view ephemeral state (e.g., "current active session") → `@Observable` singleton-ish object passed via `.environment(_:)`.
- **Do not use `ObservableObject` / `@Published` / `@StateObject` in new code.** They still work but `@Observable` is finer-grained (only views that read a specific property re-render) and is the 2025–2026 recommended pattern per Apple.

**Gotcha:** With `@Observable` + `@State`, the model's initializer is called on every view re-evaluation. If the init is expensive, hoist creation outside or use lazy initialization. This differs from `@StateObject`'s once-only init semantics.

## Navigation

**Pattern: `TabView` at the root, each tab owns its own `NavigationStack`.**

```
TabView
├── Tab: Today / Active Session
│   └── NavigationStack (path: SessionPath)
├── Tab: Routines
│   └── NavigationStack (path: RoutinePath)
├── Tab: Exercises (library)
│   └── NavigationStack (path: ExercisePath)
├── Tab: Progress / Stats
│   └── NavigationStack (path: ProgressPath)
└── Tab: Settings / Blocks
    └── NavigationStack (path: SettingsPath)
```

- Use **typed navigation paths** (one `NavigationPath` per tab, or a custom enum-based `Path` for type safety).
- **Never** wrap the `TabView` in a parent `NavigationStack` — each tab's state collapses on switch if you do.
- Tap-to-pop-to-root on the active tab is expected iOS behavior; implement it by clearing that tab's `NavigationPath` when the tab is re-tapped.
- For the exercise library (1000+ items, filter-heavy), use `.searchable(text:)` on the list view with a `Predicate<Exercise>` driving `@Query`. Compose filters into the predicate rather than filtering in memory.

## Testing Stack

| Test Type | Framework | Where |
|-----------|-----------|-------|
| Unit tests (progression math, fatigue calc, 1RM estimation, RPE back-calc, deload detection logic, volume aggregation) | **Swift Testing** (`@Test`, `#expect`) | `fitbodTests/` |
| SwiftData model tests (relationships, cascade rules, query predicates) | **Swift Testing** with in-memory `ModelContainer` | `fitbodTests/` |
| UI tests (any) | **XCTest** with `XCUIApplication` | `fitbodUITests/` |
| Snapshot tests | Skip for v1 (personal app, single eye on UI) | — |

Keep both frameworks in the project — they coexist in the same target. Swift Testing's parameterized tests (`@Test(arguments:)`) are perfect for progression-model tables (e.g., "for these (priorWeight, priorReps, priorRPE, targetReps, targetRPE) tuples, expect this prescribed weight").

## Open Exercise Dataset: Decision and Schema

**Recommended: `yuhonas/free-exercise-db`.** No competition for this use case.

| Criterion | free-exercise-db | wger | exercemus/exercises |
|-----------|------------------|------|---------------------|
| License (data) | **Public domain (Unlicense)** — zero attribution burden | AGPL-3.0+ code, CC-licensed data (varies, attribution required) | MIT code; **per-exercise license varies** — attribution required per entry |
| Exercise count | **~800** | ~400 (varies) | ~1100 aggregated |
| Schema fit for a strength app | **Excellent** — categorical fields match this app's filters exactly | Looser, more general fitness | Decent, but per-exercise license metadata adds complexity |
| Images included | **Yes** (~2.6K image files, GitHub raw CDN) | Yes, but API-fetched | Yes, URLs |
| Muscle map | 17 named muscles, primary/secondary arrays | Different taxonomy | Mixed |
| Bundling friction | **Single JSON file + images** | Requires API or scraping | Multiple sources, license tracking required |
| Maintenance state | Stable, low-churn | Active project but data churn | Aggregator, less stable |

### Verified Schema (fetched from `schema.json`, 2026-05-10)

Each exercise object:

```json
{
  "id": "Barbell_Bench_Press",            // string, unique
  "name": "Barbell Bench Press",          // string
  "force": "push",                         // enum: "static" | "pull" | "push" | null
  "level": "beginner",                     // enum: "beginner" | "intermediate" | "expert"
  "mechanic": "compound",                  // enum: "isolation" | "compound" | null
  "equipment": "barbell",                  // enum: "medicine ball" | "dumbbell" | "body only" | "bands" | "kettlebells" | "foam roll" | "cable" | "machine" | "barbell" | "exercise ball" | "e-z curl bar" | "other" | null
  "primaryMuscles": ["chest"],            // array of muscle enum
  "secondaryMuscles": ["triceps", "shoulders"],
  "instructions": ["...", "..."],          // array of strings
  "category": "strength",                  // enum: "powerlifting" | "strength" | "stretching" | "cardio" | "olympic weightlifting" | "strongman" | "plyometrics"
  "images": ["Barbell_Bench_Press/0.jpg", "Barbell_Bench_Press/1.jpg"]
}
```

**17 muscle enum values:** `abdominals`, `abductors`, `adductors`, `biceps`, `calves`, `chest`, `forearms`, `glutes`, `hamstrings`, `lats`, `lower back`, `middle back`, `neck`, `quadriceps`, `shoulders`, `traps`, `triceps`.

### Schema Fit Notes for This App

- **Good fit:** Categorical filters (force, level, mechanic, equipment, category, muscles) directly support the filter-heavy library UX in PROJECT.md.
- **Missing fields** this app needs that you must add yourself (per-exercise, not from dataset):
  - **Stimulus weighting** per primary/secondary muscle (e.g., bench-press → chest 1.0, triceps 0.4). free-exercise-db only has on/off arrays. You will need to *manually curate* weights for the most common exercises and default the rest to 1.0/0.5. Treat this as user-tunable.
  - **Grip variant** ("supinated", "pronated", "neutral") — not in dataset.
  - **Pattern** ("horizontal push", "vertical pull", "hinge", "squat") — not in dataset; derive from mechanic + muscles or add manually for the ~50 main lifts.
  - **Bar/cable variants** ("low cable row" vs "seated cable row") — these are separate `id`s in the dataset, which works.
- **Filter for v1:** Filter `category` to `["strength", "powerlifting", "olympic weightlifting", "strongman"]` only. Drop cardio/stretching/plyometrics on import to stay within scope.
- **Images:** Decide whether to bundle images in-app (~10–50 MB depending on subset) or lazy-load from GitHub raw CDN. For an offline-first personal app, **bundle them.** Strip duplicates (25 known duplicates per the dataset README).

### Download & Bundling Strategy

```bash
# One-time, locally — vendor the dataset into the repo:
cd fitbod/
mkdir -p Resources/ExerciseSeed
curl -L -o Resources/ExerciseSeed/exercises.json \
    https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json

# Optionally vendor images (large; consider lazy from CDN for v1):
git clone --depth 1 https://github.com/yuhonas/free-exercise-db.git /tmp/fedb
cp -R /tmp/fedb/exercises Resources/ExerciseSeed/images
```

Add `Resources/ExerciseSeed/` to the Xcode target as a folder reference (blue folder), not a group, so the JSON path resolution stays predictable at runtime.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| SwiftData | Core Data | Never for this project. SwiftData on iOS 17+ is the modern API; Core Data is the legacy substrate that SwiftData wraps. The argument for Core Data ("more battle-tested") is fading fast in 2026, and the user has already chosen SwiftData via the template. |
| SwiftData | Realm / GRDB / SQLite.swift | If you discover a SwiftData blocker (e.g., a specific query SwiftData can't express). For v1's workload, SwiftData is sufficient. |
| Swift Charts | DGCharts (`https://github.com/ChartsOrg/Charts`) | Only if you add VBT/real-time accelerometer streams (out of scope for v1). |
| Swift Charts | Custom `Canvas` rendering | The muscle heatmap (body silhouette) — yes, use Canvas. Not a "chart" in the data-viz sense. |
| `@Observable` | `ObservableObject` + `@Published` | Only when maintaining pre-iOS-17 code. New project, irrelevant. |
| `@Observable` | TCA (The Composable Architecture) | If the project grows past one developer and needs strong testability boundaries. For solo v1, TCA's ceremony exceeds its benefit. |
| `TabView` + per-tab `NavigationStack` | Custom router / coordinator | If deep linking from notifications becomes a feature. Out of scope for v1. |
| Swift Testing | XCTest only | UI tests must remain XCTest until Apple ships UI-testing support in Swift Testing. |
| `swift-format` (Xcode-bundled) | SwiftLint + SwiftFormat (nicklockwood) | If you want opinionated style rules beyond what swift-format covers. Optional for solo dev. |
| free-exercise-db | exercemus/exercises | If you specifically want 1000+ exercises and are willing to handle per-entry attribution at display time. For a personal local app, this is more annoyance than benefit. |
| free-exercise-db | wger API (live) | Never for v1 — offline-first is the project stance, and AGPL-3.0 has copyleft implications for any code that imports it as a library. The data under CC licenses is usable, but the API client isn't worth the dependency. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Core Data (directly) | SwiftData is the supported modern API and already chosen. Mixing both adds complexity with no payoff. | SwiftData |
| RxSwift / ReactiveSwift | Combine + `@Observable` covers the same ground natively, and SwiftUI is built around the Apple frameworks. Adding Rx is a 2018-era pattern. | `@Observable`, `AsyncSequence`, Combine where unavoidable |
| Realm | Excellent library but redundant against SwiftData. Adds a dependency, separate schema, separate migration story. | SwiftData |
| DGCharts | Heavy UIKit-bridged dependency. Unnecessary for this app's data volume. | Swift Charts |
| Charts (the old Daniel Cohen Gindi `Charts` SPM name) | Renamed to DGCharts to avoid namespace clash with Apple's `Charts`. Avoid the old name regardless. | Swift Charts |
| Combine-only architectures | Combine is fine surgically; building everything on it in 2026 is anti-pattern. SwiftUI's reactivity now comes from `@Observable`. | `@Observable` + `@Query` |
| `@StateObject` / `@ObservedObject` / `@EnvironmentObject` in new code | Legacy property wrappers. Still functional but `@Observable` + `@State`/`@Bindable`/`.environment(_:)` is the 2025+ pattern. | `@Observable` macro |
| `ObservableObject` protocol | Same reason. | `@Observable` macro |
| Bundled pre-populated `.store` file (Apple's "pre-populated database" approach) | Requires SQLite `VACUUM` workaround, complicates schema migration, harder to refresh when the upstream dataset updates. | Code-based seed from `exercises.json` on first launch |
| iCloud / CloudKit sync | Explicitly out of scope per PROJECT.md. SwiftData+CloudKit also forces **every property optional or defaulted, every relationship optional** — a real architectural cost. | Local-only `ModelConfiguration` |
| HealthKit | Out of scope per PROJECT.md. | Defer to v2+ |
| WeightTrainingWorkout from HealthKit | Same. | Defer |
| TestFlight | Personal install per PROJECT.md. | Run-to-device from Xcode |
| Fastlane / xcodebuild CI pipelines | Solo personal project, single dev machine. | Manual Xcode builds |
| wger API client | AGPL-3.0 on the wger codebase; live-API dependency contradicts offline-first stance. | Vendored free-exercise-db JSON |
| MVVM-style view models that wrap `@Query` | Breaks SwiftData's view-driven reactivity. `@Query` results don't update if hidden behind a non-`@Observable` wrapper. | Put `@Query` directly in the view; use `@Observable` view models only for ephemeral UI state |

## Stack Patterns by Variant

**If you stay on iOS 17 deployment target:**
- Lose `#Index` macro (use `@Attribute(.unique)` only — queries on non-unique fields will table-scan, but at this app's scale that's fine).
- Lose `@Previewable` (use the older `@State` in preview wrapper struct).
- Lose Swift Charts `PointPlot` (use `PointMark` — fine at this data scale).
- Everything else works identically.

**If you move to iOS 18 deployment target (recommended):**
- Add `#Index([\Session.date])`, `#Index([\Exercise.name])` for fast search.
- Use `@Previewable @State` for clean preview definitions.
- Use `PointPlot` for any chart that might cross ~1K points.

**If the app ever grows beyond a personal install:**
- Add iCloud sync — but plan for the "every property optional or defaulted" constraint *now* by writing models that way from day one (cheap insurance).
- Consider TCA if a second developer joins.
- Add SwiftLint enforced in CI.

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| SwiftData iOS 17 API | iOS 17.0+ | Baseline. Missing `#Index`, `#Unique`, history tracking. |
| SwiftData iOS 18 API | iOS 18.0+ | Adds `#Index`, `#Unique`, improvements to relationship handling. |
| Swift Charts `PointPlot` | iOS 18.0+ | Performance improvement over `PointMark` for large series. |
| Swift Testing | Xcode 16+ (Swift 6 toolchain) | UI tests still require XCTest. |
| `@Observable` | iOS 17.0+ (macOS 14, etc.) | Don't mix `@Published` and `@Observable` on the same type. |
| `@Previewable` | iOS 18.0+ / Xcode 16+ | Older code uses wrapper structs for previewing stateful views. |
| swift-format (bundled) | Xcode 16+ | No SPM needed. |

## Sources

### High Confidence (Context7 / Official Apple)
- Context7 `/websites/developer_apple_swiftdata` — `ModelContainer`, `SchemaMigrationPlan`, `VersionedSchema`, relationship handling
- [Apple Developer: SwiftData](https://developer.apple.com/xcode/swiftdata) — official framework page
- [WWDC24: What's new in SwiftData](https://developer.apple.com/videos/play/wwdc2024/10137/) — `#Index`, `#Unique` macros
- [WWDC24: Meet Swift Testing](https://developer.apple.com/videos/play/wwdc2024/10179/) — Swift Testing introduction and migration guidance
- [WWDC23: Discover Observation in SwiftUI](https://developer.apple.com/videos/play/wwdc2023/10149/) — `@Observable` macro semantics
- [Apple Developer: Swift Charts](https://developer.apple.com/documentation/Charts) — official chart framework
- [Apple Developer: Migrating from ObservableObject to Observable macro](https://developer.apple.com/documentation/SwiftUI/Migrating-from-the-observable-object-protocol-to-the-observable-macro)

### High Confidence (Schema fetched directly)
- [free-exercise-db schema.json (raw)](https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/schema.json) — enum values verified by direct fetch on 2026-05-10
- [free-exercise-db dist/exercises.json (raw)](https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json) — sample records verified
- [free-exercise-db repo](https://github.com/yuhonas/free-exercise-db) — license (Unlicense / public domain), ~800 exercises, image bundle confirmed

### Medium Confidence (verified across multiple community sources)
- [Hacking with Swift: SwiftData by Example](https://www.hackingwithswift.com/quick-start/swiftdata) — seeding, predicates, migration patterns
- [Hacking with Swift: Relationships with SwiftData, SwiftUI, and @Query](https://www.hackingwithswift.com/books/ios-swiftui/relationships-with-swiftdata-swiftui-and-query) — cascade vs nullify rules
- [Use Your Loaf: SwiftData Indexes](https://useyourloaf.com/blog/swiftdata-indexes/) — `#Index` iOS 18 confirmation
- [Donny Wals: @Observable in SwiftUI explained](https://www.donnywals.com/observable-in-swiftui-explained/) — `@Observable` lifecycle and init re-execution gotcha
- [Antoine van der Lee: @Observable Macro performance increase](https://www.avanderlee.com/swiftui/observable-macro-performance-increase-observableobject/) — fine-grained re-render evidence
- [Apple Developer Forums: Swift Charts performance with large datasets](https://developer.apple.com/forums/thread/740314) — ceiling around 10K–100K points
- [Tanaschita: SwiftUI Navigation with NavigationPath and TabView](https://tanaschita.com/swiftui-navigation-path-with-tabview/) — per-tab `NavigationStack` pattern
- [Michael Tsai: Swift Format in Xcode 16](https://mjtsai.com/blog/2024/11/06/swift-format-in-xcode-16/) — `swift-format` toolchain bundling
- [Fatbobman: Key Considerations Before Using SwiftData](https://fatbobman.com/en/posts/key-considerations-before-using-swiftdata/) — `@ModelActor` view-refresh gotcha
- [exercemus/exercises](https://github.com/exercemus/exercises) — alternative dataset license model confirmed
- [wger-project/wger](https://github.com/wger-project/wger) — AGPL-3.0 + CC data license confirmed

### Low Confidence / Single-source observations
- "Personal team provisioning expires every 7 days" — widely repeated in community guides; treat as known iOS behavior, but the exact policy can shift. Verify when signing.
- Swift Charts `PointPlot` performance improvement magnitude — community-reported, not a precise Apple-published number.

---
*Stack research for: personal iOS bodybuilding / weight-training tracker on SwiftUI + SwiftData*
*Researched: 2026-05-10*
