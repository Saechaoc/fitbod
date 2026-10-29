# Stack Research (Full)

**Domain:** Personal iOS bodybuilding / weight-training tracker (SwiftUI + SwiftData, local-only, single-user, phone-only)
**Researched:** 2026-05-10
**Confidence:** HIGH on core stack (Apple-native, Context7-verified). HIGH on exercise dataset (schema fetched and verified). MEDIUM on chart performance ceilings (forum/community evidence, not Apple-documented numbers).
**Current target:** The app now targets iOS 26.4.
The iOS 17 and iOS 18 notes below record the original research.

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Xcode | 16.x (or 26 if available on macOS) | IDE, build system, simulator, signing | Mandatory for iOS. 16.x ships `swift-format` in the toolchain and full Swift Testing support. No alternative exists. |
| Swift | 6.x (Swift 6 language mode on, strict concurrency) | Application language | Concurrency is enforced by the compiler; Swift 6 mode prevents whole classes of `@MainActor` / SwiftData threading bugs that bit early adopters in 2024. |
| SwiftUI | iOS 17 SDK baseline | UI framework | Locked by PROJECT.md. Native, declarative, integrates directly with `@Observable` and SwiftData's `@Query`. |
| SwiftData | iOS 17 SDK baseline | Persistence | Locked by PROJECT.md. By 2026 SwiftData is considered production-ready for new apps; relationship / migration regressions from 2023–2024 have been addressed. Use the `iOS 17` API surface (no `#Index`) for portability OR `iOS 18+` to unlock `#Index`. |
| iOS deployment target | **iOS 18.0** | OS API surface | The user is the only user; there is no install base to support. iOS 18 unlocks `#Index`, `#Unique` macros, `@Previewable`, improved Swift Charts (`PointPlot`), and Swift Testing maturity. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **Swift Charts** | Built into iOS 17+ | All charts: per-exercise progress, volume bars, weekly tonnage, plateau-detection plots | Default and only chart library for v1. |
| **Swift Testing** | Built into Xcode 16+ | Unit tests for progression math, fatigue model, RPE/RIR back-calculation, 1RM estimation | New tests only. Apple's recommendation for new code as of WWDC24. |
| **XCTest** | Built into Xcode | UI tests, performance tests | Keep `fitbodUITests/` on XCTest — Swift Testing does **not** support `XCUIApplication` or `XCTAttachment`-based UI automation. This is an Apple-confirmed gap. |
| **swift-format** | Bundled in Xcode 16 toolchain | Code formatting (auto-fix) | Run via build phase or pre-commit. |
| **SwiftLint** | 0.57+ | Style/safety linting | Optional for v1. Add only if you want opinionated rules (force-unwraps, file length, complexity). |

**That's the whole dependency list.** No third-party persistence, charting, state management, Combine wrappers, or DI framework. Intentional — see Alternatives Considered below.

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16.x | Build, sign, install to device | Use a Personal Team (free Apple ID). Provisioning profiles expire every 7 days — re-sign by re-running from Xcode. |
| iPhone (physical device) | Primary deployment target | Plug in, hit Run. No TestFlight needed. |
| Simulator | Fast iteration, edge cases | Use for non-haptic flows. Rest timers / haptics need device. |
| Xcode Previews | UI iteration | Use `@Previewable @State` (iOS 18) with an in-memory `ModelConfiguration(isStoredInMemoryOnly: true)`. |
| Git | Source control | `.gitignore`: `*.xcuserdata*`, `xcuserstate`, build artifacts. |

## Installation

```bash
# 1. Confirm Xcode + command-line tools
xcode-select --install
xcodebuild -version   # expect: Xcode 16.x

# 2. Set deployment target: Project > fitbod target > General > Minimum Deployments: iOS 18.0
# 3. Set Swift 6: Build Settings > Swift Compiler - Language > Swift Language Version: Swift 6
# 4. Configure signing: Signing & Capabilities > Team: <your personal team>
#    Bundle Identifier: com.<your-name>.fitbod
# 5. Seed exercise dataset (one-time): drop free-exercise-db's dist/exercises.json into bundle
# 6. Run on device (cmd+R)
```

## SwiftData Modeling Guidance

### Entity Map

| Entity | Role | Key Relationships |
|--------|------|-------------------|
| `Exercise` | Catalog item (seeded from free-exercise-db + user-added customs) | many-to-many `MuscleGroup` (with stimulus weighting), many `RoutineExerciseTemplate`, many `SessionExercise` |
| `MuscleGroup` | The 17 muscles from free-exercise-db, plus optional user-defined splits | many-to-many `Exercise` via join entity carrying `weight: Double` |
| `ExerciseMuscleMapping` | Join entity carrying stimulus weight (e.g., bench press → chest 1.0, triceps 0.4) | belongs-to `Exercise`, belongs-to `MuscleGroup`, `weight: Double`, `role: primary/secondary` |
| `Routine` | Template (the plan) | one-to-many `RoutineExerciseTemplate`, optional `Block` |
| `RoutineExerciseTemplate` | Per-exercise prescription within a routine | belongs-to `Routine`, belongs-to `Exercise`, holds `intent`, `targetReps`, `targetRPE`, `progressionModel`, `prescribedWeight` |
| `Session` | A logged instance of a routine on a date | belongs-to `Routine` (nullable), one-to-many `SessionExercise` |
| `SessionExercise` | Logged exercise within a session — carries *evaluated* prescription at log time | belongs-to `Session`, belongs-to `Exercise`, one-to-many `SetLog` |
| `SetLog` | One set: weight, reps, RPE, rest, tempo, notes | belongs-to `SessionExercise`, plus `setKind: warmup/working/backoff/dropset` |
| `Block` | Periodization phase | one-to-many `Routine`, holds `phase`, `weekCount`, `deloadEveryNWeeks` |
| `VolumeLandmark` | User-tunable MEV/MAV/MRV per muscle | belongs-to `MuscleGroup`, holds `mev`, `mav`, `mrv` (weekly sets) |

### Key SwiftData Patterns

1. **Distinguish template from instance.** `RoutineExerciseTemplate` is separate from `SessionExercise`. Copy fields at log time — do not project from the template at read time.

2. **Cascade rules.**
   - `Session` → `SessionExercise` → `SetLog`: cascade.
   - `Routine` → `RoutineExerciseTemplate`: cascade.
   - `Exercise` → everything else: **nullify**, never cascade. Soft-delete via `isArchived: Bool` is safer.

3. **Always declare inverses.** Mark with `@Relationship(inverse: \.parent)` on one side.

4. **`@Attribute(.unique)` on `Exercise.externalID`** — prevents duplicate seeds on re-launch.

5. **`#Index` (iOS 18)** on `Session.date`, `SessionExercise.exerciseID`, `Exercise.name`.

6. **Don't assign relationships in initializers.** Insert into context first, then set relationships.

7. **`@MainActor` for `ModelContext` in views.** Use `ModelActor` only for background mutations (e.g., first-launch seeding).

8. **Versioned schemas from day one.** Wrap initial schema in `VersionedSchema` + `SchemaMigrationPlan` even with one version.

9. **No `Codable` on `@Model` types.** Decode into separate DTO structs, map to `@Model` types explicitly.

## Charting Decision

Use Swift Charts. Do not add DGCharts.

| Chart Type | Swift Charts Sufficient? | Notes |
|------------|--------------------------|-------|
| Per-exercise weight/rep history (line) | Yes | Hundreds of sessions per exercise — trivial. |
| Weekly tonnage bar chart | Yes | One bar per week. |
| Volume bars per muscle group (vs MEV/MAV/MRV) | Yes | `RuleMark` overlays for threshold lines. |
| 1RM estimate over time | Yes | One point per session. |
| Plateau detection visualization | Yes | Conditional foreground style. |
| Muscle heatmap (body silhouette) | **No** | Use SwiftUI `Canvas` + custom SVG-derived paths. |

DGCharts justified only for 10K+ point real-time streaming (VBT hardware, out of scope for v1).

## Open Exercise Dataset

Chosen: `yuhonas/free-exercise-db` (Unlicense / public domain, ~800 exercises, single JSON bundle).

### Verified Schema (fetched 2026-05-10)

```json
{
  "id": "Barbell_Bench_Press",
  "name": "Barbell Bench Press",
  "force": "push",
  "level": "beginner",
  "mechanic": "compound",
  "equipment": "barbell",
  "primaryMuscles": ["chest"],
  "secondaryMuscles": ["triceps", "shoulders"],
  "instructions": ["...", "..."],
  "category": "strength",
  "images": ["Barbell_Bench_Press/0.jpg", "Barbell_Bench_Press/1.jpg"]
}
```

**17 muscles:** abdominals, abductors, adductors, biceps, calves, chest, forearms, glutes, hamstrings, lats, lower back, middle back, neck, quadriceps, shoulders, traps, triceps.

**Missing fields** to add manually: stimulus weights per muscle, grip variant, movement pattern.

**Seeding:** Ship `dist/exercises.json` as a bundle resource. On first launch, query `Exercise.count` → if 0, decode via DTO structs, insert, save. Persist a seed-version UserDefaults flag for future delta updates.

### Download

```bash
cd fitbod/
mkdir -p Resources/ExerciseSeed
curl -L -o Resources/ExerciseSeed/exercises.json \
    https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json
```

Add `Resources/ExerciseSeed/` as a folder reference (blue folder) in Xcode, not a group.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| SwiftData | Core Data | Never for this project. |
| SwiftData | Realm / GRDB / SQLite.swift | Only if SwiftData blocker found; none expected at v1 scale. |
| Swift Charts | DGCharts | Only for VBT real-time streaming (out of scope v1). |
| `@Observable` | TCA | Only if a second developer joins. |
| free-exercise-db | exercemus/exercises | Only if 1000+ exercises needed + per-entry attribution acceptable. |
| free-exercise-db | wger API | Never — AGPL-3.0 + live API contradicts offline-first stance. |

## Version Compatibility

| Component | Compatible With | Notes |
|-----------|-----------------|-------|
| SwiftData iOS 17 API | iOS 17.0+ | Baseline. Missing `#Index`, `#Unique`. |
| SwiftData iOS 18 API | iOS 18.0+ | Adds `#Index`, `#Unique`. |
| Swift Charts `PointPlot` | iOS 18.0+ | Use `PointMark` on iOS 17 — fine at this data scale. |
| Swift Testing | Xcode 16+ | UI tests still require XCTest. |
| `@Observable` | iOS 17.0+ | Don't mix `@Published` and `@Observable` on the same type. |
| `@Previewable` | iOS 18.0+ / Xcode 16+ | Use wrapper structs on iOS 17. |
| swift-format (bundled) | Xcode 16+ | No SPM needed. |

## Sources

### High Confidence (Context7 / Official Apple)
- Context7 `/websites/developer_apple_swiftdata` — `ModelContainer`, `SchemaMigrationPlan`, `VersionedSchema`, relationship handling
- Apple Developer: SwiftData, Swift Charts, Migrating from ObservableObject to Observable macro
- WWDC24: What's new in SwiftData (`#Index`, `#Unique`); Meet Swift Testing
- WWDC23: Discover Observation in SwiftUI (`@Observable` semantics)

### High Confidence (Schema fetched directly)
- free-exercise-db schema.json (raw) — enum values verified 2026-05-10
- free-exercise-db dist/exercises.json (raw) — sample records verified
- free-exercise-db repo — license (Unlicense / public domain), ~800 exercises confirmed

### Medium Confidence
- Hacking with Swift: SwiftData by Example — seeding, predicates, migration patterns
- Use Your Loaf: SwiftData Indexes — `#Index` iOS 18 confirmation
- Donny Wals: @Observable in SwiftUI — lifecycle and init re-execution gotcha
- Fatbobman: Key Considerations Before Using SwiftData — `@ModelActor` view-refresh gotcha
- Tanaschita: SwiftUI Navigation with NavigationPath and TabView — per-tab `NavigationStack` pattern

### Low Confidence / Single-source
- "Personal team provisioning expires every 7 days" — widely repeated; verify when signing.
- Swift Charts `PointPlot` performance improvement magnitude — community-reported.

---
*Stack research for: personal iOS bodybuilding / weight-training tracker on SwiftUI + SwiftData*
*Researched: 2026-05-10*
