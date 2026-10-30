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

public struct SwapExerciseSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @Bindable public var sessionExercise: SessionExercise

    public init(sessionExercise: SessionExercise) {
        self.sessionExercise = sessionExercise
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Exercise library — NOT rewritten (out of Phase 2.1 scope per UI-SPEC line 724)
                ExerciseLibraryView(onSelect: { exercise in
                    Self.swap(sessionExercise, to: exercise, context: ctx)
                    dismiss()
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
    }

    // MARK: - Swap

    /// SESS-05 — mutates SessionExercise.exercise ONLY. The source
    /// RoutineExercise.exercise is untouched. The new exercise gets the
    /// prescription and warm-up ramp a workout start would give it, and
    /// the pending working sets are re-seeded for it. Saves immediately.
    @MainActor
    static func swap(_ sessionExercise: SessionExercise, to exercise: Exercise, context: ModelContext) {
        guard let session = sessionExercise.session else { return }
        sessionExercise.exercise = exercise
        sessionExercise.exerciseNameSnapshot = exercise.name

        // SessionFactory's prescription step, with this workout's intent,
        // strategy, block and start date.
        let prescription = SessionFactory.prescription(
            for: exercise,
            targetRepsLow: sessionExercise.targetRepsLow,
            targetRepsHigh: sessionExercise.targetRepsHigh,
            targetRPE: sessionExercise.targetRPE,
            in: session,
            strategy: ProgressionStrategyFactory.make(for: session.progressionKind),
            userSettings: (try? context.fetch(FetchDescriptor<UserSettings>()))?.first,
            context: context
        )
        sessionExercise.prescribedWeight = prescription.weight
        rebuildPendingWarmups(of: sessionExercise, in: session, prescription: prescription, context: context)

        // Re-seed pending working sets with the new exercise's
        // matching-intent hint, as a workout start seeds them. A weight
        // typed for the old exercise is gone, so its "M" goes too.
        // Committed sets are immutable (PITFALLS-doc #1).
        let hint = prescription.previousSet?.weight ?? 0
        let pendingSets = (sessionExercise.sets ?? [])
            .filter { !$0.isComplete && !$0.isWarmup }
        for set in pendingSets {
            set.weight = hint
            set.reps = 0
            set.rpe = nil
            set.wasManualOverride = false
        }
        try? context.save()
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
