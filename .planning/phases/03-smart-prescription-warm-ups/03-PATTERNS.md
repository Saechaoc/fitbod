# Phase 3: Smart Prescription & Warm-ups - Pattern Map

**Mapped:** 2026-05-22
**Files analyzed:** 32 new/modified files
**Analogs found:** 32 / 32

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `fitbod/Prescription/ProgressionStrategy.swift` | protocol/utility | transform | `fitbod/Sessions/PreviousMatchingIntent.swift` | role-match (pure value type pattern) |
| `fitbod/Prescription/TuchschererTable.swift` | utility | transform | `fitbod/Models/Enums/ProgressionKind.swift` | role-match (pure enum namespace) |
| `fitbod/Prescription/RPEAutoregStrategy.swift` | service | transform | `fitbod/Sessions/PreviousMatchingIntent.swift` | role-match (pure function, Sendable) |
| `fitbod/Prescription/DoubleProgressionStrategy.swift` | service | transform | `fitbod/Sessions/PreviousMatchingIntent.swift` | role-match (pure function, Sendable) |
| `fitbod/Prescription/Calibration.swift` | utility | transform | `fitbod/Sessions/PreviousMatchingIntent.swift` | role-match (pure function) |
| `fitbod/Prescription/PlateCalculator.swift` | utility | transform | `fitbod/Sessions/PreviousMatchingIntent.swift` | role-match (pure enum + static func) |
| `fitbod/Prescription/WarmupRamp.swift` | utility | transform | `fitbod/Sessions/PreviousMatchingIntent.swift` | role-match (pure function) |
| `fitbod/Models/PlateInventory.swift` | model | CRUD | `fitbod/Models/UserSettings.swift` | exact (singleton-ish @Model with computed accessors) |
| `fitbod/Models/PlateSpec.swift` | model | transform | `fitbod/Models/RoutineExerciseSetOverride.swift` | role-match (Codable value type) |
| `fitbod/Models/WarmupConfig.swift` | model | transform | `fitbod/Models/RoutineExerciseSetOverride.swift` | role-match (Codable struct) |
| `fitbod/Models/Enums/EquipmentKind.swift` | enum | — | `fitbod/Models/Enums/Equipment.swift` | exact |
| `fitbod/Models/Exercise.swift` (modified) | model | CRUD | `fitbod/Models/Exercise.swift` | exact (additive fields) |
| `fitbod/Models/RoutineExercise.swift` (modified) | model | CRUD | `fitbod/Models/RoutineExercise.swift` | exact (additive Data? field) |
| `fitbod/Models/SetEntry.swift` (modified) | model | CRUD | `fitbod/Models/SetEntry.swift` | exact (additive Bool field) |
| `fitbod/Models/UserSettings.swift` (modified) | model | CRUD | `fitbod/Models/UserSettings.swift` | exact (additive fields with defaults) |
| `fitbod/Sessions/WhyThisWeightSheet.swift` | component | request-response | `fitbod/Sessions/DecimalRPEPickerSheet.swift` | exact (.medium detent sheet pattern) |
| `fitbod/Sessions/PrescriptionWeightCell.swift` | component | event-driven | `fitbod/Sessions/SetRow.swift` | exact (compound control with @Binding) |
| `fitbod/Sessions/PlateStackDisclosure.swift` | component | event-driven | `fitbod/Sessions/SetRow.swift` | role-match (conditional VStack child in set row) |
| `fitbod/Sessions/BumpBanner.swift` | component | event-driven | `fitbod/Sessions/ResumeWorkoutBanner.swift` | exact (pill banner with dismiss) |
| `fitbod/Sessions/CalibratingBadge.swift` | component | transform | `fitbod/Sessions/SetTypeChip.swift` | role-match (small inline badge/chip) |
| `fitbod/Sessions/WarmupRampRows.swift` | component | transform | `fitbod/Sessions/SessionExerciseCard.swift` | role-match (sorted SetEntry ForEach) |
| `fitbod/Sessions/SessionExerciseCard.swift` (modified) | component | event-driven | `fitbod/Sessions/SessionExerciseCard.swift` | exact |
| `fitbod/Sessions/SetRow.swift` (modified) | component | event-driven | `fitbod/Sessions/SetRow.swift` | exact |
| `fitbod/Sessions/SessionFactory.swift` (modified) | service | request-response | `fitbod/Sessions/SessionFactory.swift` | exact |
| `fitbod/Routines/WarmupConfigSheet.swift` | component | request-response | `fitbod/Sessions/DecimalRPEPickerSheet.swift` | exact (.medium detent sheet) |
| `fitbod/Routines/PrescriptionEditorRow.swift` (modified) | component | event-driven | `fitbod/Routines/PrescriptionEditorRow.swift` | exact |
| `fitbod/Settings/PlateInventoryEditor.swift` | component | CRUD | `fitbod/Settings/SettingsView.swift` | role-match (Form + @Query + @Bindable) |
| `fitbod/Settings/PlateCalculatorSheet.swift` | component | request-response | `fitbod/Sessions/DecimalRPEPickerSheet.swift` | role-match (.medium detent sheet) |
| `fitbod/Settings/PlateInventory+Defaults.swift` | utility | transform | `fitbod/Routines/PrescriptionDefaults.swift` | exact (pure factory extension) |
| `fitbod/Persistence/SchemaV3.swift` | config | CRUD | `fitbod/Persistence/SchemaV2.swift` | exact |
| `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` (modified) | config | CRUD | `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` | exact |
| `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (modified) | component | request-response | `fitbod/ExerciseLibrary/ExerciseDetailView.swift` | exact (new Form section at bottom) |

---

## Pattern Assignments

### `fitbod/Prescription/ProgressionStrategy.swift` (protocol + value types, transform)

**Analog:** `fitbod/Sessions/PreviousMatchingIntent.swift` and `fitbod/Models/Enums/ProgressionKind.swift`

**Imports pattern** (PreviousMatchingIntent.swift lines 1–6 / ProgressionKind.swift lines 1–5):
```swift
import Foundation
import SwiftData  // only if the file touches ModelContext; pure-function files use Foundation only
```

**Sendable value type pattern** (PreviousMatchingIntent.swift lines 30–42):
```swift
public struct PreviousMatchingIntentHit: Sendable {
    public let weight: Double
    public let reps: Int
    public let rpe: Double?
    public let sessionStartedAt: Date

    public init(weight: Double, reps: Int, rpe: Double?, sessionStartedAt: Date) {
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.sessionStartedAt = sessionStartedAt
    }
}
```
Copy this shape for `PrescriptionExplanation` (all-let stored properties, memberwise init, `: Sendable`). The protocol `ProgressionStrategy: Sendable` should be declared in the same file; conforming structs with no mutable stored properties are implicitly `Sendable`.

**Pure enum namespace pattern** (ProgressionKind.swift lines 15–22):
```swift
public enum ProgressionKind: String, CaseIterable, Sendable {
    case rpe
    case double
    case block
    case hybrid

    public static let `default`: ProgressionKind = .double
}
```
Copy this for `CalibrationStatus` (use an enum with associated values instead of `String, CaseIterable`).

---

### `fitbod/Prescription/TuchschererTable.swift` (utility, transform)

**Analog:** `fitbod/Models/Enums/Equipment.swift` (pure enum with no SwiftData coupling) and `fitbod/Models/Enums/ProgressionKind.swift`

**File header comment pattern** (Equipment.swift lines 1–10):
```swift
//
//  TuchschererTable.swift
//  fitbod
//
//  Compile-time constant RPE → %1RM table per Tuchscherer (2009).
//  Rows 1–10 are verified against the RTS / Zourdos et al. (2016) source.
//  Rows 11–12 are extrapolated at ~2.3% per-rep decrement [ASSUMED: A1].
//  No SwiftData coupling. Testable in isolation via TuchschererTableTests.
//
```

**Enum namespace with static let pattern** (matches ProgressionKind.swift structure):
```swift
public enum TuchschererTable {
    // No cases — namespace-only enum (cannot be instantiated)
    public static let percentFor: [Int: [Double: Double]] = [
        1: [10.0: 1.000, 9.5: 0.978, ...],
        // ...
    ]

    public static func percent(reps: Int, rpe: Double) -> Double? {
        let clampedReps = max(1, min(10, reps))
        let roundedRPE = (rpe * 2).rounded() / 2
        return percentFor[clampedReps]?[roundedRPE]
    }
}
```

---

### `fitbod/Prescription/RPEAutoregStrategy.swift` and `DoubleProgressionStrategy.swift` (service, transform)

**Analog:** `fitbod/Sessions/PreviousMatchingIntent.swift` (same pure-function, `ModelContext`-free pattern)

**Pure enum namespace + static func pattern** (PreviousMatchingIntent.swift lines 44–108):
```swift
public enum PreviousMatchingIntent {
    public static func fetchTopWorkingSet(
        exerciseID: UUID?,
        intentRaw: String,
        context: ModelContext
    ) -> PreviousMatchingIntentHit? {
        guard let exerciseID else { return nil }
        // ...
    }
}
```
Strategies have NO `ModelContext` — they receive pre-fetched `[HistoryPoint]` from `SessionFactory`. Mirror the `PreviousMatchingIntentHit: Sendable` value-type pattern for `HistoryPoint`.

**Guard + early-return pattern** (PreviousMatchingIntent.swift line 71):
```swift
guard let exerciseID else { return nil }
```
Strategies: `guard !history.isEmpty else { return (weight: 0, explanation: .noData) }`.

---

### `fitbod/Prescription/PlateCalculator.swift` (utility, transform)

**Analog:** `fitbod/Sessions/PreviousMatchingIntent.swift` (enum namespace with static func)

**Return struct + enum namespace pattern**:
```swift
// Mirror PreviousMatchingIntentHit shape for PlateStack:
public struct PlateStack: Sendable {
    public let platesPerSide: [(weight: Double, count: Int)]
    public let totalWeight: Double
}

public enum PlateCalculator {
    public static func roundDown(
        target: Double,
        barWeight: Double,
        plates: [(weight: Double, countPerSide: Int)]
    ) -> Double { ... }
}
```
The `Double.rounded(toPlaces:)` extension lives at the bottom of this file (not in a shared Extensions file — the project has no shared Extensions layer yet; keep helpers local per the existing pattern).

---

### `fitbod/Prescription/WarmupRamp.swift` (utility, transform)

**Analog:** `fitbod/Sessions/PreviousMatchingIntent.swift` (same pure enum + static func pattern)

**Bool-returning guard function + generator pattern**:
```swift
public enum WarmupRamp {
    public static func shouldGenerate(
        for sessionExercise: SessionExercise,
        deloadActive: Bool
    ) -> Bool { ... }

    public static func generate(
        top: Double,
        bar: Double,
        plates: [(weight: Double, countPerSide: Int)]
    ) -> [SetEntry] { ... }
}
```

---

### `fitbod/Models/PlateInventory.swift` (model, CRUD)

**Analog:** `fitbod/Models/UserSettings.swift` (singleton-ish @Model with computed accessors)

**@Model with computed enum accessor pattern** (UserSettings.swift lines 23–53):
```swift
@Model
public final class UserSettings {
    @Attribute(.unique) public var id: UUID = UUID()
    public var unitsRaw: String = "lb"
    // ... other fields with defaults

    public init() {}

    public static func `default`() -> UserSettings { ... }
}

extension UserSettings {
    public var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: unitsRaw) ?? .lb }
        set { unitsRaw = newValue.rawValue }
    }
}
```
For `PlateInventory`, the `equipmentKindRaw: String` field + computed `var equipmentKind: PlateEquipmentKind` accessor follows this exact shape.

**Data field + computed Codable accessor** (SetEntry.swift lines 47–58 — `clusterSubReps` pattern):
```swift
public var clusterSubRepsJoined: String? = nil

public var clusterSubReps: [Int] {
    get {
        guard let joined = clusterSubRepsJoined, !joined.isEmpty else { return [] }
        return joined.split(separator: ",").compactMap { Int($0) }
    }
    set {
        clusterSubRepsJoined = newValue.isEmpty ? nil : newValue.map(String.init).joined(separator: ",")
    }
}
```
Apply this pattern to `PlateInventory.availablePlatesData: Data` + computed `var availablePlates: [PlateSpec]` using `JSONEncoder`/`JSONDecoder` instead of the comma-join.

**Default factory static func** (UserSettings.swift lines 37–41):
```swift
public static func `default`() -> UserSettings {
    let s = UserSettings()
    s.unitsRaw = "lb"
    return s
}
```
Copy for `PlateInventory.default(for:unitSystem:) -> PlateInventory`.

---

### `fitbod/Models/WarmupConfig.swift` (Codable struct)

**Analog:** `fitbod/Models/RoutineExerciseSetOverride.swift` and the `clusterSubReps` pattern in `SetEntry.swift`

**Data field pattern** (SetEntry.swift lines 40–42 + 49–58):
```swift
public var clusterSubRepsJoined: String? = nil   // ← the Data? equivalent

public var clusterSubReps: [Int] {               // ← the computed accessor
    get {
        guard let joined = clusterSubRepsJoined, !joined.isEmpty else { return [] }
        return joined.split(separator: ",").compactMap { Int($0) }
    }
    set {
        clusterSubRepsJoined = newValue.isEmpty ? nil : newValue.map(String.init).joined(separator: ",")
    }
}
```
`RoutineExercise` gets:
```swift
public var warmupOverrideData: Data? = nil       // nil = default auto-warm-up behavior

var warmupOverride: WarmupConfig? {
    get {
        guard let data = warmupOverrideData else { return nil }
        return try? JSONDecoder().decode(WarmupConfig.self, from: data)
    }
    set {
        warmupOverrideData = try? JSONEncoder().encode(newValue)
    }
}
```

---

### `fitbod/Models/Enums/EquipmentKind.swift` (enum)

**Analog:** `fitbod/Models/Enums/Equipment.swift` (exact shape)

**Enum declaration pattern** (Equipment.swift lines 15–27):
```swift
import Foundation

public enum Equipment: String, CaseIterable, Sendable {
    case barbell
    case dumbbell
    case machine
    // ...
    public static let `default`: Equipment = .other
}
```
For `PlateEquipmentKind`:
```swift
public enum PlateEquipmentKind: String, CaseIterable, Sendable {
    case barbell
    case dumbbell
    case ezBar = "ez_bar"
    case trapBar = "trap_bar"
}
```
No `default` case needed (inventory editor always shows all 4 tabs).

---

### Additive model field additions (`Exercise`, `RoutineExercise`, `SetEntry`, `UserSettings`)

**Analog:** The existing models themselves — their own existing additive field pattern.

**Additive optional field with default pattern** (SetEntry.swift lines 24–43):
```swift
@Model
public final class SetEntry {
    @Attribute(.unique) public var id: UUID = UUID()
    // ... existing fields ...
    public var partialReps: Int? = nil           // Phase 2 addition — nil = not tracked
    public var clusterSubRepsJoined: String? = nil  // Phase 2 addition
    public var isComplete: Bool = false          // Phase 2 addition — default false
    // Phase 3 additions follow the same pattern:
    // public var wasManualOverride: Bool = false
}
```

**UserSettings additive field pattern** (UserSettings.swift lines 24–30):
```swift
@Model
public final class UserSettings {
    @Attribute(.unique) public var id: UUID = UUID()
    public var unitsRaw: String = "lb"
    public var defaultProgressionKindRaw: String = "double"
    // ... each with explicit default values (required for lightweight migration)
}
```
Phase 3 additions to `UserSettings`:
```swift
public var defaultIncrementKg: Double = 2.5   // fallback when Exercise.smallestIncrement is nil
public var minCalibrationSets: Int = 10       // RPE autoreg threshold
```

---

### `fitbod/Sessions/WhyThisWeightSheet.swift` (component, request-response)

**Analog:** `fitbod/Sessions/DecimalRPEPickerSheet.swift` (exact `.medium` detent sheet shape)

**Full sheet component pattern** (DecimalRPEPickerSheet.swift lines 22–59):
```swift
public struct DecimalRPEPickerSheet: View {
    @Binding public var rpe: Double
    @Environment(\.dismiss) private var dismiss

    public init(rpe: Binding<Double>) {
        self._rpe = rpe
    }

    public var body: some View {
        NavigationStack {
            // ... content ...
            .navigationTitle("RPE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview("decimal picker") {
    @Previewable @State var rpe: Double = 8.0
    return Text("RPE: \(rpe, specifier: "%.1f")")
        .sheet(isPresented: .constant(true)) {
            DecimalRPEPickerSheet(rpe: $rpe)
                .presentationDetents([.fraction(0.3)])
        }
}
```
`WhyThisWeightSheet` receives a `PrescriptionExplanation` value type (not a `@Binding`) since it is read-mostly. Use `.presentationDetents([.medium])` instead of `.fraction`. The `@Environment(\.dismiss)` + "Done" toolbar button pattern carries forward verbatim.

---

### `fitbod/Sessions/BumpBanner.swift` (component, event-driven)

**Analog:** `fitbod/Sessions/ResumeWorkoutBanner.swift` (exact pill banner with dismiss)

**Pill banner pattern** (ResumeWorkoutBanner.swift lines 82–115):
```swift
@ViewBuilder
private func bannerBody(active: Session) -> some View {
    HStack(spacing: 12) {
        Image(systemName: "arrow.uturn.backward.circle")
            .foregroundStyle(Color.accentColor)
        VStack(alignment: .leading) {
            Text("Resume Workout: \(active.routineSnapshotName)")
                .font(.headline)
        }
        Spacer()
        Button("Resume") { onResume(active) }
            .foregroundStyle(Color.accentColor)
        Button("Discard", role: .destructive) { discardConfirm = true }
    }
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
}
```
`BumpBanner` uses `Color(.systemGreen).opacity(0.15)` background (NOT accent — per UI-SPEC). Replace `@Query` + reactive show/hide with `@Binding<Bool> isVisible` since `BumpBanner` is driven by `PrescriptionExplanation.bumpOccurred`, not a query.

---

### `fitbod/Sessions/PrescriptionWeightCell.swift` (component, event-driven)

**Analog:** `fitbod/Sessions/SetRow.swift` (the weight TextField it replaces)

**TextField + Button compound control pattern** (SetRow.swift lines 92–145):
```swift
HStack(spacing: 8) {                           // UI-SPEC sm
    TextField("—", text: $weightText)          // UI-SPEC verbatim placeholder
        .keyboardType(.decimalPad)
        .frame(width: 60)
        .onTapGesture {
            if !entry.isComplete { onTapEmptyCell() }
        }
        .onChange(of: weightText) { _, newValue in
            if let d = Double(newValue) { entry.weight = d }
        }
    // ...
    Button {
        presentingSetNote = true
    } label: {
        Image(systemName: "square.and.pencil")
            .font(.caption)
            .foregroundStyle(entry.notes != nil ? Color.accentColor : Color.secondary)
    }
    .buttonStyle(.plain)
    .frame(width: 32, height: 32)
    .accessibilityLabel("Note for set \(entry.orderIndex + 1)")
}
.padding(.vertical, 12)                        // UI-SPEC md
```
`PrescriptionWeightCell` replaces the weight `TextField` with this compound: `TextField` (same shape) + `info.circle` `Button` (accent foreground, `.contentShape(Rectangle()).frame(minWidth: 44, minHeight: 44)` hit area per UI-SPEC) + optional "M" badge `Text`.

**@State for local presentation flag** (SetRow.swift lines 73–78):
```swift
@State private var weightText: String = ""
@State private var presentingSetNote: Bool = false
```
`PrescriptionWeightCell`: `@State private var presentingWhySheet: Bool = false`.

---

### `fitbod/Sessions/WarmupRampRows.swift` (component, transform)

**Analog:** `fitbod/Sessions/SessionExerciseCard.swift` — the sorted SetEntry ForEach block

**Sorted ForEach + conditional rendering pattern** (SessionExerciseCard.swift lines 110–133):
```swift
ForEach(sortedSets) { set in
    VStack(spacing: 4) {                                    // UI-SPEC xs
        SetRow(
            entry: set,
            sessionExercise: sessionExercise,
            onCommit: { onCommitSet(set) },
            onTapEmptyCell: onTapEmptyCell
        )
        if sessionExercise.tracksTempo {
            TempoEntryRow(entry: set)
        }
    }
}
```
`WarmupRampRows` renders a filtered view of `setEntries.filter { $0.isWarmup }` sorted by `orderIndex`, followed by a "Working sets" divider and a "Skip warm-ups" text button.

---

### `fitbod/Sessions/SessionExerciseCard.swift` (modified, component, event-driven)

**Analog:** Self — the existing file is modified.

**Conditional top-of-card injection pattern** (SessionExerciseCard.swift lines 81–85):
```swift
if let note = sessionExercise.pinnedNote, !note.isEmpty {
    PinnedNoteCapsule(note: note) {
        onEditPinnedNote(sessionExercise)
    }
}
```
Phase 3 adds `BumpBanner` and `CalibratingBadge` with the same guard pattern before the column-header row:
```swift
if showBumpBanner {
    BumpBanner(isVisible: $showBumpBanner, bumpedToWeight: bumpedWeight)
}
```

**@State for local dismissal flag** (ResumeWorkoutBanner.swift line 63):
```swift
@State private var discardConfirm = false
```
Card gets: `@State private var bannerDismissed = false`.

---

### `fitbod/Sessions/SessionFactory.swift` (modified, service, request-response)

**Analog:** Self — the existing file is extended.

**The current loop body pattern** (SessionFactory.swift lines 106–165) is the integration hook. Phase 3 adds two blocks AFTER the `PreviousMatchingIntent.fetchTopWorkingSet(...)` call and BEFORE the `SetEntry` pre-population loop:

```swift
// Existing Phase 2 pattern (lines 143–147):
let previousHint = PreviousMatchingIntent.fetchTopWorkingSet(
    exerciseID: re.exercise?.id,
    intentRaw: re.intentRaw,
    context: context
)?.weight ?? 0
```

Phase 3 inserts between this and the `for setIndex in 0..<re.targetSets` loop. The `do { try context.save() } catch { throw SessionFactoryError.persistenceFailed(underlying: error) }` pattern (lines 168–172) remains unchanged — the entire factory body stays one transaction.

**Error enum pattern** (SessionFactory.swift lines 43–47):
```swift
public enum SessionFactoryError: Error {
    case activeSessionAlreadyExists
    case routineHasNoExercises
    case persistenceFailed(underlying: Error)
}
```
No new error cases needed for Phase 3.

---

### `fitbod/Routines/WarmupConfigSheet.swift` (component, request-response)

**Analog:** `fitbod/Sessions/DecimalRPEPickerSheet.swift` (exact .medium detent sheet)

Same pattern as `WhyThisWeightSheet` above. Input: `@Binding<WarmupConfig?>`. Uses `@Environment(\.dismiss)` + "Save" / "Cancel" toolbar items (not a "Done" single-button — this sheet has two actions per UI-SPEC).

**Two-toolbar-item pattern** (from `PrescriptionEditorRow`'s enclosing sheet in `RoutineBuilderView` — the builder's sheet uses `.topBarLeading` Cancel + `.topBarTrailing` Save):
```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") { dismiss() }
    }
    ToolbarItem(placement: .topBarTrailing) {
        Button("Save") {
            // commit + dismiss
            dismiss()
        }
    }
}
```

---

### `fitbod/Settings/PlateInventoryEditor.swift` (component, CRUD)

**Analog:** `fitbod/Settings/SettingsView.swift` (@Query + @Bindable Form pattern)

**@Query + @Bindable write-through pattern** (SettingsView.swift lines 57–106):
```swift
public struct SettingsView: View {
    @Query private var settingsList: [UserSettings]

    public var body: some View {
        NavigationStack {
            Form {
                if let settings = settingsList.first {
                    unitsSection(settings: settings)
                } else {
                    // empty state
                }
            }
            .navigationTitle("Settings")
        }
    }

    @ViewBuilder
    private func unitsSection(settings: UserSettings) -> some View {
        @Bindable var s = settings
        Section {
            Toggle(isOn: Binding(
                get: { s.weightUnit == .kg },
                set: { newValue in s.weightUnit = newValue ? .kg : .lb }
            )) { ... }
        } header: {
            Text("Units")
        } footer: {
            Text("...")
        }
    }
}
```
`PlateInventoryEditor` uses `@Query private var inventories: [PlateInventory]` and `@Environment(\.modelContext) private var ctx`. Edits write through `@Bindable var inv = inventories.first(where: ...)` with no explicit "Save" button (live write-through per UI-SPEC).

**Section + footer pattern** (SettingsView.swift lines 87–106):
```swift
Section {
    Toggle(...) { ... }
} header: {
    Text("Units")
} footer: {
    Text("Affects display only.")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

**NavigationStack + Form shape** (SettingsView.swift lines 63–78):
```swift
NavigationStack {
    Form {
        // sections
    }
    .navigationTitle("Settings")
}
```
`PlateInventoryEditor` is pushed (no NavigationStack of its own — it lands on the Settings tab's existing NavigationStack).

---

### `fitbod/Settings/PlateInventory+Defaults.swift` (utility, transform)

**Analog:** `fitbod/Routines/PrescriptionDefaults.swift` (pure defaults factory)

**Pure static factory pattern** (PrescriptionDefaults.swift — pure function returning value types, no SwiftData coupling):
```swift
// Pattern: pure namespace enum with static factory functions
enum PlateInventoryDefaults {
    static func make(for kind: PlateEquipmentKind, unitSystem: WeightUnit) -> [PlateSpec] {
        switch (kind, unitSystem) {
        case (.barbell, .kg): return kgBarbellDefaults
        case (.barbell, .lb): return lbBarbellDefaults
        // ...
        }
    }
    private static let kgBarbellDefaults: [PlateSpec] = [
        PlateSpec(weight: 25, countPerSide: 4),
        PlateSpec(weight: 20, countPerSide: 2),
        // ...
    ]
}
```

---

### `fitbod/Persistence/SchemaV3.swift` (config, CRUD)

**Analog:** `fitbod/Persistence/SchemaV2.swift` (exact shape)

**VersionedSchema enum pattern** (SchemaV2.swift lines 36–60):
```swift
import SwiftData

public enum SchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            // V1 inheritors
            Exercise.self,
            // ...
            // NEW in V2
            RoutineFolder.self,
            SupersetGroup.self,
            RoutineExerciseSetOverride.self,
        ]
    }
}
```
`SchemaV3`:
```swift
public enum SchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)

    public static var models: [any PersistentModel.Type] {
        SchemaV2.models + [PlateInventory.self]   // additive — one new entity
    }
}
```

---

### `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` (modified, config)

**Analog:** Self — the existing file gains one more stage.

**Migration stage registration pattern** (FitbodSchemaMigrationPlan.swift lines 29–47):
```swift
public enum FitbodSchemaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]           // ← add SchemaV3.self
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2]                          // ← add migrateV2toV3
    }

    public static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
    // add: public static let migrateV2toV3 = MigrationStage.lightweight(...)
}
```

---

### `fitbod/ExerciseLibrary/ExerciseDetailView.swift` (modified, component)

**Analog:** Self — adds a "Prescription Settings" section at the bottom.

**Section at bottom of List pattern** (ExerciseDetailView.swift line 80+ — the existing four sections pattern). New section follows the same structure:
```swift
Section {
    LabeledContent("Smallest increment") {
        TextField("e.g. 2.5", value: $smallestIncrement, format: .number)
            .multilineTextAlignment(.trailing)
            .keyboardType(.decimalPad)
    }
    // ... more rows
} header: {
    Text("Prescription Settings")
} footer: {
    Text("Weight advances by this amount each progression step.")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

---

## Test File Pattern Assignments

### `fitbodTests/Prescription/TuchschererTableTests.swift`

**Analog:** `fitbodTests/PreviousMatchingIntentTests.swift` (exact @Suite + @MainActor + .serialized + makeContext() helper pattern)

**Suite declaration pattern** (PreviousMatchingIntentTests.swift lines 28–43):
```swift
import Foundation
import SwiftData
import Testing
@testable import fitbod

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
```
`TuchschererTableTests` does NOT need `ModelContext` (pure function) — omit `makeContext()`. Use `@Suite` without `.serialized` (no shared mutable state). Use `@MainActor` only if the test calls `@MainActor`-isolated code.

**Parameterized test pattern** (from RESEARCH.md code example — matches Swift Testing 2026 best practice):
```swift
@Test("known cell values", arguments: zip(
    [(1, 10.0), (1, 8.0), (5, 8.0), (10, 6.0)],
    [1.000,     0.922,    0.811,     0.656]
))
func knownCellValues(input: (reps: Int, rpe: Double), expected: Double) {
    #expect(TuchschererTable.percent(reps: input.reps, rpe: input.rpe) == expected)
}
```

### `fitbodTests/Persistence/SchemaV3MigrationTests.swift`

**Analog:** `fitbodTests/SchemaV2MigrationTests.swift` (exact shape — no `@MainActor`, no `.serialized`)

**Migration test structure** (SchemaV2MigrationTests.swift lines 37–158):
```swift
@Suite("SchemaV2Migration")
struct SchemaV2MigrationTests {

    @Test("SchemaV2 models list contains every V1 entity plus 3 new types")
    func v2ModelsListIsCompleteSuperset() { ... }

    @Test("FitbodSchemaMigrationPlan registers V1 and V2 and a single lightweight stage")
    func migrationPlanIsWiredCorrectly() { ... }

    @Test("Fresh in-memory V2 ModelContainer opens; round-trips a Routine + new entity")
    func freshV2ContainerRoundTripsRoutineAndNewEntities() throws { ... }
}
```
`SchemaV3MigrationTests`:
- `SchemaV3 models list = SchemaV2.models + [PlateInventory]`
- `FitbodSchemaMigrationPlan.schemas == ["SchemaV1", "SchemaV2", "SchemaV3"]`
- `FitbodSchemaMigrationPlan.stages.count == 2`
- Round-trip `PlateInventory` insert/fetch with `availablePlatesData` field surviving save/reload

### `fitbodTests/Sessions/SessionFactoryPhase3Tests.swift`

**Analog:** `fitbodTests/SessionFactoryTests.swift` (@MainActor + .serialized + makeContext() helper)

**Context helper** (SessionFactoryTests.swift lines 45–54):
```swift
@MainActor
@Suite("SessionFactory", .serialized)
struct SessionFactoryTests {

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
```
Phase 3 version: `Schema(SchemaV3.models)` + `FitbodSchemaMigrationPlan.self`. Tests verify `SessionExercise.prescribedWeight` is non-nil after `SessionFactory.start(...)` and warm-up `SetEntry` rows are inserted with correct `orderIndex`.

---

## Shared Patterns

### @Model pattern
**Source:** `fitbod/Models/UserSettings.swift` (lines 23–53), `fitbod/Models/SetEntry.swift` (lines 24–58)
**Apply to:** `PlateInventory.swift`
```swift
@Model
public final class PlateInventory {
    @Attribute(.unique) public var id: UUID = UUID()
    public var equipmentKindRaw: String = "barbell"
    public var barWeight: Double = 20.0
    public var availablePlatesData: Data = Data()
    public var createdAt: Date = Date.now
    public var updatedAt: Date = Date.now

    public init() {}
}

extension PlateInventory {
    public var equipmentKind: PlateEquipmentKind {
        get { PlateEquipmentKind(rawValue: equipmentKindRaw) ?? .barbell }
        set { equipmentKindRaw = newValue.rawValue }
    }
    public var availablePlates: [PlateSpec] {
        get { (try? JSONDecoder().decode([PlateSpec].self, from: availablePlatesData)) ?? [] }
        set { availablePlatesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
```

### Enum-as-String persistence pattern
**Source:** `fitbod/Models/RoutineExercise.swift` (lines 31–57), `fitbod/Models/Exercise.swift` (lines 100–106)
**Apply to:** All new enums persisted on @Model entities (`PlateInventory.equipmentKindRaw`, `Exercise.unitOverrideRaw`)
```swift
// On the model:
public var equipmentKindRaw: String = "barbell"
// In extension:
public var equipmentKind: PlateEquipmentKind {
    get { PlateEquipmentKind(rawValue: equipmentKindRaw) ?? .barbell }
    set { equipmentKindRaw = newValue.rawValue }
}
```

### Pure function + Sendable struct pattern
**Source:** `fitbod/Sessions/PreviousMatchingIntent.swift` (lines 30–42, 44–108)
**Apply to:** All Prescription/ layer files — `ProgressionStrategy.swift`, `RPEAutoregStrategy.swift`, `DoubleProgressionStrategy.swift`, `Calibration.swift`, `PlateCalculator.swift`, `WarmupRamp.swift`

All strategy types are `struct` (implicitly `Sendable`) with no stored mutable properties. History data arrives as `[HistoryPoint]` pre-fetched by `SessionFactory`. The `enum` namespace pattern (no-instance enum with `static func`) is the project default for pure utility namespaces.

### #Predicate local-capture pattern
**Source:** `fitbod/Sessions/PreviousMatchingIntent.swift` (lines 73–84)
**Apply to:** Any new `FetchDescriptor` in `SessionFactory`'s Phase 3 additions (history fetch for calibration, `PlateInventory` fetch)
```swift
// ALWAYS extract to locals BEFORE the #Predicate body:
let targetID = exerciseID
let targetIntent = intentRaw
var descriptor = FetchDescriptor<SessionExercise>(
    predicate: #Predicate { se in
        se.intentRaw == targetIntent && se.exercise?.id == targetID
    },
    sortBy: [SortDescriptor(\.session?.startedAt, order: .reverse)]
)
descriptor.fetchLimit = 5
```

### Sheet presentation + dismiss pattern
**Source:** `fitbod/Sessions/DecimalRPEPickerSheet.swift` (lines 22–59)
**Apply to:** `WhyThisWeightSheet.swift`, `WarmupConfigSheet.swift`, `PlateCalculatorSheet.swift`
```swift
public struct DecimalRPEPickerSheet: View {
    @Binding public var rpe: Double
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            // content
            .navigationTitle("RPE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```
Caller:
```swift
.sheet(isPresented: $presentingSheet) {
    MySheet(...)
        .presentationDetents([.medium])   // UI-SPEC for Phase 3 sheets
}
```

### @Query + @Bindable write-through pattern
**Source:** `fitbod/Settings/SettingsView.swift` (lines 57–106)
**Apply to:** `PlateInventoryEditor.swift`, `SettingsView.swift` (new section)
```swift
@Query private var settingsList: [UserSettings]

// ...inside body:
if let settings = settingsList.first {
    @Bindable var s = settings
    Toggle(...) { ... }  // writes live through to SwiftData
}
```

### Section + footer help text pattern
**Source:** `fitbod/Settings/SettingsView.swift` (lines 87–106)
**Apply to:** All new `Form` sections in `SettingsView`, `PlateInventoryEditor`, `ExerciseDetailView`
```swift
Section {
    // row(s)
} header: {
    Text("Section Name")
} footer: {
    Text("Explanatory text.")
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

### Conditional inline view pattern
**Source:** `fitbod/Sessions/SessionExerciseCard.swift` (lines 81–85)
**Apply to:** `BumpBanner`, `CalibratingBadge`, `WarmupRampRows` insertion in `SessionExerciseCard`
```swift
if let note = sessionExercise.pinnedNote, !note.isEmpty {
    PinnedNoteCapsule(note: note) { onEditPinnedNote(sessionExercise) }
}
```

### @Preview pattern
**Source:** `fitbod/Sessions/DecimalRPEPickerSheet.swift` (lines 52–59), `fitbod/Sessions/ResumeWorkoutBanner.swift` (lines 117–147)
**Apply to:** All new View files
```swift
#Preview("descriptive name") {
    @Previewable @State var value: SomeType = .default
    return SomeView(value: $value)
        .modelContainer(PreviewModelContainer.make())
}
```
For sheets: wrap in `.sheet(isPresented: .constant(true)) { ... }` with `PreviewModelContainer.make()`.

### Swift Testing suite declaration pattern
**Source:** `fitbodTests/PreviousMatchingIntentTests.swift` (lines 28–43)
**Apply to:** All new test files in `fitbodTests/Prescription/` and `fitbodTests/Sessions/`
```swift
import Foundation
import SwiftData
import Testing
@testable import fitbod

@MainActor
@Suite("SuiteName", .serialized)
struct SuiteNameTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(SchemaV3.models)   // Phase 3: use V3
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: FitbodSchemaMigrationPlan.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test("descriptive test name")
    func descriptiveTestName() throws {
        let ctx = try makeContext()
        // ... arrange / act / assert
        #expect(result == expected)
    }
}
```
Pure-function tests (TuchschererTable, PlateCalculator, WarmupRamp, Calibration) omit `@MainActor` and `.serialized` since they touch no shared state.

---

## No Analog Found

All Phase 3 files have analogs. The closest-to-novel files are below — the planner should reference both the RESEARCH.md code examples AND the analog listed:

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `fitbod/Prescription/Calibration.swift` | utility | transform | No existing statistical/math utility in the codebase — use pure-enum namespace from `TuchschererTable`; algorithm from RESEARCH.md §3 |
| `fitbod/Sessions/PlateStackDisclosure.swift` | component | event-driven | No existing disclosure-animation component — use `SetRow`'s `VStack(spacing: 4)` conditional-child pattern; plate-rectangle visualization uses inline `HStack` of `Rectangle` shapes per UI-SPEC |
| `fitbod/Sessions/CalibratingBadge.swift` | component | transform | No existing capsule badge — reference `SetTypeChip.swift` for the chip/capsule shape |

---

## Metadata

**Analog search scope:** `fitbod/` (all Swift source) + `fitbodTests/` (all test Swift source)
**Files scanned:** 95 Swift source files
**Pattern extraction date:** 2026-05-22
