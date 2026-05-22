# Phase 4: Periodization & Blocks - Pattern Map

**Mapped:** 2026-05-22
**Files analyzed:** 32 new/modified files
**Analogs found:** 32 / 32

---

## Phase 3 Status Note (load-bearing)

As of mapping, `fitbod/Prescription/` does NOT exist on disk — Phase 3 is plan-only. This Phase 4 PATTERNS.md treats Phase 3 deliverables (`ProgressionStrategy` protocol, `PrescriptionExplanation`, `RPEAutoregStrategy`, `DoubleProgressionStrategy`, `PlateCalculator`, `WarmupRamp`, `TuchschererTable`, `CalibrationStatus`, `SchemaV3`) as **prerequisites** that Phase 4 plans must verify exist before consumption. If a Phase 4 plan would land before Phase 3, the planner inlines the Phase 3 protocol shape from Phase 3's plan docs (`.planning/phases/03-smart-prescription-warm-ups/03-05-PLAN.md` lines 99–102, 138–149, 156–161 are the canonical references) and the schema chain (V2 → V3 → V4) per CONTEXT D-26.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `fitbod/Prescription/PeriodizationEngine.swift` | service / utility | transform | `fitbod/Sessions/PreviousMatchingIntent.swift` | role-match (pure-function namespace enum) |
| `fitbod/Prescription/BlockPeriodizedStrategy.swift` | service / strategy | transform | Phase 3 plan: `RPEAutoregStrategy` (03-05-PLAN.md) + `fitbod/Sessions/PreviousMatchingIntent.swift` | role-match (Sendable struct conforming to a Sendable protocol) |
| `fitbod/Prescription/HybridStrategy.swift` | service / strategy | transform | Phase 3 plan: `DoubleProgressionStrategy` (03-05-PLAN.md) | role-match (composes two other strategies) |
| `fitbod/Prescription/FatigueAdvisory.swift` | protocol / value type | transform | `fitbod/Sessions/PreviousMatchingIntent.swift` (PreviousMatchingIntentHit) + `fitbod/Models/Enums/BlockPhaseKind.swift` | role-match (Sendable protocol + value type) |
| `fitbod/Prescription/StubFatigueAdvisory.swift` | service | transform | `fitbod/Sessions/RestTimer/RestTimerEngine.swift` (NoopActivityController) | role-match (Noop default impl pattern) |
| `fitbod/Periodization/BlockBuilderView.swift` | view / form | event-driven | `fitbod/Routines/RoutineBuilderView.swift` | exact (Form + @Bindable draft + Save/Cancel toolbar + edit/create modes) |
| `fitbod/Periodization/BlockDraft.swift` | view-model (ephemeral) | transform | `fitbod/Routines/RoutineDraft.swift` | exact (@Observable draft + three-way merge save) |
| `fitbod/Periodization/BlockPhaseDraft.swift` | view-model (ephemeral) | transform | `fitbod/Routines/RoutineDraft.swift` (RoutineExerciseDraft) | exact (@Observable inner draft, mirrors child @Model row) |
| `fitbod/Periodization/BlockPhaseEditorRow.swift` | view (inline editor) | event-driven | `fitbod/Routines/PrescriptionEditorRow.swift` | exact (Stepper + Picker rows bound to @Bindable draft) |
| `fitbod/Periodization/BlockTemplates.swift` | utility / static catalog | transform | `fitbod/Routines/PrescriptionDefaults.swift` | exact (pure enum namespace with static factory methods) |
| `fitbod/Periodization/BlockTemplate.swift` | value type | transform | `fitbod/Sessions/PreviousMatchingIntent.swift` (PreviousMatchingIntentHit) | role-match (Sendable struct, memberwise init) |
| `fitbod/Periodization/BlockPhaseColors.swift` | utility / static catalog | transform | `fitbod/Routines/PrescriptionDefaults.swift` | role-match (pure enum namespace, semantic factory) |
| `fitbod/Periodization/BlockCard.swift` | view / component | event-driven | `fitbod/Sessions/ResumeWorkoutBanner.swift` + `fitbod/App/RootView.swift` (TabView) | role-match (banner-shape view with internal TabView pager) |
| `fitbod/Periodization/MesocycleWeekPage.swift` | view / component | transform | `fitbod/Sessions/SessionExerciseCard.swift` (subview) + `fitbod/Sessions/ResumeWorkoutBanner.swift` (banner body) | role-match (single composite SwiftUI block reading a context value) |
| `fitbod/Periodization/MesocycleWeekContext.swift` | value type | transform | `fitbod/Sessions/PreviousMatchingIntent.swift` (PreviousMatchingIntentHit) | role-match (Sendable value carrier) |
| `fitbod/Periodization/DeloadWeekBanner.swift` | view / banner | transform | `fitbod/Sessions/ResumeWorkoutBanner.swift` | exact (top-of-tab banner, conditional render, no @Query — receives context) |
| `fitbod/Periodization/ConsiderDeloadBanner.swift` | view / banner | event-driven | `fitbod/Sessions/ResumeWorkoutBanner.swift` | exact (dismissible banner with two trailing buttons) |
| `fitbod/Periodization/BlockReviewView.swift` | view / sheet | request-response | `fitbod/Sessions/PerSetNoteSheet.swift` (sheet shell) + `fitbod/Settings/SettingsView.swift` (Form sections + @Query) | role-match (NavigationStack-wrapped Form sheet) |
| `fitbod/Periodization/BlockRow.swift` | view / row | transform | `fitbod/Routines/RoutineRow.swift` | exact (List row with name + caption + trailing badge) |
| `fitbod/Periodization/StartBlockCTA.swift` | view / empty-state | event-driven | `fitbod/Routines/RoutinesListView.swift` (emptyState) | role-match (heading + body + accent text button) |
| `fitbod/Periodization/BlockPickerMenu.swift` | view / picker | event-driven | `fitbod/Routines/MoveRoutineSheet.swift` + `fitbod/Routines/RoutinesListView.swift` toolbar Menu | role-match (Menu with current selection + accent foreground) |
| `fitbod/Persistence/SchemaV3.swift` (modify if Phase 3 ships first) **OR** `fitbod/Persistence/SchemaV4.swift` (new) | config | CRUD | `fitbod/Persistence/SchemaV2.swift` | exact (VersionedSchema with additive delta) |
| `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` (modify) | config | CRUD | `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` | exact (append schema + lightweight stage) |
| `fitbod/Models/Block.swift` (modify) | model | CRUD | `fitbod/Models/Block.swift` | exact (one additive Date? field with default nil) |
| `fitbod/Routines/RoutinesListView.swift` (modify) | view / list | event-driven | `fitbod/Routines/RoutinesListView.swift` | exact (add a section above existing sections) |
| `fitbod/Routines/RoutineBuilderView.swift` (modify) | view / form | event-driven | `fitbod/Routines/RoutineBuilderView.swift` | exact (add a header-section row) |
| `fitbod/Routines/RoutineDraft.swift` (modify) | view-model | transform | `fitbod/Routines/RoutineDraft.swift` | exact (one new field on the @Observable class + save-path materialization) |
| `fitbod/Routines/PrescriptionEditorRow.swift` (modify) | view / editor | event-driven | `fitbod/Routines/PrescriptionEditorRow.swift` | exact (conditional Picker cases) |
| `fitbod/Sessions/SessionFactory.swift` (modify) | service | request-response | `fitbod/Sessions/SessionFactory.swift` | exact (already line 101 sets `session.block = routine.block` — Phase 4 adds the deload set-count cut sibling logic) |
| `fitbod/App/RootView.swift` (modify TodayView) | view / tab body | event-driven | `fitbod/App/RootView.swift` (TodayView) | exact (insert new stack ordering before existing ResumeWorkoutBanner) |
| `fitbod/Prescription/ProgressionStrategy.swift` (Phase 3 — modify) | protocol | transform | `.planning/phases/03-smart-prescription-warm-ups/03-05-PLAN.md` lines 99–102, 156–161 | role-match (extend protocol requirement with default-valued params) |
| `fitbod/Prescription/ProgressionStrategyFactory.swift` (Phase 3 — modify) | factory | transform | Phase 3 plan docs (factory ships in Phase 3) | role-match (swap fallback stub for real strategies) |

---

## Pattern Assignments

### `fitbod/Prescription/PeriodizationEngine.swift` (service, transform)

**Analog:** `fitbod/Sessions/PreviousMatchingIntent.swift`

**Imports pattern** (PreviousMatchingIntent.swift lines 24–25):
```swift
import Foundation
import SwiftData
```
Engine is pure-function but optionally accepts `Block` (a `@Model` reference) — keep both imports. The engine itself does NOT touch `ModelContext`.

**Namespace-enum + static func pattern** (PreviousMatchingIntent.swift lines 44–66 — abridged):
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
Copy this shape for `public enum PeriodizationEngine { public static func phase(for: Block, on: Date) -> BlockPhase? { ... } }`. Empty initializer not needed because it's a caseless enum.

**Sendable value-type carrier pattern** (PreviousMatchingIntent.swift lines 30–42):
```swift
public struct PreviousMatchingIntentHit: Sendable {
    public let weight: Double
    public let reps: Int
    public let rpe: Double?
    public let sessionStartedAt: Date
    public init(weight: Double, reps: Int, rpe: Double?, sessionStartedAt: Date) { ... }
}
```
Mirror this for `MesocycleWeekContext` — all-let stored properties, memberwise public init, `: Sendable`. Lives alongside `PeriodizationEngine` or in a sibling file per planner choice (per 04-RESEARCH.md line 608, inline is acceptable).

**Reference implementation already drafted** (04-RESEARCH.md lines 870–905) — the executor reuses the day-count math verbatim (`Int(floor(date.timeIntervalSince(block.startDate) / 86400))`) and the `recommendedNextKind(after:)` switch.

---

### `fitbod/Prescription/BlockPeriodizedStrategy.swift` (service / strategy, transform)

**Analog:** Phase 3 plan `RPEAutoregStrategy` (`.planning/phases/03-smart-prescription-warm-ups/03-05-PLAN.md` lines 263–294) + `fitbod/Sessions/PreviousMatchingIntent.swift`.

**Protocol-conforming Sendable struct pattern** (03-05-PLAN.md line 281):
```swift
public struct RPEAutoregStrategy: ProgressionStrategy {
    public init() {}
    public func prescribe(...) -> (weight: Double, explanation: PrescriptionExplanation) { ... }
}
```
Mirror for `BlockPeriodizedStrategy`: no stored properties, public init, single `prescribe(...)` method conforming to the protocol. Implicit `Sendable` follows from `Sendable`-only stored state (none).

**Imports pattern** (PreviousMatchingIntent.swift lines 24–25):
```swift
import Foundation
import SwiftData  // because the prescribe() signature takes `block: Block?` and Block is a SwiftData @Model
```

**No-history fallback pattern** (03-05-PLAN.md line 204):
```swift
// When lastSessionWeight is nil (first session, no prior data):
return (weight: 0, explanation: PrescriptionExplanation(
    lastSessionLine: nil,
    formulaName: "Double progression",
    computedLine: nil,
    roundedWeight: 0,
    roundedLine: "No prior data — starting at prescribed weight.",
    status: .notApplicable,
    bumpOccurred: false,
    range: nil
))
```
Adapt for `BlockPeriodizedStrategy`: when `RoutineExercise.prescribedWeight` is nil (or whatever no-history baseline source is resolved per Open Question #1), return `(0, PrescriptionExplanation(formulaName: "Block periodized", roundedWeight: 0, roundedLine: "No prior data — log a baseline session first.", status: .notApplicable, ...))`.

**Pure-function with engine call pattern** (04-RESEARCH.md §HybridStrategy code example lines 954–1008 shows the prescribe signature shape Phase 4 lands):
```swift
public func prescribe(
    history: [HistoryPoint],
    targetRepsLow: Int, targetRepsHigh: Int,
    targetRPE: Double?,
    smallestIncrement: Double,
    plates: [(weight: Double, countPerSide: Int)],
    barWeight: Double,
    minCalibrationSets: Int,
    lastSessionWeight: Double?, lastSessionReps: Int?,
    lastSessionRPE: Double?, lastSessionDate: Date?,
    lastSessionRepsArray: [Int]? = nil,
    block: Block? = nil,
    today: Date = Date.now
) -> (weight: Double, explanation: PrescriptionExplanation) {
    guard let block, let phase = PeriodizationEngine.phase(for: block, on: today),
          let baseline = lastSessionWeight else { /* no-history fallback */ }
    let raw = baseline * phase.intensityMultiplier
    let rounded = PlateCalculator.roundDown(target: raw, barWeight: barWeight, plates: plates)
    return (rounded, PrescriptionExplanation(
        lastSessionLine: ...,
        formulaName: "Block periodized",
        computedLine: "Phase \(phase.kind.rawValue): baseline \(baseline) kg × ×\(phase.intensityMultiplier) → \(raw) kg",
        roundedWeight: rounded,
        roundedLine: "→ \(rounded) kg (plate-rounded)",
        status: .notApplicable,
        bumpOccurred: false,
        range: nil
    ))
}
```

---

### `fitbod/Prescription/HybridStrategy.swift` (service / strategy, transform)

**Analog:** Phase 3 plan `DoubleProgressionStrategy` (03-05-PLAN.md lines 200–241) + composition pattern from 04-RESEARCH.md lines 953–1008.

**Composition pattern** (04-RESEARCH.md lines 975–1006 — verbatim drafted):
```swift
let blockResult = BlockPeriodizedStrategy().prescribe(/* full param list incl block, today */)
let rpeResult   = RPEAutoregStrategy().prescribe(/* full param list, omit block-aware params */)
let chosen = min(blockResult.weight, rpeResult.weight)
let source = chosen == blockResult.weight ? "block ceiling" : "rpe-driven"
let explanation = PrescriptionExplanation(
    lastSessionLine: rpeResult.explanation.lastSessionLine,
    formulaName: "Hybrid (block + RPE)",
    computedLine: "Block ceiling: \(blockResult.weight) kg · RPE target: \(rpeResult.weight) kg · Using: \(source) → \(chosen) kg",
    roundedWeight: chosen,
    roundedLine: "→ \(chosen) kg (chose lower of block / RPE)",
    status: rpeResult.explanation.status,
    bumpOccurred: false,
    range: nil
)
```
Property-based invariant: `chosen <= blockResult.weight && chosen <= rpeResult.weight` (tested in `HybridStrategyTests`).

---

### `fitbod/Prescription/FatigueAdvisory.swift` (protocol + value type, transform)

**Analog:** `fitbod/Models/Enums/BlockPhaseKind.swift` (Sendable type) + `fitbod/Sessions/PreviousMatchingIntent.swift` (PreviousMatchingIntentHit value type).

**Sendable protocol pattern** (Phase 3 plan 03-05-PLAN.md line 138 — `public protocol ProgressionStrategy: Sendable`):
```swift
public protocol FatigueAdvisory: Sendable {
    func shouldSuggest(context: SessionContext) -> Bool
    func suggestion(context: SessionContext) -> FatigueSuggestion
}
```
Type-level canonicality contract (CONTEXT D-25): both methods return either `Bool` or `FatigueSuggestion`, NEVER a `DeloadMutation` or any `Block`-mutating value. The `FatigueAdvisoryCanonicalityTests` suite asserts this by inspecting the protocol surface.

**Sendable value type pattern** (PreviousMatchingIntent.swift lines 30–42):
```swift
public struct FatigueSuggestion: Sendable {
    public let reason: String
    public init(reason: String) { self.reason = reason }
}
```
All-let stored properties; memberwise public init; implicitly `Sendable` because every stored property is.

---

### `fitbod/Prescription/StubFatigueAdvisory.swift` (service, transform)

**Analog:** `fitbod/Sessions/RestTimer/RestTimerEngine.swift` (NoopActivityController) — same "default no-op impl swappable for production impl" pattern.

**Noop default impl pattern** (RestTimerEngine.swift lines 110–118):
```swift
public init(
    scheduler: RestTimerNotificationScheduling = LiveNotificationScheduler(),
    activityController: RestTimerActivityControlling = NoopActivityController(),
    now: @escaping () -> Date = { Date.now }
) { ... }
```
Mirror this DI pattern for `ConsiderDeloadBanner(advisory: FatigueAdvisory = StubFatigueAdvisory())`. Phase 5 swaps the default to the real impl without touching the view's init signature.

**Stub body shape:**
```swift
public struct StubFatigueAdvisory: FatigueAdvisory {
    public init() {}
    public func shouldSuggest(context: SessionContext) -> Bool { false }
    public func suggestion(context: SessionContext) -> FatigueSuggestion {
        FatigueSuggestion(reason: "")
    }
}
```

---

### `fitbod/Periodization/BlockBuilderView.swift` (view / form, event-driven)

**Analog:** `fitbod/Routines/RoutineBuilderView.swift` (lines 66–215)

**Imports + struct + @Bindable + edit-mode property pattern** (RoutineBuilderView.swift lines 63–84):
```swift
import SwiftUI
import SwiftData

public struct RoutineBuilderView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Bindable public var draft: RoutineDraft
    public let editing: Routine?

    @State private var expandedExerciseIDs: Set<UUID> = []
    @State private var presentingDiscardConfirm = false
    @State private var initialSnapshot: String = ""

    public init(draft: RoutineDraft, editing: Routine? = nil) {
        self.draft = draft
        self.editing = editing
    }
}
```
Mirror for `BlockBuilderView`: `@Bindable public var draft: BlockDraft`, `public let editing: Block?`, same `ctx`/`dismiss` environment, same `initialSnapshot: String` for dirty check.

**Form + Section + @State expansion-tracking pattern** (RoutineBuilderView.swift lines 85–142):
```swift
Form {
    Section { TextField("Routine name", text: $draft.name) }
    Section("Exercises") {
        if draft.exercises.isEmpty {
            Text("Add an exercise to begin.").foregroundStyle(.secondary)
        } else {
            ForEach(draft.exercises) { exDraft in
                RoutineExerciseCard(draft: exDraft, ...)
            }
            .onMove { source, destination in
                draft.exercises.move(fromOffsets: source, toOffset: destination)
                for (i, ex) in draft.exercises.enumerated() { ex.orderIndex = i }
            }
            .onDelete { offsets in
                draft.exercises.remove(atOffsets: offsets)
                for (i, ex) in draft.exercises.enumerated() { ex.orderIndex = i }
            }
        }
        InlineExerciseSearchRow { exercise in draft.append(exercise: exercise) }
    }
}
.environment(\.editMode, .constant(.active))
```
Mirror for `BlockBuilderView`: name + start-date + active-toggle in a top Section; phases Section with `ForEach(draft.phases) { phaseDraft in BlockPhaseEditorRow(draft: phaseDraft) }`; same `.onMove` rewriting `orderIndex` 0..<count; same `.onDelete` for swipe-to-delete; "+ Phase" Menu trigger at the bottom (replaces `InlineExerciseSearchRow`).

**Toolbar Save/Cancel pattern** (RoutineBuilderView.swift lines 159–176):
```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") {
            if hasUnsavedChanges { presentingDiscardConfirm = true } else { dismiss() }
        }
    }
    ToolbarItem(placement: .topBarTrailing) {
        Button("Save") { save() }
            .disabled(!draft.isValid)
            .foregroundStyle(Color.accentColor)
    }
}
.confirmationDialog(
    "Discard Changes?", isPresented: $presentingDiscardConfirm, titleVisibility: .visible
) {
    Button("Discard", role: .destructive) { dismiss() }
    Button("Keep Editing", role: .cancel) { presentingDiscardConfirm = false }
}
```
Copy verbatim; only the navigation title changes (`"New Block"` / `editing.name`).

**Save action pattern** (RoutineBuilderView.swift lines 262–273):
```swift
private func save() {
    let routine: Routine
    if let editing { routine = editing } else {
        routine = Routine()
        ctx.insert(routine)
    }
    draft.save(into: routine, context: ctx)
    try? ctx.save()
    dismiss()
}
```
Adapt for `BlockBuilderView.save()`: BlockDraft's save signature is different (takes `into context: ModelContext` only; it owns the Block fetch/create internally per 04-RESEARCH.md lines 912–948), so the wrapper becomes:
```swift
private func save() {
    do {
        try draft.save(into: ctx)
        dismiss()
    } catch {
        // surface inline "Couldn't save block. Try again." footer
    }
}
```

**Dirty-check snapshot pattern** (RoutineBuilderView.swift lines 247–258):
```swift
private var hasUnsavedChanges: Bool { snapshotHash() != initialSnapshot }
private func snapshotHash() -> String {
    let counts = draft.exercises.map { $0.targetSets }.reduce(0, +)
    let ids = draft.exercises.map { $0.id?.uuidString ?? "new" }.joined(separator: ",")
    return "\(draft.name)|\(draft.exercises.count)|\(counts)|\(ids)"
}
```
Adapt: `"\(draft.name)|\(draft.phases.count)|\(draft.phases.map(\.weeks).reduce(0, +))|\(draft.isActive)|\(draft.startDate.timeIntervalSince1970)"`.

---

### `fitbod/Periodization/BlockDraft.swift` (view-model ephemeral, transform)

**Analog:** `fitbod/Routines/RoutineDraft.swift` (lines 50–182)

**@Observable @MainActor class shell** (RoutineDraft.swift lines 53–104):
```swift
@Observable
@MainActor
public final class RoutineDraft {
    public var name: String = ""
    public var notes: String? = nil
    public var folderID: UUID? = nil
    public var exercises: [RoutineExerciseDraft] = []

    public init() {}

    public init(routine: Routine) {
        self.name = routine.name
        self.notes = routine.notes
        self.folderID = routine.folderID
        self.exercises = (routine.exercises ?? [])
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { RoutineExerciseDraft(re: $0) }
    }

    public var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !exercises.isEmpty
    }
}
```
Mirror for `BlockDraft`: fields per 04-RESEARCH.md line 600 (`name`, `startDate`, `isActive`, `phases: [BlockPhaseDraft]`, optional `reviewedAt`). `isValid` requires non-empty name AND at least one phase.

**Round-trip-from-existing init pattern** (RoutineDraft.swift lines 79–86): mirror with `public init(block: Block)` reading `name`, `startDate`, `isActive`, sorting phases by `orderIndex`, mapping to `BlockPhaseDraft`.

**Three-way merge save pattern with transaction** (04-RESEARCH.md lines 910–948 — already drafted for the single-active invariant):
```swift
extension BlockDraft {
    func save(into context: ModelContext) throws {
        try context.transaction {
            // D-05: deactivate other active blocks first
            if isActive {
                let descriptor = FetchDescriptor<Block>(predicate: #Predicate<Block> { other in
                    other.isActive == true
                })
                let others = try context.fetch(descriptor)
                for other in others where other.id != self.id {
                    other.isActive = false
                }
            }
            // Materialize (fetch existing or create new)
            let block = try fetchOrCreate(in: context)
            block.name = self.name
            block.startDate = self.startDate
            block.isActive = self.isActive
            block.endDate = computedEndDate()
            // Replace phases (cascade-managed)
            block.phases?.forEach { context.delete($0) }
            block.phases = self.phases.enumerated().map { idx, draftPhase in
                let phase = BlockPhase()
                phase.orderIndex = idx
                phase.nameRaw = draftPhase.kind.rawValue
                phase.weeks = draftPhase.weeks
                phase.volumeMultiplier = draftPhase.volumeMultiplier
                phase.intensityMultiplier = draftPhase.intensityMultiplier
                return phase
            }
            try context.save()
        }
    }
}
```
**KEY DIVERGENCE FROM RoutineDraft:** BlockDraft's save deletes-and-recreates the phases array (since BlockPhase has no soft-ref children to worry about), whereas RoutineDraft does a full three-way merge per-id (because cascade-owned RoutineExerciseSetOverride children need id preservation). Simpler model — Block has no grandchildren to preserve.

**RoutineDraft three-way merge for reference** (RoutineDraft.swift lines 124–130 — pattern Phase 4 deliberately simplifies past):
```swift
let existingExercises = routine.exercises ?? []
let draftIDs = Set(exercises.compactMap { $0.id })
for old in existingExercises where !draftIDs.contains(old.id) {
    context.delete(old)
}
```

---

### `fitbod/Periodization/BlockPhaseDraft.swift` (view-model ephemeral, transform)

**Analog:** `fitbod/Routines/RoutineDraft.swift` (RoutineExerciseDraft, lines 186–262)

**@Observable inner draft pattern** (RoutineDraft.swift lines 186–221):
```swift
@Observable
@MainActor
public final class RoutineExerciseDraft: Identifiable {
    public var id: UUID? = nil
    public var exercise: Exercise? = nil
    public var orderIndex: Int = 0
    public var intent: Intent = .hypertrophy

    public var targetSets: Int = 3 {
        didSet { /* prune overrides */ }
    }
    public var targetRepsLow: Int = 8
    public var targetRepsHigh: Int = 12
    public var targetRPE: Double? = 8.0
    // ...
    public init() {}

    convenience init(re: RoutineExercise) {
        self.init()
        self.id = re.id
        self.exercise = re.exercise
        // ...
    }
}
```
Mirror for `BlockPhaseDraft`: 
- `id: UUID?` (nil until materialized)
- `kind: BlockPhaseKind` (default `.accumulation`)
- `weeks: Int = 4`
- `volumeMultiplier: Double = 1.0`
- `intensityMultiplier: Double = 1.0`
- `kind`'s `didSet` auto-applies D-10 multiplier defaults (UI-SPEC § Interaction patterns line 462 — picking a kind auto-applies that kind's RP defaults)
- `convenience init(phase: BlockPhase)` round-trips from the persisted row.

---

### `fitbod/Periodization/BlockPhaseEditorRow.swift` (view inline editor, event-driven)

**Analog:** `fitbod/Routines/PrescriptionEditorRow.swift` (lines 32–192)

**@Bindable inline editor shell** (PrescriptionEditorRow.swift lines 32–55):
```swift
public struct PrescriptionEditorRow: View {
    @Bindable public var draft: RoutineExerciseDraft

    public init(draft: RoutineExerciseDraft) { self.draft = draft }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            intentPicker
            setsStepper
            // ...
        }
        .padding(.vertical, 8)
    }
}
```
Mirror for `BlockPhaseEditorRow`: `@Bindable public var draft: BlockPhaseDraft`, body is a VStack of: phase-kind chip (Menu), weeks Stepper, volume Stepper, intensity Stepper.

**Picker / Menu pattern** (PrescriptionEditorRow.swift lines 166–180):
```swift
private var progressionPicker: some View {
    HStack {
        Text("Progression")
        Spacer()
        Picker("Progression", selection: $draft.progressionKind) {
            Text("RPE Autoregulation").tag(ProgressionKind.rpe)
            Text("Double Progression").tag(ProgressionKind.double)
            Text("Block Periodized").tag(ProgressionKind.block)
            Text("Hybrid").tag(ProgressionKind.hybrid)
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .accessibilityLabel("Progression")
    }
}
```
Adapt for the phase-kind chip — but per UI-SPEC line 458–462, the kind picker uses a `Menu` with chip styling (not a `.pickerStyle(.menu)`). Closer to the long-press context menu shape in RoutineRow.swift lines 87–114. The chip body itself reuses `IntentFilterChipRow.chip(...)` shape (see Shared Patterns below).

**Stepper pattern** (PrescriptionEditorRow.swift lines 79–88):
```swift
private var setsStepper: some View {
    Stepper(value: $draft.targetSets, in: 1...20) {
        HStack {
            Text("Sets")
            Spacer()
            Text("\(draft.targetSets)")
                .foregroundStyle(.secondary)
        }
    }
}
```
Copy 3× for weeks (range 1...12, step 1), volume (range 0.3...1.5, step 0.05), intensity (range 0.3...1.1, step 0.01). UI-SPEC lines 232–239 lock the ranges.

**Conditional render pattern** (PrescriptionEditorRow.swift lines 198–218 — `if draft.tracksTempo`): use the same `@ViewBuilder if {}` shape if any phase-row sub-element is conditional.

---

### `fitbod/Periodization/BlockTemplates.swift` (utility / static catalog, transform)

**Analog:** `fitbod/Routines/PrescriptionDefaults.swift` (lines 27–57)

**Pure enum namespace + static factory pattern** (PrescriptionDefaults.swift lines 27–57):
```swift
import Foundation

public enum PrescriptionDefaults {
    @MainActor
    public static func apply(to draft: RoutineExerciseDraft, from exercise: Exercise) {
        let isCompound = exercise.mechanic == .compound
        let isBarbell = exercise.equipment == .barbell

        draft.prescribedRestSeconds = isCompound ? 180 : 90
        if isCompound && isBarbell {
            draft.intent = .strength
            draft.targetRepsLow = 4
            draft.targetRepsHigh = 6
            // ...
        }
    }
}
```
Mirror for `BlockTemplates`:
```swift
public enum BlockTemplates {
    public static let generic = BlockTemplate(
        name: "Generic Strength Meso",
        phases: [
            BlockPhaseDraft(kind: .accumulation,    weeks: 4, volumeMultiplier: 1.0,  intensityMultiplier: 0.75),
            BlockPhaseDraft(kind: .intensification, weeks: 2, volumeMultiplier: 0.85, intensityMultiplier: 0.88),
            BlockPhaseDraft(kind: .realization,     weeks: 1, volumeMultiplier: 0.6,  intensityMultiplier: 0.97),
            BlockPhaseDraft(kind: .deload,          weeks: 1, volumeMultiplier: 0.5,  intensityMultiplier: 0.75)
        ]
    )
    public static let hypertrophy = BlockTemplate(name: "Hypertrophy Meso", phases: [...])
    public static let powerliftingPeak = BlockTemplate(name: "Powerlifting Peak", phases: [...])
    public static let blank = BlockTemplate(name: "Blank Block", phases: [])

    /// For BlockReviewView's "Start [Recommended] Block" CTA.
    public static func template(for kind: BlockPhaseKind) -> BlockTemplate {
        switch kind {
        case .accumulation:    return generic
        case .intensification: return hypertrophy
        // ...
        }
    }
}
```
Per CONTEXT D-10 multipliers and 04-RESEARCH.md §Files line 603.

---

### `fitbod/Periodization/BlockPhaseColors.swift` (utility / static catalog, transform)

**Analog:** Same as `BlockTemplates.swift` (pure enum namespace, semantic factory).

**Reference implementation already drafted** (04-UI-SPEC.md lines 479–495):
```swift
public enum BlockPhaseColors {
    public static func color(for kind: BlockPhaseKind) -> Color {
        switch kind {
        case .accumulation:    return Color.accentColor              // #0E7C86 / #3FBFC9
        case .intensification: return Color(red: 0.96, green: 0.62, blue: 0.04)  // #F59E0B
        case .realization:     return Color(red: 0.92, green: 0.34, blue: 0.05)  // #EA580C
        case .deload:          return Color(red: 0.58, green: 0.64, blue: 0.72)  // #94A3B8
        }
    }
    public static func tint(for kind: BlockPhaseKind) -> Color {
        color(for: kind).opacity(0.15)
    }
}
```
Per UI-SPEC line 305, also add `public static func phaseLabel(_ kind: BlockPhaseKind) -> String` for title-case rendering.

---

### `fitbod/Periodization/BlockCard.swift` (view / component, event-driven)

**Analog:** `fitbod/Sessions/ResumeWorkoutBanner.swift` (banner shape) + `fitbod/App/RootView.swift` lines 152–199 (TabView with `tabSelection` binding).

**Top-of-tab banner shell + @Query pattern** (ResumeWorkoutBanner.swift lines 52–80):
```swift
public struct ResumeWorkoutBanner: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<Session> { $0.completedAt == nil })
    private var activeSessions: [Session]
    // ...
    public var body: some View {
        if let active = activeSessions.first {
            bannerBody(active: active)
        } else {
            EmptyView()
        }
    }
}
```
Adapt for `BlockCard`:
```swift
public struct BlockCard: View {
    @Query(filter: #Predicate<Block> { $0.isActive })
    private var activeBlocks: [Block]
    @State private var selectedWeekIndex: Int = 0

    public var body: some View {
        if let active = activeBlocks.first {
            cardBody(active: active)
        } else {
            EmptyView()
        }
    }
}
```
**KEY:** the parent `TodayView` decides whether to render `BlockCard` vs `StartBlockCTA` based on the SAME predicate. Either both views own `@Query` (cheap; SwiftData reuses the query result) or the parent owns it and passes a `Block` down. Per RESEARCH.md and UI-SPEC line 381, `BlockCard` owns its own `@Query`.

**TabView paging pattern** (RootView.swift line 153 + 04-RESEARCH.md §Don't Hand-Roll line 1123):
```swift
TabView(selection: $selectedWeekIndex) {
    ForEach(0..<totalWeeks, id: \.self) { weekIndex in
        MesocycleWeekPage(
            block: active,
            weekIndex: weekIndex,
            phase: PeriodizationEngine.phase(for: active, on: weekStartDate(weekIndex)) ?? defaultPhase
        )
        .tag(weekIndex)
    }
}
.tabViewStyle(.page(indexDisplayMode: .never))
```
**Initial selection** (UI-SPEC line 400): `selectedWeekIndex = PeriodizationEngine.weekIndex(for: active, on: Date.now) ?? 0` — set in `.onAppear` or via `@State` initializer.

**Banner body wrapper styling** (ResumeWorkoutBanner.swift lines 96–101):
```swift
.padding(16)
.background(Color(.secondarySystemGroupedBackground))
.clipShape(RoundedRectangle(cornerRadius: 12))
.padding(.horizontal, 16)
.padding(.vertical, 8)
```
Copy for the BlockCard outer card; per UI-SPEC the card background tint changes to the current week's phase tint (15% opacity).

**Overflow menu pattern** — UI-SPEC line 145 "End Block / Edit Block" Menu — mirror RoutinesListView.swift lines 99–112 toolbar Menu:
```swift
Menu {
    Button("End Block", role: .destructive) { /* ... */ }
    Button("Edit Block") { /* ... */ }
} label: {
    Label("Block actions", systemImage: "ellipsis.circle")
        .labelStyle(.iconOnly)
}
```

---

### `fitbod/Periodization/MesocycleWeekPage.swift` (view / component, transform)

**Analog:** `fitbod/Sessions/ResumeWorkoutBanner.swift` body shape + `fitbod/Routines/RoutineRow.swift` for the routines-list rows.

**Composite body from a single context value pattern** (ResumeWorkoutBanner.swift lines 82–101 — abridged):
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
        // ...
    }
    .padding(16)
    // ...
}
```
Mirror for `MesocycleWeekPage`: receives `(block: Block, weekIndex: Int, phase: BlockPhase)`, renders VStack with phase chip + week badge + days-remaining + multipliers preview + scheduled-routines list. Each routine row reuses the `RoutineRow` styling shape but is a simpler "tap-to-navigate" disclosure row.

**Scheduled-routines list pattern** — borrow from RoutinesListView.swift lines 229–238 (one row per `Routine`, navigation closure):
```swift
ForEach(scheduledRoutines) { routine in
    HStack {
        Text(routine.name).font(.body)
        Spacer()
        Image(systemName: "chevron.right").foregroundStyle(.secondary)
    }
    .onTapGesture { /* navigate to RoutineBuilderView */ }
}
```

---

### `fitbod/Periodization/DeloadWeekBanner.swift` (view / banner, transform)

**Analog:** `fitbod/Sessions/ResumeWorkoutBanner.swift` (lines 73–115)

**Conditional banner + tinted background pattern** (ResumeWorkoutBanner.swift lines 96–101):
```swift
.padding(16)
.background(Color(.secondarySystemGroupedBackground))
.clipShape(RoundedRectangle(cornerRadius: 12))
.padding(.horizontal, 16)
.padding(.vertical, 8)
```
Adapt — replace background color with `BlockPhaseColors.tint(for: .deload)` per UI-SPEC line 164:
```swift
public struct DeloadWeekBanner: View {
    public let currentPhase: BlockPhase

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Deload week — recover, don't load.")              // UI-SPEC verbatim
                .font(.headline)
            Text("Working sets cut by ~50%. Weights held to phase intensity.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BlockPhaseColors.tint(for: .deload))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Deload week active. Working sets are cut by approximately fifty percent. Weights are held at deload phase intensity.")
    }
}
```
**Non-dismissible** — no @State dismiss flag, no trailing button.

---

### `fitbod/Periodization/ConsiderDeloadBanner.swift` (view / banner, event-driven)

**Analog:** `fitbod/Sessions/ResumeWorkoutBanner.swift` (lines 73–115) — but DISMISSIBLE.

**Trailing buttons + dismiss pattern** (ResumeWorkoutBanner.swift lines 88–95):
```swift
HStack(spacing: 12) {
    // ...
    Spacer()
    Button("Resume") { onResume(active) }
        .foregroundStyle(Color.accentColor)
    Button("Discard", role: .destructive) {
        discardConfirm = true
    }
}
```
Adapt for ConsiderDeloadBanner — trailing "Adjust block" (accent) + xmark dismiss button. Per UI-SPEC lines 176–177:
- `xmark` button → sets a per-session `@State var dismissed: Bool = false` (resets on cold launch)
- "Adjust block" → opens `BlockBuilderView` for the active block in edit mode

**DI default for advisory** (mirror RestTimerEngine.swift line 112 `NoopActivityController()` default):
```swift
public struct ConsiderDeloadBanner: View {
    public let advisory: FatigueAdvisory
    @State private var dismissed: Bool = false

    public init(advisory: FatigueAdvisory = StubFatigueAdvisory()) {
        self.advisory = advisory
    }
    // ...
}
```

---

### `fitbod/Periodization/BlockReviewView.swift` (view / sheet, request-response)

**Analog:** `fitbod/Sessions/PerSetNoteSheet.swift` (sheet shell) + `fitbod/Settings/SettingsView.swift` (Form sections + @Query)

**NavigationStack-wrapped sheet pattern** (PerSetNoteSheet.swift lines 37–55):
```swift
public var body: some View {
    NavigationStack {
        Form {
            Section { ... }
        }
        .navigationTitle("Set \(entry.orderIndex + 1) Note")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}
```
Mirror for `BlockReviewView`:
```swift
public struct BlockReviewView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    public let block: Block

    public var body: some View {
        NavigationStack {
            Form {
                totalVolumeSection
                e1RMDeltasSection
                prsHitSection
                recommendedNextSection
            }
            .navigationTitle("\(block.name) — review")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { acknowledgeAndDismiss() }
                }
            }
        }
    }
}
```

**Form-with-@Query section pattern** (SettingsView.swift lines 62–78):
```swift
public struct SettingsView: View {
    @Query private var settingsList: [UserSettings]

    public var body: some View {
        NavigationStack {
            Form {
                if let settings = settingsList.first {
                    unitsSection(settings: settings)
                    aboutSectionPlaceholder
                }
                // ...
            }
            .navigationTitle("Settings")
        }
    }
}
```
Adapt for `BlockReviewView.totalVolumeSection`:
```swift
private var totalVolumeSection: some View {
    Section("Total volume") {
        // @Query over SetEntry filtered to block.startDate ... block.endDate.
        // RESEARCH §6 Pitfall 2 (PATTERN 04-RESEARCH.md lines 1042-1053) —
        // capture date bounds into local lets BEFORE the #Predicate.
        let blockStart = block.startDate
        let blockEnd = block.endDate ?? Date.now
        Text("\(totalKg) kg total").font(.headline)
        Text("\(workingSetsCount) working sets across \(sessionsCount) sessions")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

**Acknowledge-and-dismiss transaction pattern** (per CONTEXT D-21 + UI-SPEC line 269):
```swift
private func acknowledgeAndDismiss() {
    do {
        try ctx.transaction {
            block.reviewedAt = Date.now
            block.isActive = false
            try ctx.save()
        }
        dismiss()
    } catch {
        // Surface inline error (rare)
    }
}
```

**Trigger pattern from parent TodayView** (analog: pattern from RoutinesListView.swift `.sheet(item:)` line 117 + RoutineBuilderView's `.sheet(isPresented:)` line 189 — see RootView's TodayView modification):
```swift
.sheet(item: $pendingBlockReview) { block in
    BlockReviewView(block: block)
}
.task {
    // Query: blocks where endDate < Date.now AND isActive == true AND reviewedAt == nil
    pendingBlockReview = ...
}
```

---

### `fitbod/Periodization/BlockRow.swift` (view / row, transform)

**Analog:** `fitbod/Routines/RoutineRow.swift` (lines 32–115)

**Row shell + tap closure pattern** (RoutineRow.swift lines 32–66):
```swift
public struct RoutineRow: View {
    public let routine: Routine
    public let onTap: (Routine) -> Void
    public let onStart: (Routine) -> Void
    // ...

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(routine.name)
                .font(.body)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap(routine) }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete(routine)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
```
Mirror for `BlockRow`:
```swift
public struct BlockRow: View {
    public let block: Block
    public let onTap: (Block) -> Void
    public let onDelete: (Block) -> Void

    public var body: some View {
        HStack(spacing: 8) {
            // UI-SPEC line 204 — 6pt accent dot when isActive
            if block.isActive {
                Circle().fill(Color.accentColor).frame(width: 6, height: 6)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(block.name).font(.body)
                Text(captionText)                    // "Starting {date}" / "Started {date}" / "Ended {date}"
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(weekBadgeText)                       // "Week N of M" or "M weeks"
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap(block) }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onDelete(block) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
```

---

### `fitbod/Periodization/StartBlockCTA.swift` (view / empty-state, event-driven)

**Analog:** `fitbod/Routines/RoutinesListView.swift` empty-state (lines 285–304)

**Empty-state CTA pattern** (RoutinesListView.swift lines 286–304):
```swift
@ViewBuilder
private var emptyState: some View {
    VStack(spacing: 16) {
        Spacer().frame(height: 48)
        Text("No routines yet")
            .font(.title2)
            .fontWeight(.semibold)
        Text("Build a routine to start logging workouts.")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        Button("New Routine") {
            presentingNewRoutine = true
        }
        .foregroundStyle(Color.accentColor)
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal, 32)
}
```
Mirror for `StartBlockCTA` (per UI-SPEC lines 185–189). Single closure-injected action: `onStart: () -> Void`.

---

### `fitbod/Periodization/BlockPickerMenu.swift` (view / picker, event-driven)

**Analog:** `fitbod/Routines/MoveRoutineSheet.swift` (Form-of-options pattern) + `fitbod/Routines/RoutinesListView.swift` toolbar Menu (lines 99–112)

**Menu trigger with `@Binding<UUID?>` selection pattern** (Combined from MoveRoutineSheet.swift lines 43–73 + RoutinesListView.swift Menu):
```swift
public struct BlockPickerMenu: View {
    @Binding public var blockID: UUID?
    @Query(sort: [SortDescriptor(\Block.isActive, order: .reverse), SortDescriptor(\Block.startDate, order: .reverse)])
    private var blocks: [Block]

    public init(blockID: Binding<UUID?>) {
        self._blockID = blockID
    }

    public var body: some View {
        Menu {
            Button("No Block") { blockID = nil }
            ForEach(blocks) { block in
                Button {
                    blockID = block.id
                } label: {
                    HStack {
                        if block.isActive { Circle().fill(Color.accentColor).frame(width: 6, height: 6) }
                        Text(block.name)
                    }
                }
            }
            Divider()
            Button("+ Create New Block") { /* push BlockBuilderView */ }
                .foregroundStyle(Color.accentColor)
        } label: {
            HStack {
                Text("Block:")
                Spacer()
                Text(currentBlockName ?? "None")
                    .foregroundStyle(blockID != nil ? Color.accentColor : .secondary)
            }
        }
    }

    private var currentBlockName: String? {
        blockID.flatMap { id in blocks.first(where: { $0.id == id })?.name }
    }
}
```
**Sort order from UI-SPEC line 258 + RESEARCH.md line 628** (`isActive desc, startDate desc`).

---

### `fitbod/Persistence/SchemaV3.swift` (modify if Phase 3 unsealed) OR `fitbod/Persistence/SchemaV4.swift` (new)

**Analog:** `fitbod/Persistence/SchemaV2.swift`

**VersionedSchema additive-delta pattern** (SchemaV2.swift lines 36–60):
```swift
public enum SchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Exercise.self,
            // ... 11 V1 inheritors ...
            Block.self,
            BlockPhase.self,
            UserSettings.self,
            MuscleVolumeTarget.self,
            // NEW in V2.
            RoutineFolder.self,
            SupersetGroup.self,
            RoutineExerciseSetOverride.self,
        ]
    }
}
```
**For SchemaV4 (or SchemaV3 if mutating Phase 3's draft):** identical shape, append the new schema version number, list ALL models (none change identity — Block gains one field but stays in the list as `Block.self`). Version identifier bumps to `Schema.Version(4, 0, 0)` (or `(3, 0, 0)` if Phase 3 not yet sealed). The lightweight migration handles `Block.reviewedAt`'s addition because it's a default-valued optional (FOUND-02 safe).

---

### `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` (modify)

**Analog:** `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` (existing file, lines 29–47)

**Schema migration plan append pattern** (FitbodSchemaMigrationPlan.swift lines 29–46):
```swift
public enum FitbodSchemaMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    public static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
```
**Append:**
- Add `SchemaV3.self` and `SchemaV4.self` to `schemas` (whichever path D-26 resolves to).
- Add `migrateV2toV3` / `migrateV3toV4` to `stages` (each `MigrationStage.lightweight(...)` — Block.reviewedAt is the only delta and it's a default-valued optional, so lightweight is safe per the file header comment lines 11–15).

---

### `fitbod/Models/Block.swift` (modify)

**Analog:** `fitbod/Models/Block.swift` (existing) — pattern stays identical, one new line.

**Existing field shape** (Block.swift lines 22–41):
```swift
@Model
public final class Block {
    @Attribute(.unique) public var id: UUID = UUID()
    public var name: String = ""
    public var startDate: Date = Date.now
    public var endDate: Date? = nil
    public var notes: String? = nil
    public var isActive: Bool = false
    // relationships...
}
```
**Add:** `public var reviewedAt: Date? = nil` (single line, after `isActive`). Default nil keeps the lightweight migration safe (FOUND-02). Per CONTEXT D-26 + 04-RESEARCH.md line 622.

**Optional but recommended — add `#Index<Block>([\.isActive], [\.startDate])`** at the top of the class body (matches `Session.swift` line 29 pattern):
```swift
@Model
public final class Block {
    #Index<Block>([\.isActive], [\.startDate])
    @Attribute(.unique) public var id: UUID = UUID()
    // ...
}
```
The active-block query (`@Query<Block>(filter: #Predicate { $0.isActive })`) on the Today tab runs on every Today-tab open; the sort-by-startDate query on RoutinesListView runs on every Routines-tab open. Both are hot paths per CONTEXT line 157 (FOUND-04 verification). If indexes not present in Phase 1 schema, this addition belongs in the SchemaV3/V4 delta.

---

### `fitbod/Routines/RoutinesListView.swift` (modify)

**Analog:** `fitbod/Routines/RoutinesListView.swift` (existing — add a new section)

**Section + Query + custom header pattern** (RoutinesListView.swift lines 69–73 + 202–243):
```swift
@Query(sort: \RoutineFolder.sortOrder)
private var folders: [RoutineFolder]

@Query(sort: [SortDescriptor(\Routine.name)])
private var routines: [Routine]
// ...
List {
    ResumeWorkoutBanner(...)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)

    ForEach(sectionsForRendering, id: \.id) { section in
        Section(section.title) { ... }
    }
}
```
**Add ABOVE the existing `ForEach(sectionsForRendering, ...)`:**
```swift
@Query(sort: [SortDescriptor(\Block.isActive, order: .reverse), SortDescriptor(\Block.startDate, order: .reverse)])
private var blocks: [Block]

// ...
Section {
    if blocks.isEmpty {
        // UI-SPEC line 205–207 empty state
        VStack(alignment: .leading, spacing: 8) {
            Text("No blocks yet.").font(.body)
            Text("Define a training block to organize routines into a mesocycle.")
                .font(.caption).foregroundStyle(.secondary)
        }
    } else {
        ForEach(blocks) { block in
            BlockRow(block: block, onTap: { handleBlockTap($0) }, onDelete: { handleBlockDelete($0) })
        }
    }
} header: {
    HStack {
        Text("Blocks")
        Spacer()
        Menu {
            Button("Generic Strength Meso") { presentBuilder(template: .generic) }
            Button("Hypertrophy Meso") { presentBuilder(template: .hypertrophy) }
            Button("Powerlifting Peak") { presentBuilder(template: .powerliftingPeak) }
            Button("Blank Block") { presentBuilder(template: .blank) }
        } label: {
            Text("+ Block").foregroundStyle(Color.accentColor)
        }
    }
}
```

---

### `fitbod/Routines/RoutineBuilderView.swift` (modify)

**Analog:** `fitbod/Routines/RoutineBuilderView.swift` (existing — extend header section)

**Header section addition pattern** (RoutineBuilderView.swift lines 85–91):
```swift
Form {
    // MARK: Name + folder
    Section {
        TextField("Routine name", text: $draft.name)
    }
    // ...
}
```
**Add a row beneath the name field** (per UI-SPEC line 251 — placed beneath the folder picker; folder picker is not currently in the Phase 2 file but Phase 3 plans add it — Phase 4 places BlockPickerMenu beneath whatever is there):
```swift
Section {
    TextField("Routine name", text: $draft.name)
    BlockPickerMenu(blockID: $draft.blockID)
}
```

---

### `fitbod/Routines/RoutineDraft.swift` (modify)

**Analog:** `fitbod/Routines/RoutineDraft.swift` (existing) — additive field on @Observable + materialization on save.

**Field addition pattern** (RoutineDraft.swift lines 57–73):
```swift
public var name: String = ""
public var notes: String? = nil
public var folderID: UUID? = nil
public var exercises: [RoutineExerciseDraft] = []
```
**Add:** `public var blockID: UUID? = nil` (single new field, default nil).

**Round-trip from existing Routine** (RoutineDraft.swift lines 79–86):
```swift
public init(routine: Routine) {
    self.name = routine.name
    self.notes = routine.notes
    self.folderID = routine.folderID
    self.exercises = (routine.exercises ?? [])
        .sorted { $0.orderIndex < $1.orderIndex }
        .map { RoutineExerciseDraft(re: $0) }
}
```
**Add:** `self.blockID = routine.block?.id`.

**Materialization on save pattern** (RoutineDraft.swift lines 118–122):
```swift
public func save(into routine: Routine, context: ModelContext) {
    routine.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    routine.notes = notes
    routine.folderID = folderID
    routine.updatedAt = .now
    // ...
}
```
**Add inside save:**
```swift
// Materialize Routine.block from blockID via fetch-by-id.
if let blockID {
    let targetID = blockID  // local-let workaround for predicate
    let descriptor = FetchDescriptor<Block>(predicate: #Predicate { $0.id == targetID })
    routine.block = (try? context.fetch(descriptor))?.first
} else {
    routine.block = nil
}
```

---

### `fitbod/Routines/PrescriptionEditorRow.swift` (modify)

**Analog:** `fitbod/Routines/PrescriptionEditorRow.swift` (existing — filter Picker cases conditionally)

**Existing progression Picker** (PrescriptionEditorRow.swift lines 166–180):
```swift
private var progressionPicker: some View {
    HStack {
        Text("Progression")
        Spacer()
        Picker("Progression", selection: $draft.progressionKind) {
            Text("RPE Autoregulation").tag(ProgressionKind.rpe)
            Text("Double Progression").tag(ProgressionKind.double)
            Text("Block Periodized").tag(ProgressionKind.block)
            Text("Hybrid").tag(ProgressionKind.hybrid)
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .accessibilityLabel("Progression")
    }
}
```
**Modify:** PrescriptionEditorRow needs to know whether the parent `routine.block` is nil. Two options:
- (a) Add a `let hasBlock: Bool` parameter to the init (preferred; explicit dependency).
- (b) Read `draft.routine?.block` via the back-pointer (current Phase 2 draft has no back-pointer; would require a draft schema change).

Adopt option (a). Then wrap the `.block` and `.hybrid` Text rows in `if hasBlock { ... }`. Per CONTEXT D-19 + UI-SPEC line 260, also add a conditional footnote below the picker when block-dependent kinds are selected with no block context.

---

### `fitbod/Sessions/SessionFactory.swift` (modify)

**Analog:** `fitbod/Sessions/SessionFactory.swift` (existing) — extend the existing snapshot loop.

**Snapshot pattern already wired for Session.block at line 101**:
```swift
session.block = routine.block                 // optional; safe to carry forward
```
**No code change needed for the snapshot itself** (it's already there from Phase 2). Phase 4 adds adjacent logic:

**Deload set-count cut pattern** (CONTEXT D-12 + 04-RESEARCH.md Open Question #3 lines 833–836 + Pitfall #7 line 1103):
```swift
// After computing `previousHint`, determine the deload-week scaling.
let deloadVolumeMultiplier: Double
if let block = routine.block,
   let phase = PeriodizationEngine.phase(for: block, on: date),
   phase.kind == .deload {
    deloadVolumeMultiplier = phase.volumeMultiplier
} else {
    deloadVolumeMultiplier = 1.0
}
let scaledSetCount = max(1, Int(floor(Double(re.targetSets) * deloadVolumeMultiplier)))
// Replace the existing `for setIndex in 0..<re.targetSets` with `for setIndex in 0..<scaledSetCount`.
```

**Existing pre-population loop** (SessionFactory.swift lines 152–165):
```swift
for setIndex in 0..<re.targetSets {
    let entry = SetEntry()
    entry.sessionExercise = se
    entry.orderIndex = setIndex
    entry.weight = previousHint
    entry.reps = 0
    entry.rpe = nil
    entry.setTypeRaw = SetType.working.rawValue
    entry.isWarmup = false
    entry.isComplete = false                  // SENTINEL
    entry.completedAt = date                  // overwritten on commit
    context.insert(entry)
}
```
Replace the loop bound with `scaledSetCount`; everything else stays identical. The Pitfall #7 clamp at `max(1, ...)` is the load-bearing guard against `1 * 0.5 = 0 sets`.

---

### `fitbod/App/RootView.swift` (modify TodayView)

**Analog:** `fitbod/App/RootView.swift` lines 237–274 (existing TodayView body)

**TodayView body shape** (RootView.swift lines 241–273):
```swift
private struct TodayView: View {
    @Environment(\.modelContext) private var ctx
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 16) {
                ResumeWorkoutBanner(
                    onResume: { session in
                        navigationPath.append(SessionRoute.logger(session))
                    },
                    onDiscard: { session in
                        ctx.delete(session)
                        try? ctx.save()
                    }
                )
                Spacer()
                Text("No workout in progress")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Start a workout from your Routines tab.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding(.horizontal, 32)
            .navigationTitle("Today")
            .navigationDestination(for: SessionRoute.self) { route in
                switch route {
                case .logger(let session): SessionLoggerView(session: session)
                }
            }
        }
    }
}
```
**Modify** — replace the VStack content per UI-SPEC line 381 + RESEARCH.md line 633:
```swift
VStack(spacing: 16) {
    // (1) DeloadWeekBanner — conditional on current week being deload
    if let activeBlock = activeBlocks.first,
       let phase = PeriodizationEngine.phase(for: activeBlock, on: .now),
       phase.kind == .deload {
        DeloadWeekBanner(currentPhase: phase)
    }
    // (2) ConsiderDeloadBanner — conditional on advisory (Phase 4 stub: never)
    ConsiderDeloadBanner()
    // (3) BlockCard OR StartBlockCTA
    if activeBlocks.isEmpty {
        StartBlockCTA(onStart: { presentBuilder = true })
    } else {
        BlockCard()
    }
    // (4) ResumeWorkoutBanner (existing)
    ResumeWorkoutBanner(...)
    Spacer()
}
```
Add `@Query(filter: #Predicate<Block> { $0.isActive }) private var activeBlocks: [Block]` at the struct's top.

**Sheet trigger for BlockReviewView** — add `.task` + `.sheet(item:)` (per UI-SPEC line 421):
```swift
@State private var pendingBlockReview: Block? = nil
// ...
.task {
    let descriptor = FetchDescriptor<Block>(predicate: #Predicate { block in
        block.isActive == true && block.endDate != nil && block.endDate! < Date.now && block.reviewedAt == nil
    })
    pendingBlockReview = (try? ctx.fetch(descriptor))?.first
}
.sheet(item: $pendingBlockReview) { block in
    BlockReviewView(block: block)
        .presentationDetents([.large])
}
```

---

### `fitbod/Prescription/ProgressionStrategy.swift` (Phase 3 — modify)

**Analog:** Phase 3 plan 03-05-PLAN.md lines 99–102, 138–149, 156–161.

**Extension pattern** (per CONTEXT A3 risk + 04-RESEARCH.md §HybridStrategy lines 971–972):
```swift
public protocol ProgressionStrategy: Sendable {
    func prescribe(
        history: [HistoryPoint],
        targetRepsLow: Int, targetRepsHigh: Int,
        targetRPE: Double?,
        smallestIncrement: Double,
        plates: [(weight: Double, countPerSide: Int)],
        barWeight: Double,
        minCalibrationSets: Int,
        lastSessionWeight: Double?, lastSessionReps: Int?,
        lastSessionRPE: Double?, lastSessionDate: Date?,
        lastSessionRepsArray: [Int]? = nil,
        block: Block? = nil,           // NEW Phase 4 param (default nil)
        today: Date = Date.now          // NEW Phase 4 param (default Date.now)
    ) -> (weight: Double, explanation: PrescriptionExplanation)
}
```
**Default-valued params preserve Phase 3 test green-state.** Phase 3's `RPEAutoregStrategy` / `DoubleProgressionStrategy` ignore the new params.

---

### `fitbod/Prescription/ProgressionStrategyFactory.swift` (Phase 3 — modify)

**Analog:** Phase 3 plan docs (factory ships in Phase 3).

**Swap fallback stubs for real strategies** — wherever the factory currently routes `.block` and `.hybrid` to `DoubleProgressionStrategy()`, route to `BlockPeriodizedStrategy()` and `HybridStrategy()` respectively. The factory's `Block` injection point (CONTEXT D-14 + D-15) is where this lands.

---

## Shared Patterns

### Single-active block invariant — transactional save

**Source:** 04-RESEARCH.md lines 910–948 (drafted) + `fitbod/Sessions/SessionFactory.swift` lines 88–94 (existing one-active-session check)

**Apply to:** `BlockDraft.save(into:context:)`, `BlockReviewView.acknowledgeAndDismiss()`.

**Existing analog for the "fetch all matching → mutate → save" pattern in a single transaction:**
SessionFactory.swift lines 88–94 fetches active sessions and decides to throw OR proceed; Phase 4's BlockDraft.save fetches active blocks and zeroes them BEFORE saving the target. The `try modelContext.transaction { ... }` wrapper is per 04-RESEARCH.md §Pitfall 3 (line 1063):
```swift
try context.transaction {
    if isActive {
        let descriptor = FetchDescriptor<Block>(predicate: #Predicate<Block> { $0.isActive })
        let others = try context.fetch(descriptor)
        for other in others where other.id != self.id {
            other.isActive = false
        }
    }
    // ... mutate target block ...
    try context.save()
}
```

### #Predicate local-let workaround (RESEARCH §6 Pitfall 1 + 2)

**Source:** `fitbod/Sessions/PreviousMatchingIntent.swift` lines 73–84 (existing canonical)

**Apply to:** every Phase 4 `#Predicate` that compares against a captured variable (BlockReviewView's date-range query, RoutineDraft's block-by-id fetch, BlockDraft's other-active-blocks fetch).

**Existing canonical pattern** (PreviousMatchingIntent.swift lines 73–84):
```swift
// RESEARCH §6 Pitfall 1 — extract to locals BEFORE the #Predicate.
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
Phase 4 BlockReviewView volume query becomes:
```swift
let blockStart = block.startDate
let blockEnd = block.endDate ?? Date.now
let descriptor = FetchDescriptor<SetEntry>(predicate: #Predicate { entry in
    let session = entry.sessionExercise?.session
    return session?.startedAt != nil
        && session!.startedAt >= blockStart
        && session!.startedAt <= blockEnd
})
```

### @Observable + three-way merge save (FOUND-06 / MV-VM-lite)

**Source:** `fitbod/Routines/RoutineDraft.swift` (lines 118–181)

**Apply to:** `BlockDraft.save(into:context:)`, all per-row `BlockPhaseDraft` rendering bindings.

**Existing canonical** (RoutineDraft.swift lines 53–74):
```swift
@Observable
@MainActor
public final class RoutineDraft {
    public var name: String = ""
    // ...
    public init() {}
    public init(routine: Routine) { /* round-trip */ }
}
```
Phase 4's `BlockDraft` is structurally identical; differs only in field names and the save body (BlockDraft adds the active-block transaction; RoutineDraft has no such global invariant).

### Snapshot at session start (PITFALLS #1)

**Source:** `fitbod/Sessions/SessionFactory.swift` line 101 (existing — already snapshots `session.block = routine.block`)

**Apply to:** No further snapshot work needed in Phase 4 — the field is already wired. The only additions are:
1. Reading `session.block` (not `routine.block`) in any Phase 4 view that needs "what block is this session in?" per 04-RESEARCH.md §Pitfall 4 (line 1067).
2. Adding deload set-count cut logic alongside the snapshot (see `SessionFactory.swift (modify)` above).

### Sendable value type carrier

**Source:** `fitbod/Sessions/PreviousMatchingIntent.swift` lines 30–42 (PreviousMatchingIntentHit)

**Apply to:** `MesocycleWeekContext`, `BlockTemplate`, `FatigueSuggestion`.

**Existing canonical:**
```swift
public struct PreviousMatchingIntentHit: Sendable {
    public let weight: Double
    public let reps: Int
    public let rpe: Double?
    public let sessionStartedAt: Date
    public init(weight: Double, reps: Int, rpe: Double?, sessionStartedAt: Date) {
        self.weight = weight; self.reps = reps; self.rpe = rpe; self.sessionStartedAt = sessionStartedAt
    }
}
```
All-let stored properties; memberwise `public init`; `: Sendable`; implicitly `Sendable` because every stored property is.

### Inline chip styling (44pt HIG-compliant capsule)

**Source:** `fitbod/ExerciseLibrary/IntentFilterChipRow.swift` lines 74–92

**Apply to:** `BlockCard` phase chip, `BlockPhaseEditorRow` phase-kind chip (UI-SPEC § Component Inventory lines 348 + 350 reference "chip styling").

**Existing canonical** (IntentFilterChipRow.swift lines 74–92):
```swift
private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(label)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .clipShape(Capsule())
    }
    .buttonStyle(.plain)
    .frame(minWidth: 44, minHeight: 44)
    .accessibilityLabel("\(label) filter, \(isSelected ? "selected" : "unselected")")
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
}
```
Phase 4 phase chips replace the accent fill with `BlockPhaseColors.color(for: phase.kind)` instead of accent (since phase color IS the signal).

### Toolbar Save/Cancel + Discard confirmation

**Source:** `fitbod/Routines/RoutineBuilderView.swift` lines 159–188

**Apply to:** `BlockBuilderView`.

**Existing canonical:**
```swift
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        Button("Cancel") {
            if hasUnsavedChanges { presentingDiscardConfirm = true } else { dismiss() }
        }
    }
    ToolbarItem(placement: .topBarTrailing) {
        Button("Save") { save() }
            .disabled(!draft.isValid)
            .foregroundStyle(Color.accentColor)
    }
}
.confirmationDialog(
    "Discard Changes?",
    isPresented: $presentingDiscardConfirm,
    titleVisibility: .visible
) {
    Button("Discard", role: .destructive) { dismiss() }
    Button("Keep Editing", role: .cancel) { presentingDiscardConfirm = false }
}
```

### Lightweight migration for additive default-valued field

**Source:** `fitbod/Persistence/FitbodSchemaMigrationPlan.swift` lines 11–15 (header citation) + lines 43–46 (existing canonical)

**Apply to:** SchemaV3→V4 stage for `Block.reviewedAt` (or SchemaV2→V3 if Phase 3 unsealed).

**Existing canonical:**
```swift
public static let migrateV1toV2 = MigrationStage.lightweight(
    fromVersion: SchemaV1.self,
    toVersion: SchemaV2.self
)
```
Phase 4 appends `migrateV3toV4` (or extends `migrateV2toV3`) with the same shape. Lightweight is eligible because the delta is one optional field with a default value (FOUND-02 / per the file header citation at lines 11–15).

### `#Index` macro on hot query paths (FOUND-04)

**Source:** `fitbod/Models/Session.swift` line 29

**Apply to:** `fitbod/Models/Block.swift` (active-block query is a Today-tab cold-launch hot path; sort-by-startDate is a Routines-tab hot path).

**Existing canonical:**
```swift
@Model
public final class Session {
    #Index<Session>([\.startedAt], [\.sourceRoutineID])
    // ...
}
```
Phase 4 adds (if not already present in Phase 1 schema): `#Index<Block>([\.isActive], [\.startDate])`. Per CONTEXT line 157 verification.

---

## No Analog Found

Files where Phase 4 introduces a pattern with no close existing match:

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `fitbod/Prescription/HybridStrategy.swift` | service composing two other strategies | transform | No existing strategy composes two siblings; the composition pattern is novel to Phase 4. Drafted in 04-RESEARCH.md lines 953–1008. Use the explicit code excerpt there as the executor reference. |
| `fitbod/Periodization/MesocycleWeekContext.swift` | pure value carrier with multiple typed fields | transform | `PreviousMatchingIntentHit` is the closest analog but only carries 4 fields; `MesocycleWeekContext` carries 6 (phase, weekStartDate, weekEndDate, daysRemaining, isCurrentWeek, isDeloadWeek). Same `Sendable` value-type shape; just larger. |
| Internal `TabView(.page)` paging inside a card | view | event-driven | No existing in-card pager. The codebase TabView usage is the root tab bar (RootView.swift line 153). The `.tabViewStyle(.page(indexDisplayMode: .never))` modifier is documented in 04-RESEARCH.md §Don't Hand-Roll line 1123 with the explicit "use TabView, don't hand-roll" guidance. |
| `FatigueAdvisory` protocol with type-level write contract | protocol | transform | The shape (Sendable protocol returning value types only) is borrowable from `ProgressionStrategy: Sendable` (Phase 3), but the "no @Model-mutation in return type" canonicality enforcement is a new architectural invariant (CONTEXT D-25 / BLOCK-08). The `FatigueAdvisoryCanonicalityTests` suite asserts this with a static-shape inspection (no real runtime). |

---

## Metadata

**Analog search scope:**
- `fitbod/App/`, `fitbod/Models/` (incl. `Enums/`), `fitbod/Persistence/`, `fitbod/Routines/`, `fitbod/Sessions/` (incl. `RestTimer/`), `fitbod/Settings/`, `fitbod/ExerciseLibrary/`
- Phase 3 plan docs (`.planning/phases/03-smart-prescription-warm-ups/03-05-PLAN.md`, `03-08-PLAN.md`) for in-flight strategy + factory shape
- Phase 3's `03-PATTERNS.md` for pattern-mapping precedent on the new `Prescription/` directory

**Files scanned:** ~85 Swift sources across the fitbod module + 8 Phase 3 / Phase 4 planning files.

**Pattern extraction date:** 2026-05-22
