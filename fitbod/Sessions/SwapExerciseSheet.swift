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
                    // SESS-05 — mutate SessionExercise.exercise ONLY.
                    // The source RoutineExercise.exercise is untouched.
                    sessionExercise.exercise = exercise
                    sessionExercise.exerciseNameSnapshot = exercise.name

                    // Re-seed pending sets with the new exercise's matching-intent hint.
                    // Committed sets are immutable (PITFALLS-doc #1).
                    // PIVOT-02 / PIVOT-05: intent is read from the parent Session.
                    let hint = PreviousMatchingIntent.fetchTopWorkingSet(
                        exerciseID: exercise.id,
                        intentRaw: sessionExercise.session?.intentRaw ?? Intent.strength.rawValue,
                        context: ctx,
                        excludingSessionID: sessionExercise.session?.id
                    )?.weight ?? 0
                    let pendingSets = (sessionExercise.sets ?? [])
                        .filter { !$0.isComplete }
                    for set in pendingSets {
                        set.weight = hint
                        set.reps = 0
                        set.rpe = nil
                    }
                    try? ctx.save()
                    dismiss()
                })

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
