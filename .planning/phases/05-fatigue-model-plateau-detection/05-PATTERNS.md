# Phase 5: Fatigue Model & Plateau Detection - Pattern Map

**Mapped:** 2026-05-22
**Files analyzed:** 38 new/modified files
**Analogs found:** 35 / 38

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `fitbod/Persistence/SchemaV4.swift` | schema-version | additive | `fitbod/Persistence/SchemaV3.swift` | exact |
| `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` (modified) | migration-plan | additive | same file + `SchemaV3MigrationTests.swift` | exact |
| `fitbod/Models/UserSettings.swift` (modified — additive fields) | model | CRUD | same file | exact |
| `fitbod/Models/Exercise.swift` (modified — additive fields) | model | CRUD | same file + `SchemaV3MigrationTests.swift` additive-fields test | exact |
| `fitbod/Models/ExerciseMuscleStimulus.swift` (modified — additive field) | model | CRUD | same file | exact |
| `fitbod/Models/MuscleVolumeTarget.swift` (modified — additive field) | model | CRUD | same file | exact |
| `fitbod/Fatigue/FatigueModel.swift` | pure-function service | batch/transform | `fitbod/Prescription/Calibration.swift` + `PlateCalculator.swift` | exact |
| `fitbod/Fatigue/VolumeZone.swift` | pure-function enum | transform | `fitbod/Prescription/TuchschererTable.swift` | role-match |
| `fitbod/Fatigue/PlateauDetector.swift` | pure-function service | batch/transform | `fitbod/Prescription/RPEAutoregStrategy.swift` | exact |
| `fitbod/Fatigue/DeloadAdvisor.swift` | pure-function service | batch/transform | `fitbod/Prescription/Calibration.swift` | exact |
| `fitbod/Prescription/OneRepMaxEstimator.swift` | pure-function utility | transform | `fitbod/Prescription/Calibration.swift` + `fitbod/Prescription/TuchschererTable.swift` | exact |
| `fitbod/Fatigue/StimulusWeightSeeder.swift` | seeder | CRUD | `fitbod/Settings/PlateInventorySeeder.swift` | exact |
| `fitbod/Fatigue/MuscleVolumeTargetSeeder.swift` | seeder | CRUD | `fitbod/Settings/PlateInventorySeeder.swift` | exact |
| `fitbod/Fatigue/StimulusWeightTable.swift` | static-literal-table | transform | `fitbod/Prescription/TuchschererTable.swift` | role-match |
| `fitbod/Fatigue/RPVolumeLandmarks.swift` | static-literal-table | transform | `fitbod/Prescription/TuchschererTable.swift` | role-match |
| `fitbod/Fatigue/FatigueSurfaceView.swift` | view (host) | request-response | `fitbod/App/RootView.swift` (TodayView inner struct) | role-match |
| `fitbod/Fatigue/MuscleVolumeBar.swift` | view (component) | request-response | `fitbod/Sessions/SetTypeChip.swift` / `fitbod/Sessions/PinnedNoteCapsule.swift` | role-match |
| `fitbod/Fatigue/BodySilhouetteView.swift` | view (canvas/path) | request-response | no internal analog (first Canvas+Path impl) | none |
| `fitbod/Fatigue/MuscleRegionPaths.swift` | pure-function registry | transform | `fitbod/ExerciseLibrary/MuscleRegionMap.swift` | role-match |
| `fitbod/Fatigue/PerMuscleDetailView.swift` | view (detail) | request-response | `fitbod/ExerciseLibrary/ExerciseDetailView.swift` | exact |
| `fitbod/Fatigue/MuscleVolumeTargetStepper.swift` | view (editor component) | CRUD | `fitbod/Settings/SettingsView.swift` (Stepper rows) | exact |
| `fitbod/Settings/MuscleVolumeTargetEditor.swift` | view (settings list) | CRUD | `fitbod/Settings/SettingsView.swift` | exact |
| `fitbod/Fatigue/DeloadAdvisoryBanner.swift` | view (banner overlay) | request-response | `fitbod/Sessions/ResumeWorkoutBanner.swift` | exact |
| `fitbod/Fatigue/DeloadSignalDetailSheet.swift` | view (sheet) | request-response | `fitbod/Sessions/PinnedNoteSheet.swift` | role-match |
| `fitbod/Fatigue/WeeklyRecapSheet.swift` | view (sheet) | batch/transform | `fitbod/Sessions/PinnedNoteSheet.swift` | role-match |
| `fitbod/Fatigue/TryVariationSheet.swift` | view (sheet) | request-response | `fitbod/Sessions/SwapExerciseSheet.swift` | exact |
| `fitbod/Fatigue/StallBadge.swift` | view (badge component) | request-response | `fitbod/Sessions/SetTypeChip.swift` | role-match |
| `fitbod/Fatigue/SuggestedActionChip.swift` | view (chip component) | request-response | `fitbod/Sessions/SetTypeChip.swift` | role-match |
| `fitbod/App/RootView.swift` (modified) | view (host, modified) | request-response | same file | exact |
| `fitbod/Settings/SettingsView.swift` (modified) | view (settings, modified) | CRUD | same file | exact |
| `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (modified) | view (detail, modified) | CRUD | same file | exact |
| `fitbod/Sessions/SessionExerciseCard.swift` (modified) | view (card, modified) | request-response | same file | exact |
| `fitbodTests/Fatigue/` (13 unit test files) | unit tests | transform | `fitbodTests/RPEAutoregStrategyTests.swift` | exact |
| `fitbodTests/Persistence/SchemaV4MigrationTests.swift` | migration test | CRUD | `fitbodTests/SchemaV3MigrationTests.swift` | exact |
| `fitbodTests/Fatigue/FatigueTestFixtures.swift` | test fixture | transform | `fitbodTests/TestSupport/InMemoryContainer.swift` | role-match |
| `fitbodUITests/` (7 UI test files) | UI tests | request-response | `fitbodUITests/fitbodUITests.swift` | role-match |
| Asset Catalog color entries (4 new colorsets) | asset | — | `AccentColor.colorset` pattern | exact |

---

## Pattern Assignments

---

### `fitbod/Persistence/SchemaV4.swift` (schema-version, additive)

**Analog:** `fitbod/Persistence/SchemaV3.swift`

**Full file pattern** (lines 1–38 — copy verbatim, update version and comment):
```swift
import SwiftData

public enum SchemaV4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(4, 0, 0)

    public static var models: [any PersistentModel.Type] {
        SchemaV3.models  // unchanged entity list; only field additions on existing entities
    }
}
```

**Comment block to carry forward:** The block header in SchemaV3.swift lists every additive delta introduced in that phase — copy and update for Phase 5's 8 additive fields (3 on UserSettings, 2 on Exercise, 1 on ExerciseMuscleStimulus, 1 on MuscleVolumeTarget, and the `plateauTolerance` default bump).

---

### `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` (modified — add V3→V4 stage)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Persistence/FitbodSchemaMigrationPlan.swift`

**Existing `schemas` array pattern** (lines 31–33) — extend:
```swift
public static var schemas: [any VersionedSchema.Type] {
    [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self]
}
```

**Existing `stages` array pattern** (lines 35–37) — extend:
```swift
public static var stages: [MigrationStage] {
    [migrateV1toV2, migrateV2toV3, migrateV3toV4]
}
```

**New custom migration stage (V3→V4)** — copy willMigrate pattern from RESEARCH §9.3:
```swift
public static let migrateV3toV4 = MigrationStage.custom(
    fromVersion: SchemaV3.self,
    toVersion: SchemaV4.self,
    willMigrate: { context in
        // Bump plateauTolerance default for users still on the V1 seed (0.005).
        // All other deltas are additive default-valued fields — handled automatically
        // by the lightweight-eligible schema change.
        if let settings = try? context.fetch(FetchDescriptor<UserSettings>()).first,
           abs(settings.plateauTolerance - 0.005) < 1e-9 {
            settings.plateauTolerance = 0.02
            try? context.save()
        }
    },
    didMigrate: nil
)
```

**Why custom (not lightweight) for V3→V4:** The `plateauTolerance` default bump requires a one-shot data mutation on existing rows. All other 7 fields are lightweight-eligible, but mixing lightweight + custom on the same stage is not possible — a single custom stage covers both the schema delta and the data migration.

---

### `fitbod/Models/UserSettings.swift` (modified — 3 new fields)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Models/UserSettings.swift`

**Existing field declaration pattern** (lines 24–44 — copy style exactly):
```swift
@Model
public final class UserSettings {
    @Attribute(.unique) public var id: UUID = UUID()
    // ... existing fields ...
    public var plateauWindowSessions: Int = 4
    public var plateauTolerance: Double = 0.005  // UPDATED to 0.02 in Phase 5
    public var deloadAlertEnabled: Bool = true
    public var weekStartsMonday: Bool = true
    public var defaultIncrementKg: Double = 2.5
    public var minCalibrationSets: Int = 10
}
```

**Three new additive fields to append** (after `minCalibrationSets`):
```swift
// Phase 5 — D-03 frequency-hit threshold; additive default-valued
public var frequencyHitMinSets: Int = 2
// Phase 5 — D-17 deload advisory dismissal state; nil = not dismissed
public var deloadAdvisoryDismissedWeekStart: Date? = nil
// Phase 5 — VOL-07 weekly recap trigger guard; nil = not shown yet
public var weeklyRecapShownForWeekStart: Date? = nil
```

**Note on `plateauTolerance`:** The default in `UserSettings.default()` and in the `@Model` property declaration must be updated to `0.02`. Existing rows are migrated by the custom `willMigrate` closure in the migration plan.

---

### `fitbod/Models/ExerciseMuscleStimulus.swift` (modified — 1 new field)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Models/ExerciseMuscleStimulus.swift`

**Existing field pattern** (lines 23–48):
```swift
@Model
public final class ExerciseMuscleStimulus {
    @Attribute(.unique) public var id: UUID = UUID()
    public var role: String = "primary"
    public var weight: Double = 1.0
    public var exercise: Exercise? = nil
    public var muscle: MuscleGroup? = nil
    public init() {}
}
```

**New additive field** (append after `weight`):
```swift
// Phase 5 — idempotency flag: seeder skips rows where this is true
public var userEditedWeight: Bool = false
```

---

### `fitbod/Models/MuscleVolumeTarget.swift` (modified — 1 new field)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Models/MuscleVolumeTarget.swift`

**Existing field pattern** (lines 25–35):
```swift
@Model
public final class MuscleVolumeTarget {
    @Attribute(.unique) public var id: UUID = UUID()
    public var muscle: MuscleGroup? = nil
    public var mev: Int = 8
    public var mav: Int = 14
    public var mrv: Int = 22
    public var mv: Int = 6
    public var notes: String? = nil
    public init() {}
}
```

**New additive field** (append after `notes`):
```swift
// Phase 5 — idempotency flag: seeder skips rows where this is true
public var userEdited: Bool = false
```

---

### `fitbod/Models/Exercise.swift` (modified — 2 new fields)

**Analog:** Pattern follows existing optional fields (`smallestIncrement: Double?`, `barWeightOverride: Double?`) confirmed in SchemaV3MigrationTests.swift lines 122–135.

**New additive fields** (both nil → fall back to UserSettings defaults per SET-06):
```swift
// Phase 5 — SET-06 per-exercise plateau override fields
public var plateauWindowOverride: Int? = nil
public var plateauToleranceOverride: Double? = nil
```

---

### `fitbod/Fatigue/FatigueModel.swift` (pure-function service, batch/transform)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Prescription/Calibration.swift`

**`enum` namespace pattern** (Calibration.swift lines 46–82):
```swift
public enum Calibration {

    public static func predict(
        history: [HistoryPoint],
        targetReps: Int,
        targetRPE: Double,
        now: Date = Date()
    ) -> Double? {
        guard !history.isEmpty else { return nil }
        // ... pure computation, no SwiftData ...
    }
}
```

**Key patterns to copy:**
- `public enum` namespace (not a class or struct) — matches Calibration, PlateCalculator, TuchschererTable
- All functions are `public static func`
- No stored mutable state (`// No SwiftData coupling. No @MainActor. Implicitly Sendable.`)
- `@MainActor` on functions that accept a `ModelContext` parameter (FatigueModel needs this; Calibration does not because it takes pre-fetched arrays)
- `now: Date = Date()` injectable parameter for deterministic testing — copy this pattern

**ModelContext predicate pattern for multi-hop traversal** (from RESEARCH §10 Pitfall #1):
```swift
// Local-let capture workaround for #Predicate multi-hop limitation (see PreviousMatchingIntent.swift)
let weekEnd = weekStart.addingTimeInterval(7 * 86400)
let workingKinds = ["working", "drop", "failure", "rest_pause"]

let descriptor = FetchDescriptor<SetEntry>(
    predicate: #Predicate { entry in
        entry.isComplete == true
        && entry.isWarmup == false
        && workingKinds.contains(entry.setTypeRaw)
        && entry.sessionExercise?.session?.startedAt ?? .distantPast >= weekStart
        && entry.sessionExercise?.session?.startedAt ?? .distantPast < weekEnd
    }
)
// Resolve stimulus weights in-memory after fetch (predicate can't traverse join cleanly)
```

**Supporting value types** — follow `HistoryPoint` pattern (Calibration.swift lines 25–35):
```swift
public struct HistoryPoint: Sendable, Equatable {
    public let e1RM: Double
    public let date: Date
    public init(e1RM: Double, date: Date) { ... }
}
```

Apply same pattern for `WeightedSetTotal` and `WeekOverWeekDelta`.

---

### `fitbod/Fatigue/VolumeZone.swift` (pure-function enum, transform)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Prescription/TuchschererTable.swift`

**Static literal dictionary pattern** (TuchschererTable.swift lines 26–42):
```swift
public enum TuchschererTable {
    public static let percentFor: [Int: [Double: Double]] = [
        1: [10.0: 1.000, 9.5: 0.978, ...],
        ...
    ]
    public static func percent(reps: Int, rpe: Double) -> Double? {
        let clampedReps = max(1, min(reps, 10))
        return percentFor[clampedReps]?[rpe]
    }
}
```

**VolumeZone must be verbatim** — user supplied the exact Swift (CONTEXT.md D-05). Copy character-for-character:
```swift
public enum VolumeZone: Sendable, Equatable {
    case belowMEV
    case productive
    case nearMRV
    case overMRV
}

public func volumeZone(currentSets: Int, mev: Int, mav: Int, mrv: Int) -> VolumeZone {
    if currentSets < mev { return .belowMEV }
    if currentSets < mav { return .productive }
    if currentSets < mrv { return .nearMRV }
    return .overMRV
}
```

**Verb copy** — add as a computed property on `VolumeZone` using D-06 strings verbatim. Use `< ` not `<=` throughout.

---

### `fitbod/Fatigue/PlateauDetector.swift` (pure-function service, batch/transform)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Prescription/RPEAutoregStrategy.swift`

**Key structural pattern** (RPEAutoregStrategy.swift lines 31–50):
```swift
public struct RPEAutoregStrategy: ProgressionStrategy {
    public init() {}

    public func prescribe(
        history: [HistoryPoint],
        ...
    ) -> (weight: Double, explanation: PrescriptionExplanation) {

        // MARK: Calibrated path
        if history.count >= minCalibrationSets { ... }

        // MARK: Calibrating path — with prior session data
        if let lastWeight = lastSessionWeight, ... { ... }

        // MARK: Calibrating path — no prior session data
        let exp = PrescriptionExplanation(...)
        return (weight: 0, explanation: exp)
    }
}
```

**For PlateauDetector:** use `public enum` (not struct — no instance state needed per Calibration pattern) with `public static func evaluate(...)` returning `PlateauSignal` enum. The multi-branch decision logic (notEnoughData / stalled / progressing) mirrors RPEAutoregStrategy's calibrating/calibrated branches.

**Associated-value result enum** — follow `CalibrationStatus` pattern (ProgressionStrategy.swift lines 18–25):
```swift
public enum CalibrationStatus: Sendable, Equatable {
    case calibrating(current: Int, threshold: Int)
    case calibrated
    case notApplicable
}
```

Apply same pattern for `PlateauSignal`:
```swift
public enum PlateauSignal: Sendable, Equatable {
    case notEnoughData
    case stalled(e1RMs: [Double], rangeRatio: Double)
    case progressing(e1RMs: [Double])
}
```

---

### `fitbod/Prescription/OneRepMaxEstimator.swift` (pure-function utility, transform)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Prescription/Calibration.swift` + `/Users/chrissaechao/Desktop/fitbod/fitbod/Prescription/TuchschererTable.swift`

**Pattern:** `public enum` namespace with `public static func estimate(weight: Double, reps: Int) -> Double?`. Returns nil for reps > 10 per REQUIREMENTS PROG-02.

**File header comment pattern** (Calibration.swift lines 1–16):
```swift
//  OneRepMaxEstimator.swift
//  fitbod
//
//  Brzycki formula (reps ≤ 6): e1RM = weight × (36 / (37 - reps))
//  Epley formula (reps 7–10):  e1RM = weight × (1 + reps / 30)
//  Suppressed (reps > 10): returns nil per REQUIREMENTS PROG-02.
//
//  No SwiftData coupling. No @MainActor. Implicitly Sendable.
//

import Foundation

public enum OneRepMaxEstimator {
    public static func estimate(weight: Double, reps: Int) -> Double? {
        guard reps > 0 else { return nil }
        if reps <= 6 {
            return weight * (36.0 / Double(37 - reps))   // Brzycki
        } else if reps <= 10 {
            return weight * (1.0 + Double(reps) / 30.0)  // Epley
        } else {
            return nil  // suppress per PROG-02
        }
    }
}
```

---

### `fitbod/Fatigue/DeloadAdvisor.swift` (pure-function service, batch/transform)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Prescription/Calibration.swift`

**Same `public enum` namespace pattern.** Key difference: DeloadAdvisor must conform to Phase 4's `FatigueAdvisory` protocol (confirm at plan time — the protocol type exists at `fitbod/Models/Enums/BlockPhaseKind.swift` vicinity per the grep results, though no file was found in the grep above, meaning Phase 4 has not yet landed in code). If Phase 4 is incomplete, DeloadAdvisor stubs the protocol conformance using the same stub-and-replace approach noted in RESEARCH §10 Pitfall #10.

**Result struct pattern** — follow `PlateStack` pattern (PlateCalculator.swift lines 19–40):
```swift
public struct PlateStack: Sendable {
    public let platesPerSide: [(weight: Double, count: Int)]
    public let totalWeight: Double
    public init(...) { ... }
    public static func == ...: Bool { ... }
}
extension PlateStack: Equatable {}
```

Apply same `Sendable + Equatable` struct pattern for `DeloadAdvisory` and `DeloadSignalReport`.

---

### `fitbod/Fatigue/StimulusWeightSeeder.swift` (seeder, CRUD)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Settings/PlateInventorySeeder.swift`

**Full file structural pattern** (PlateInventorySeeder.swift lines 28–78):
```swift
@MainActor
public enum PlateInventorySeeder {

    public static let seededKey = "plateInventorySeeded"

    public static func seedIfNeeded(
        in context: ModelContext,
        unitSystem: WeightUnit
    ) {
        // Fast path: UserDefaults flag already set.
        if UserDefaults.standard.bool(forKey: seededKey) { return }

        // Double-idempotency: count existing inventory rows.
        let descriptor = FetchDescriptor<PlateInventory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        if existingCount >= PlateEquipmentKind.allCases.count {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }

        // Seed rows...
        for kind in PlateEquipmentKind.allCases {
            let inv = PlateInventory()
            // ... configure ...
            context.insert(inv)
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: seededKey)
    }
}
```

**Differences for StimulusWeightSeeder:**
- Use `@MainActor public enum` pattern (not `@ModelActor` — this seeder writes small counts, not 700+ rows, so main-actor is fine)
- Idempotency via `ExerciseMuscleStimulus.userEditedWeight == false` row-level guard (NOT UserDefaults flag — stimulus weights can be updated on any version bump, so row-level is required)
- Consume `StimulusWeightTable.overrides` dictionary for curated rows; fall back to 1.0/0.5 for uncurated

---

### `fitbod/Fatigue/MuscleVolumeTargetSeeder.swift` (seeder, CRUD)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Settings/PlateInventorySeeder.swift`

**Identical structural pattern to PlateInventorySeeder.** Differences:
- Iterates `MuscleRegionMap.allSlugs` (17 strings) instead of `PlateEquipmentKind.allCases`
- Finds existing `MuscleVolumeTarget` row via `muscle.slug` comparison
- Skips row if `target.userEdited == true`
- Writes RP landmark values from `RPVolumeLandmarks.landmarks` dictionary

---

### `fitbod/Fatigue/StimulusWeightTable.swift` (static-literal-table, transform)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Prescription/TuchschererTable.swift`

**Static dictionary pattern** (TuchschererTable.swift lines 22–45):
```swift
public enum TuchschererTable {
    public static let percentFor: [Int: [Double: Double]] = [
        1: [10.0: 1.000, ...],
        ...
    ]
}
```

Apply same pattern:
```swift
public enum StimulusWeightTable {

    /// Curated overrides keyed by canonical exercise name (lowercased,
    /// diacritic-stripped — matches Exercise.canonicalName).
    /// Value: array of (muscleSlug, role, weight) triples.
    /// [ASSUMED] — see RESEARCH §6.1.
    public static let overrides: [String: [(muscleSlug: String, role: String, weight: Double)]] = [
        "barbell bench press": [
            ("chest", "primary", 1.0),
            ("shoulders", "secondary", 0.5),
            ("triceps", "secondary", 0.5),
        ],
        // ... 50 entries total per RESEARCH §6.1 ...
    ]
}
```

---

### `fitbod/Fatigue/RPVolumeLandmarks.swift` (static-literal-table, transform)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/ExerciseLibrary/MuscleRegionMap.swift`

**Static lookup function pattern** (MuscleRegionMap.swift lines 37–64):
```swift
public enum MuscleRegionMap {
    public static let allSlugs: [String] = [
        "abdominals", "abductors", ...
    ]

    public static func region(for slug: String) -> MuscleRegion {
        switch slug.lowercased() {
        case "chest", "lats", ...: return .upper
        default: return .upper
        }
    }
}
```

Apply same pattern:
```swift
public enum RPVolumeLandmarks {

    public struct Landmark: Sendable {
        public let mv: Int; public let mev: Int; public let mav: Int; public let mrv: Int
    }

    /// RP-anchored MEV/MAV/MRV per muscle. See RESEARCH §7.1.
    public static let landmarks: [String: Landmark] = [
        "chest":       Landmark(mv: 6, mev: 8, mav: 16, mrv: 22),
        "lats":        Landmark(mv: 6, mev: 8, mav: 18, mrv: 25),
        // ... all 17 slugs per RESEARCH §7.1 table ...
    ]

    public static func landmark(for slug: String) -> Landmark {
        landmarks[slug.lowercased()] ?? Landmark(mv: 4, mev: 6, mav: 12, mrv: 18)
    }
}
```

---

### `fitbod/Fatigue/FatigueSurfaceView.swift` (view host, request-response)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/App/RootView.swift` (TodayView inner struct, lines 245–282)

**ScrollView host with stacked subcomponents pattern:**
```swift
private struct TodayView: View {
    @Environment(\.modelContext) private var ctx
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 16) {
                ResumeWorkoutBanner(...)
                Spacer()
                // empty-state content
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationTitle("Today")
            .navigationDestination(for: SessionRoute.self) { route in ... }
        }
    }
}
```

**For FatigueSurfaceView:** use `ScrollView` + `VStack` (not NavigationStack — it's embedded inside TodayView's existing NavigationStack). Use `@Query<MuscleGroup>` + `@Query<MuscleVolumeTarget>` directly in the view body (per FOUND-06 / CLAUDE.md "Put @Query directly in the view").

**`@Environment(\.modelContext)` pattern** for calling `FatigueModel.weeklyVolume(...)` inline.

---

### `fitbod/Fatigue/MuscleVolumeBar.swift` (view component, request-response)

**Analog:** `fitbod/Sessions/SetTypeChip.swift` + the inline SwiftUI from RESEARCH §5

**GeometryReader two-tone bar pattern** (RESEARCH §5 code example):
```swift
struct MuscleVolumeBar: View {
    let muscle: MuscleGroup
    let target: MuscleVolumeTarget
    let total: WeightedSetTotal
    let delta: WeekOverWeekDelta

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(muscle.displayName).font(.headline)
                Spacer()
                Text("\(total.totalSetsRounded) / \(target.mrv)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(zoneColor(zone).opacity(0.4))
                        .frame(width: (total.totalSets / Double(target.mrv)) * geo.size.width)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(zoneColor(zone))
                        .frame(width: (total.directSets / Double(target.mrv)) * geo.size.width)
                }
            }
            .frame(height: 16)
            Text(zone.verb).font(.caption).foregroundStyle(.secondary)
            Text(delta.deltaCopy).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
```

**Zone color helper** — use Asset Catalog names (same pattern as Phase 2's `Color("PinnedNoteYellow")`):
```swift
private func zoneColor(_ z: VolumeZone) -> Color {
    switch z {
    case .belowMEV:   return Color("VolumeBelowMEVGray")
    case .productive: return Color("VolumeProductiveGreen")
    case .nearMRV:    return Color("VolumeNearMRVAmber")
    case .overMRV:    return Color("VolumeOverMRVRed")
    }
}
```

**Pulse animation on overMRV** — gate on `@Environment(\.accessibilityReduceMotion)` per UI-SPEC.

---

### `fitbod/Fatigue/BodySilhouetteView.swift` + `fitbod/Fatigue/MuscleRegionPaths.swift` (view, path registry)

**No internal analog — first Canvas + Path implementation in codebase.**

**External pattern reference:** RESEARCH.md §8.2 contains the complete structural pattern. Key points:

- `public enum MuscleRegionPaths` with two static dictionaries: `front: [String: Path]` and `back: [String: Path]`
- Paths normalized to 0…1 unit square; `GeometryReader` scales them in the view
- `BodySilhouetteView` uses `ZStack { ForEach(paths.keys) { ... } }` with `.fill(zoneColor).contentShape(path).onTapGesture { onTap(slug) }`
- `.aspectRatio(0.4, contentMode: .fit)` on the GeometryReader
- Wave 0: stub `Path` rectangles at approximate body positions; Wave 3: anatomical bezier curves

**Closest analog for `MuscleRegionPaths` (registry pattern):** `/Users/chrissaechao/Desktop/fitbod/fitbod/ExerciseLibrary/MuscleRegionMap.swift` — same `public enum` with static dictionaries keyed by muscle slug.

---

### `fitbod/Fatigue/PerMuscleDetailView.swift` (view detail, request-response)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/ExerciseLibrary/ExerciseDetailView.swift`

**`List(.insetGrouped)` with sectioned content pattern** (ExerciseDetailView.swift lines 108–197):
```swift
struct ExerciseDetailView: View {
    let exercise: Exercise
    @Query private var settingsList: [UserSettings]
    @State private var draftFromCopy: CustomExerciseDraft? = nil
    @State private var presentingCustomEditor = false

    var body: some View {
        List {
            if !exercise.instructions.isEmpty {
                Section("Instructions") { ... }
            }
            muscleSection
            Section("Equipment") { Text(equipmentDisplay) }
            Section("Mechanic") { Text(mechanicDisplay) }
            prescriptionSettingsSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presentingCustomEditor) { ... }
    }
}
```

**For PerMuscleDetailView:** same List(.insetGrouped) + sectioned pattern. Four sections per Claude's discretion: "This Week" / "Contributing Exercises" / "Frequency This Week" / "Adjust Targets".

**`@Query` with predicate pattern** — use `@Query(filter: #Predicate<MuscleGroup> { $0.slug == slug })` (same approach as ExerciseDetailView's `@Query private var settingsList: [UserSettings]`).

---

### `fitbod/Fatigue/MuscleVolumeTargetStepper.swift` (view editor component, CRUD)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Settings/SettingsView.swift` (Stepper rows, lines 129–156)

**`@Bindable` + Stepper + LabeledContent pattern:**
```swift
@ViewBuilder
private func smartProgressionSection(settings: UserSettings) -> some View {
    @Bindable var s = settings
    let unitLabel = s.weightUnit == .kg ? "kg" : "lb"

    Section {
        Stepper(value: $s.defaultIncrementKg, in: 0.25...10.0, step: 0.25) {
            LabeledContent("Default weight increment") {
                Text("\(s.defaultIncrementKg, specifier: "%g") \(unitLabel)")
                    .foregroundStyle(.secondary)
            }
        }
        Stepper(value: $s.minCalibrationSets, in: 5...30, step: 1) {
            LabeledContent("Sets before calibrating") {
                Text("\(s.minCalibrationSets) sets")
                    .foregroundStyle(.secondary)
            }
        }
    } header: {
        Text("Smart Progression")
    } footer: {
        VStack(alignment: .leading, spacing: 4) {
            Text("...").font(.caption).foregroundStyle(.secondary)
        }
    }
}
```

**For MuscleVolumeTargetStepper:** same `@Bindable var target = muscleVolumeTarget` pattern. Four Steppers (MV/MEV/MAV/MRV). Add monotonic validation on the computed property that reads the four values.

---

### `fitbod/Settings/MuscleVolumeTargetEditor.swift` (view settings list, CRUD)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Settings/SettingsView.swift`

**`Form` + sectioned list + NavigationLink pattern** (SettingsView.swift lines 62–79):
```swift
public struct SettingsView: View {
    @Query private var settingsList: [UserSettings]

    public var body: some View {
        NavigationStack {
            Form {
                if let settings = settingsList.first {
                    unitsSection(settings: settings)
                    smartProgressionSection(settings: settings)
                    aboutSectionPlaceholder
                } else {
                    Section {
                        Text("Settings unavailable — library seed not yet complete.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

**For MuscleVolumeTargetEditor:** `@Query<MuscleGroup>` + `@Query<MuscleVolumeTarget>` driving a `List` (not Form, because the muscle list is longer and uses NavigationLinks for disclosure). One section per muscle. Navigation title "Volume Targets".

---

### `fitbod/Fatigue/DeloadAdvisoryBanner.swift` (view banner overlay, request-response)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Sessions/ResumeWorkoutBanner.swift`

**Banner structural pattern** (ResumeWorkoutBanner.swift lines 55–115):
```swift
public struct ResumeWorkoutBanner: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]

    public let onResume: (Session) -> Void
    public let onDiscard: (Session) -> Void
    @State private var discardConfirm = false

    public var body: some View {
        if let active = activeSessions.first {
            bannerBody(active: active)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func bannerBody(active: Session) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text("Resume Workout: \(active.routineSnapshotName)").font(.headline)
            }
            Spacer()
            Button("Resume") { onResume(active) }.foregroundStyle(Color.accentColor)
            Button("Discard", role: .destructive) { discardConfirm = true }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .alert("Discard active workout?", isPresented: $discardConfirm) { ... }
    }
}
```

**For DeloadAdvisoryBanner:** same HStack(spacing) + VStack(leading) + Spacer() + dismiss-button pattern. Key differences:
- Background: `Color("VolumeNearMRVAmber").opacity(0.15)` (not secondarySystemGroupedBackground)
- Dismiss: `xmark` button (not destructive text button)
- No `@Query` — receives `advisory: DeloadAdvisory` as a parameter
- Tap on banner body → present `DeloadSignalDetailSheet` as `.sheet`
- Mount via `.safeAreaInset(edge: .top)` in TodayView (same anchor as ResumeWorkoutBanner)

---

### `fitbod/Fatigue/TryVariationSheet.swift` (view sheet, request-response)

**Analog:** `fitbod/Sessions/SwapExerciseSheet.swift` (swap exercise sheet pattern — exercise list in a sheet)

**Sheet presentation pattern** (from ExerciseDetailView.swift lines 192–200):
```swift
.sheet(isPresented: $presentingCustomEditor) {
    if let draft = draftFromCopy {
        NavigationStack {
            CustomExerciseEditor(draft: draft)
        }
    }
}
```

**For TryVariationSheet:** `.sheet` with `[.medium, .large]` detents. No NavigationStack needed — sheet title "Try Variation" via `.navigationTitle` (if embedded in a thin NavigationStack for the title bar). List of 2–3 exercises with "Never logged" caption for unlogged entries. Footer "View all similar exercises in library" (accent text link).

---

### `fitbod/Fatigue/WeeklyRecapSheet.swift` (view sheet, batch/transform)

**Analog:** `fitbod/Sessions/PinnedNoteSheet.swift` (sheet with toolbar Done button)

**`.large` detent sheet with toolbar dismiss pattern:**
```swift
struct WeeklyRecapSheet: View {
    let weekStart: Date
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                // Four sections per Claude's discretion
            }
            .navigationTitle("Weekly Recap")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

**Presentation pattern** (from RootView.swift .sheet wiring + checkWeeklyRecap trigger):
```swift
// In TodayView.body:
.sheet(isPresented: $showWeeklyRecap) {
    WeeklyRecapSheet(weekStart: thisMonday)
        .presentationDetents([.large])
}
.task {
    checkWeeklyRecap(now: .now)
}
```

---

### `fitbod/Fatigue/StallBadge.swift` + `fitbod/Fatigue/SuggestedActionChip.swift` (view badge/chip components)

**Analog:** `fitbod/Sessions/SetTypeChip.swift` (small capsule badge component)

**Capsule badge pattern** — copy the capsule-background + foreground-label approach:
```swift
// StallBadge: orange capsule, "Stalled" label
Text("Stalled")
    .font(.caption)
    .fontWeight(.semibold)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color(.systemOrange).opacity(0.15))
    .foregroundStyle(Color(.systemOrange))
    .clipShape(Capsule())

// SuggestedActionChip: accent-tinted capsule (matches Phase 2 intent chip)
Text(action.label)
    .font(.caption)
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(Color.accentColor.opacity(0.15))
    .foregroundStyle(Color.accentColor)
    .clipShape(Capsule())
    .contentShape(Rectangle())   // wider tap area per 44pt HIG
    .onTapGesture { onTap() }
```

---

### `fitbod/App/RootView.swift` (modified — Today tab stacking order)

**Analog:** same file — existing TodayView inner struct (lines 245–282)

**Modification:** Add `DeloadAdvisoryBanner` via `.safeAreaInset(edge: .top)` above current content. Add `.sheet(isPresented: $showWeeklyRecap)` + `.task { checkWeeklyRecap() }`. Mirror the existing `ResumeWorkoutBanner` anchor:

```swift
// Existing pattern to extend:
VStack(spacing: 16) {
    ResumeWorkoutBanner(...)
    // PHASE 5: FatigueSurfaceView goes here
    FatigueSurfaceView()
    Spacer()
}
.safeAreaInset(edge: .top) {
    // PHASE 5: DeloadAdvisoryBanner when advisory non-nil
    if let advisory = deloadAdvisory, !isDismissedThisWeek {
        DeloadAdvisoryBanner(advisory: advisory, onDismiss: { ... })
    }
}
```

---

### `fitbod/Settings/SettingsView.swift` (modified — add Volume Targets section)

**Analog:** same file — existing `smartProgressionSection` (lines 116–157)

**NavigationLink section pattern** (SettingsView.swift lines 124–127):
```swift
Section {
    NavigationLink {
        PlateInventoryEditor()
    } label: {
        Text("Plate Inventory")
    }
} header: {
    Text("Smart Progression")
}
```

**New section to add** (insert above `aboutSectionPlaceholder`):
```swift
Section {
    NavigationLink {
        MuscleVolumeTargetEditor()
    } label: {
        HStack {
            Text("Volume Targets")
            Spacer()
            Text("17 muscles")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
    }
} header: {
    Text("Volume Targets")
}
```

---

### `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (modified — add Plateau Detection section)

**Analog:** same file — existing `prescriptionSettingsSection` (the Stepper block around lines 142–167)

**Stepper + Toggle section pattern** (SettingsView.swift lines 129–156 for Stepper binding shape):
```swift
// New section after "History" section:
Section {
    @Bindable var ex = exercise
    Toggle("Override global settings", isOn: Binding(
        get: { ex.plateauWindowOverride != nil },
        set: { on in
            if !on {
                ex.plateauWindowOverride = nil
                ex.plateauToleranceOverride = nil
            } else {
                ex.plateauWindowOverride = settings.plateauWindowSessions
                ex.plateauToleranceOverride = settings.plateauTolerance
            }
        }
    ))
    if ex.plateauWindowOverride != nil {
        Stepper(value: Binding($ex.plateauWindowOverride)!, in: 1...12, step: 1) {
            LabeledContent("Window (sessions)") {
                Text("\(ex.plateauWindowOverride!) sessions").foregroundStyle(.secondary)
            }
        }
        // ... tolerance stepper ...
    }
} header: {
    Text("Plateau Detection")
} footer: {
    Text("Global defaults: \(settings.plateauWindowSessions) sessions, \(Int((settings.plateauTolerance * 100).rounded()))% tolerance. Set in Settings.")
        .font(.caption).foregroundStyle(.secondary)
}
```

---

### `fitbod/Sessions/SessionExerciseCard.swift` (modified — add StallBadge + SuggestedActionChip)

**Analog:** same file — existing `contextMenu` header (lines 143–167)

**Conditional rendering pattern** (SessionExerciseCard.swift lines 81–86):
```swift
if let note = sessionExercise.pinnedNote, !note.isEmpty {
    PinnedNoteCapsule(note: note) {
        onEditPinnedNote(sessionExercise)
    }
}
```

**Modification** — add stall badge after the section header (inside the `Section { ... } header:` block), conditionally:
```swift
// After the contextMenu header, before the column-header row:
if case .stalled = plateauSignal {
    HStack {
        StallBadge(...)
        if let action = suggestedAction {
            SuggestedActionChip(action: action, onTap: { ... })
        }
        Spacer()
    }
}
```

**`PlateauDetector.evaluate(...)` call site** — call in a computed property or `.task` off the card; results stored as `@State private var plateauSignal: PlateauSignal = .notEnoughData`.

---

### `fitbodTests/Persistence/SchemaV4MigrationTests.swift` (migration test, integration)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbodTests/SchemaV3MigrationTests.swift`

**Complete test structure pattern** (SchemaV3MigrationTests.swift lines 28–144):
```swift
import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("SchemaV4Migration")
struct SchemaV4MigrationTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV4.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test("SchemaV4 models list equals SchemaV3.models (no new entity types, only field additions)")
    func schemaV4ModelsListEqualsV3() {
        let v3Names = Set(SchemaV3.models.map { String(describing: $0) })
        let v4Names = Set(SchemaV4.models.map { String(describing: $0) })
        #expect(v3Names == v4Names)  // pure additive field changes, no new entities
    }

    @Test("FitbodSchemaMigrationPlan registers V1+V2+V3+V4 and THREE stages")
    func migrationPlanWiringIsV1V2V3V4() {
        let names = FitbodSchemaMigrationPlan.schemas.map { String(describing: $0) }
        #expect(names == ["SchemaV1", "SchemaV2", "SchemaV3", "SchemaV4"])
        #expect(FitbodSchemaMigrationPlan.stages.count == 3)
    }

    @Test("plateauTolerance willMigrate bump: 0.005 → 0.02 on existing row")
    @MainActor
    func plateauToleranceBumpMigrates() throws { ... }

    @Test("Additive Phase 5 fields round-trip with correct defaults")
    @MainActor
    func additiveFieldsRoundTrip() throws {
        let ctx = try makeContext()
        let settings = UserSettings.default()
        ctx.insert(settings)
        try ctx.save()

        let s = try #require(try ctx.fetch(FetchDescriptor<UserSettings>()).first)
        #expect(s.frequencyHitMinSets == 2)
        #expect(s.deloadAdvisoryDismissedWeekStart == nil)
        #expect(s.weeklyRecapShownForWeekStart == nil)

        let ex = Exercise()
        ctx.insert(ex)
        try ctx.save()

        let e = try #require(try ctx.fetch(FetchDescriptor<Exercise>()).first)
        #expect(e.plateauWindowOverride == nil)
        #expect(e.plateauToleranceOverride == nil)

        let stim = ExerciseMuscleStimulus()
        ctx.insert(stim)
        try ctx.save()
        let st = try #require(try ctx.fetch(FetchDescriptor<ExerciseMuscleStimulus>()).first)
        #expect(st.userEditedWeight == false)

        let mvt = MuscleVolumeTarget()
        ctx.insert(mvt)
        try ctx.save()
        let m = try #require(try ctx.fetch(FetchDescriptor<MuscleVolumeTarget>()).first)
        #expect(m.userEdited == false)
    }
}
```

---

### `fitbodTests/Fatigue/FatigueModelWeeklyVolumeTests.swift` + other unit test files (unit tests, transform)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbodTests/RPEAutoregStrategyTests.swift`

**Swift Testing suite structure** (RPEAutoregStrategyTests.swift lines 14–58):
```swift
import Foundation
import Testing
@testable import fitbod

@Suite("RPEAutoregStrategy")
struct RPEAutoregStrategyTests {
    private let strategy = RPEAutoregStrategy()
    private let barWeight: Double = 20.0

    @Test("calibratingBelowThresholdShowsRange")
    func calibratingBelowThresholdShowsRange() throws {
        let history = [
            HistoryPoint(e1RM: 120.0, date: Date()),
        ]
        let (_, explanation) = strategy.prescribe(...)
        #expect(explanation.status == .calibrating(current: 3, threshold: 10))
        #expect(explanation.range != nil)
    }
}
```

**Tests that require ModelContext** — follow PreviousMatchingIntentTests.swift pattern (lines 28–59):
```swift
@MainActor
@Suite("FatigueModel", .serialized)
struct FatigueModelWeeklyVolumeTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV4.models)   // Use V4 schema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test("weeklyVolume counts working sets and excludes warmups")
    func weeklyVolumeExcludesWarmups() throws {
        let ctx = try makeContext()
        // ... build fixture via FatigueTestFixtures ...
        let total = FatigueModel.weeklyVolume(muscleSlug: "chest", weekStart: monday, in: ctx)
        #expect(total.directSets == 3.0)
        #expect(total.indirectSets == 0.0)
    }
}
```

**Pure-function tests (no ModelContext)** — follow RPEAutoregStrategyTests pattern: no `makeContext()`, no `@MainActor`, no `.serialized`.

---

### `fitbodTests/Fatigue/FatigueTestFixtures.swift` (test fixture helper)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbodTests/TestSupport/InMemoryContainer.swift`

**Fixture factory pattern** (InMemoryContainer.swift lines 28–60):
```swift
import Foundation
import SwiftData
@testable import fitbod

enum InMemoryContainer {
    static func makeEmpty() throws -> ModelContainer {
        let schema = Schema(SchemaV1.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
        return try ModelContainer(for: schema, migrationPlan: FitbodSchemaMigrationPlan.self, configurations: config)
    }

    static func makeWithFixture() -> ModelContainer {
        PreviewModelContainer.make(seedFixture: true)
    }
}
```

**For FatigueTestFixtures:** static factory methods returning configured in-memory ModelContexts with pre-built session/exercise data. Named per the edge cases in RESEARCH §4:
```swift
@MainActor
enum FatigueTestFixtures {

    static func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV4.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    /// 4 sessions, all e1RM within ±2% — triggers .stalled
    static func stalledWindow(ctx: ModelContext, exerciseID: UUID) throws { ... }

    /// 4 sessions, e1RM trending up 3%/session — returns .progressing
    static func progressingWindow(ctx: ModelContext, exerciseID: UUID) throws { ... }

    // ... one factory per edge case in RESEARCH §4 table ...
}
```

---

### `fitbodUITests/` (7 UI test files)

**Analog:** `/Users/chrissaechao/Desktop/fitbod/fitbodUITests/fitbodUITests.swift`

**XCTest + XCUIApplication pattern** (fitbodUITests.swift lines 10–43):
```swift
import XCTest

final class fitbodUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        // XCTAssert...
    }
}
```

**Apply same class/XCTestCase pattern** for all 7 UI test files:
- `VolumeBarsUITests` — verify `.accessibilityLabel` on bar rows contains zone verb copy
- `BodySilhouetteUITests` — verify Front/Back segmented control + region tap navigation
- `DeloadAdvisoryBannerUITests` — verify banner appears / dismisses / persists across tab switches
- `WeeklyRecapUITests` — verify sheet presents on first Monday launch

Each class: `continueAfterFailure = false` in `setUpWithError`. Launch app with test-seeded ModelContainer (inject via launch arguments or `XCUIApplication.launchEnvironment`).

---

## Shared Patterns

### Pure-function `public enum` service shape

**Source:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Prescription/Calibration.swift` + `/Users/chrissaechao/Desktop/fitbod/fitbod/Prescription/PlateCalculator.swift`

**Apply to:** `FatigueModel`, `VolumeZone`, `PlateauDetector`, `DeloadAdvisor`, `OneRepMaxEstimator`, `StimulusWeightTable`, `RPVolumeLandmarks`, `MuscleRegionPaths`

```swift
// fitbod/Prescription/Calibration.swift lines 46-48, 64-66
public enum Calibration {
    public static func predict(
        history: [HistoryPoint],
        targetReps: Int,
        targetRPE: Double,
        now: Date = Date()    // injectable for deterministic testing
    ) -> Double? {
        guard !history.isEmpty else { return nil }
        // ... pure computation ...
    }
}
```

Rules:
- `public enum` (not class/struct — no instance state)
- All functions `public static func`
- File header always includes: `// No SwiftData coupling. No @MainActor. Implicitly Sendable.`
- Exception: functions taking `ModelContext` are `@MainActor`
- `now: Date = Date()` for any date-sensitive function (testability)

---

### `@Bindable` write-through pattern (no ViewModel layer)

**Source:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Settings/SettingsView.swift` (lines 87–107)

**Apply to:** `MuscleVolumeTargetStepper`, `MuscleVolumeTargetEditor`, SET-06 section in `ExerciseDetailView`

```swift
// SettingsView.swift lines 87-107
@ViewBuilder
private func unitsSection(settings: UserSettings) -> some View {
    @Bindable var s = settings
    Section {
        Toggle(isOn: Binding(
            get: { s.weightUnit == .kg },
            set: { newValue in s.weightUnit = newValue ? .kg : .lb }
        )) { ... }
    }
}
```

Never wrap `@Query` in a view model. Put `@Query` directly in the view body. Use `@Bindable` for write-through to `@Model` types.

---

### `@MainActor` seeder pattern

**Source:** `/Users/chrissaechao/Desktop/fitbod/fitbod/Settings/PlateInventorySeeder.swift` (lines 28–78)

**Apply to:** `StimulusWeightSeeder`, `MuscleVolumeTargetSeeder`

```swift
@MainActor
public enum PlateInventorySeeder {
    public static let seededKey = "plateInventorySeeded"

    public static func seedIfNeeded(in context: ModelContext, ...) {
        if UserDefaults.standard.bool(forKey: seededKey) { return }
        let descriptor = FetchDescriptor<PlateInventory>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        if existingCount >= threshold {
            UserDefaults.standard.set(true, forKey: seededKey)
            return
        }
        // ... insert rows ...
        try? context.save()
        UserDefaults.standard.set(true, forKey: seededKey)
    }
}
```

Note: StimulusWeightSeeder uses row-level `userEditedWeight` guard instead of UserDefaults (since stimulus weights may be re-seeded on version updates). MuscleVolumeTargetSeeder uses `userEdited` guard similarly.

---

### Asset Catalog color entry pattern

**Source:** Phase 2 precedent (`PinnedNoteYellow.colorset`) + UI-SPEC §Asset Contract

**Apply to:** 4 new color assets: `VolumeBelowMEVGray`, `VolumeProductiveGreen`, `VolumeNearMRVAmber`, `VolumeOverMRVRed`

Each `.colorset` directory in `fitbod/Assets.xcassets/` contains a `Contents.json` following the same structure as `AccentColor.colorset`. Light/dark hex values from UI-SPEC §Color:

```
VolumeBelowMEVGray:   light #8E8E93, dark #636366
VolumeProductiveGreen: light #34C759, dark #30D158
VolumeNearMRVAmber:   light #FF9500, dark #FF9F0A
VolumeOverMRVRed:     light #FF3B30, dark #FF453A
```

---

### SwiftData schema test pattern

**Source:** `/Users/chrissaechao/Desktop/fitbod/fitbodTests/SchemaV3MigrationTests.swift`

**Apply to:** `SchemaV4MigrationTests`

```swift
// SchemaV3MigrationTests.swift lines 33-44
private func makeContext() throws -> ModelContext {
    let schema = Schema(SchemaV3.models)
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: schema,
        migrationPlan: FitbodSchemaMigrationPlan.self,
        configurations: config
    )
    return ModelContext(container)
}
```

Every schema migration test builds its own `ModelContainer` using the production migration plan — never `InMemoryContainer.makeEmpty()` (which uses SchemaV1 and is reserved for Phase 1 baseline tests).

---

### In-memory ModelContext for service unit tests

**Source:** `/Users/chrissaechao/Desktop/fitbod/fitbodTests/PreviousMatchingIntentTests.swift` (lines 29–43)

**Apply to:** `FatigueModelWeeklyVolumeTests`, `PlateauDetectorTests`, `DeloadAdvisorTests`, `StimulusWeightSeederTests`, `MuscleVolumeTargetSeederTests`

```swift
// PreviousMatchingIntentTests.swift lines 29-43
@MainActor
@Suite("PreviousMatchingIntent", .serialized)
struct PreviousMatchingIntentTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV2.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }
    // ...
}
```

Phase 5 tests use `Schema(SchemaV4.models)` instead of `SchemaV2.models`.

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `fitbod/Fatigue/BodySilhouetteView.swift` | view (Canvas/Path) | request-response | First `SwiftUI.Path` + `.contentShape()` implementation in codebase. Pattern source: RESEARCH.md §8.2 verbatim code example. |
| `fitbod/Fatigue/MuscleRegionPaths.swift` | path registry | transform | No Path geometry registry exists. Closest: `MuscleRegionMap.swift` for the `public enum` + static dictionary structure. Path data sourced from public-domain SVG hand-traced per RESEARCH §8.3. |

---

## Metadata

**Analog search scope:** `fitbod/` (all subdirectories), `fitbodTests/`, `fitbodUITests/`

**Files scanned:** 47 Swift source files read or grepped

**Pattern extraction date:** 2026-05-22

---

## PATTERN MAPPING COMPLETE
