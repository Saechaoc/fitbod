// SwapExerciseSheet.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 43).
// UI-SPEC v2 § Session logger line 391.
//
// Mid-session swap (SESS-05). Long-pressing the header on a SessionExerciseCard
// surfaces "Swap Exercise…" in a contextMenu. Tapping it presents this sheet,
// which embeds Phase 1's ExerciseLibraryView(onSelect:) picker. Choosing a row
// mutates SessionExercise.exercise on the active session ONLY — the source
// RoutineExercise.exercise is never touched (PITFALLS-doc #1).
//
// Chrome: BRUHeaderBar replaces .navigationTitle("Swap Exercise") + .toolbar.
//
// Footer copy (UI-SPEC verbatim line 391):
//   "This swap applies to this session only. The routine template will not change."
//
// BRU contract:
//   NO .navigationTitle / NO .toolbar with system chrome
//   NO Capsule() / NO RoundedRectangle / NO accentColor
//   NO Image(systemName:) / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI
import SwiftData

/// An in-memory Undo, not a second prescription evaluation. Deleted warm-ups
/// are kept as values so their identity, metadata and skipped state survive.
@MainActor
struct VariationUndoSnapshot {
    enum RestoreError: Error {
        case noLongerApplicable
    }

    let displayName: String
    private let sessionExerciseID: UUID
    private let exercise: Exercise?
    private let exerciseNameSnapshot: String
    private let prescription: Prescription
    private let rows: [SetValues]
    private let completedWorkingIDs: Set<UUID>

    init(_ sessionExercise: SessionExercise) {
        displayName = sessionExercise.displayName
        sessionExerciseID = sessionExercise.id
        exercise = sessionExercise.exercise
        exerciseNameSnapshot = sessionExercise.exerciseNameSnapshot
        prescription = Prescription(sessionExercise)
        let sets = SessionSetActions.ordered(sessionExercise)
        rows = sets.filter { $0.isWarmup || !$0.isComplete }.map(SetValues.init)
        completedWorkingIDs = Set(sets.filter { !$0.isWarmup && $0.isComplete }.map(\.id))
    }

    func restore(
        to sessionExercise: SessionExercise,
        context: ModelContext,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws {
        let current = SessionSetActions.ordered(sessionExercise)
        let loggedIDs = Set(current.filter { !$0.isWarmup && $0.isComplete }.map(\.id))
        guard sessionExercise.id == sessionExerciseID,
              let session = sessionExercise.session, session.completedAt == nil,
              exercise?.isDeleted != true, loggedIDs == completedWorkingIDs
        else { throw RestoreError.noLongerApplicable }

        do {
            try context.transaction {
                sessionExercise.exercise = exercise
                sessionExercise.exerciseNameSnapshot = exerciseNameSnapshot
                prescription.apply(to: sessionExercise)
                let capturedIDs = Set(rows.map(\.id))
                let editable = current.filter { $0.isWarmup || !$0.isComplete }
                for set in editable where !capturedIDs.contains(set.id) {
                    context.delete(set)
                }
                let byID = Dictionary(uniqueKeysWithValues: editable.map { ($0.id, $0) })
                for values in rows {
                    let set: SetEntry
                    if let existing = byID[values.id] {
                        set = existing
                    } else {
                        set = SetEntry()
                        context.insert(set)
                        set.sessionExercise = sessionExercise
                    }
                    values.apply(to: set)
                }
                // Completed working rows are deliberately never assigned to.
                try save(context)
            }
        } catch {
            SessionSetActions.rollBack(context)
            throw error
        }
    }

    fileprivate struct Prescription {
        let targetSets: Int
        let targetRepsLow: Int
        let targetRepsHigh: Int
        let targetRPE: Double?
        let targetRIR: Int?
        let prescribedRestSeconds: Int
        let tempo: String?
        let tracksTempo: Bool
        let tracksPartialReps: Bool
        let prescribedWeight: Double?
        let pinnedNote: String?
        /// The machine (RM-066): a copy of finished sets keeps the machine
        /// they were done on, and undo brings it back.
        let machine: MachineProfile?
        /// The cardio plan (RM-062).
        let targetDurationSeconds: Int?
        let targetLevel: Double?
        let targetSpeedKmh: Double?
        let targetIncline: Double?

        init(_ exercise: SessionExercise) {
            targetSets = exercise.targetSets
            targetRepsLow = exercise.targetRepsLow
            targetRepsHigh = exercise.targetRepsHigh
            targetRPE = exercise.targetRPE
            targetRIR = exercise.targetRIR
            prescribedRestSeconds = exercise.prescribedRestSeconds
            tempo = exercise.tempo
            tracksTempo = exercise.tracksTempo
            tracksPartialReps = exercise.tracksPartialReps
            prescribedWeight = exercise.prescribedWeight
            pinnedNote = exercise.pinnedNote
            machine = exercise.machine
            targetDurationSeconds = exercise.targetDurationSeconds
            targetLevel = exercise.targetLevel
            targetSpeedKmh = exercise.targetSpeedKmh
            targetIncline = exercise.targetIncline
        }

        func apply(to exercise: SessionExercise) {
            exercise.targetSets = targetSets
            exercise.targetRepsLow = targetRepsLow
            exercise.targetRepsHigh = targetRepsHigh
            exercise.targetRPE = targetRPE
            exercise.targetRIR = targetRIR
            exercise.prescribedRestSeconds = prescribedRestSeconds
            exercise.tempo = tempo
            exercise.tracksTempo = tracksTempo
            exercise.tracksPartialReps = tracksPartialReps
            exercise.prescribedWeight = prescribedWeight
            exercise.pinnedNote = pinnedNote
            exercise.machine = machine
            exercise.targetDurationSeconds = targetDurationSeconds
            exercise.targetLevel = targetLevel
            exercise.targetSpeedKmh = targetSpeedKmh
            exercise.targetIncline = targetIncline
        }
    }

    private struct SetValues {
        let id: UUID
        let orderIndex: Int
        let weight: Double
        let reps: Int
        let rpe: Double?
        let rir: Int?
        let restAfterSeconds: Int?
        let tempoActual: String?
        let notes: String?
        let isWarmup: Bool
        let setTypeRaw: String
        let completedAt: Date
        let partialReps: Int?
        let clusterSubRepsJoined: String?
        let isComplete: Bool
        let wasManualOverride: Bool
        let startedAt: Date?
        let durationSeconds: Int?
        let distanceMeters: Double?
        let level: Double?
        let speedKmh: Double?
        let incline: Double?

        init(_ set: SetEntry) {
            id = set.id
            orderIndex = set.orderIndex
            weight = set.weight
            reps = set.reps
            rpe = set.rpe
            rir = set.rir
            restAfterSeconds = set.restAfterSeconds
            tempoActual = set.tempoActual
            notes = set.notes
            isWarmup = set.isWarmup
            setTypeRaw = set.setTypeRaw
            completedAt = set.completedAt
            partialReps = set.partialReps
            clusterSubRepsJoined = set.clusterSubRepsJoined
            isComplete = set.isComplete
            wasManualOverride = set.wasManualOverride
            startedAt = set.startedAt
            durationSeconds = set.durationSeconds
            distanceMeters = set.distanceMeters
            level = set.level
            speedKmh = set.speedKmh
            incline = set.incline
        }

        func apply(to set: SetEntry) {
            set.id = id
            set.orderIndex = orderIndex
            set.weight = weight
            set.reps = reps
            set.rpe = rpe
            set.rir = rir
            set.restAfterSeconds = restAfterSeconds
            set.tempoActual = tempoActual
            set.notes = notes
            set.isWarmup = isWarmup
            set.setTypeRaw = setTypeRaw
            set.completedAt = completedAt
            set.partialReps = partialReps
            set.clusterSubRepsJoined = clusterSubRepsJoined
            set.isComplete = isComplete
            set.wasManualOverride = wasManualOverride
            set.startedAt = startedAt
            set.durationSeconds = durationSeconds
            set.distanceMeters = distanceMeters
            set.level = level
            set.speedKmh = speedKmh
            set.incline = incline
        }
    }
}

public struct SwapExerciseSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var saveFailed = false

    @Bindable public var sessionExercise: SessionExercise

    public init(sessionExercise: SessionExercise) {
        self.sessionExercise = sessionExercise
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Exercise library — NOT rewritten (out of Phase 2.1 scope per UI-SPEC line 724)
                ExerciseLibraryView(onSelect: { exercise in
                    if Self.swap(sessionExercise, to: exercise, context: ctx) {
                        dismiss()
                    } else {
                        saveFailed = true
                    }
                }, showsPickerHeader: false)

                // Footer note per UI-SPEC verbatim line 391
                Text("This swap applies to this session only. The routine template will not change.")   // UI-SPEC verbatim
                    .font(BRUFont.bodyDefault)
                    .foregroundStyle(Color.bruMuted)
                    .multilineTextAlignment(.center)
                    .padding(16)
            }
            .background(Color.bruPaper)
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top, spacing: 0) {
                BRUHeaderBar(
                    left: HeaderAction("CANCEL") { dismiss() },                    // UI-SPEC verbatim
                    center: "SWAP EXERCISE",                                        // UI-SPEC verbatim
                    right: nil
                )
            }
        }
        .alert("Couldn't swap exercise", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The workout is still saved as it was. Try the swap again.")
        }
    }

    // MARK: - Swap

    /// The replacement gets a fresh prescription. Completed work belongs
    /// to the original lift, so it can't seed sets on a different lift.
    @MainActor
    @discardableResult
    static func swap(_ sessionExercise: SessionExercise, to exercise: Exercise, context: ModelContext) -> Bool {
        guard let session = sessionExercise.session else { return false }
        if sessionExercise.exercise?.id == exercise.id { return true }
        preserveCompletedSets(of: sessionExercise, in: session, context: context)
        sessionExercise.exercise = exercise
        sessionExercise.exerciseNameSnapshot = exercise.name
        // The replacement starts on its own last machine (RM-066).
        sessionExercise.machine = SessionMachine.lastUsed(for: exercise, during: session, in: context)
        return represcribe(sessionExercise, in: session, context: context)
    }

    /// Gives `sessionExercise` what a fresh start would give its exercise
    /// on its machine now: the prescribed weight, the warm-up ramp rebuilt,
    /// and pending rows cleared so their offers come from the new history.
    /// Completed sets stay. A swap and a machine change (RM-066) both end
    /// here. Saves, or rolls back and returns false.
    @MainActor
    static func represcribe(_ sessionExercise: SessionExercise, in session: Session, context: ModelContext) -> Bool {
        // SessionFactory's prescription step, with this workout's intent,
        // strategy, block and start date.
        let prescription = SessionFactory.prescription(
            for: sessionExercise.exercise,
            targetRepsLow: sessionExercise.targetRepsLow,
            targetRepsHigh: sessionExercise.targetRepsHigh,
            targetRPE: sessionExercise.targetRPE,
            in: session,
            strategy: ProgressionStrategyFactory.make(for: session.progressionKind),
            userSettings: (try? context.fetch(FetchDescriptor<UserSettings>()))?.first,
            context: context,
            machine: sessionExercise.machine
        )
        sessionExercise.prescribedWeight = prescription.weight
        rebuildPendingWarmups(of: sessionExercise, in: session, prescription: prescription, context: context)

        // Offers now come from the replacement's history and prescription.
        var replacementRows = SessionSetActions.ordered(sessionExercise).filter {
            !$0.isDeleted && $0.sessionExercise?.id == sessionExercise.id
        }
        // Cardio is one bout (RM-062): a lift's other pending rows go.
        if sessionExercise.exercise?.isCardio == true {
            let pending = replacementRows.filter { !$0.isComplete && !$0.isWarmup }
            for extra in pending.dropFirst() { context.delete(extra) }
            let extraIDs = Set(pending.dropFirst().map(\.id))
            replacementRows.removeAll { extraIDs.contains($0.id) }
        }
        for (index, set) in replacementRows.enumerated() {
            set.orderIndex = index
            guard !set.isComplete && !set.isWarmup else { continue }
            set.weight = 0
            set.reps = 0
            set.rpe = nil
            set.wasManualOverride = false
            set.startedAt = nil
            set.durationSeconds = nil
            set.distanceMeters = nil
            set.level = nil
            set.speedKmh = nil
            set.incline = nil
        }
        do {
            try SessionSetActions.saveOrRollBack(context)
            return true
        } catch {
            return false
        }
    }

    /// Moves the finished working sets to a copy of the log that keeps its
    /// exercise, prescription and machine, placed just before it.
    @MainActor
    static func preserveCompletedSets(
        of exercise: SessionExercise,
        in session: Session,
        context: ModelContext
    ) {
        let logged = SessionSetActions.ordered(exercise).filter { $0.isComplete && !$0.isWarmup }
        guard !logged.isEmpty else { return }

        let index = exercise.orderIndex
        for other in (session.exercises ?? []) where other.orderIndex >= index {
            other.orderIndex += 1
        }
        let original = SessionExercise()
        context.insert(original)
        original.session = session
        original.orderIndex = index
        original.exercise = exercise.exercise
        original.exerciseNameSnapshot = exercise.exerciseNameSnapshot
        VariationUndoSnapshot.Prescription(exercise).apply(to: original)

        for (order, set) in logged.enumerated() {
            set.sessionExercise = original
            set.orderIndex = order
        }
    }

    /// Replaces the warm-ups, pending or skipped, with the ramp
    /// SessionFactory's warm-up step builds for the new exercise, or
    /// removes them when it builds none. Only SKIP WARM-UPS completes a
    /// warm-up, so a ramp the card shows as skipped (every warm-up done)
    /// stays skipped, and UNDO brings back the new exercise's ramp.
    /// Without warm-ups nothing changes: a swap never adds a ramp.
    @MainActor
    private static func rebuildPendingWarmups(
        of sessionExercise: SessionExercise,
        in session: Session,
        prescription: SessionFactory.ExercisePrescription,
        context: ModelContext
    ) {
        let sets = SessionSetActions.ordered(sessionExercise)
        let warmups = sets.filter(\.isWarmup)
        guard !warmups.isEmpty else { return }
        let skipped = warmups.allSatisfy(\.isComplete)

        // The deload check a start makes, on this workout's block and start
        // date. The template row's warm-up setting allowed this ramp, so
        // the default applies.
        let scheduledPhase = session.block.flatMap {
            PeriodizationEngine.phase(for: $0, on: session.startedAt)
        }
        let ramp = SessionFactory.warmupRamp(
            for: sessionExercise,
            prescription: prescription,
            deloadActive: scheduledPhase?.kind == .deload,
            warmupConfig: nil
        )
        for warmup in warmups {
            context.delete(warmup)
        }
        for warmup in ramp {
            context.insert(warmup)
            warmup.sessionExercise = sessionExercise
            warmup.isComplete = skipped
        }

        // The new ramp, then the working sets, numbered contiguously as
        // SessionSetActions keeps them.
        let rows = ramp + sets.filter { !$0.isWarmup }
        for (index, row) in rows.enumerated() where row.orderIndex != index {
            row.orderIndex = index
        }
    }
}

#if DEBUG
#Preview("swap exercise sheet") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let ex = Exercise.previewSample(name: "Bench", equipment: .barbell, mechanic: .compound)
    ctx.insert(ex)
    let session = Session()
    session.startedAt = .now
    session.routineSnapshotName = "Push Day A"
    session.intentRaw = Intent.strength.rawValue
    ctx.insert(session)
    let se = SessionExercise()
    se.session = session
    se.exercise = ex
    ctx.insert(se)
    try? ctx.save()
    return SwapExerciseSheet(sessionExercise: se)
        .modelContainer(container)
}
#endif
