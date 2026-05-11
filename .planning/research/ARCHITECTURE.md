# Architecture Research

**Domain:** Single-user iOS bodybuilding/weight-training tracker (SwiftUI + SwiftData, local-only)
**Researched:** 2026-05-10
**Confidence:** HIGH on SwiftData / SwiftUI patterns and on the workout domain model. MEDIUM on the exact numeric formulas baked into progression and plateau detection (these are deliberately swappable behind protocols, so the values can be tuned later without architectural change).

---

## Architectural Stance (read this first)

Three opinionated decisions drive everything below. Naming them up front because they each cut down later debate.

1. **MV-VM-lite, not classic MVVM.** SwiftData's `@Model` types are the source of truth, queried directly from views with `@Query` / `@Bindable`. Cross-cutting logic that does *not* belong on a single model (progression math, fatigue rollups, plateau scoring, warm-up generation) lives in **stateless service types** that take a `ModelContext` and operate over models. This is the pattern Apple's own SwiftData sample apps use, and it's what `@Observable` + `@Bindable` is designed for. We do not build a parallel "ViewModel + DTO" layer that mirrors the SwiftData schema — that's the architectural anti-pattern that wastes the most time in SwiftData apps and breaks `@Query` reactivity.
2. **Template vs Instance via snapshot-and-decouple.** A `Routine` (template) is a reusable plan. Starting a workout creates a `Session` that **copies** the template's exercise list and prescription into `SessionExercise` rows. From that point, editing the template never mutates historical sessions, and editing a logged session never mutates the template. This is the Martin Fowler "Snapshot" pattern adapted for SwiftData. No event sourcing — just immutable copies at session-start time.
3. **Progression and fatigue are pure functions behind protocols.** `ProgressionStrategy` and `FatigueModel` take inputs (history, prescription, settings) and return outputs (suggested weight, volume per muscle, plateau flag). They do **not** mutate SwiftData. The session logger calls them and writes the result. This makes all the hard math unit-testable without spinning up a `ModelContainer`, and makes the four progression algorithms hot-swappable per exercise or per block.

---

## System Overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│                              SwiftUI Views                                 │
│                                                                            │
│  ExerciseLibrary │ RoutineBuilder │ SessionLogger │ ProgressViews │ Settings│
│       View              View            View            View         View   │
│                                                                            │
│   (use @Query for reactive reads, @Bindable for model editing)             │
└─────────┬──────────────┬─────────────────┬─────────────┬──────────────────┘
          │              │                 │             │
          ▼              ▼                 ▼             ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                          Service Layer (stateless)                         │
│                                                                            │
│  ┌─────────────────┐ ┌─────────────────┐ ┌──────────────────────────────┐  │
│  │ProgressionEngine│ │  FatigueModel   │ │      PeriodizationEngine     │  │
│  │ (4 strategies)  │ │ (volume rollups)│ │ (block phase → set/intensity │  │
│  └─────────────────┘ └─────────────────┘ │  adjustment)                 │  │
│                                          └──────────────────────────────┘  │
│  ┌─────────────────┐ ┌─────────────────┐ ┌──────────────────────────────┐  │
│  │ WarmupGenerator │ │PlateauDetector  │ │      SessionFactory          │  │
│  │                 │ │ (rolling slope) │ │ (Template → Session snapshot)│  │
│  └─────────────────┘ └─────────────────┘ └──────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ ExerciseLibraryImporter  (one-shot seed from bundled JSON @ launch) │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────┬──────────────────────────────────────────────────────────────────┘
          │
          ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                        SwiftData Persistence Layer                         │
│                                                                            │
│  ModelContainer ──── ModelContext (main)                                   │
│         │                                                                  │
│         └──── ImportActor (@ModelActor)  ← background bulk inserts only    │
│                                                                            │
│  @Model entities:                                                          │
│   Exercise · MuscleGroup · ExerciseMuscleStimulus · Routine ·              │
│   RoutineExercise · Session · SessionExercise · SetEntry ·                 │
│   Block · BlockPhase · UserSettings · MuscleVolumeTarget                   │
└────────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Implementation |
|-----------|---------------|----------------|
| **ExerciseLibrary** (View + filter logic) | Browse/filter the 1000+ exercise catalog; create custom exercises | SwiftUI `List` + `@Query` with `#Predicate`, filter chips bound to `@State` |
| **RoutineBuilder** (View) | Build/edit `Routine` templates: pick exercises, set prescription, reorder | SwiftUI `List` with `.onMove`, `@Bindable Routine`, `NavigationStack` |
| **SessionLogger** (View) | Log a live workout: each set, RPE, rest timer, notes | Local `@State`, writes through to `SessionExercise.sets` |
| **SessionFactory** (Service) | Snapshot a `Routine` into a new `Session` at start time; resolves prescription via `ProgressionEngine` | Stateless `struct` taking `(Routine, ModelContext, Date, UserSettings) -> Session` |
| **ProgressionEngine** (Service) | Compute prescribed weight/reps for the upcoming set given history + intent + algorithm | Protocol `ProgressionStrategy` with 4 conforming `struct`s; selected at runtime via `ProgressionKind` enum on `RoutineExercise` or `Block` |
| **PeriodizationEngine** (Service) | Resolve which phase of which block "today" is; apply phase-level volume/intensity modifiers; schedule deloads | Stateless functions over `Block` + `Date` |
| **FatigueModel** (Service) | Compute weekly volume per muscle from `SetEntry` data using `ExerciseMuscleStimulus` weighting; compare against `MuscleVolumeTarget` (MEV/MAV/MRV); flag "consider deload" | Stateless `struct` with `weeklyVolume(in: DateInterval) -> [MuscleGroup: VolumeReport]` |
| **PlateauDetector** (Service) | Per-exercise, per-intent rolling slope of estimated 1RM over last N sessions; flag stalls | Stateless function: takes `[SessionExercise]` sorted by date, returns `PlateauSignal` |
| **WarmupGenerator** (Service) | Generate ascending warm-up ramp for first compound of session | Stateless: `[WarmupSet] = generate(forTopSet:Weight, scheme: WarmupScheme)` |
| **ProgressViews** (View) | Per-exercise charts (intent-split), PRs, weekly tonnage, muscle heatmap, volume bars | SwiftUI + Swift Charts, reads aggregates from `FatigueModel` and direct `@Query` |
| **ExerciseLibraryImporter** (Service) | One-time seed of the 1000+ exercises from a bundled JSON file on first launch | Runs inside an `@ModelActor` so the bulk insert doesn't block the main thread |

**Why a thin service layer instead of fat models or fat view models:**
- The hard math (progression, fatigue, plateau) is **cross-cutting** — it depends on multiple entity types and on settings. Putting it on any one `@Model` creates an awkward dependency graph.
- View models that mirror the schema add a translation layer that fights `@Query`'s reactive behavior. SwiftData's whole point is that the model layer *is* observable.
- Pure-function services are trivially unit-testable: feed them arrays of plain structs (or in-memory model instances) and assert on returns.

---

## SwiftData Entity Model

The full entity set. Relationships use SwiftData's `@Relationship` with explicit `inverse:` where needed. All entities are `final class` annotated with `@Model`. On iOS 18, `#Index` macros are added to the hot query paths (noted per entity).

### Core domain entities

```swift
// =====================================================
// Exercise Library
// =====================================================

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var canonicalName: String           // lowercased, normalized for search
    var equipmentRaw: String            // see Equipment enum
    var mechanicRaw: String             // compound / isolation
    var forceRaw: String?               // push / pull / static
    var levelRaw: String?               // beginner / intermediate / advanced
    var category: String                // strength, stretching, etc.
    var instructions: [String]          // bundled steps
    var isCustom: Bool                  // user-added vs seeded
    var createdAt: Date

    // One Exercise → many muscle stimulus links (primary + secondary, weighted)
    @Relationship(deleteRule: .cascade, inverse: \ExerciseMuscleStimulus.exercise)
    var muscleStimuli: [ExerciseMuscleStimulus] = []

    // Indexes on hot library filter paths
    #Index<Exercise>([\.canonicalName], [\.equipmentRaw], [\.mechanicRaw], [\.isCustom])
}

@Model
final class MuscleGroup {
    @Attribute(.unique) var id: String   // stable slug, e.g. "chest", "lats"
    var displayName: String
    var region: String                   // upper / lower / core (for heatmap grouping)

    @Relationship(deleteRule: .cascade, inverse: \ExerciseMuscleStimulus.muscle)
    var stimuli: [ExerciseMuscleStimulus] = []

    @Relationship(deleteRule: .cascade, inverse: \MuscleVolumeTarget.muscle)
    var volumeTargets: [MuscleVolumeTarget] = []
}

// Join entity carrying the stimulus weight: lets us say
// "barbell row" hits lats at 1.0 and biceps at 0.5
@Model
final class ExerciseMuscleStimulus {
    var exercise: Exercise?
    var muscle: MuscleGroup?
    var role: String                     // "primary" | "secondary"
    var weight: Double                   // 0.0 - 1.0 contribution per working set
}

// =====================================================
// Routines (templates)
// =====================================================

@Model
final class Routine {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    // Optional link to a block — a routine can belong to a training block
    var block: Block?

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var exercises: [RoutineExercise] = []
}

@Model
final class RoutineExercise {
    @Attribute(.unique) var id: UUID
    var routine: Routine?
    var exercise: Exercise?
    var orderIndex: Int                  // user-controlled order in routine

    // Prescription
    var intentRaw: String                // strength / hypertrophy / power / endurance
    var targetSets: Int
    var targetRepsLow: Int
    var targetRepsHigh: Int               // single rep target → low == high
    var targetRPE: Double?
    var targetRIR: Int?
    var prescribedRestSeconds: Int
    var tempo: String?                   // e.g. "3-1-1-0"
    var notes: String?

    // Which algorithm decides next weight for THIS exercise in THIS routine
    var progressionKindRaw: String       // rpe / double / block / hybrid
    var generateWarmups: Bool            // typically true on first compound only
}

// =====================================================
// Sessions (instances — immutable copies of routine state)
// =====================================================

@Model
final class Session {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var routineSnapshotName: String      // routine name at time of session
    var sourceRoutineID: UUID?           // weak link back to the template
    var block: Block?                    // which block this session was logged under
    var notes: String?
    var totalDurationSeconds: Int?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise] = []

    #Index<Session>([\.startedAt], [\.sourceRoutineID])
}

@Model
final class SessionExercise {
    @Attribute(.unique) var id: UUID
    var session: Session?
    var exercise: Exercise?               // the canonical exercise reference (kept live)
    var orderIndex: Int

    // Snapshotted prescription — copied from RoutineExercise at session start
    var intentRaw: String
    var targetSets: Int
    var targetRepsLow: Int
    var targetRepsHigh: Int
    var targetRPE: Double?
    var targetRIR: Int?
    var prescribedRestSeconds: Int
    var tempo: String?
    var progressionKindRaw: String

    // What was prescribed for THIS session, after progression resolution
    var prescribedWeight: Double?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    var sets: [SetEntry] = []

    #Index<SessionExercise>([\.intentRaw])    // intent-split history queries
}

@Model
final class SetEntry {
    @Attribute(.unique) var id: UUID
    var sessionExercise: SessionExercise?
    var orderIndex: Int                   // includes warm-ups; isWarmup distinguishes
    var weight: Double
    var reps: Int
    var rpe: Double?
    var rir: Int?
    var restAfterSeconds: Int?
    var tempoActual: String?
    var notes: String?
    var isWarmup: Bool
    var completedAt: Date
}

// =====================================================
// Periodization
// =====================================================

@Model
final class Block {
    @Attribute(.unique) var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date?                    // computed from phases, denormalized for query
    var notes: String?
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \BlockPhase.block)
    var phases: [BlockPhase] = []

    @Relationship(inverse: \Routine.block) var routines: [Routine] = []
    @Relationship(inverse: \Session.block) var sessions: [Session] = []
}

@Model
final class BlockPhase {
    @Attribute(.unique) var id: UUID
    var block: Block?
    var orderIndex: Int
    var nameRaw: String                   // accumulation / intensification / realization / deload
    var weeks: Int
    var volumeMultiplier: Double          // e.g. 1.0 baseline, 0.6 for deload
    var intensityMultiplier: Double       // e.g. 0.85 vs 1.0
    var notes: String?
}

// =====================================================
// User settings & volume targets
// =====================================================

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID = UUID()  // singleton row
    var unitsRaw: String                  // kg / lb
    var defaultProgressionKindRaw: String
    var warmupSchemeRaw: String           // standard / aggressive / custom
    var customWarmupPercents: [Double]?   // when scheme = custom
    var plateauWindowSessions: Int        // default 4
    var plateauTolerance: Double          // e.g. <0.5% e1RM trend = stalled
    var deloadAlertEnabled: Bool
    var weekStartsMonday: Bool
}

@Model
final class MuscleVolumeTarget {
    @Attribute(.unique) var id: UUID
    var muscle: MuscleGroup?
    var mev: Int                          // sets per week
    var mav: Int
    var mrv: Int
    var mv: Int                           // maintenance
    var notes: String?
}
```

### Entity relationship diagram (logical)

```
Exercise ──┬──< ExerciseMuscleStimulus >──┬── MuscleGroup ──< MuscleVolumeTarget
           │                              │
           │                              └── (heatmap, volume bars)
           │
           ├──< RoutineExercise >── Routine ──> Block
           │                                     │
           └──< SessionExercise >── Session ─────┤
                       │                         │
                       └──< SetEntry             │
                                                 │
                                       Block ──< BlockPhase

UserSettings (singleton)
```

### Indexing strategy (iOS 18+)

| Entity | Indexed key paths | Why |
|--------|-------------------|-----|
| `Exercise` | `canonicalName`, `equipmentRaw`, `mechanicRaw`, `isCustom` | Library filter UX hits these on every keystroke / chip toggle |
| `Session` | `startedAt`, `sourceRoutineID` | Calendar views, "history of this routine" |
| `SessionExercise` | `intentRaw` | Intent-split charts are *the* feature — they need to be fast |
| `SetEntry` | `completedAt` (implicit through SessionExercise.session.startedAt) | Volume rollups by week |

If targeting iOS 17 alongside iOS 18, gate `#Index` declarations with `#if available(iOS 18, *)` and accept slower queries on iOS 17 — there's no shim.

### Why enums are stored as `*Raw: String`

SwiftData's enum persistence has known sharp edges around `rawValue` evolution. Storing as `String` columns and providing computed `var intent: Intent` accessors keeps migrations lightweight (most enum additions become non-breaking) and avoids the gotcha where changing an enum's `RawValue` type silently changes on-disk layout.

### Template-vs-instance: the snapshot decision in concrete terms

When the user taps "Start workout" on a Routine:

1. `SessionFactory.start(routine:date:context:settings:)` creates a `Session`.
2. For each `RoutineExercise` in `routine.exercises`, it creates a `SessionExercise` and **copies** every prescription field (intent, target reps, target RPE, rest, tempo, progression kind).
3. It calls `ProgressionEngine.suggestWeight(for: sessionExercise, history: ...)` and stores the result on `sessionExercise.prescribedWeight`.
4. The user logs `SetEntry`s into that `SessionExercise`.

Consequence: editing the `Routine` template tomorrow does **not** rewrite yesterday's session. Deleting the `Routine` does **not** delete its sessions — `Session.sourceRoutineID` is a soft `UUID?` reference, not a SwiftData relationship with a delete rule. Editing a *logged* `SessionExercise` (e.g., correcting a typo) only mutates that session.

This is intentionally NOT event sourcing. We don't keep an immutable event log of every edit; we just snapshot at session-start and accept that post-session edits are destructive to that session's history.

---

## Where Logic Lives (the decision table)

| Concern | Model | Service | View / ViewModel |
|---------|-------|---------|------------------|
| Persistence, relationships, cascade | Model | — | — |
| Trivial derived values (e.g. `Session.totalVolume`) | Model (computed property) | — | — |
| Filter the library by muscle/equipment | — | — | View (`@Query` with `#Predicate`) |
| Snapshot a Routine into a Session | — | `SessionFactory` | — |
| Choose next-set weight (the 4 algorithms) | — | `ProgressionEngine` + `ProgressionStrategy` | — |
| Generate warm-up sets | — | `WarmupGenerator` | — |
| Compute weekly volume per muscle | — | `FatigueModel` | — |
| Compare volume to MEV/MAV/MRV thresholds | — | `FatigueModel` (returns `VolumeReport`) | View (renders colors) |
| Detect plateau on an exercise | — | `PlateauDetector` | — |
| Resolve current block phase for today | — | `PeriodizationEngine` | — |
| Apply phase volume/intensity multipliers to prescription | — | `PeriodizationEngine` (wraps `ProgressionEngine`) | — |
| Chart per-exercise history with intent split | — | (no service — direct `@Query`) | View + Swift Charts |
| Muscle heatmap shading | — | `FatigueModel.heatmapData()` | View |
| Rest timer | — | — | View (`Timer` in `@State`) |
| Seed exercise library on first launch | — | `ExerciseLibraryImporter` (inside `@ModelActor`) | — |

**Rule of thumb:** if a piece of logic touches **one entity**, put it on the model. If it touches **multiple entities or settings**, put it in a service. View bodies should never do math beyond formatting.

---

## Critical Service Design: ProgressionStrategy

This is the hardest part. The architecture intentionally separates "what algorithm to use" from "how to apply it."

```swift
protocol ProgressionStrategy {
    /// Pure function. No SwiftData writes. No side effects.
    /// Returns the prescribed weight for the next session of this exercise,
    /// or nil if there isn't enough history yet (caller falls back to user-entered).
    func suggestWeight(
        for sessionExercise: SessionExercise,
        history: [HistoryEntry],          // pre-built array, sorted recent-first
        settings: UserSettings,
        phase: BlockPhase?
    ) -> ProgressionSuggestion?
}

struct HistoryEntry {
    let date: Date
    let intent: Intent
    let topSet: SetSummary               // weight, reps, RPE achieved
    let allWorkingSets: [SetSummary]
    let estimated1RM: Double
}

struct ProgressionSuggestion {
    let prescribedWeight: Double
    let rationale: String                 // shown in UI: "+5lb from last (RPE 7 → target 8)"
    let confidence: Confidence            // high / medium / low — affects UI styling
}
```

Four concrete implementations:

| Strategy | Logic summary | Inputs that matter most |
|----------|---------------|-------------------------|
| `RPEAutoregStrategy` | Back-calculate user's current e1RM from last session's actual RPE + reps via Tuchscherer RPE table, then prescribe load for `targetRPE × targetReps` | Last 1-3 sessions, target RPE, target reps |
| `DoubleProgressionStrategy` | If last session hit top of rep range at all working sets → add increment (2.5lb iso / 5lb compound). Else hold weight, push for more reps. | Last session only, rep range, weight increment |
| `BlockPeriodizedStrategy` | Phase-driven curve: accumulation = e1RM × phase.volumeMultiplier; intensification = e1RM × phase.intensityMultiplier on lower reps; deload = 60% of accumulation. | Current `BlockPhase`, baseline e1RM |
| `HybridStrategy` | `BlockPeriodizedStrategy` sets the macro target; `RPEAutoregStrategy` adjusts ±5% based on yesterday's RPE delta | Both inputs |

Selection happens via `ProgressionKind` enum on `RoutineExercise` (and falls back to `UserSettings.defaultProgressionKindRaw`). A small factory resolves it:

```swift
enum ProgressionKind: String { case rpe, double, block, hybrid }

struct ProgressionEngine {
    static func strategy(for kind: ProgressionKind) -> ProgressionStrategy {
        switch kind {
        case .rpe:    return RPEAutoregStrategy()
        case .double: return DoubleProgressionStrategy()
        case .block:  return BlockPeriodizedStrategy()
        case .hybrid: return HybridStrategy()
        }
    }
}
```

**Why this shape:** every strategy is a value type, every input is plain Swift, every output is plain Swift. Unit tests are trivially `XCTAssertEqual(strategy.suggestWeight(...)?.prescribedWeight, 142.5)` with no `ModelContainer` setup. Adding a fifth algorithm is one new file.

---

## Critical Service Design: FatigueModel

```swift
struct FatigueModel {
    /// Returns weekly volume per muscle for a date range.
    /// Pure function over SetEntry data — does not mutate.
    func weeklyVolume(
        in range: DateInterval,
        sets: [SetEntry],
        stimulusByExercise: [UUID: [ExerciseMuscleStimulus]]
    ) -> [MuscleGroup.ID: WeeklyVolumeReport]

    /// For the heatmap: how "hot" is each muscle group right now,
    /// considering last 7d sets and decay.
    func heatmapIntensity(
        forSets sets: [SetEntry],
        asOf date: Date,
        decayHalfLifeHours: Double = 48
    ) -> [MuscleGroup.ID: Double]          // 0.0 - 1.0

    /// Returns deload recommendation if multi-muscle MRV breach or
    /// performance drop is detected.
    func deloadRecommendation(...) -> DeloadSignal?
}

struct WeeklyVolumeReport {
    let muscle: MuscleGroup.ID
    let workingSets: Double                 // weighted by ExerciseMuscleStimulus.weight
    let zone: VolumeZone                    // belowMEV / inMEV-MAV / approachingMRV / overMRV
    let target: MuscleVolumeTarget
}
```

The key insight is that each working `SetEntry` doesn't count as "1 set for biceps" if the exercise is, say, a barbell row — it counts as `1.0 × biceps_weight` where `biceps_weight` is set on the `ExerciseMuscleStimulus` join row (typically 0.3–0.5 for secondary muscles, 1.0 for primary). This is what makes the RP-style tracking actually accurate for compounds.

`FatigueModel` is called from:
- `ProgressViews` (volume bars, heatmap, deload alert)
- `PeriodizationEngine` (to know if "consider deload" should fire)

---

## Data Flow

### Starting a session (the critical path)

```
[User taps "Start" on Routine]
        ↓
[RoutineDetailView] ──→ SessionFactory.start(routine, context, settings)
                              │
                              │ creates Session row
                              │ for each RoutineExercise:
                              │   - creates SessionExercise (snapshot fields)
                              │   - calls PeriodizationEngine.resolvePhase(date)
                              │   - calls ProgressionEngine.strategy(for: kind)
                              │             .suggestWeight(sessionExercise, history, settings, phase)
                              │   - sets sessionExercise.prescribedWeight
                              │   - if firstCompound && generateWarmups:
                              │       WarmupGenerator.generate(forTopSet: weight) → SetEntry rows w/ isWarmup=true
                              │
                              ↓
                       ModelContext.save()
                              ↓
[SessionLoggerView] re-renders via @Query
```

### Logging a set

```
[User taps "Log set" with weight, reps, RPE]
        ↓
[SetEntryView] ──→ creates SetEntry, appends to sessionExercise.sets
        ↓
ModelContext.save() (autosave handles this)
        ↓
@Query re-runs in PR/volume views ─→ live update
```

### Reactivity model

SwiftUI views observe SwiftData via `@Query` and `@Bindable`. There is no manual notification, no `Combine.Publisher` plumbing, no event bus. When the session logger writes a `SetEntry`, the muscle heatmap (in a separate tab/view) re-queries and re-renders automatically because `@Query` is wired into the model context's change stream.

Services that compute aggregates (e.g., `FatigueModel.weeklyVolume`) are called **inside** view bodies — `let report = FatigueModel.shared.weeklyVolume(...)` — and re-run whenever their input `@Query` re-emits. This is fine for the scale we're at (a few thousand sets total across many months). If it becomes a problem, the migration path is to wrap the aggregation in a `@Observable` view-scoped object that caches.

---

## Concurrency Model

- **Main actor:** every `ModelContext` access from views is on `@MainActor`. SwiftUI hosts this for free.
- **Background actor:** **one** `@ModelActor` for the exercise-library seed import. The 1000+ exercise insert happens once, on first launch, off the main thread.
- **Services:** the math services (`ProgressionEngine`, `FatigueModel`, `PlateauDetector`) are deliberately **synchronous** and **stateless**. They do not need an actor. They take inputs and return outputs. Calling them from the main thread is fine because the algorithms are O(N) over small N (history windows of dozens of sessions, not millions).
- **What we do NOT do:** we do not push session logging or progression calculation off the main thread. The data volumes are tiny and the perceived-latency cost of actor-hopping during a live workout (where the user is mid-set) is real. Keep it simple, keep it on main.

```swift
@ModelActor
actor ExerciseLibraryImporter {
    func seedIfNeeded() async throws {
        let count = try modelContext.fetchCount(FetchDescriptor<Exercise>())
        guard count == 0 else { return }
        let data = Bundle.main.url(forResource: "exercises", withExtension: "json")
        // decode and bulk insert; ModelActor serializes this off main
    }
}
```

---

## Recommended Xcode Project Structure

```
fitbod/
├── fitbodApp.swift                       # @main, ModelContainer setup, first-launch seed
├── App/
│   ├── RootView.swift                    # TabView: Train | Library | Progress | Settings
│   └── AppEnvironment.swift              # Settings singleton bootstrap
│
├── Models/                               # SwiftData @Model types — one file per entity
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
│       ├── Intent.swift
│       ├── ProgressionKind.swift
│       ├── Equipment.swift
│       ├── Mechanic.swift
│       └── BlockPhaseKind.swift
│
├── Services/                             # Stateless cross-cutting logic
│   ├── Progression/
│   │   ├── ProgressionStrategy.swift     # protocol
│   │   ├── RPEAutoregStrategy.swift
│   │   ├── DoubleProgressionStrategy.swift
│   │   ├── BlockPeriodizedStrategy.swift
│   │   ├── HybridStrategy.swift
│   │   ├── ProgressionEngine.swift       # factory + history builder
│   │   └── RPETable.swift                # Tuchscherer table → percentages
│   ├── Fatigue/
│   │   ├── FatigueModel.swift
│   │   ├── VolumeZone.swift
│   │   └── WeeklyVolumeReport.swift
│   ├── Periodization/
│   │   └── PeriodizationEngine.swift
│   ├── Warmup/
│   │   ├── WarmupGenerator.swift
│   │   └── WarmupScheme.swift
│   ├── Plateau/
│   │   └── PlateauDetector.swift
│   ├── Session/
│   │   └── SessionFactory.swift
│   ├── Library/
│   │   └── ExerciseLibraryImporter.swift # @ModelActor
│   └── Math/
│       ├── OneRepMaxEstimator.swift      # Epley / Brzycki — start with Epley
│       └── RollingSlope.swift            # used by PlateauDetector
│
├── Features/                             # SwiftUI views, grouped by feature
│   ├── ExerciseLibrary/
│   │   ├── ExerciseLibraryView.swift
│   │   ├── ExerciseDetailView.swift
│   │   ├── ExerciseFilterChips.swift
│   │   └── CustomExerciseEditor.swift
│   ├── Routines/
│   │   ├── RoutineListView.swift
│   │   ├── RoutineBuilderView.swift
│   │   ├── RoutineExerciseEditor.swift
│   │   └── PrescriptionPickers.swift     # intent, RPE, rep range pickers
│   ├── Sessions/
│   │   ├── SessionLoggerView.swift
│   │   ├── SetLogger.swift
│   │   ├── RestTimerView.swift
│   │   └── SessionSummaryView.swift
│   ├── Periodization/
│   │   ├── BlockListView.swift
│   │   ├── BlockBuilderView.swift
│   │   └── BlockPhaseEditor.swift
│   ├── Progress/
│   │   ├── ProgressDashboardView.swift
│   │   ├── ExerciseHistoryChart.swift    # intent-split
│   │   ├── PRsView.swift
│   │   ├── WeeklyTonnageChart.swift
│   │   ├── MuscleHeatmapView.swift       # body silhouette
│   │   └── VolumeBarsView.swift          # MEV/MAV/MRV bars
│   └── Settings/
│       ├── SettingsView.swift
│       └── VolumeTargetsEditor.swift
│
├── Resources/
│   └── exercises.json                    # bundled free-exercise-db seed
│
└── Support/
    ├── PreviewData.swift                 # in-memory ModelContainer + sample data
    └── DateMath.swift                    # week boundaries, etc.

fitbodTests/
├── ProgressionStrategyTests.swift        # the four algorithms
├── FatigueModelTests.swift               # volume rollup math
├── PlateauDetectorTests.swift            # rolling slope cases
├── WarmupGeneratorTests.swift
├── SessionFactoryTests.swift             # snapshot integrity
└── OneRepMaxEstimatorTests.swift

fitbodUITests/
├── RoutineBuilderUITests.swift
├── SessionLoggerUITests.swift
└── LaunchPerformanceTests.swift
```

### Structure rationale

- **`Models/` vs `Features/` separation:** SwiftData entities are the schema; they don't belong inside any one feature folder because three features touch them. Keeping them flat makes migrations and relationship debugging easier.
- **`Services/` grouped by domain:** keeps `ProgressionStrategy` and its four implementations together; same for fatigue, warmup, plateau. Easy to find "where is the math for X."
- **`Features/` grouped by user-facing area:** matches the tab bar. A new dev opening the project should be able to find every screen by tab name.
- **`Resources/exercises.json`:** the bundled seed — see PITFALLS.md for the "ship pre-baked store vs ship JSON" tradeoff.

---

## Architectural Patterns

### Pattern 1: Snapshot at Boundary (Template → Instance)

**What:** When a workflow transitions from "plan" to "execution," copy the relevant plan data into the execution row at boundary time. Don't reference the plan by relationship if the plan is mutable.

**When:** Any time a "template" can be edited after instances have been created and you don't want retroactive mutation.

**Trade-offs:** Slightly higher write cost at session start (copying ~5–10 RoutineExercise fields to SessionExercise). Some data duplication. Massive simplification of "what did I prescribe back then" semantics — the answer is on the row, always.

```swift
// SessionFactory.swift
static func start(routine: Routine, on date: Date, context: ModelContext,
                  settings: UserSettings) -> Session {
    let session = Session(startedAt: date,
                          routineSnapshotName: routine.name,
                          sourceRoutineID: routine.id,
                          block: routine.block)
    context.insert(session)

    for (i, re) in routine.exercises.sorted(by: \.orderIndex).enumerated() {
        let se = SessionExercise(
            session: session,
            exercise: re.exercise,
            orderIndex: i,
            intentRaw: re.intentRaw,
            targetSets: re.targetSets,
            targetRepsLow: re.targetRepsLow,
            targetRepsHigh: re.targetRepsHigh,
            targetRPE: re.targetRPE,
            targetRIR: re.targetRIR,
            prescribedRestSeconds: re.prescribedRestSeconds,
            tempo: re.tempo,
            progressionKindRaw: re.progressionKindRaw
        )
        context.insert(se)

        let kind = ProgressionKind(rawValue: re.progressionKindRaw) ?? .double
        let strategy = ProgressionEngine.strategy(for: kind)
        let history = HistoryBuilder.build(for: re.exercise, intent: se.intent, context: context)
        let phase = PeriodizationEngine.phase(for: routine.block, on: date)
        se.prescribedWeight = strategy.suggestWeight(
            for: se, history: history, settings: settings, phase: phase
        )?.prescribedWeight
    }
    return session
}
```

### Pattern 2: Strategy via Protocol (the four progression algorithms)

**What:** A protocol with one method, four conforming value types, a factory that hands you one.

**When:** Any time there's a swap-by-config algorithm choice. Critical for the progression algorithm requirement.

**Trade-offs:** One more layer of indirection. Pays for itself the moment you add the second algorithm — and we're starting with four.

### Pattern 3: Stateless Service over Model Context

**What:** Services are `struct`s with `static` methods or instance methods that take everything they need. No stored state, no `var`s. They take a `ModelContext` (or just plain `[SetEntry]`) and return values.

**When:** Cross-cutting logic that touches multiple entities or settings.

**Trade-offs:** Less encapsulation than OO. Much easier to test. No retain-cycle risk. No accidental shared mutable state.

### Pattern 4: Stimulus-Weighted Aggregation

**What:** Don't model "muscle gets 1 set." Model "exercise contributes weight `w` to muscle." Then aggregation = `Σ w` per muscle per week.

**When:** Volume tracking for compound exercises that hit multiple muscles.

**Trade-offs:** Requires curating the stimulus weights for ~1000 exercises (or accepting defaults from the seed dataset — and free-exercise-db already provides primary/secondary lists; we map primary → 1.0, secondary → 0.5 as a starting heuristic).

---

## Build Order

Each step depends on the previous; each lands on a stable foundation before the next starts. This ordering is what the roadmap should mirror.

### Foundation
1. **Schema + ModelContainer wiring.** Replace the stock `Item` model with the full `@Model` set above. Wire the `Schema` into `fitbodApp.swift`. Build empty preview data. No UI logic yet — just compile and seed an in-memory container with five hand-crafted exercises and verify relationships work.

   *Stable when:* container builds, you can `context.insert()` and `@Query` a model from a SwiftUI preview.

2. **Exercise library seed pipeline.** Add `exercises.json` (free-exercise-db dist) to the bundle. Implement `ExerciseLibraryImporter` inside a `@ModelActor`. On first launch, if the Exercise count is 0, run the seed. Verify 1000+ rows present after first launch.

   *Stable when:* fresh install → 800+ exercises queryable on second launch; warm launches don't re-seed.

3. **Exercise library UI.** `ExerciseLibraryView` with `@Query`, filter chips for muscle/equipment/mechanic. Use `#Predicate` for filtering. `ExerciseDetailView` shows fields and muscle stimulus. `CustomExerciseEditor` writes a new `Exercise` with `isCustom = true`.

   *Stable when:* user can browse 1000+ exercises, filter by 3 axes simultaneously without UI hitching, and add a custom exercise that appears in the list.

### Routine + Session basics

4. **Routine builder.** `RoutineListView` lists routines. `RoutineBuilderView` lets user add `RoutineExercise`s from the library, reorder via `.onMove`, set prescription (intent picker, rep range, target RPE/RIR, rest, tempo, notes). Pick a progression kind per exercise (default from settings).

   *Stable when:* user can build a 6-exercise routine with full prescription, save it, reopen it, edit it.

5. **Session logger (minimum viable).** `SessionFactory.start(...)` without progression yet (just copy fields, prescribed weight defaults to last logged weight or nil). `SessionLoggerView` shows exercises, lets user log `SetEntry`s with weight, reps, RPE. Rest timer between sets.

   *Stable when:* user can start a routine, log all sets across multiple exercises, mark session complete, see the completed session in a history list. **This validates the snapshot pattern works.**

6. **Session history & basic per-exercise view.** Per-exercise history list grouped by intent (strength sessions in one group, hypertrophy in another). No charts yet, just lists.

   *Stable when:* logging the "same routine different intent" scenario shows two separate history streams for the same exercise.

### Progression engine

7. **`OneRepMaxEstimator` + `RPETable`.** Pure math primitives. Tested in isolation.

8. **`ProgressionStrategy` protocol + `DoubleProgressionStrategy`.** Simplest of the four; validates the protocol shape. Wire it into `SessionFactory.start(...)` so prescribed weight is now computed.

   *Stable when:* logging a session at the top of the rep range → next session's prescription shows the increment. Logging a missed rep → next session holds.

9. **`RPEAutoregStrategy`.** Pull from `RPETable`. Test against known cases (e.g. "5 reps at RPE 8 = 81.1% 1RM").

10. **`WarmupGenerator`.** Generates warm-up SetEntries on first compound. Hidden behind `generateWarmups` flag on `RoutineExercise`.

    *Stable when:* the bench press warm-up scheme produces the expected 4-set ramp to the top set.

### Periodization

11. **Block + BlockPhase models, Block builder UI.** Let user define a 4+1 block (4 accumulation weeks + 1 deload) with phase multipliers. Link a Routine to a Block.

12. **`PeriodizationEngine.phase(for: block, on: date)`.** Pure function. Tested.

13. **`BlockPeriodizedStrategy` and `HybridStrategy`.** Both depend on phase resolution. Now four strategies live.

    *Stable when:* switching the progression kind on a `RoutineExercise` changes the prescribed weight predictably across all four algorithms.

### Fatigue + progress

14. **`MuscleVolumeTarget` seed.** Bundled default MEV/MAV/MRV table per muscle (start from RP published values), user-editable in settings.

15. **`FatigueModel.weeklyVolume(...)`.** Pure function. Tested with hand-crafted set arrays.

16. **Volume bars view.** Per-muscle bars colored by zone (below MEV / MEV-MAV / MAV-MRV / over MRV). The first piece of visible fatigue tracking.

17. **Muscle heatmap.** Body silhouette tinted by `FatigueModel.heatmapIntensity()`. (This is "nice" but the volume bars are the *correct* RP-style answer; the heatmap is the marketing-y one.)

18. **`PlateauDetector` + alerts.** Rolling slope of e1RM over the user-configured window per exercise + intent. Surface a yellow flag on the exercise card.

19. **Deload alert.** When `FatigueModel.deloadRecommendation()` fires (multiple muscles at MRV + plateau signal on key compounds), show banner.

### Charts & polish

20. **Per-exercise charts (intent-split).** Swift Charts. Two series per chart — one per intent — sharing the x-axis.

21. **Weekly tonnage chart, PRs view.** Direct `@Query`, light aggregation.

22. **Settings polish.** Units, week start, plateau window, deload alert toggle, volume target editor.

### Dependency rationale

- Steps 1-3 establish the schema and the largest single data set (library), which surfaces SwiftData performance issues early when they're cheap to fix.
- Steps 4-6 prove the template/instance separation works before any algorithmic complexity is layered on.
- Steps 7-13 build progression and periodization on top of *real* logged data from step 5, so each strategy can be tested against actual sessions rather than fixtures.
- Steps 14-19 build the RP-style fatigue model after sessions exist to compute from. Building it earlier would mean inventing fake data to test against.
- Steps 20-22 are pure presentation polish on a stable backend.

The roadmap should treat steps 1-3 as the foundation phase, 4-6 as the "core loop" phase (this is the minimum lovable product — logging a workout), 7-13 as "smart prescription," 14-19 as "fatigue model," 20-22 as "progress views."

---

## Testing Strategy

| Layer | Test type | Approach |
|-------|-----------|----------|
| `OneRepMaxEstimator`, `RPETable`, `RollingSlope`, `WarmupGenerator` | Pure unit | Plain Swift inputs, plain Swift outputs. `XCTAssertEqual` on numeric outputs. No `ModelContainer` needed. |
| All four `ProgressionStrategy` impls | Pure unit | Build `[HistoryEntry]` fixtures by hand. Assert on `ProgressionSuggestion.prescribedWeight`. |
| `FatigueModel`, `PlateauDetector` | Pure unit | Build `[SetEntry]` fixtures plus stimulus dictionary. Assert on aggregates. |
| `PeriodizationEngine.phase(for:on:)` | Pure unit | Hand-crafted `Block` with known phases. |
| `SessionFactory.start(...)` | Integration | In-memory `ModelContainer` (`isStoredInMemoryOnly: true`). Insert a Routine, call `start`, assert `Session` and `SessionExercise` rows exist with correct snapshotted fields. |
| `ExerciseLibraryImporter` | Integration | In-memory container, run `seedIfNeeded`, assert count > 800. |
| SwiftData migrations (later) | Integration | `VersionedSchema` + `MigrationStage` tests as new schema versions are introduced. |
| `RoutineBuilderView`, `SessionLoggerView` | UI test | `XCUITest`. Focus on the high-value flows: build a routine, start a session, log a set with RPE. Don't test the entire UI surface — test the critical paths. |
| Library browse performance | Performance | `XCTMeasureMetric` on a fresh launch with the full 1000-row library. Catch index regressions early. |

**Test detection in app code:** detect `ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"]` in `fitbodApp.swift` to short-circuit the importer and other launch-time work when running tests.

The architecture is deliberately structured so that **the hardest math has the easiest tests.** No `ModelContainer`, no `@MainActor` ceremony — just functions over fixtures.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Mirroring SwiftData models in ViewModels

**What people do:** Create `RoutineViewModel` that wraps `Routine`, with its own `@Published` properties that get synced back to the SwiftData model.

**Why it's wrong:** Doubles the schema, breaks `@Query` reactivity, creates two-way sync bugs, and makes every edit go through manual save logic. Bad in any SwiftData app; especially bad when the schema is as relational as this one.

**Do this instead:** Bind directly. `@Bindable var routine: Routine` in the builder view. Edit fields directly. SwiftData's autosave handles persistence.

### Anti-Pattern 2: Hard-coding the progression algorithm

**What people do:** `if intent == .strength { weight = last + 5 } else if intent == .hypertrophy { ... }` scattered through `SessionFactory`.

**Why it's wrong:** Adding the fourth algorithm becomes a refactor instead of a new file. Testing requires running the whole session start flow. Two of the four algorithms (RPE + block) have *no relation* to each other internally — bundling them as `if/else` is a category error.

**Do this instead:** `ProgressionStrategy` protocol. One implementation per algorithm. Factory dispatch.

### Anti-Pattern 3: Mutating Routine when editing past Session

**What people do:** "User wants to fix a typo in last week's bench session. Let's just give them an edit screen that writes to the same RoutineExercise."

**Why it's wrong:** The snapshot pattern only works if it's enforced. Once you tunnel through it to edit the source template, you've retroactively rewritten history for all other sessions that referenced it.

**Do this instead:** Session edits write to `SessionExercise` / `SetEntry`. Routine edits write to `RoutineExercise`. They are never the same screen.

### Anti-Pattern 4: Computing volume rollups via `@Query` filters in the chart view

**What people do:** `@Query(filter: #Predicate<SetEntry> { $0.completedAt > weekAgo })` inside the chart view, then loop in the body to sum by muscle.

**Why it's wrong:** Predicates can't easily express the "join through SessionExercise → Exercise → ExerciseMuscleStimulus → MuscleGroup" path that volume tracking requires. The loop-in-body approach silently degrades as set count grows and re-runs on every render.

**Do this instead:** Query the broad set of `SetEntry`s with a date predicate, hand the result to `FatigueModel.weeklyVolume(...)`. Cache the result by wrapping the call in a `@State`-backed memo if profiling shows it matters.

### Anti-Pattern 5: Putting `ProgressionEngine` calls on a background actor

**What people do:** "Async-await all the things — let's run progression suggestions on a `@ModelActor`."

**Why it's wrong:** The history window is tiny (~10–50 SessionExercises max). The math is microseconds. The cost of hopping actors during session start is real (visible flicker on slower devices). Reserve `@ModelActor` for the bulk import case where it actually matters.

**Do this instead:** Call services synchronously from the main thread. Only push to a `@ModelActor` for the one-time exercise library seed.

---

## Scaling Considerations

This is a single-user, local-only app. "Scale" here means "data accumulating over months of training."

| Time horizon | Approximate data volume | Approach |
|--------------|-------------------------|----------|
| 0-3 months | ~50 sessions, ~3k sets, 1000 exercises | Everything queries directly. No optimization needed. |
| 3-12 months | ~200 sessions, ~12k sets | Add `#Index` on `Session.startedAt`, `SessionExercise.intentRaw`. Indexes are iOS 18+; on iOS 17 this stays fast through sheer small N. |
| 1-3 years | ~1000 sessions, ~60k sets | Consider derived caching for FatigueModel weekly rollups — e.g., a `WeeklyVolumeSnapshot` model that the FatigueModel writes once at week-rollover. |
| 3+ years | ~3000+ sessions | Archive older sessions to a separate readonly store; keep main store hot. Not a v1 concern. |

### Scaling priorities (what breaks first)

1. **Library filter view janks on slow keystrokes.** Mitigation: ensure `#Index` on `Exercise.canonicalName`, debounce the search input.
2. **Heatmap recomputes too often.** Mitigation: cache the heatmap intensity in a view-scoped `@State` keyed off "last set logged at." Recompute on change, not on every body re-render.
3. **Cold launch slow.** Mitigation: don't re-import exercises; check count first.

What does NOT scale-fail: the snapshot pattern. Even at 10k sessions, copying ~10 RoutineExercise fields into 10 SessionExercise fields at session start is microseconds.

---

## Integration Points

### External — None (v1)

Local-only. No HealthKit, no CloudKit, no APIs, no auth.

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| View → Service | Direct function call | Services are stateless; pass `ModelContext` or pre-fetched arrays |
| View → Model | `@Query`, `@Bindable` | No intermediate layer |
| Service → Service | Direct function call | `SessionFactory` calls `ProgressionEngine` and `PeriodizationEngine` |
| Service → SwiftData | Through `ModelContext` parameter | Services do not store contexts |
| Background work → SwiftData | `@ModelActor` (only `ExerciseLibraryImporter`) | Send `PersistentIdentifier`s across actor boundary, never model instances |

---

## Sources

- [SwiftData — Apple Developer Documentation](https://developer.apple.com/documentation/swiftdata) (HIGH confidence, via Context7)
- [SwiftData Indexes — Use Your Loaf](https://useyourloaf.com/blog/swiftdata-indexes/) (HIGH, corroborated by Apple docs on `#Index` macro, iOS 18+)
- [Defining data relationships with enumerations and model classes — Apple](https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes) (HIGH)
- [Relationships in SwiftData — Changes and Considerations — fatbobman](https://fatbobman.com/en/posts/relationships-in-swiftdata-changes-and-considerations/) (MEDIUM, corroborates inverse relationship requirements)
- [SwiftData Architecture Patterns and Practices — AzamSharp](https://azamsharp.com/2025/03/28/swiftdata-architecture-patterns-and-practices.html) (MEDIUM, on direct-model vs ViewModel debate)
- [Is SwiftData incompatible with MVVM? — Matteo Manferdini](https://matteomanferdini.com/swiftdata-mvvm/) (MEDIUM, articulates the SwiftUI-native architecture stance)
- [Using ModelActor in SwiftData — BrightDigit](https://brightdigit.com/tutorials/swiftdata-modelactor/) (MEDIUM)
- [How SwiftData works with Swift concurrency — Hacking With Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-swiftdata-works-with-swift-concurrency) (HIGH)
- [Considerations for Using Codable and Enums in SwiftData Models — fatbobman](https://fatbobman.com/en/posts/considerations-for-using-codable-and-enums-in-swiftdata-models/) (HIGH, justifies the `*Raw: String` convention)
- [How to write unit tests for your SwiftData code — Hacking With Swift](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-write-unit-tests-for-your-swiftdata-code) (HIGH)
- [Snapshot — Martin Fowler](https://martinfowler.com/eaaDev/Snapshot.html) (HIGH, source of the template/instance pattern)
- [Strategy Pattern in Swift — Refactoring.guru](https://refactoring.guru/design-patterns/strategy/swift/example) (HIGH)
- [Simply The Best: Tuchscherer's Reactive Training Systems — PowerliftingToWin](https://www.powerliftingtowin.com/a-review-of-mike-tuchscherer-rts/) (HIGH, source of the RPE-to-percentage table)
- [Training Volume Landmarks for Muscle Growth — RP Strength](https://rpstrength.com/blogs/articles/training-volume-landmarks-muscle-growth) (HIGH, MEV/MAV/MRV definitions)
- [free-exercise-db — yuhonas (GitHub)](https://github.com/yuhonas/free-exercise-db) (HIGH, the bundled seed source — 800+ exercises with the exact schema fields we need: id, name, force, level, mechanic, equipment, primaryMuscles, secondaryMuscles, instructions, category)
- [Block Periodization — Hevy Coach Glossary](https://hevycoach.com/glossary/block-periodization/) (MEDIUM, accumulation/intensification/realization summary)
- [1RM Calculator — Strength Journeys](https://www.strengthjourneys.xyz/articles/how-do-i-calculate-my-e1rm-estimated-one-rep-max) (MEDIUM, Epley vs Brzycki tradeoff — start with Epley, swap later behind protocol)
- [Rolling Regression — GeeksforGeeks](https://www.geeksforgeeks.org/machine-learning/rolling-regression/) (MEDIUM, basis for `PlateauDetector` design)
- [Swift Charts — Apple Developer Documentation](https://developer.apple.com/documentation/Charts) (HIGH)

---
*Architecture research for: single-user iOS bodybuilding/weight-training tracker (SwiftUI + SwiftData)*
*Researched: 2026-05-10*
