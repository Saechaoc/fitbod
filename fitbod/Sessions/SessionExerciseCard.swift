//
//  SessionExerciseCard.swift
//  fitbod
//
//  Wave-4 plan 04-01 — one card per snapshotted `SessionExercise` inside a
//  `SessionLoggerView` list. Renders:
//
//    1. A section header with the exercise name (`.headline`).
//    2. A column-header row (UI-SPEC verbatim labels): "Set" / "Previous"
//       / "Weight" / "Reps" / "RPE".
//    3. One `SetRow` per `SetEntry` (sorted by `orderIndex`).
//    4. A trailing "Add Set" button (UI-SPEC § Session logger trailing).
//
//  ## Scoping discipline (PITFALLS-doc #1 / UI-SPEC "Anti-Patterns to Avoid")
//
//  The card binds to a single `SessionExercise` — NOT the parent `Session`.
//  This is defensive: the logger reads/writes `SessionExercise` /
//  `SetEntry` only, never the source `Routine`. Passing the entire Session
//  in would invite a slip where a routine prescription field gets mutated
//  via the snapshot.
//
//  ## "Add Set" behavior
//
//  Tapping "Add Set" appends a new `SetEntry` with `orderIndex =
//  sortedSets.count` and `setTypeRaw = working` (the explicit "planned
//  but not yet logged" sentinel). Persistence is driven by the parent
//  context — SwiftData's relationship semantics insert the new entry via
//  the parent SessionExercise binding.
//

import SwiftUI
import SwiftData

public struct SessionExerciseCard: View {
    @Environment(\.modelContext) private var ctx
    @Bindable public var sessionExercise: SessionExercise
    public let engine: RestTimerEngine
    public let onCommitSet: (SetEntry) -> Void
    public let onTapEmptyCell: () -> Void
    /// Wave-4 plan 04-02 — fires when the user taps "Swap Exercise…"
    /// in the header long-press menu. The parent SessionLoggerView is
    /// responsible for presenting SwapExerciseSheet.
    public let onSwap: (SessionExercise) -> Void
    /// Wave-4 plan 04-02 — fires when the user taps "Remove from
    /// Session" in the header long-press menu. The parent
    /// SessionLoggerView is responsible for the destructive
    /// confirmation alert + the actual ctx.delete(_:).
    public let onRemove: (SessionExercise) -> Void

    public init(
        sessionExercise: SessionExercise,
        engine: RestTimerEngine,
        onCommitSet: @escaping (SetEntry) -> Void,
        onTapEmptyCell: @escaping () -> Void,
        onSwap: @escaping (SessionExercise) -> Void = { _ in },
        onRemove: @escaping (SessionExercise) -> Void = { _ in }
    ) {
        self.sessionExercise = sessionExercise
        self.engine = engine
        self.onCommitSet = onCommitSet
        self.onTapEmptyCell = onTapEmptyCell
        self.onSwap = onSwap
        self.onRemove = onRemove
    }

    public var body: some View {
        Section {
            // Column-header row — UI-SPEC verbatim labels.
            HStack {
                Text("Set")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                Text("Previous")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 80, alignment: .leading)
                Text("Weight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
                Text("Reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
                Text("RPE")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(sortedSets) { set in
                VStack(spacing: 4) {                                            // UI-SPEC xs
                    SetRow(
                        entry: set,
                        sessionExercise: sessionExercise,
                        onCommit: { onCommitSet(set) },
                        onTapEmptyCell: onTapEmptyCell
                    )
                    // Wave-4 plan 04-02 — opt-in row conditional rendering.
                    // Each row only renders when its enabling toggle/flag
                    // is true; otherwise the card lays out exactly as
                    // before. The toggles are snapshotted onto
                    // SessionExercise at SessionFactory time.
                    if sessionExercise.tracksTempo {
                        TempoEntryRow(entry: set)
                    }
                    if sessionExercise.tracksPartialReps {
                        PartialRepsRow(entry: set)
                    }
                    if set.setType == .restPause {
                        ClusterSubRepChipRow(entry: set)
                    }
                }
            }

            Button {
                addSet()
            } label: {
                Label("Add Set", systemImage: "plus.circle")                    // UI-SPEC § Session logger trailing
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        } header: {
            // Wave-4 plan 04-02 — header is a long-press menu surface:
            // "Swap Exercise…" / "Remove from Session" / "Edit Pinned
            // Note" (the third entry is a stub here — the pinned-note
            // edit sheet ships in plan 04-03).
            Text(sessionExercise.exercise?.name ?? "Exercise")
                .font(.headline)
                .contextMenu {
                    Button {
                        onSwap(sessionExercise)
                    } label: {
                        Label("Swap Exercise…", systemImage: "arrow.left.arrow.right")   // UI-SPEC verbatim
                    }
                    Button {
                        // Plan 04-03 — present PinnedNoteSheet.
                    } label: {
                        Label("Edit Pinned Note", systemImage: "pin.fill")               // UI-SPEC verbatim
                    }
                    Button(role: .destructive) {
                        onRemove(sessionExercise)
                    } label: {
                        Label("Remove from Session", systemImage: "trash")               // UI-SPEC verbatim
                    }
                }
        }
    }

    /// `SetEntry` rows sorted by `orderIndex` for stable rendering and
    /// stable "next orderIndex" calculation for "Add Set" appends.
    private var sortedSets: [SetEntry] {
        (sessionExercise.sets ?? []).sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Appends a new planned `SetEntry` with the canonical sentinel state:
    /// `isComplete = false`, `setTypeRaw = working`, `reps = 0`, `weight = 0`.
    /// The new entry inherits the most-recent matching-intent weight hint
    /// via the same path SessionFactory uses on session-start so the user
    /// gets a sensible seeded weight when they begin logging.
    private func addSet() {
        let entry = SetEntry()
        entry.sessionExercise = sessionExercise
        entry.orderIndex = sortedSets.count
        entry.setTypeRaw = SetType.working.rawValue
        entry.isComplete = false
        entry.weight = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: sessionExercise.exercise?.id,
            intentRaw: sessionExercise.intentRaw,
            context: ctx
        )?.weight ?? 0
        ctx.insert(entry)
        try? ctx.save()
    }
}

#Preview("exercise card") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let se = SessionExercise()
    se.exercise = ex
    se.intentRaw = "strength"
    se.targetSets = 3
    ctx.insert(se)
    for i in 0..<3 {
        let entry = SetEntry()
        entry.sessionExercise = se
        entry.orderIndex = i
        ctx.insert(entry)
    }
    try? ctx.save()
    let engine = RestTimerEngine()
    return List {
        SessionExerciseCard(
            sessionExercise: se,
            engine: engine,
            onCommitSet: { _ in },
            onTapEmptyCell: {}
        )
    }
    .modelContainer(container)
}
