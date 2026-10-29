// AddUnplannedExerciseButton.swift
// fitbod
//
// BRU rewrite — Phase 2.1 Plan 08 (Wave 4, UI-REVIEW item 44).
// UI-SPEC v2 § Session logger line 582.
//
// "+ Add Exercise" affordance at the bottom of the session logger's list (SESS-06).
// Rewritten as a BRUDashedSlot per UI-SPEC line 582.
//
// UI-SPEC verbatim:
//   label:  "+ ADD EXERCISE"
//   hint:   "↘ FROM LIBRARY"
//
// Tapping opens ExerciseLibraryView in a sheet; choosing an exercise appends
// a brand-new SessionExercise row to the active Session.exercises ONLY —
// the source Routine.exercises is never touched (PITFALLS-doc #1).
//
// BRU contract:
//   NO systemName plus.circle — removed per UI-SPEC line 582
//   NO Color.accentColor — removed per UI-SPEC line 214
//   NO Capsule() / NO RoundedRectangle / NO .font(.body/.headline/.title/.caption)
//   NO Color(.system*)

import SwiftUI
import SwiftData

public struct AddUnplannedExerciseButton: View {
    @Environment(\.modelContext) private var ctx
    @Bindable public var session: Session
    @State private var presentingPicker = false

    public init(session: Session) {
        self.session = session
    }

    public var body: some View {
        // BRUDashedSlot replaces the old Button + systemName plus.circle icon
        BRUDashedSlot(
            label: "+ ADD EXERCISE",                                                // UI-SPEC verbatim
            hint: "↘ FROM LIBRARY",                                                // UI-SPEC verbatim
            leadingGlyph: "+",
            action: { presentingPicker = true }
        )
        .sheet(isPresented: $presentingPicker) {
            NavigationStack {
                ExerciseLibraryView(onSelect: { exercise in
                    append(exercise: exercise)
                    presentingPicker = false
                })
                .navigationBarHidden(true)
                .safeAreaInset(edge: .top, spacing: 0) {
                    BRUHeaderBar(
                        left: HeaderAction("CANCEL") { presentingPicker = false }, // UI-SPEC verbatim
                        center: "ADD EXERCISE",                                     // UI-SPEC verbatim
                        right: nil
                    )
                }
            }
        }
    }

    /// SESS-06 — append a fresh SessionExercise + 3 planned SetEntry rows.
    /// The source Routine is untouched.
    private func append(exercise: Exercise) {
        // After the last exercise, even if one was removed mid-workout
        // (a count would reuse a live index).
        let nextOrderIndex = ((session.exercises ?? []).map(\.orderIndex).max() ?? -1) + 1

        let se = SessionExercise()
        se.exercise = exercise
        se.exerciseNameSnapshot = exercise.name
        se.orderIndex = nextOrderIndex
        se.session = session
        // PIVOT-02 / PIVOT-05: intent is session-level after Plan 02.
        se.targetSets = 3
        se.targetRepsLow = 8
        se.targetRepsHigh = 12
        se.prescribedRestSeconds = exercise.mechanic == .compound ? 180 : 90
        ctx.insert(se)

        // Seed 3 planned sets with the matching-intent weight hint
        let hint = PreviousMatchingIntent.fetchTopWorkingSet(
            exerciseID: exercise.id,
            intentRaw: session.intentRaw,
            context: ctx,
            excludingSessionID: session.id
        )?.weight ?? 0
        for i in 0..<3 {
            let entry = SetEntry()
            entry.sessionExercise = se
            entry.orderIndex = i
            entry.weight = hint
            entry.reps = 0
            entry.setTypeRaw = SetType.working.rawValue
            entry.isComplete = false
            entry.completedAt = .now
            ctx.insert(entry)
        }
        try? ctx.save()
    }
}

#if DEBUG
#Preview("add unplanned exercise button") {
    let container = PreviewModelContainer.make()
    let ctx = ModelContext(container)
    let session = Session()
    session.startedAt = .now
    session.routineSnapshotName = "Push Day A"
    ctx.insert(session)
    try? ctx.save()
    return AddUnplannedExerciseButton(session: session)
        .modelContainer(container)
        .padding()
        .background(Color.bruPaper)
}
#endif
