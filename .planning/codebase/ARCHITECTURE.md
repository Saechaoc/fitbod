<!-- refreshed: 2026-05-28 -->
# Architecture

**Analysis Date:** 2026-05-28

## System Overview

```text
┌────────────────────────────────────────────────────────────────────┐
│  App Entry                                                         │
│  `fitbod/fitbodApp.swift` — @main struct fitbodApp: App            │
│  Owns the single `ModelContainer` (SchemaV6 + migration plan)      │
│  WindowGroup { RootView() }.modelContainer(container)              │
└──────────────────────────────┬─────────────────────────────────────┘
                               │ @Environment(\.modelContext)
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│  Root / Tabs — `fitbod/App/RootView.swift`                         │
│  Splash gate (SeedState .idle/.loading/.ready/.failed)             │
│  Custom VStack-over-BRUTabBar (NOT TabView — see note)             │
│  4 tabs: today / program / progress / settings                     │
│  Each tab owns its own NavigationStack; re-tap pops to root        │
└──────┬───────────────┬──────────────────┬──────────────────┬───────┘
       │               │                  │                  │
       ▼               ▼                  ▼                  ▼
  ┌─────────┐    ┌──────────┐    ┌─────────────────┐    ┌──────────┐
  │ TodayView│    │ProgramView│   │ProgressHomeView │    │SettingsVw│
  │ Views/   │    │Periodiztn/│   │Progress/        │    │Settings/ │
  └──┬───────┘    └────┬──────┘   └────┬────────────┘    └────┬─────┘
     │                 │                │                       │
     ▼                 ▼                ▼                       ▼
┌────────────────────────────────────────────────────────────────────┐
│  Feature Modules (`fitbod/<Feature>/`)                             │
│  Sessions/  Routines/  Periodization/  Progress/  Fatigue/         │
│  Prescription/ ExerciseLibrary/ Settings/ Export/ Backup/          │
│  Plus shared: Views/ (Today composites), Design/ (BRU tokens)      │
└──────────────────────────────┬─────────────────────────────────────┘
                               │ reads / writes via @Query, @Bindable
                               ▼
┌────────────────────────────────────────────────────────────────────┐
│  Persistence — `fitbod/Models/` + `fitbod/Persistence/`            │
│  16 @Model entities, 6 VersionedSchema steps (V1→V6)               │
│  FitbodSchemaMigrationPlan: 5 stages, 2 custom (V3→V4, V5→V6)      │
└──────────────────────────────┬─────────────────────────────────────┘
                               │ SQLite WAL store
                               ▼
                       Local-only on-disk store
                       (no CloudKit, no backend)

┌─────────────────────────────────┐    ┌────────────────────────────┐
│  Widget Extension               │    │  Bundled Resources         │
│  `FitbodWidgets/`               │    │  `fitbod/Resources/`       │
│  RestTimerLiveActivity          │◀───│  exercises.json (~702),    │
│  Dynamic Island + lock screen   │    │  SEED_VERSION.txt, fonts   │
│  Bridged from main app via      │    │  (SpaceGrotesk, JetBrains  │
│  RestTimerActivityController    │    │  Mono, BebasNeue, Geist)   │
└─────────────────────────────────┘    └────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| App entry | Build the single shared `ModelContainer`; inject via `.modelContainer` | `fitbod/fitbodApp.swift` |
| Root / tabs | Splash-vs-tabs gate, 4-tab bar, per-tab NavigationPath, re-tap pop-to-root | `fitbod/App/RootView.swift` |
| Seed state | `@Observable` lifecycle for first-launch importer | `fitbod/App/SeedState.swift` |
| Today | Today's session, block context, fatigue surface composition | `fitbod/Views/TodayView.swift` |
| Program | Block builder empty-state, block list, mesocycle week pages | `fitbod/Periodization/ProgramView.swift` |
| Progress | Recent / Trends / Compare home + per-exercise drilldowns | `fitbod/Progress/ProgressHomeView.swift` |
| Settings | Units, calibration, volume targets, smart progression, export, backup | `fitbod/Settings/SettingsView.swift` |
| Active workout | Bindable `Session` editor with rest timer overlay | `fitbod/Sessions/SessionLoggerView.swift` |
| Session factory | Snapshot deep-copy `Routine` → `Session` + prescribe weights | `fitbod/Sessions/SessionFactory.swift` |
| Prescription | `ProgressionStrategy` protocol + 4 strategies; plate calc; warmup ramp | `fitbod/Prescription/` |
| Periodization math | Phase/week resolution for an active block (pure, no ctx) | `fitbod/Prescription/PeriodizationEngine.swift` |
| Fatigue math | Weighted weekly volume vs MEV/MAV/MRV; plateau detection; deload advisor | `fitbod/Fatigue/FatigueModel.swift` |
| Exercise seed | `@ModelActor` importer + idempotent UserDefaults version stamp | `fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift` |
| Persistence | Versioned schemas + migration plan + preview/in-memory container | `fitbod/Persistence/` |
| Design system (BRU) | Color tokens, type roles, primitives (chips, buttons, dividers, tab bar) | `fitbod/Design/` |
| Widget bundle | `WidgetBundle` host for `RestTimerLiveActivity` | `FitbodWidgets/FitbodWidgetsBundle.swift` |

## Pattern Overview

**Overall:** Single-app SwiftUI + SwiftData with MV-VM-lite. Feature folders co-locate views, drafts (form-holders), and feature-local helpers around the shared `Models/` schema.

**Key Characteristics:**
- One shared `ModelContainer` constructed in `fitbodApp.init()`; views consume via `@Environment(\.modelContext)`. No DI container, no singleton service locator.
- `@Query` lives directly in views (no view-model wrapper around it) — SwiftUI reactivity is preserved.
- `@Observable` (not `ObservableObject`/`@Published`) for every ephemeral state holder: drafts, filter states, rest timer engine, in-session PR state, seed lifecycle.
- `@ModelActor` for any background SwiftData write batch: exercise seed import, CSV/JSON export, backup archiver. Never plain `Task { @MainActor in ... }` for batch SwiftData work.
- Snapshot-and-decouple: `Session*` rows are deep-copies of `Routine*` rows at session-start. The link is a soft `sourceRoutineID: UUID?` (not a `@Relationship`) so deleting templates never erases history.
- Pure-function strategy/engine namespaces (`ProgressionStrategy`, `PeriodizationEngine`, `FatigueModel`, `OneRepMaxEstimator`, `PRDetector`) take pre-fetched inputs from the caller and return value types — no `ModelContext` coupling.

## Layers

**App / chrome layer:**
- Purpose: Build container, gate splash, host the tab bar.
- Location: `fitbod/App/`, `fitbod/fitbodApp.swift`.
- Depends on: `fitbod/Persistence/` (migration plan), `fitbod/Design/` (BRUTabBar), feature roots.

**Feature layer:**
- Purpose: One folder per user-visible surface or domain area. Self-contained views, drafts, and local helpers.
- Location: `fitbod/Sessions/`, `Routines/`, `Periodization/`, `Progress/`, `Fatigue/`, `Prescription/`, `ExerciseLibrary/`, `Settings/`, `Export/`, `Backup/`, `Views/` (shared Today-tab composites).
- Depends on: `fitbod/Models/`, `fitbod/Design/`, feature-local types.

**Design system (BRU):**
- Purpose: Brutalist primitive library — color tokens, typography, chips, buttons, dividers, the tab bar, dashed slots, plate stack viz.
- Location: `fitbod/Design/` (21 files). Color tokens at `fitbod/Design/Color+BRU.swift`; type roles at `fitbod/Design/BRUFont.swift` (Space Grotesk + JetBrains Mono).
- Used by: every feature view. Banned tokens in feature code: `Capsule`, `RoundedRectangle`, `Color.accentColor`, `Image(systemName:)` in chrome, `.font(.body|.headline|.title*|.caption)`, `Form`, `List` (most surfaces). Compliance is grep-audited by `BRUGrepAuditTests`/`Phase3BRUGrepAuditTests`/`BRUPhase5GrepAuditTests`.

**Persistence layer:**
- Purpose: `@Model` entity definitions, versioned schemas, migration plan, preview/in-memory container factory.
- Location: `fitbod/Models/` (16 `@Model` types + 14 enum raw-string backers in `Models/Enums/`), `fitbod/Persistence/` (SchemaV1–V6 + `FitbodSchemaMigrationPlan` + `PreviewModelContainer`).
- Used by: every layer above.

**Widget extension:**
- Purpose: ActivityKit Live Activity for the rest timer (lock screen, Dynamic Island compact/minimal/expanded).
- Location: `FitbodWidgets/`.
- Bridged from app via: `fitbod/Sessions/RestTimer/RestTimerActivityController.swift` + `RestTimerLiveActivityBridge.swift`. The controller falls back silently if Live Activities are unavailable (simulator, disabled in Settings, pre-Pro device).
- BRU color tokens (`Color.bruInk`, `bruSignal`) are shared via `fitbod/Design/Color+BRU.swift` being compiled into both targets (the Assets.xcassets entries are the cross-target API; the generated `Color.bru*` symbol extensions are app-internal only).

## Data Flow

### Primary request path — first launch and seed

1. `fitbodApp.init()` builds `ModelContainer(for: Schema(SchemaV6.models), migrationPlan: FitbodSchemaMigrationPlan.self)` (`fitbod/fitbodApp.swift:34`).
2. `WindowGroup { RootView() }.modelContainer(container)` injects it (`fitbod/fitbodApp.swift:48`).
3. `RootView.task { await runSeed() }` runs once on first appearance (`fitbod/App/RootView.swift:109`).
4. `runSeed()` constructs `ExerciseLibraryImporter(modelContainer: modelContext.container)` (a `@ModelActor`) and calls `seedIfNeeded(bundle: .main)` — short-circuits in O(1) on second+ launches via `UserDefaults["exercise_seed_version"]` vs bundled `SEED_VERSION.txt` (`fitbod/ExerciseLibrary/ExerciseLibraryImporter.swift`).
5. After exercise seed: `PlateInventorySeeder.seedIfNeeded(...)`, `StimulusWeightSeeder.seedIfNeeded(...)`, `MuscleVolumeTargetSeeder.seedIfNeeded(...)` (all idempotent — row-level flags or version stamps).
6. `seedState.phase = .ready` → `RootView.shouldShowSplash` flips false → `tabBar` renders.

### Primary user-facing flow — start a session

1. User taps a routine or "Start workout" CTA somewhere under the Today/Program tab.
2. `SessionFactory.start(routine:date:context:)` inserts a new `Session` (`sourceRoutineID = routine.id`, `routineSnapshotName = routine.name`), deep-copies each `RoutineExercise` into a `SessionExercise`, pre-populates planned `SetEntry` rows with prescribed weight (`fitbod/Sessions/SessionFactory.swift`).
3. Prescription per exercise: `ProgressionStrategyFactory.make(for: session.progressionKind)` returns one of `RPEAutoregStrategy` / `DoubleProgressionStrategy` / `BlockPeriodizedStrategy` / `HybridStrategy` (`fitbod/Prescription/ProgressionStrategyFactory.swift`). Strategy `prescribe(...)` is pure — caller fetches history scalars via `PreviousMatchingIntent`.
4. `SessionLoggerView(session:)` opens with `@Bindable session`. Each `SessionExerciseCard` binds a `SessionExercise`; `SetRow` mutations land directly on `SetEntry` `@Model` rows (autosave-driven).
5. `RestTimerEngine` (an `@Observable @MainActor` class) tracks `startedAt: Date?` + `targetSeconds`. UI uses `TimelineView(.periodic(...))` for the countdown. Notifications via `RestTimerNotificationScheduler`; Live Activity via `RestTimerActivityController` (`fitbod/Sessions/RestTimer/`).
6. Finish: `session.completedAt = .now`; `ctx.save()`.

### Volume / fatigue flow (read-side)

1. View calls `FatigueModel.weightedWeeklyVolume(...)` with a pre-resolved week start (`MondayAtMidnight` helper) and the `ModelContext`.
2. Function fetches `SetEntry` rows in window via `#Index<SetEntry>([\.completedAt])`, traverses `sessionExercise.exercise.muscleStimuli` to compute weighted direct/indirect set totals per `MuscleGroup` (`fitbod/Fatigue/FatigueModel.swift`).
3. Result is a `[String: WeightedSetTotal]` value type rendered by `MuscleVolumeBar` / `FatigueSurfaceView` / `WeeklyRecapSheet`.

**State Management:**
- Persistent: `@Query` directly in the view; `@Bindable` for two-way binding onto `@Model` rows.
- Ephemeral form state: `@Observable` draft types (`RoutineDraft`, `BlockDraft`, `CustomExerciseDraft`, `RoutineFolderDraft`, `BlockPhaseDraft`) owned by views via `@State`; written into `@Model` rows on save.
- Filter / UI-only state: `@Observable` (`ChartFilterState`, `FilterState`, `InSessionPRState`, `SeedState`).
- Cross-view: environment injection used only for `\.modelContext` and `\.dismiss` — no custom environment-injected singletons in feature code.

## Key Abstractions

**`@Model` entity (SwiftData):**
- Purpose: A persisted row with relationships, cascade rules, and `#Index` / `#Unique` macros.
- Examples: `fitbod/Models/Exercise.swift`, `Routine.swift`, `Session.swift`, `SessionExercise.swift`, `SetEntry.swift`, `Block.swift`, `BlockPhase.swift`, `UserSettings.swift`, `MuscleGroup.swift`, `ExerciseMuscleStimulus.swift`, `MuscleVolumeTarget.swift`, `RoutineExercise.swift`, `RoutineExerciseSetOverride.swift`, `RoutineFolder.swift`, `SupersetGroup.swift`, `PlateInventory.swift`.
- Pattern: every enum-typed field stored as `*Raw: String` with a computed accessor in an extension (`Exercise.equipment`, `Session.intent`, etc.). Every field has a literal default so additive lightweight migrations succeed (FOUND-02).

**Draft (form holder):**
- Purpose: Ephemeral, in-memory mutation surface for builder/editor flows. Validates with `isValid`; projects onto `@Model` rows in `save(into:context:)`.
- Examples: `fitbod/Routines/RoutineDraft.swift`, `fitbod/Periodization/BlockDraft.swift`, `fitbod/Periodization/BlockPhaseDraft.swift`, `fitbod/ExerciseLibrary/CustomExerciseDraft.swift`, `fitbod/Routines/RoutineFolderDraft.swift`.
- Pattern: `@Observable final class`, bound to views via `@Bindable`, owned by the view via `@State`.

**Strategy (pure):**
- Purpose: Pluggable algorithm with no ctx coupling. Caller pre-fetches inputs.
- Examples: `ProgressionStrategy` (`fitbod/Prescription/ProgressionStrategy.swift`) with 4 conformers; `FatigueAdvisory` / `StubFatigueAdvisory`.
- Pattern: `Sendable` protocol, value-type conformers, dispatched by a `*Factory` namespace enum.

**`@ModelActor` worker:**
- Purpose: Off-main batch SwiftData work.
- Examples: `ExerciseLibraryImporter` (seed), `ExportService` (CSV/JSON render), `BackupArchiver` (zip + manifest).
- Pattern: Macro synthesizes a private `ModelContext` on its own executor; caller awaits.

## Entry Points

**`@main` app:**
- Location: `fitbod/fitbodApp.swift`.
- Triggers: iOS launch.
- Responsibilities: Build the shared `ModelContainer`; host `RootView` in a `WindowGroup`.

**`@main` widget extension:**
- Location: `FitbodWidgets/FitbodWidgetsBundle.swift`.
- Triggers: WidgetKit / ActivityKit host process.
- Responsibilities: Register `RestTimerLiveActivity`. Driven by the main app via `Activity<RestTimerAttributes>.request(...)` from `RestTimerActivityController`.

**Root view:**
- Location: `fitbod/App/RootView.swift`.
- Triggers: First scene render.
- Responsibilities: Run one-shot seeds inside `.task`; switch between splash and tab bar; own the Progress tab's `NavigationPath`.

## Architectural Constraints

- **Threading:** Main-actor SwiftUI + main-actor `ModelContext`. All batch writes off-main via `@ModelActor`. `RestTimerEngine` is explicitly `@MainActor` and `@Observable`. ActivityKit imported with `@preconcurrency` and `ContentState` constructed inside the `Task` body (Swift 6 + ActivityKit pattern — see project memory).
- **Global state:** None. The container is owned by `fitbodApp` and threaded through `\.modelContext`. No service-locator singletons.
- **Tab host shape:** `RootView` does NOT use `TabView`. It uses a `VStack` with a `Group` switch over `selectedTab` plus a `BRUTabBar` cell below (see `RootView.tabBar`, lines 169–206). Reason documented inline: `.toolbar(.hidden, for: .tabBar)` only works inside a NavigationStack and `.toolbarBackground(.hidden, …)` hides only the blur layer.
- **NavigationStack ownership:** One per tab, hosted inside the tab's root view. `RootView` owns the Progress tab's `NavigationPath` so re-tap can clear it.
- **Single active session invariant:** `SessionFactory.start(...)` throws `activeSessionAlreadyExists` if any `Session.completedAt == nil` row exists. Enforced by `SingleActiveBlockInvariantTests` and `ActiveSessionConflictTests`.
- **Migration plan registration:** `FitbodSchemaMigrationPlan.schemas` MUST include every historical schema (`SchemaV1.self … SchemaV6.self`) — SwiftData walks pre-V6 stores forward through the chain. `stages` is `[migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6]`; V3→V4 (intent/progression hoist) and V5→V6 (plateauTolerance default bump) are custom, the rest are lightweight.
- **Snapshot decoupling:** `Session.sourceRoutineID` is a `UUID?`, NOT a `@Relationship`. `RoutineFolder` and `SupersetGroup` use soft `UUID` references too. Deleting templates/folders/groups never cascades into logged history.
- **Cascade map (canonical):** `Exercise → ExerciseMuscleStimulus` cascade; `Exercise → SessionExercise` nullify (historical sessions retain a nil `exercise` ref); `Routine → RoutineExercise → RoutineExerciseSetOverride` cascade; `Session → SessionExercise → SetEntry` cascade; `Block → BlockPhase` cascade; `Block → Routine`, `Block → Session` nullify.
- **Live Activity rate limit:** `RestTimerActivityController.update(...)` debounces back-to-back updates (default 200 ms) per RESEARCH §6 Pitfall 9.

## Anti-Patterns

### Wrapping `@Query` in a view model

**What happens:** A separate `@Observable` "view model" fetches `@Query` results and re-exposes them.
**Why it's wrong:** SwiftUI's `@Query` reactivity is view-driven; hiding it behind an `@Observable` wrapper loses automatic re-render on store changes. CLAUDE.md calls this out explicitly.
**Do this instead:** Put `@Query` directly in the view. Use drafts (`fitbod/Routines/RoutineDraft.swift`) for ephemeral form state, not for wrapping queries.

### Predicate traversal of `[ExerciseMuscleStimulus]`

**What happens:** A filter predicate tries to walk `Exercise → muscleStimuli → muscle.slug`.
**Why it's wrong:** SwiftData's NSPredicate translator can't index/traverse many-to-many joins cleanly (PITFALLS #3).
**Do this instead:** Use the denormalized indexed string `Exercise.primaryMuscleSlugsJoined` (e.g., `"|chest|triceps|"`) with `.contains("|chest|")`. Populated at seed time in `ExerciseLibraryImporter`.

### Building `ContentState` outside the `Task` body for Live Activities

**What happens:** Capture `ContentState` from outer scope, hand into ActivityKit.
**Why it's wrong:** Swift 6 strict concurrency rejects the captured Sendable boundary; runtime crashes on iOS 18 ActivityKit.
**Do this instead:** `@preconcurrency import ActivityKit` and build `ContentState` + `ActivityContent` inside the `Task { … }` body. Pattern enforced in `RestTimerLiveActivity` and `RestTimerActivityController`.

### `Task { @MainActor in ... ctx.insert(...) }` for batch writes

**What happens:** Inserting hundreds of `@Model` rows on the main actor via a closure.
**Why it's wrong:** Blocks the main thread for >1 s on cold seed (PITFALLS #6), and risks autosave races against the main context.
**Do this instead:** Wrap the work in a `@ModelActor` class (`ExerciseLibraryImporter`, `ExportService`, `BackupArchiver`). The macro synthesizes a private context on its own executor.

### Bypassing `SessionFactory` to build a `Session` ad-hoc

**What happens:** Constructing `Session()` + `SessionExercise()` rows directly from a `Routine` reference.
**Why it's wrong:** Loses the snapshot semantics (a future template rename rewrites past sessions) and skips the single-active-session guard, the prescription prefill, and the empty-routine guard.
**Do this instead:** `SessionFactory.start(routine:date:context:)` is the only sanctioned entry point.

## Error Handling

**Strategy:** Typed `throws` at the boundary of every batch write, surfaced to the UI as alerts.

**Patterns:**
- `ExerciseLibraryImporter` throws `SeedError` (`fitbod/ExerciseLibrary/SeedError.swift`). `RootView.runSeed` logs via `OSLog` and flips `seedState.phase = .failed(message:)` but still renders the tab bar — historical `@Query` data is unaffected on later launches.
- `SessionFactory.start(...)` throws `activeSessionAlreadyExists` / `routineHasNoExercises` (UI-SPEC "Couldn't Start Workout" alert).
- `BackupRestorer` exposes `RestoreError` cases (`fitbod/Backup/BackupRestorer.swift`) gated by a two-step destructive confirm in `SettingsView`.
- App-init failure is `fatalError` — the on-disk store being un-openable is unrecoverable.

## Cross-Cutting Concerns

**Logging:** Apple `OSLog` via `os.Logger`. Subsystem `com.fitbod.app`, categories like `"seed"` (see `RootView.log`). No third-party analytics.
**Validation:** Done in drafts (`isValid: Bool`) and in factory throws (`SessionFactory`, `BlockBuilderView` save path).
**Authentication:** None — single-user personal app.
**Theming:** BRU tokens in `fitbod/Design/Color+BRU.swift` (12 adaptive light/dark colorsets in `Assets.xcassets`) and `fitbod/Design/BRUFont.swift` (7 semantic roles over Space Grotesk + JetBrains Mono). Banned-token enforcement is grep-test driven; see `BRUGrepAuditTests`, `Phase3BRUGrepAuditTests`, `BRUPhase5GrepAuditTests`, `BRUGrepAuditPhase6Tests` under `fitbodTests/`.
**Concurrency:** Swift 6 strict concurrency on. Background work via `@ModelActor`. Live Activity via `@preconcurrency import ActivityKit`.

## SwiftData Schema Map (current = V6, 16 entities)

| Entity | Key relationships | Cascade |
|--------|-------------------|---------|
| `Exercise` | → `[ExerciseMuscleStimulus]` (inverse), `#Index` on canonicalName + filters | cascade to stimuli |
| `MuscleGroup` | → `[ExerciseMuscleStimulus]`, → `[MuscleVolumeTarget]`; `#Unique` on slug | cascade to both |
| `ExerciseMuscleStimulus` | belongsTo `Exercise` + `MuscleGroup`; carries `weight: Double`, `role`, `userEditedWeight` | — |
| `Routine` | → `[RoutineExercise]`, optional `block: Block?`, soft `folderID: UUID?` | cascade to RoutineExercise |
| `RoutineExercise` | belongsTo `Routine` + `Exercise`; → `[RoutineExerciseSetOverride]`; soft `supersetGroupID: UUID?` | cascade to overrides |
| `RoutineExerciseSetOverride` | belongsTo `RoutineExercise` | — |
| `RoutineFolder` | (no relationships) — soft-linked via `Routine.folderID` | — |
| `SupersetGroup` | (no relationships) — soft-linked via UUIDs both directions | — |
| `Session` | soft `sourceRoutineID: UUID?`, optional `block: Block?`, → `[SessionExercise]`; `#Index` on startedAt + sourceRoutineID + intentRaw | cascade to SessionExercise |
| `SessionExercise` | belongsTo `Session` + `Exercise` (nullify); → `[SetEntry]` | cascade to SetEntry |
| `SetEntry` | belongsTo `SessionExercise`; `#Index` on completedAt | — |
| `Block` | → `[BlockPhase]`, ← `[Routine]`, ← `[Session]` | cascade phases; nullify routines/sessions |
| `BlockPhase` | belongsTo `Block` | — |
| `UserSettings` | singleton row | — |
| `MuscleVolumeTarget` | belongsTo `MuscleGroup`; MEV/MAV/MRV/MV + `userEdited` flag | — |
| `PlateInventory` | one row per `PlateEquipmentKind` | — |

**Versioned schema chain:** `SchemaV1 → V2 (folders, supersets) → V3 (+PlateInventory + per-exercise warmup overrides) → V4 (PIVOT-03: intent/progressionKind hoist Routine/Session → Routine/Session via CUSTOM migration in `backfillSessionLevelFields`) → V5 (Block.reviewedAt) → V6 (8 additive fields + CUSTOM willMigrate to retroactively bump UserSettings.plateauTolerance default 0.005→0.02).` All steps registered in `FitbodSchemaMigrationPlan.schemas`.

**Migration test gate:** `fitbodTests/SchemaV4MigrationTests.swift` is the canonical correctness gate for the V3→V4 custom backfill (mode-of-children with `.strength` / `.double` tie-break, via `FitbodSchemaMigrationPlan.modeRaw(of:tieBreak:)`). `fitbodTests/SchemaV1Tests.swift`, `SchemaV2MigrationTests.swift`, `SchemaV3MigrationTests.swift`, `fitbodTests/Persistence/SchemaV6MigrationTests.swift` cover the rest of the chain.

## Confidence

- **Direct-read (high confidence):** every claim about `fitbodApp.swift`, `App/RootView.swift`, `App/SeedState.swift`, `Persistence/FitbodSchemaMigrationPlan.swift`, `Persistence/PreviewModelContainer.swift`, `Persistence/SchemaV6.swift`, every `Models/*.swift` entity, `Design/Color+BRU.swift`, `Design/BRUFont.swift`, `Prescription/ProgressionStrategy.swift`, `Prescription/ProgressionStrategyFactory.swift`, `Prescription/PeriodizationEngine.swift`, `Sessions/SessionFactory.swift`, `Sessions/SessionLoggerView.swift`, `Sessions/SessionExerciseCard.swift`, `Sessions/RestTimer/RestTimerEngine.swift`, `Sessions/RestTimer/RestTimerActivityController.swift`, `ExerciseLibrary/ExerciseLibraryImporter.swift`, `Routines/RoutineBuilderView.swift`, `Routines/RoutineDraft.swift`, `Routines/PrescriptionEditorRow.swift`, `Periodization/ProgramView.swift`, `Periodization/BlockBuilderView.swift`, `Progress/ProgressHomeView.swift`, `Settings/SettingsView.swift`, `Views/TodayView.swift`, `Fatigue/FatigueModel.swift`, `FitbodWidgets/FitbodWidgetsBundle.swift`, `FitbodWidgets/RestTimerLiveActivity.swift`.
- **Inferred from filename patterns + spot reads:** the per-feature folder boundaries (e.g., that `Fatigue/` houses both math and views, that `Prescription/` houses all 4 strategies); the count of feature-folder Swift files (counted via `find | wc -l`); the precise `@ModelActor`/`@Observable` usage was verified via a repo-wide grep but not every file was opened.
- **Inferred from comments:** the deeper history (PIVOT-03 backfill semantics, RESEARCH § Pitfall references) is quoted from in-file headers — believed accurate but the actual RESEARCH / PITFALLS docs were not opened.
