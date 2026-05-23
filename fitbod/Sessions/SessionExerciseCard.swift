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
//  Phase 3 (plan 03-08) additions:
//    - BumpBanner: rendered above the column-header row when
//      currentExplanation().bumpOccurred == true && !bannerDismissed.
//    - CalibratingBadge: rendered inline when status == .calibrating.
//    - WarmupRampRows: rendered above column-header row when the exercise
//      has isWarmup SetEntry rows.
//    - currentExplanation(): private helper that recomputes the
//      PrescriptionExplanation at render time using the same helpers as
//      SessionFactory (no stored explanation — pure recompute is < 1ms).
//    - expandedPlateSetID: @State UUID? for single-disclosure-at-a-time
//      coordination passed to each SetRow.
//    - bannerDismissed: @State Bool; tap-anywhere-on-card dismisses banner.
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
    /// Wave-4 plan 04-03 — fires when the user taps "Edit Pinned Note"
    /// in the header long-press menu OR taps the inline
    /// PinnedNoteCapsule. The parent SessionLoggerView is responsible
    /// for presenting PinnedNoteSheet.
    public let onEditPinnedNote: (SessionExercise) -> Void

    // MARK: - Phase 3 (plan 03-08) state

    /// Tracks whether the bump banner has been dismissed by a card tap.
    @State private var bannerDismissed: Bool = false
    /// Single-disclosure-at-a-time coordination: which SetEntry's plate
    /// stack is currently open. Passed to each SetRow as a binding so
    /// tapping a new row automatically collapses any open disclosure.
    @State private var expandedPlateSetID: UUID? = nil
    /// Live UserSettings query for minCalibrationSets + defaultIncrementKg.
    @Query private var settingsList: [UserSettings]
    /// Live PlateInventory query for plate math in currentExplanation().
    @Query private var inventories: [PlateInventory]

    public init(
        sessionExercise: SessionExercise,
        engine: RestTimerEngine,
        onCommitSet: @escaping (SetEntry) -> Void,
        onTapEmptyCell: @escaping () -> Void,
        onSwap: @escaping (SessionExercise) -> Void = { _ in },
        onRemove: @escaping (SessionExercise) -> Void = { _ in },
        onEditPinnedNote: @escaping (SessionExercise) -> Void = { _ in }
    ) {
        self.sessionExercise = sessionExercise
        self.engine = engine
        self.onCommitSet = onCommitSet
        self.onTapEmptyCell = onTapEmptyCell
        self.onSwap = onSwap
        self.onRemove = onRemove
        self.onEditPinnedNote = onEditPinnedNote
    }

    public var body: some View {
        // Compute the explanation once per body evaluation so both the
        // Section content and Section header can access the same value
        // without calling currentExplanation() twice per render. Declared
        // here (not inside a closure) so all closures below share scope.
        let explanation = currentExplanation()

        Section {
            // Wave-4 plan 04-03 — inline pinned-note capsule (UI-SPEC §
            // Session logger "per-exercise card — pinned-note inline
            // display"). Renders above the column-header row only when
            // SessionExercise.pinnedNote is populated; tap fires
            // onEditPinnedNote, which the parent SessionLoggerView wires
            // to PinnedNoteSheet presentation.
            if let note = sessionExercise.pinnedNote, !note.isEmpty {
                PinnedNoteCapsule(note: note) {
                    onEditPinnedNote(sessionExercise)
                }
            }

            // ─── Phase 3 (plan 03-08) — conditional components ───
            //
            // (1) BumpBanner: visible when the last session triggered a
            //     DoubleProgression bump and the user hasn't dismissed it yet.
            if let exp = explanation, exp.bumpOccurred, !bannerDismissed {
                BumpBanner(
                    isVisible: Binding(
                        get: { !bannerDismissed },
                        set: { newValue in bannerDismissed = !newValue }
                    ),
                    bumpedToWeight: exp.roundedWeight
                )
            }

            // (2) WarmupRampRows: rendered above column-header when the
            //     exercise has warm-up SetEntry rows (generated by SessionFactory).
            let warmupSets = warmupEntries
            if !warmupSets.isEmpty {
                WarmupRampRows(
                    warmupSets: warmupSets,
                    onSkip: { handleSkipWarmups() },
                    sessionExercise: sessionExercise
                )
            }

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
                        prescribed: sessionExercise.prescribedWeight,
                        explanation: explanation,
                        expandedPlateSetID: $expandedPlateSetID,
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
            HStack(spacing: 8) {
                Text(sessionExercise.exercise?.name ?? "Exercise")
                    .font(.headline)
                // (3) CalibratingBadge: rendered inline in the header when
                //     the RPE autoreg strategy is still accumulating data.
                if let exp = explanation, case .calibrating(let n, let threshold) = exp.status {
                    CalibratingBadge(current: n, threshold: threshold)
                }
                Spacer()
            }
            .contextMenu {
                Button {
                    onSwap(sessionExercise)
                } label: {
                    Label("Swap Exercise…", systemImage: "arrow.left.arrow.right")   // UI-SPEC verbatim
                }
                Button {
                    onEditPinnedNote(sessionExercise)                                 // Wave-4 plan 04-03
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
        // Tap-anywhere-on-card dismisses the bump banner per UI-SPEC §
        // Bump banner interaction: "Tap anywhere on the card → banner
        // dismisses; does not re-appear."
        .onTapGesture {
            if !bannerDismissed {
                bannerDismissed = true
            }
        }
    }

    // MARK: - Private computed properties

    /// Working `SetEntry` rows sorted by `orderIndex` for stable rendering.
    private var sortedSets: [SetEntry] {
        (sessionExercise.sets ?? [])
            .filter { !$0.isWarmup }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    /// Warm-up `SetEntry` rows sorted by `orderIndex`.
    private var warmupEntries: [SetEntry] {
        (sessionExercise.sets ?? [])
            .filter { $0.isWarmup }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    // MARK: - currentExplanation (plan 03-08)

    /// Recomputes the PrescriptionExplanation at render time using the
    /// same SessionFactory helper logic (fetchHistoryPoints /
    /// lastSessionWorkingReps / plateInventory / equipmentKind).
    ///
    /// This is a pure recompute — no context.save(). The returned value
    /// carries `.range` non-nil when the RPE autoreg strategy is in the
    /// calibrating-with-prior-data window (CONTEXT.md Area 1).
    ///
    /// Returns nil when prescribedWeight is nil (e.g. Phase 2 sessions
    /// started before Phase 3 shipped) to guard against forced-unwrap.
    private func currentExplanation() -> PrescriptionExplanation? {
        let se = sessionExercise
        let userSettings = settingsList.first

        let exerciseID = se.exercise?.id
        let intentRaw = se.intentRaw

        let ekind = SessionFactory.equipmentKind(
            for: se.exercise?.equipment ?? .other
        )
        let inventory = inventories.first { $0.equipmentKind == ekind }

        let barWeight: Double
        let plates: [(weight: Double, countPerSide: Int)]
        if let inv = inventory {
            barWeight = se.exercise?.barWeightOverride ?? inv.barWeight
            plates = inv.availablePlates.map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        } else {
            let unit = userSettings?.weightUnit ?? .kg
            barWeight = se.exercise?.barWeightOverride
                ?? PlateInventoryDefaults.barWeight(for: ekind, unitSystem: unit)
            plates = PlateInventoryDefaults.make(for: ekind, unitSystem: unit)
                .map { (weight: $0.weight, countPerSide: $0.countPerSide) }
        }

        let smallestIncrement = se.exercise?.smallestIncrement
            ?? userSettings?.defaultIncrementKg
            ?? 2.5
        let minCalibrationSets = userSettings?.minCalibrationSets ?? 10

        let historyPoints = SessionFactory.fetchHistoryPoints(
            exerciseID: exerciseID,
            intentRaw: intentRaw,
            context: ctx
        )
        let lastRepsArray = SessionFactory.lastSessionWorkingReps(
            exerciseID: exerciseID,
            intentRaw: intentRaw,
            context: ctx
        )
        let lastHint = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: exerciseID,
            intentRaw: intentRaw,
            context: ctx
        )

        let strategy = ProgressionStrategyFactory.make(for: se.progressionKind)
        let (_, explanation) = strategy.prescribe(
            history: historyPoints,
            targetRepsLow: se.targetRepsLow,
            targetRepsHigh: se.targetRepsHigh,
            targetRPE: se.targetRPE,
            lastSessionRepsArray: lastRepsArray.isEmpty ? nil : lastRepsArray,
            smallestIncrement: smallestIncrement,
            plates: plates,
            barWeight: barWeight,
            minCalibrationSets: minCalibrationSets,
            lastSessionWeight: lastHint?.weight,
            lastSessionReps: lastHint?.reps,
            lastSessionRPE: lastHint?.rpe,
            lastSessionDate: lastHint?.sessionStartedAt
        )
        return explanation
    }

    // MARK: - handleSkipWarmups

    /// Marks all warm-up SetEntry rows as completed (weight = 0) so
    /// WarmupRampRows hides them. Called from WarmupRampRows.onSkip.
    private func handleSkipWarmups() {
        for warmup in warmupEntries {
            warmup.isComplete = true
        }
        try? ctx.save()
    }

    // MARK: - addSet

    /// Appends a new planned `SetEntry` with the canonical sentinel state:
    /// `isComplete = false`, `setTypeRaw = working`, `reps = 0`, `weight = 0`.
    /// The new entry inherits the most-recent matching-intent weight hint
    /// via the same path SessionFactory uses on session-start so the user
    /// gets a sensible seeded weight when they begin logging.
    private func addSet() {
        let entry = SetEntry()
        entry.sessionExercise = sessionExercise
        // Place after all existing sets (warmup + working combined).
        let allSets = sessionExercise.sets ?? []
        entry.orderIndex = allSets.count
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
